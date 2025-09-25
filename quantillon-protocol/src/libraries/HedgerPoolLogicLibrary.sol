// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ErrorLibrary} from "./ErrorLibrary.sol";
import {VaultMath} from "./VaultMath.sol";
import {ValidationLibrary} from "./ValidationLibrary.sol";

/**
 * @title HedgerPoolLogicLibrary
 * @notice Logic functions for HedgerPool to reduce contract size
 */
library HedgerPoolLogicLibrary {
    using SafeERC20 for IERC20;
    using VaultMath for uint256;

    struct PositionData {
        uint256 positionSize;
        uint256 margin;
        uint256 entryPrice;
        uint32 entryTime;
        uint32 lastUpdateTime;
        int128 unrealizedPnL;
        uint16 leverage;
        bool isActive;
    }

    struct HedgerData {
        uint256 totalMargin;
        uint256 totalExposure;
        uint128 pendingRewards;
        uint64 lastRewardClaim;
        bool isActive;
    }

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
     * @param maxPositionsPerHedger Maximum positions per hedger
     * @param activePositionCount Current active position count for hedger
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
        uint256 maxPositionsPerHedger,
        uint256 activePositionCount,
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
        ValidationLibrary.validatePositiveAmount(usdcAmount);
        ValidationLibrary.validateLeverage(leverage, maxLeverage);
        ValidationLibrary.validatePositionCount(activePositionCount, maxPositionsPerHedger);

        fee = usdcAmount.percentageOf(entryFee);
        netMargin = usdcAmount - fee;
        positionSize = netMargin.mulDiv(leverage, 1);
        marginRatio = netMargin.mulDiv(10000, positionSize);
        ValidationLibrary.validateMarginRatio(marginRatio, minMarginRatio);
        ValidationLibrary.validateMaxMarginRatio(marginRatio, maxMarginRatio);

        ValidationLibrary.validatePositionParams(
            netMargin, positionSize, eurUsdPrice, leverage,
            maxMargin, maxPositionSize, maxEntryPrice, maxLeverageValue
        );
        ValidationLibrary.validateTimestamp(currentTime);
    }

    /**
     * @notice Calculates profit or loss for a hedge position
     * @dev Computes PnL based on price movement from entry to current price
     * @param positionSize Size of the position in USDC
     * @param entryPrice Price at which the position was opened
     * @param currentPrice Current market price
     * @return Profit (positive) or loss (negative) amount
     * @custom:security No security validations required for pure function
     * @custom:validation None required for pure function
     * @custom:state-changes None (pure function)
     * @custom:events None
     * @custom:errors None
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal function
     * @custom:oracle Uses provided currentPrice parameter
     */
    function calculatePnL(
        uint256 positionSize,
        uint256 entryPrice,
        uint256 currentPrice
    ) internal pure returns (int256) {
        int256 priceChange = int256(entryPrice) - int256(currentPrice);
        
        if (priceChange >= 0) {
            uint256 absPriceChange = uint256(priceChange);
            uint256 intermediate = positionSize.mulDiv(absPriceChange, entryPrice);
            return int256(intermediate);
        } else {
            uint256 absPriceChange = uint256(-priceChange);
            uint256 intermediate = positionSize.mulDiv(absPriceChange, entryPrice);
            return -int256(intermediate);
        }
    }

    /**
     * @notice Determines if a position is eligible for liquidation
     * @dev Checks if position margin ratio is below liquidation threshold
     * @param margin Current margin amount for the position
     * @param positionSize Size of the position in USDC
     * @param entryPrice Price at which the position was opened
     * @param currentPrice Current market price
     * @param liquidationThreshold Liquidation threshold in basis points
     * @return True if position can be liquidated, false otherwise
     * @custom:security No security validations required for pure function
     * @custom:validation None required for pure function
     * @custom:state-changes None (pure function)
     * @custom:events None
     * @custom:errors None
     * @custom:reentrancy Not applicable - pure function
     * @custom:access External pure function
     * @custom:oracle Uses provided currentPrice parameter
     */
    function isPositionLiquidatable(
        uint256 margin,
        uint256 positionSize,
        uint256 entryPrice,
        uint256 currentPrice,
        uint256 liquidationThreshold
    ) external pure returns (bool) {
        int256 pnl = calculatePnL(positionSize, entryPrice, currentPrice);
        int256 effectiveMargin = int256(margin) + pnl;
        
        if (effectiveMargin <= 0) return true;
        
        uint256 marginRatio = uint256(effectiveMargin).mulDiv(10000, positionSize);
        return marginRatio < liquidationThreshold;
    }

    /**
     * @notice Calculates reward updates for hedgers based on interest rate differentials
     * @dev Computes new pending rewards based on time elapsed and interest rates
     * @param totalExposure Total exposure across all positions
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
        if (newPendingRewards < currentPendingRewards) revert ErrorLibrary.RewardOverflow();
        
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
            if (currentMargin < amount) revert ErrorLibrary.InsufficientMargin();
            newMargin = currentMargin - amount;
        }
        
        newMarginRatio = newMargin.mulDiv(10000, positionSize);
        
        if (!isAddition) {
            ValidationLibrary.validateMarginRatio(newMarginRatio, minMarginRatio);
        }
        
        ValidationLibrary.validateNewMargin(newMargin, maxMargin);
    }

    /**
     * @notice Generates a unique liquidation commitment hash
     * @dev Creates a commitment hash for MEV protection in liquidation process
     * @param hedger Address of the hedger whose position will be liquidated
     * @param positionId ID of the position to liquidate
     * @param salt Random salt for commitment uniqueness
     * @param liquidator Address of the liquidator making the commitment
     * @return Commitment hash for liquidation process
     * @custom:security No security validations required for pure function
     * @custom:validation None required for pure function
     * @custom:state-changes None (pure function)
     * @custom:events None
     * @custom:errors None
     * @custom:reentrancy Not applicable - pure function
     * @custom:access External pure function
     * @custom:oracle Not applicable
     */
    function generateLiquidationCommitment(
        address hedger,
        uint256 positionId,
        bytes32 salt,
        address liquidator
    ) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(hedger, positionId, salt, liquidator));
    }
}
