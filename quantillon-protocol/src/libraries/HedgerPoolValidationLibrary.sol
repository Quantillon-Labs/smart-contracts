// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./ErrorLibrary.sol";

/**
 * @title HedgerPoolValidationLibrary
 * @notice Validation functions for HedgerPool to reduce contract size
 */
library HedgerPoolValidationLibrary {
    /**
     * @notice Validates all position parameters against maximum limits
     * @dev Ensures all position parameters are within acceptable bounds
     * @param netMargin The net margin amount after fees
     * @param positionSize The size of the position
     * @param eurUsdPrice The EUR/USD entry price
     * @param leverage The leverage multiplier
     * @param maxMargin Maximum allowed margin
     * @param maxPositionSize Maximum allowed position size
     * @param maxEntryPrice Maximum allowed entry price
     * @param maxLeverage Maximum allowed leverage
     * @custom:security Validates all position parameters against maximum limits
     * @custom:validation Validates all position parameters against maximum limits
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors Throws various errors if parameters exceed limits
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal function - no access restrictions
     * @custom:oracle No oracle dependencies
     */
    function validatePositionParams(
        uint256 netMargin,
        uint256 positionSize,
        uint256 eurUsdPrice,
        uint256 leverage,
        uint256 maxMargin,
        uint256 maxPositionSize,
        uint256 maxEntryPrice,
        uint256 maxLeverage
    ) internal pure {
        if (netMargin > maxMargin) revert ErrorLibrary.MarginExceedsMaximum();
        if (positionSize > maxPositionSize) revert ErrorLibrary.PositionSizeExceedsMaximum();
        if (eurUsdPrice > maxEntryPrice) revert ErrorLibrary.EntryPriceExceedsMaximum();
        if (leverage > maxLeverage) revert ErrorLibrary.LeverageExceedsMaximum();
    }
    
    /**
     * @notice Validates total margin and exposure limits
     * @dev Ensures combined totals don't exceed system-wide limits
     * @param currentMargin Current total margin
     * @param currentExposure Current total exposure
     * @param additionalMargin Additional margin being added
     * @param additionalExposure Additional exposure being added
     * @param maxTotalMargin Maximum allowed total margin
     * @param maxTotalExposure Maximum allowed total exposure
     * @custom:security Validates total margin and exposure limits
     * @custom:validation Validates total margin and exposure limits
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors Throws various errors if totals exceed limits
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal function - no access restrictions
     * @custom:oracle No oracle dependencies
     */
    function validateTotals(
        uint256 currentMargin,
        uint256 currentExposure,
        uint256 additionalMargin,
        uint256 additionalExposure,
        uint256 maxTotalMargin,
        uint256 maxTotalExposure
    ) internal pure {
        if (currentMargin + additionalMargin > maxTotalMargin) revert ErrorLibrary.TotalMarginExceedsMaximum();
        if (currentExposure + additionalExposure > maxTotalExposure) revert ErrorLibrary.TotalExposureExceedsMaximum();
    }
    
    /**
     * @notice Validates timestamp fits in uint32 for storage optimization
     * @dev Prevents timestamp overflow when casting to uint32
     * @param timestamp The timestamp to validate
     * @custom:security Validates timestamp fits in uint32 for storage optimization
     * @custom:validation Validates timestamp fits in uint32 for storage optimization
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors Throws TimestampOverflow if timestamp exceeds uint32 max
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal function - no access restrictions
     * @custom:oracle No oracle dependencies
     */
    function validateTimestamp(uint256 timestamp) internal pure {
        if (timestamp > type(uint32).max) revert ErrorLibrary.TimestampOverflow();
    }
    
    /**
     * @notice Validates new margin amount against maximum limit
     * @dev Ensures margin additions don't exceed individual position limits
     * @param newMargin The new total margin amount
     * @param maxMargin Maximum allowed margin per position
     * @custom:security Validates new margin amount against maximum limit
     * @custom:validation Validates new margin amount against maximum limit
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors Throws NewMarginExceedsMaximum if margin exceeds limit
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal function - no access restrictions
     * @custom:oracle No oracle dependencies
     */
    function validateNewMargin(uint256 newMargin, uint256 maxMargin) internal pure {
        if (newMargin > maxMargin) revert ErrorLibrary.NewMarginExceedsMaximum();
    }
    
    /**
     * @notice Validates pending rewards against maximum accumulation limit
     * @dev Prevents excessive reward accumulation that could cause overflow
     * @param newRewards The new total pending rewards amount
     * @param maxRewards Maximum allowed pending rewards
     * @custom:security Validates pending rewards against maximum accumulation limit
     * @custom:validation Validates pending rewards against maximum accumulation limit
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors Throws PendingRewardsExceedMaximum if rewards exceed limit
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal function - no access restrictions
     * @custom:oracle No oracle dependencies
     */
    function validatePendingRewards(uint256 newRewards, uint256 maxRewards) internal pure {
        if (newRewards > maxRewards) revert ErrorLibrary.PendingRewardsExceedMaximum();
    }
}
