// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {VaultMath} from "./VaultMath.sol";

/**
 * @title HedgerPoolRedeemMathLibrary
 * @notice Externalized math helpers for redemption and realized PnL transitions
 */
library HedgerPoolRedeemMathLibrary {
    using VaultMath for uint256;

    struct MarginTransition {
        uint256 totalMarginAfter;
        uint256 nextMargin;
        uint256 nextPositionSize;
        uint256 deltaAmount;
        uint256 newMarginRatio;
        bool isProfit;
        bool marginWiped;
    }

    /**
     * @notice Computes realized PnL delta for a redemption share.
     * @dev Derives the realized PnL portion corresponding to `qeuroAmount` being redeemed
     *      from a position with `currentQeuroBacked`, using filled volume and mark price.
     *      Works by:
     *        1. Converting `currentQeuroBacked` to USDC notionals using `price`.
     *        2. Computing total unrealized PnL relative to `filledBefore`.
     *        3. Subtracting `previousRealizedPnL` to get net unrealized.
     *        4. Allocating a proportional share of that PnL to `qeuroAmount`.
     * @param currentQeuroBacked Total QEURO amount currently backed by the position.
     * @param filledBefore Total filled USDC notionals before redemption.
     * @param price Current EUR/USD price scaled as in `VaultMath.mulDiv` context (1e30 factor).
     * @param qeuroAmount QEURO amount being redeemed (share of the position).
     * @param previousRealizedPnL Previously realized PnL stored on the position (signed, 128-bit).
     * @return realizedDelta Signed realized PnL delta attributable to this redemption.
     * @custom:security Pure math helper; no direct security impact.
     * @custom:validation Assumes `currentQeuroBacked > 0` and `qeuroAmount <= currentQeuroBacked`
     *                   are enforced by the caller.
     * @custom:state-changes None – pure function.
     * @custom:events None.
     * @custom:errors None – callers must validate inputs.
     * @custom:reentrancy Not applicable – pure function.
     * @custom:access Library function; callable from HedgerPool only.
     * @custom:oracle Expects `price` to be validated by caller using protocol oracle guards.
     */
    function calculateRedeemPnL(
        uint256 currentQeuroBacked,
        uint256 filledBefore,
        uint256 price,
        uint256 qeuroAmount,
        int128 previousRealizedPnL
    ) external pure returns (int256 realizedDelta) {
        uint256 qeuroValueInUSDC = currentQeuroBacked.mulDiv(price, 1e30);
        int256 totalUnrealizedPnL = filledBefore >= qeuroValueInUSDC
            // forge-lint: disable-next-line(unsafe-typecast)
            ? int256(filledBefore - qeuroValueInUSDC)
            // forge-lint: disable-next-line(unsafe-typecast)
            : -int256(qeuroValueInUSDC - filledBefore);

        int256 netUnrealizedPnL = totalUnrealizedPnL - int256(previousRealizedPnL);
        // forge-lint: disable-next-line(unsafe-typecast)
        uint256 absNetPnL = netUnrealizedPnL >= 0 ? uint256(netUnrealizedPnL) : uint256(-netUnrealizedPnL);
        uint256 pnlShare = qeuroAmount.mulDiv(absNetPnL, currentQeuroBacked);
        // forge-lint: disable-next-line(unsafe-typecast)
        realizedDelta = netUnrealizedPnL >= 0 ? int256(pnlShare) : -int256(pnlShare);
    }

    /**
     * @notice Computes margin/position totals after applying realized PnL.
     * @dev Updates per-position and global margin figures after realizing `realizedDelta`.
     *      Handles both profit and loss cases, including full margin wipe-out.
     *      Caps `nextMargin` and `nextPositionSize` to `uint96` max to stay within packing limits.
     * @param totalMarginBefore Global total margin across all positions before realization.
     * @param currentMargin Margin currently allocated to the position being updated.
     * @param leverage Position leverage used to recompute notional size from margin.
     * @param realizedDelta Signed realized PnL amount to apply to this position.
     * @return t Struct encoding new margin, position size, ratio and flags describing outcome.
     * @custom:security Pure math helper; callers must ensure values fit within business invariants.
     * @custom:validation Assumes `currentMargin` and `totalMarginBefore` are consistent and that
     *                   leverage is a sane protocol value; overflow is bounded by explicit caps.
     * @custom:state-changes None – pure function, returns `MarginTransition` for caller to persist.
     * @custom:events None.
     * @custom:errors None – callers must handle invalid inputs.
     * @custom:reentrancy Not applicable – pure function.
     * @custom:access Library function; intended for HedgerPool internal use.
     * @custom:oracle No direct oracle dependency – uses already-priced PnL delta.
     */
    function computeMarginTransition(
        uint256 totalMarginBefore,
        uint256 currentMargin,
        uint256 leverage,
        int256 realizedDelta
    ) external pure returns (MarginTransition memory t) {
        t.isProfit = realizedDelta > 0;
        if (t.isProfit) {
            // forge-lint: disable-next-line(unsafe-typecast)
            t.deltaAmount = uint256(realizedDelta);
            t.nextMargin = currentMargin + t.deltaAmount;
            if (t.nextMargin > type(uint96).max) t.nextMargin = type(uint96).max;
            t.totalMarginAfter = totalMarginBefore - currentMargin + t.nextMargin;
        } else {
            // forge-lint: disable-next-line(unsafe-typecast)
            t.deltaAmount = uint256(-realizedDelta);
            if (t.deltaAmount >= currentMargin) {
                t.marginWiped = true;
                t.nextMargin = 0;
                t.nextPositionSize = 0;
                t.newMarginRatio = 0;
                t.totalMarginAfter = totalMarginBefore - currentMargin;
                return t;
            }

            t.nextMargin = currentMargin - t.deltaAmount;
            t.totalMarginAfter = totalMarginBefore - t.deltaAmount;
        }

        t.nextPositionSize = t.nextMargin * leverage;
        if (t.nextPositionSize > type(uint96).max) t.nextPositionSize = type(uint96).max;
        t.newMarginRatio = t.nextPositionSize == 0 ? 0 : (t.nextMargin * 10000) / t.nextPositionSize;
    }
}
