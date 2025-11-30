// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {CommonErrorLibrary} from "./CommonErrorLibrary.sol";

/**
 * @title TokenValidationLibrary
 * @notice Token-specific validation functions for Quantillon Protocol
 * 
 * @dev Main characteristics:
 *      - Validation functions specific to token operations
 *      - Fee and threshold validations
 *      - Oracle price validations
 *      - Treasury address validations
 * 
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
 * @custom:security-contact team@quantillon.money
 */
library TokenValidationLibrary {
    /**
     * @notice Validates fee amount against maximum allowed fee
     * @dev Ensures fees don't exceed protocol limits (typically in basis points)
     * @param fee The fee amount to validate
     * @param maxFee The maximum allowed fee
     * @custom:security Prevents excessive fees that could harm users
     * @custom:validation Ensures fees stay within protocol limits
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors Throws AboveLimit if fee exceeds maximum
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal library function
     * @custom:oracle No oracle dependencies
     */
    function validateFee(uint256 fee, uint256 maxFee) internal pure {
        if (fee > maxFee) revert CommonErrorLibrary.AboveLimit();
    }
    
    /**
     * @notice Validates threshold value against maximum limit
     * @dev Used for liquidation thresholds, margin ratios, etc.
     * @param threshold The threshold value to validate
     * @param maxThreshold The maximum allowed threshold
     * @custom:security Prevents thresholds that could destabilize the system
     * @custom:validation Ensures thresholds stay within acceptable bounds
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors Throws AboveLimit if threshold exceeds maximum
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal library function
     * @custom:oracle No oracle dependencies
     */
    function validateThreshold(uint256 threshold, uint256 maxThreshold) internal pure {
        if (threshold > maxThreshold) revert CommonErrorLibrary.AboveLimit();
    }
    
    /**
     * @notice Validates that a value meets minimum threshold requirements
     * @dev Used for minimum deposits, stakes, withdrawals, etc.
     * @param value The value to validate
     * @param threshold The minimum required threshold
     * @custom:security Prevents operations below minimum thresholds
     * @custom:validation Ensures values meet business requirements
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors Throws BelowThreshold if value is below minimum
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal library function
     * @custom:oracle No oracle dependencies
     */
    function validateThresholdValue(uint256 value, uint256 threshold) internal pure {
        if (value < threshold) revert CommonErrorLibrary.BelowThreshold();
    }
    
    /**
     * @notice Validates oracle price data integrity
     * @dev Ensures oracle price is valid before using in calculations
     * @param isValid Whether the oracle price is valid and recent
     * @custom:security Prevents use of invalid oracle data that could cause financial losses
     * @custom:validation Ensures oracle price data is valid and recent
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors Throws InvalidParameter if oracle price is invalid
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal library function
     * @custom:oracle Validates oracle price data integrity
     */
    function validateOraclePrice(bool isValid) internal pure {
        if (!isValid) revert CommonErrorLibrary.InvalidParameter();
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
    
    // Note: validatePositiveAmount moved to CommonValidationLibrary to avoid duplication.
    // Use CommonValidationLibrary.validatePositiveAmount() instead.
}
