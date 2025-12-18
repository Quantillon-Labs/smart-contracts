// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {HedgerPoolErrorLibrary} from "./HedgerPoolErrorLibrary.sol";
import {CommonErrorLibrary} from "./CommonErrorLibrary.sol";
import {VaultErrorLibrary} from "./VaultErrorLibrary.sol";

/**
 * @title HedgerPoolValidationLibrary
 * @notice HedgerPool-specific validation functions for Quantillon Protocol
 * 
 * @dev Main characteristics:
 *      - Validation functions specific to HedgerPool operations
 *      - Trading position management validations
 *      - Liquidation system validations
 *      - Margin and leverage validation functions
 * 
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
 * @custom:security-contact team@quantillon.money
 */
library HedgerPoolValidationLibrary {
    /**
     * @notice Validates leverage parameters for trading positions
     * @dev Ensures leverage is within acceptable bounds (> 0 and <= max)
     * @param leverage The leverage multiplier to validate
     * @param maxLeverage The maximum allowed leverage
     * @custom:security Prevents excessive leverage that could cause system instability
     * @custom:validation Ensures leverage is within acceptable risk bounds
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors Throws InvalidLeverage or LeverageTooHigh based on validation
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal library function
     * @custom:oracle No oracle dependencies
     */
    function validateLeverage(uint256 leverage, uint256 maxLeverage) internal pure {
        if (leverage == 0) revert HedgerPoolErrorLibrary.InvalidLeverage();
        if (leverage > maxLeverage) revert HedgerPoolErrorLibrary.LeverageTooHigh();
    }
    
    /**
     * @notice Validates margin ratio to ensure sufficient collateralization
     * @dev Prevents positions from being under-collateralized
     * @param marginRatio The current margin ratio to validate
     * @param minRatio The minimum required margin ratio
     * @custom:security Prevents under-collateralized positions that could cause liquidations
     * @custom:validation Ensures sufficient margin for position safety
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors Throws MarginRatioTooLow if ratio is below minimum
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal library function
     * @custom:oracle No oracle dependencies
     */
    function validateMarginRatio(uint256 marginRatio, uint256 minRatio) internal pure {
        if (marginRatio < minRatio) revert HedgerPoolErrorLibrary.MarginRatioTooLow();
    }
    
    /**
     * @notice Validates margin ratio against maximum limit to prevent excessive collateralization
     * @dev Prevents positions from being over-collateralized (leverage too low)
     * @param marginRatio The current margin ratio to validate
     * @param maxRatio The maximum allowed margin ratio
     * @custom:security Prevents over-collateralization that could reduce capital efficiency
     * @custom:validation Ensures margin ratio stays within acceptable bounds
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors Throws MarginRatioTooHigh if ratio exceeds maximum
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal library function
     * @custom:oracle No oracle dependencies
     */
    function validateMaxMarginRatio(uint256 marginRatio, uint256 maxRatio) internal pure {
        if (marginRatio > maxRatio) revert HedgerPoolErrorLibrary.MarginRatioTooHigh();
    }
    
    /**
     * @notice Validates that a position is active before operations
     * @dev Prevents operations on closed or invalid positions
     * @param isActive The position's active status
     * @custom:security Prevents operations on inactive positions
     * @custom:validation Ensures position is active before modifications
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors Throws PositionNotActive if position is inactive
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal library function
     * @custom:oracle No oracle dependencies
     */
    function validatePositionActive(bool isActive) internal pure {
        if (!isActive) revert CommonErrorLibrary.PositionNotActive();
    }
    
    /**
     * @notice Validates position ownership before allowing operations
     * @dev Security check to ensure only position owner can modify it
     * @param owner The position owner's address
     * @param caller The address attempting the operation
     * @custom:security Prevents unauthorized position modifications
     * @custom:validation Ensures only position owner can modify position
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors Throws PositionOwnerMismatch if caller is not owner
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal library function
     * @custom:oracle No oracle dependencies
     */
    function validatePositionOwner(address owner, address caller) internal pure {
        if (owner != caller) revert HedgerPoolErrorLibrary.PositionOwnerMismatch();
    }
    
    /**
     * @notice Validates position count limits to prevent system overload
     * @dev Enforces maximum positions per user for gas and complexity management
     * @param count The current position count
     * @param max The maximum allowed positions
     * @custom:security Prevents system overload through excessive positions
     * @custom:validation Ensures position count stays within system limits
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors Throws TooManyPositions if count exceeds maximum
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal library function
     * @custom:oracle No oracle dependencies
     */
    function validatePositionCount(uint256 count, uint256 max) internal pure {
        if (count >= max) revert CommonErrorLibrary.TooManyPositions();
    }
    
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
     * @custom:security Prevents position parameters that could destabilize system
     * @custom:validation Ensures all position parameters are within limits
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors Throws specific errors for each parameter that exceeds limits
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal library function
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
        if (netMargin > maxMargin) revert HedgerPoolErrorLibrary.MarginExceedsMaximum();
        if (positionSize > maxPositionSize) revert HedgerPoolErrorLibrary.PositionSizeExceedsMaximum();
        if (eurUsdPrice > maxEntryPrice) revert HedgerPoolErrorLibrary.EntryPriceExceedsMaximum();
        if (leverage > maxLeverage) revert HedgerPoolErrorLibrary.LeverageExceedsMaximum();
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
     * @custom:security Prevents system-wide limits from being exceeded
     * @custom:validation Ensures combined totals stay within system limits
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors Throws TotalMarginExceedsMaximum or TotalExposureExceedsMaximum
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal library function
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
        if (currentMargin + additionalMargin > maxTotalMargin) revert HedgerPoolErrorLibrary.TotalMarginExceedsMaximum();
        if (currentExposure + additionalExposure > maxTotalExposure) revert HedgerPoolErrorLibrary.TotalExposureExceedsMaximum();
    }
    
    /**
     * @notice Validates timestamp fits in uint32 for storage optimization
     * @dev Prevents timestamp overflow when casting to uint32
     * @param timestamp The timestamp to validate
     * @custom:security Prevents timestamp overflow that could cause data corruption
     * @custom:validation Ensures timestamp fits within uint32 bounds
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors Throws TimestampOverflow if timestamp exceeds uint32 max
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal library function
     * @custom:oracle No oracle dependencies
     */
    function validateTimestamp(uint256 timestamp) internal pure {
        if (timestamp > type(uint32).max) revert HedgerPoolErrorLibrary.TimestampOverflow();
    }
    
    /**
     * @notice Validates new margin amount against maximum limit
     * @dev Ensures margin additions don't exceed individual position limits
     * @param newMargin The new total margin amount
     * @param maxMargin Maximum allowed margin per position
     * @custom:security Prevents margin additions that exceed position limits
     * @custom:validation Ensures new margin stays within position limits
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors Throws NewMarginExceedsMaximum if new margin exceeds limit
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal library function
     * @custom:oracle No oracle dependencies
     */
    function validateNewMargin(uint256 newMargin, uint256 maxMargin) internal pure {
        if (newMargin > maxMargin) revert HedgerPoolErrorLibrary.NewMarginExceedsMaximum();
    }
    
    /**
     * @notice Validates pending rewards against maximum accumulation limit
     * @dev Prevents excessive reward accumulation that could cause overflow
     * @param newRewards The new total pending rewards amount
     * @param maxRewards Maximum allowed pending rewards
     * @custom:security Prevents reward overflow that could cause system issues
     * @custom:validation Ensures pending rewards stay within accumulation limits
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors Throws PendingRewardsExceedMaximum if rewards exceed limit
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal library function
     * @custom:oracle No oracle dependencies
     */
    function validatePendingRewards(uint256 newRewards, uint256 maxRewards) internal pure {
        if (newRewards > maxRewards) revert HedgerPoolErrorLibrary.PendingRewardsExceedMaximum();
    }
    
    // Note: validatePositiveAmount moved to CommonValidationLibrary to avoid duplication.
    // Use CommonValidationLibrary.validatePositiveAmount() instead.
    
    /**
     * @notice Validates fee amount against maximum allowed fee
     * @dev Ensures fees don't exceed protocol limits (typically in basis points)
     * @param fee The fee amount to validate
     * @param maxFee The maximum allowed fee
     * @custom:security Prevents excessive fees that could harm users
     * @custom:validation Ensures fees stay within protocol limits
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors Throws FeeTooHigh if fee exceeds maximum
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal library function
     * @custom:oracle No oracle dependencies
     */
    function validateFee(uint256 fee, uint256 maxFee) internal pure {
        if (fee > maxFee) revert VaultErrorLibrary.FeeTooHigh();
    }
    
    /**
     * @notice Validates treasury address is not zero address
     * @dev Prevents setting treasury to zero address which could cause loss of funds
     * @param treasury The treasury address to validate
     * @custom:security Prevents loss of funds by ensuring treasury is properly set
     * @custom:validation Ensures treasury address is valid for fund operations
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors Throws ZeroAddress if treasury is zero address
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal library function
     * @custom:oracle No oracle dependencies
     */
    function validateTreasuryAddress(address treasury) internal pure {
        if (treasury == address(0)) revert CommonErrorLibrary.ZeroAddress();
    }
}
