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
     * @notice Validates and calculates position opening parameters
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
     * @notice Calculates profit/loss for a position
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
     * @notice Calculates liquidation eligibility
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
     * @notice Calculates reward updates for hedgers
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
     * @notice Validates margin operations
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
     * @notice Generates liquidation commitment hash
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
