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
