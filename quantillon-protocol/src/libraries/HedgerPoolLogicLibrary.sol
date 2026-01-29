// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {HedgerPoolErrorLibrary} from "./HedgerPoolErrorLibrary.sol";
import {VaultMath} from "./VaultMath.sol";
import {HedgerPoolValidationLibrary} from "./HedgerPoolValidationLibrary.sol";
import {CommonValidationLibrary} from "./CommonValidationLibrary.sol";

/**
 * @title HedgerPoolLogicLibrary
 * @notice Logic functions for HedgerPool to reduce contract size
 * 
 * @dev Core P&L Calculation Formulas:
 * 
 * 1. TOTAL UNREALIZED P&L (mark-to-market of current position):
 *    totalUnrealizedPnL = FilledVolume - (QEUROBacked × OraclePrice / 1e30)
 *    - Positive when price drops (hedger profits from short EUR position)
 *    - Negative when price rises (hedger loses from short EUR position)
 * 
 * 2. NET UNREALIZED P&L (after accounting for realized portions):
 *    netUnrealizedPnL = totalUnrealizedPnL - realizedPnL
 *    - Used when margin has been adjusted by realized P&L during redemptions
 *    - Prevents double-counting since margin already reflects realized P&L
 * 
 * 3. EFFECTIVE MARGIN (true economic value of position):
 *    effectiveMargin = margin + netUnrealizedPnL
 *    - Represents what the hedger would have if position closed now
 *    - Used for collateralization checks and available collateral calculations
 * 
 * 4. LIQUIDATION MODE (CR ≤ 101%):
 *    In liquidation mode, the entire hedger margin is considered at risk.
 *    unrealizedPnL = -margin, meaning effectiveMargin = 0
 * 
 * @author Quantillon Labs
 */
