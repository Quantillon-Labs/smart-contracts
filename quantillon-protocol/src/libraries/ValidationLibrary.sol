// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./ErrorLibrary.sol";

/**
 * @title ValidationLibrary
 * @notice Validation functions for Quantillon Protocol
 * 
 * @dev Main characteristics:
 *      - Comprehensive parameter validation for leverage, margin, fees, and rates
 *      - Time-based validation for holding periods and liquidation cooldowns
 *      - Balance and exposure validation functions
 *      - Array and position validation utilities
 * 
 * @author Quantillon Labs
 * @custom:security-contact team@quantillon.money
 */
library ValidationLibrary {
    /**
     * @notice Validates leverage parameters for trading positions
     * @dev Ensures leverage is within acceptable bounds (> 0 and <= max)
     * @param leverage The leverage multiplier to validate
     * @param maxLeverage The maximum allowed leverage
     */
    function validateLeverage(uint256 leverage, uint256 maxLeverage) internal pure {
        if (leverage == 0) revert ErrorLibrary.InvalidLeverage();
        if (leverage > maxLeverage) revert ErrorLibrary.LeverageTooHigh();
    }
    
    /**
     * @notice Validates margin ratio to ensure sufficient collateralization
     * @dev Prevents positions from being under-collateralized
     * @param marginRatio The current margin ratio to validate
     * @param minRatio The minimum required margin ratio
     */
    function validateMarginRatio(uint256 marginRatio, uint256 minRatio) internal pure {
        if (marginRatio < minRatio) revert ErrorLibrary.MarginRatioTooLow();
    }
    
    /**
     * @notice Validates fee amount against maximum allowed fee
     * @dev Ensures fees don't exceed protocol limits (typically in basis points)
     * @param fee The fee amount to validate
     * @param maxFee The maximum allowed fee
     */
    function validateFee(uint256 fee, uint256 maxFee) internal pure {
        if (fee > maxFee) revert ErrorLibrary.FeeTooHigh();
    }
    
    /**
     * @notice Validates threshold value against maximum limit
     * @dev Used for liquidation thresholds, margin ratios, etc.
     * @param threshold The threshold value to validate
     * @param maxThreshold The maximum allowed threshold
     */
    function validateThreshold(uint256 threshold, uint256 maxThreshold) internal pure {
        if (threshold > maxThreshold) revert ErrorLibrary.InvalidThreshold();
    }
    
    /**
     * @notice Validates that an amount is positive (greater than zero)
     * @dev Essential for token amounts, deposits, withdrawals, etc.
     * @param amount The amount to validate
     */
    function validatePositiveAmount(uint256 amount) internal pure {
        if (amount <= 0) revert ErrorLibrary.InvalidAmount();
    }
    
    /**
     * @notice Validates yield shift percentage (0-100%)
     * @dev Ensures yield shift is within valid range of 0-10000 basis points
     * @param shift The yield shift percentage to validate (in basis points)
     */
    function validateYieldShift(uint256 shift) internal pure {
        if (shift > 10000) revert ErrorLibrary.InvalidYieldShift();
    }
    
    /**
     * @notice Validates adjustment speed for yield shift mechanisms
     * @dev Prevents excessively fast adjustments that could destabilize the system
     * @param speed The adjustment speed to validate
     * @param maxSpeed The maximum allowed adjustment speed
     */
    function validateAdjustmentSpeed(uint256 speed, uint256 maxSpeed) internal pure {
        if (speed > maxSpeed) revert ErrorLibrary.AdjustmentSpeedTooHigh();
    }
    
    /**
     * @notice Validates target ratio for yield distribution mechanisms
     * @dev Ensures ratio is positive and within acceptable bounds
     * @param ratio The target ratio to validate
     * @param maxRatio The maximum allowed ratio
     */
    function validateTargetRatio(uint256 ratio, uint256 maxRatio) internal pure {
        if (ratio == 0) revert ErrorLibrary.InvalidRatio();
        if (ratio > maxRatio) revert ErrorLibrary.TargetRatioTooHigh();
    }
    
    /**
     * @notice Validates liquidation cooldown period to prevent manipulation
     * @dev Uses block numbers to prevent timestamp manipulation attacks
     * @param lastAttempt The block number of the last liquidation attempt
     * @param cooldown The required cooldown period in blocks
     */
    function validateLiquidationCooldown(uint256 lastAttempt, uint256 cooldown) internal view {
        if (block.number < lastAttempt + cooldown) revert ErrorLibrary.LiquidationCooldown();
    }
    
    /**
     * @notice Validates slippage protection for token swaps/trades
     * @dev Ensures received amount is within acceptable tolerance of expected
     * @param received The actual amount received
     * @param expected The expected amount
     * @param tolerance The slippage tolerance in basis points
     */
    function validateSlippage(uint256 received, uint256 expected, uint256 tolerance) internal pure {
        if (received < expected * (10000 - tolerance) / 10000) revert ErrorLibrary.ExcessiveSlippage();
    }
    
    /**
     * @notice Validates that a value meets minimum threshold requirements
     * @dev Used for minimum deposits, stakes, withdrawals, etc.
     * @param value The value to validate
     * @param threshold The minimum required threshold
     */
    function validateThresholdValue(uint256 value, uint256 threshold) internal pure {
        if (value < threshold) revert ErrorLibrary.BelowThreshold();
    }
    
    /**
     * @notice Validates that a position is active before operations
     * @dev Prevents operations on closed or invalid positions
     * @param isActive The position's active status
     */
    function validatePositionActive(bool isActive) internal pure {
        if (!isActive) revert ErrorLibrary.PositionNotActive();
    }
    
    /**
     * @notice Validates position ownership before allowing operations
     * @dev Security check to ensure only position owner can modify it
     * @param owner The position owner's address
     * @param caller The address attempting the operation
     */
    function validatePositionOwner(address owner, address caller) internal pure {
        if (owner != caller) revert ErrorLibrary.PositionOwnerMismatch();
    }
    
    /**
     * @notice Validates position count limits to prevent system overload
     * @dev Enforces maximum positions per user for gas and complexity management
     * @param count The current position count
     * @param max The maximum allowed positions
     */
    function validatePositionCount(uint256 count, uint256 max) internal pure {
        if (count >= max) revert ErrorLibrary.TooManyPositions();
    }
    
    /**
     * @notice Validates that a commitment doesn't already exist
     * @dev Prevents duplicate commitments in liquidation system
     * @param exists Whether the commitment already exists
     */
    function validateCommitmentNotExists(bool exists) internal pure {
        if (exists) revert ErrorLibrary.CommitmentAlreadyExists();
    }
    
    /**
     * @notice Validates that a valid commitment exists
     * @dev Ensures commitment exists before executing liquidation
     * @param exists Whether a valid commitment exists
     */
    function validateCommitment(bool exists) internal pure {
        if (!exists) revert ErrorLibrary.NoValidCommitment();
    }
    
    /**
     * @notice Validates oracle price data integrity
     * @dev Ensures oracle price is valid before using in calculations
     * @param isValid Whether the oracle price is valid and recent
     */
    function validateOraclePrice(bool isValid) internal pure {
        if (!isValid) revert ErrorLibrary.InvalidOraclePrice();
    }
    
    /**
     * @notice Validates treasury address is not zero address
     * @dev Prevents setting treasury to zero address which could cause loss of funds
     * @param treasury The treasury address to validate
     */
    function validateTreasuryAddress(address treasury) internal pure {
        if (treasury == address(0)) revert ErrorLibrary.InvalidTreasuryAddress();
    }
}