library HedgerPoolLogicLibrary {
    using VaultMath for uint256;

    /**
     * @notice Validates position parameters and calculates derived values
     * @dev Validates all position constraints and calculates fee, margin, and position size
     * @param usdcAmount Amount of USDC to deposit
     * @param leverage Leverage multiplier for the position
     * @param eurUsdPrice Current EUR/USD price from oracle
     * @param entryFee Entry fee rate in basis points
     * @param minMarginRatio Minimum margin ratio in basis points
     * @param maxMarginRatio Maximum margin ratio in basis points
     * @param maxLeverage Maximum allowed leverage
     * @param maxMargin Maximum margin per position
     * @param maxPositionSize Maximum position size
     * @param maxEntryPrice Maximum entry price
     * @param maxLeverageValue Maximum leverage value
     * @param currentTime Current timestamp
     * @return fee Calculated entry fee
     * @return netMargin Net margin after fee deduction
     * @return positionSize Calculated position size
     * @return marginRatio Calculated margin ratio
     * @custom:security Validates all position constraints and limits
     * @custom:validation Ensures amounts, leverage, and ratios are within limits
     * @custom:state-changes None (pure function)
     * @custom:events None
     * @custom:errors Throws various validation errors if constraints not met
     * @custom:reentrancy Not applicable - pure function
     * @custom:access External pure function
     * @custom:oracle Uses provided eurUsdPrice parameter
     */

    function validateAndCalculatePositionParams(
        uint256 usdcAmount,
        uint256 leverage,
        uint256 eurUsdPrice,
        uint256 entryFee,
        uint256 minMarginRatio,
        uint256 maxMarginRatio,
        uint256 maxLeverage,
        uint256 maxMargin,
        uint256 maxPositionSize,
        uint256 maxEntryPrice,
        uint256 maxLeverageValue,
        uint256 currentTime
    ) external pure returns (
        uint256 fee,
        uint256 netMargin,
        uint256 positionSize,
        uint256 marginRatio
    ) {
        // Validate basic parameters first
        CommonValidationLibrary.validatePositiveAmount(usdcAmount);
        HedgerPoolValidationLibrary.validateLeverage(leverage, maxLeverage);

        // Calculate basic values
        fee = usdcAmount.percentageOf(entryFee);
        netMargin = usdcAmount - fee;
        positionSize = netMargin.mulDiv(leverage, 1);
        marginRatio = netMargin.mulDiv(10000, positionSize);
        
        // Validate calculated values
        HedgerPoolValidationLibrary.validateMarginRatio(marginRatio, minMarginRatio);
        HedgerPoolValidationLibrary.validateMaxMarginRatio(marginRatio, maxMarginRatio);

        // Final validation with all parameters
        HedgerPoolValidationLibrary.validatePositionParams(
            netMargin, positionSize, eurUsdPrice, leverage,
            maxMargin, maxPositionSize, maxEntryPrice, maxLeverageValue
        );
        HedgerPoolValidationLibrary.validateTimestamp(currentTime);
    }


    /**
     * @notice Calculates TOTAL unrealized P&L for a hedge position (mark-to-market)
     * @dev Formula: TotalUnrealizedP&L = FilledVolume - (QEUROBacked × OraclePrice / 1e30)
     * 
     * Hedgers are SHORT EUR (they owe QEURO to users). When price rises, they lose.
     * - Price UP → qeuroValueInUSDC increases → P&L becomes more negative → hedger loses
     * - Price DOWN → qeuroValueInUSDC decreases → P&L becomes more positive → hedger profits
     * 
     * This returns the TOTAL unrealized P&L for the current position state.
     * To get NET unrealized P&L (after partial redemptions), subtract realizedPnL from this value.
     * 
     * @param filledVolume Size of the filled position in USDC (6 decimals)
     * @param qeuroBacked Exact QEURO amount backed by this position (18 decimals)
     * @param currentPrice Current EUR/USD oracle price (18 decimals)
     * @return Profit (positive) or loss (negative) amount in USDC (6 decimals)
     * @custom:security No security validations required for pure function
     * @custom:validation Validates filledVolume and currentPrice are non-zero
     * @custom:state-changes None (pure function)
     * @custom:events None (pure function)
     * @custom:errors None (returns 0 for edge cases)
     * @custom:reentrancy Not applicable (pure function)
     * @custom:access Internal library function
     * @custom:oracle Uses provided currentPrice parameter (must be fresh oracle data)
     */
    function calculatePnL(
        uint256 filledVolume,
        uint256 qeuroBacked,
        uint256 currentPrice
    ) internal pure returns (int256) {
        // Edge case: If no filled volume or price, return 0
        if (filledVolume == 0 || currentPrice == 0) {
            return 0;
        }
        
        // Special case: When all QEURO is redeemed (qeuroBacked == 0), but filledVolume still exists,
        // the remaining filledVolume represents a loss that should be shown as unrealized P&L
        if (qeuroBacked == 0) {
            // Return negative filledVolume as unrealized loss
            // forge-lint: disable-next-line(unsafe-typecast)
            return -int256(filledVolume);
        }

        // Formula: UnrealizedP&L = FilledVolume - QEUROBacked * OracleCurrentPrice
        // filledVolume is in 6 decimals (USDC)
        // qeuroBacked is in 18 decimals (QEURO)
        // currentPrice is in 18 decimals (USD/EUR)
        // qeuroBacked * currentPrice gives USDC value in 36 decimals
        // Divide by 1e30 to convert to 6 decimals (USDC)
        uint256 qeuroValueInUSDC = qeuroBacked.mulDiv(currentPrice, 1e30);

        // Calculate P&L: filledVolume - qeuroValueInUSDC
        // Both are in 6 decimals, result is in 6 decimals
        if (filledVolume >= qeuroValueInUSDC) {
            // forge-lint: disable-next-line(unsafe-typecast)
            return int256(filledVolume - qeuroValueInUSDC);
        } else {
            // forge-lint: disable-next-line(unsafe-typecast)
            return -int256(qeuroValueInUSDC - filledVolume);
        }
    }

    /**
     * @notice Calculates collateral-based capacity for a position
     * @dev Returns how much additional USDC exposure a position can absorb
     * 
     * Formula breakdown:
     * 1. totalUnrealizedPnL = calculatePnL(filledVolume, qeuroBacked, currentPrice)
     * 2. netUnrealizedPnL = totalUnrealizedPnL - realizedPnL
     *    (margin already reflects realized P&L, so we use net unrealized to avoid double-counting)
     * 3. effectiveMargin = margin + netUnrealizedPnL
     * 4. requiredMargin = (qeuroBacked × currentPrice / 1e30) × minMarginRatio / 10000
     * 5. availableCollateral = effectiveMargin - requiredMargin
     * 6. capacity = availableCollateral × 10000 / minMarginRatio
     * 
     * @param margin Position margin in USDC (6 decimals)
     * @param filledVolume Current filled volume in USDC (6 decimals)
     * @param currentPrice Current EUR/USD oracle price (18 decimals)
     * @param minMarginRatio Minimum margin ratio in basis points (e.g., 500 = 5%)
     * @param realizedPnL Cumulative realized P&L from partial redemptions (6 decimals, signed)
     * @param qeuroBacked Exact QEURO amount backed by this position (18 decimals)
     * @return capacity Additional USDC exposure the position can absorb (6 decimals)
     * @custom:security No security validations required for pure function
     * @custom:validation Validates currentPrice > 0 and minMarginRatio > 0
     * @custom:state-changes None (pure function)
     * @custom:events None (pure function)
     * @custom:errors None (returns 0 for invalid inputs)
     * @custom:reentrancy Not applicable (pure function)
     * @custom:access Internal library function
     * @custom:oracle Uses provided currentPrice parameter (must be fresh oracle data)
     */
    function calculateCollateralCapacity(
        uint256 margin,
        uint256 filledVolume,
        uint256 /* entryPrice */,
        uint256 currentPrice,
        uint256 minMarginRatio,
        int128 realizedPnL,
        uint128 qeuroBacked
    ) internal pure returns (uint256) {
        if (currentPrice == 0 || minMarginRatio == 0) return 0;
        
        // Calculate total unrealized P&L (mark-to-market of current position)
        int256 totalUnrealizedPnL = calculatePnL(filledVolume, uint256(qeuroBacked), currentPrice);
        
        // Calculate net unrealized P&L (total unrealized - realized)
        // The margin has already been adjusted by realized P&L during redemptions,
        // so we subtract realizedPnL to avoid double-counting.
        // This matches the formula used in isPositionLiquidatable and scenario scripts.
        // forge-lint: disable-next-line(unsafe-typecast)
        int256 netUnrealizedPnL = totalUnrealizedPnL - int256(realizedPnL);

        // Effective margin = margin + net unrealized P&L
        // forge-lint: disable-next-line(unsafe-typecast)
        int256 effectiveMargin = int256(margin) + netUnrealizedPnL;
        if (effectiveMargin <= 0) return 0;

        // Required margin is based on exact QEURO backed × current price
        // mintedExposure = qeuroBacked × currentPrice / 1e30 (converts to 6 decimals USDC)
        uint256 mintedExposure = uint256(qeuroBacked).mulDiv(currentPrice, 1e30);
        uint256 requiredMargin = mintedExposure.mulDiv(minMarginRatio, 10000);

        // Available collateral = effectiveMargin - requiredMargin
        // forge-lint: disable-next-line(unsafe-typecast)
        if (uint256(effectiveMargin) <= requiredMargin) return 0;
        // forge-lint: disable-next-line(unsafe-typecast)
        uint256 availableCollateral = uint256(effectiveMargin) - requiredMargin;
        
        // Capacity = availableCollateral / minMarginRatio × 10000
        return availableCollateral.mulDiv(10000, minMarginRatio);
    }

    /**
     * @notice Determines if a position is eligible for liquidation
     * @dev Checks if position margin ratio falls below the liquidation threshold
     * 
     * Formula breakdown:
     * 1. totalUnrealizedPnL = calculatePnL(filledVolume, qeuroBacked, currentPrice)
     * 2. netUnrealizedPnL = totalUnrealizedPnL - realizedPnL
     *    (margin already reflects realized P&L, so we use net unrealized to avoid double-counting)
     * 3. effectiveMargin = margin + netUnrealizedPnL
     * 4. qeuroValueInUSDC = qeuroBacked × currentPrice / 1e30
     * 5. marginRatio = effectiveMargin × 10000 / qeuroValueInUSDC
     * 6. liquidatable = marginRatio < liquidationThreshold
     * 
     * @param margin Current margin amount for the position (6 decimals USDC)
     * @param filledVolume Filled size of the position in USDC (6 decimals)
     * @param currentPrice Current EUR/USD oracle price (18 decimals)
     * @param liquidationThreshold Minimum margin ratio in basis points (e.g., 500 = 5%)
     * @param qeuroBacked Exact QEURO amount backed by this position (18 decimals)
     * @param realizedPnL Cumulative realized P&L from partial redemptions (6 decimals, signed)
     * @return True if position margin ratio is below threshold, false otherwise
     * @custom:security No security validations required for pure function
     * @custom:validation Validates currentPrice > 0 and liquidationThreshold > 0
     * @custom:state-changes None (pure function)
     * @custom:events None (pure function)
     * @custom:errors None (returns false for invalid inputs)
     * @custom:reentrancy Not applicable (pure function)
     * @custom:access Internal library function
     * @custom:oracle Uses provided currentPrice parameter (must be fresh oracle data)
     */
    function isPositionLiquidatable(
        uint256 margin,
        uint256 filledVolume,
        uint256 /* entryPrice */,
        uint256 currentPrice,
        uint256 liquidationThreshold,
        uint128 qeuroBacked,
        int128 realizedPnL
    ) external pure returns (bool) {
        // No exposure means no liquidation risk
        if (qeuroBacked == 0 || currentPrice == 0) {
            return false;
        }

        // Calculate total unrealized P&L (mark-to-market of current position)
        int256 totalUnrealizedPnL = calculatePnL(filledVolume, uint256(qeuroBacked), currentPrice);
        
        // Calculate net unrealized P&L (total unrealized - realized)
        // The margin has already been adjusted by realized P&L during redemptions,
        // so we subtract realizedPnL to avoid double-counting.
        // forge-lint: disable-next-line(unsafe-typecast)
        int256 netUnrealizedPnL = totalUnrealizedPnL - int256(realizedPnL);

        // Effective margin = margin + net unrealized P&L
        // forge-lint: disable-next-line(unsafe-typecast)
        int256 effectiveMargin = int256(margin) + netUnrealizedPnL;

        // If effective margin is zero or negative, position is definitely liquidatable
        if (effectiveMargin <= 0) return true;

        // Calculate current QEURO value in USDC: (qeuroBacked × currentPrice) / 1e30
        // qeuroBacked (18 dec) × currentPrice (18 dec) = 36 dec, divide by 1e30 → 6 dec
        uint256 qeuroValueInUSDC = (uint256(qeuroBacked) * currentPrice) / 1e30;

        if (qeuroValueInUSDC == 0) return false;

        // Calculate margin ratio: effectiveMargin / qeuroValueInUSDC × 10000
        // Position is liquidatable if marginRatio < liquidationThreshold
        // forge-lint: disable-next-line(unsafe-typecast)
        uint256 marginRatio = uint256(effectiveMargin).mulDiv(10000, qeuroValueInUSDC);
        return marginRatio < liquidationThreshold;
    }

    /**
     * @notice Calculates reward updates for hedgers based on interest rate differentials
     * @dev Computes new pending rewards based on time elapsed and interest rates
     * @param totalExposure Total exposure for the hedger position
     * @param eurInterestRate EUR interest rate in basis points
     * @param usdInterestRate USD interest rate in basis points
     * @param lastRewardBlock Block number of last reward calculation
     * @param currentBlock Current block number
     * @param maxRewardPeriod Maximum reward period in blocks
     * @param currentPendingRewards Current pending rewards amount
     * @return newPendingRewards Updated pending rewards amount
     * @return newLastRewardBlock Updated last reward block
     * @custom:security No security validations required for pure function
     * @custom:validation None required for pure function
     * @custom:state-changes None (pure function)
     * @custom:events None
     * @custom:errors None
     * @custom:reentrancy Not applicable - pure function
     * @custom:access External pure function
     * @custom:oracle Not applicable
     */
    function calculateRewardUpdate(
        uint256 totalExposure,
        uint256 eurInterestRate,
        uint256 usdInterestRate,
        uint256 lastRewardBlock,
        uint256 currentBlock,
        uint256 maxRewardPeriod,
        uint256 currentPendingRewards
    ) external pure returns (uint256 newPendingRewards, uint256 newLastRewardBlock) {
        if (totalExposure == 0) {
            return (currentPendingRewards, currentBlock);
        }
        
        if (lastRewardBlock < 1) {
            return (currentPendingRewards, currentBlock);
        }
        
        uint256 blocksElapsed = currentBlock - lastRewardBlock;
        uint256 timeElapsed = blocksElapsed * 12;
        
        if (timeElapsed > maxRewardPeriod) {
            timeElapsed = maxRewardPeriod;
        }
        
        uint256 interestDifferential = usdInterestRate > eurInterestRate ? 
            usdInterestRate - eurInterestRate : 0;
        
        uint256 reward = totalExposure
            .mulDiv(interestDifferential, 10000)
            .mulDiv(timeElapsed, 365 days);
        
        newPendingRewards = currentPendingRewards + reward;
        if (newPendingRewards < currentPendingRewards) revert HedgerPoolErrorLibrary.RewardOverflow();
        
        newLastRewardBlock = currentBlock;
    }

    /**
     * @notice Validates margin operations and calculates new margin values
     * @dev Validates margin addition/removal and calculates resulting margin ratio
     * @param currentMargin Current margin amount for the position
     * @param amount Amount of margin to add or remove
     * @param isAddition True if adding margin, false if removing
     * @param minMarginRatio Minimum margin ratio in basis points
     * @param positionSize Size of the position in USDC
     * @param maxMargin Maximum margin per position
     * @return newMargin New margin amount after operation
     * @return newMarginRatio New margin ratio after operation
     * @custom:security Validates margin constraints and limits
     * @custom:validation Ensures margin operations are within limits
     * @custom:state-changes None (pure function)
     * @custom:events None
     * @custom:errors Throws InsufficientMargin or validation errors
     * @custom:reentrancy Not applicable - pure function
     * @custom:access External pure function
     * @custom:oracle Not applicable
     */
    function validateMarginOperation(
        uint256 currentMargin,
        uint256 amount,
        bool isAddition,
        uint256 minMarginRatio,
        uint256 positionSize,
        uint256 maxMargin
    ) external pure returns (uint256 newMargin, uint256 newMarginRatio) {
        if (isAddition) {
            newMargin = currentMargin + amount;
        } else {
            if (currentMargin < amount) revert HedgerPoolErrorLibrary.InsufficientMargin();
            newMargin = currentMargin - amount;
        }
        
        newMarginRatio = newMargin.mulDiv(10000, positionSize);
        
        if (!isAddition) {
            HedgerPoolValidationLibrary.validateMarginRatio(newMarginRatio, minMarginRatio);
        }
        
        HedgerPoolValidationLibrary.validateNewMargin(newMargin, maxMargin);
    }

}
