// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {CommonErrorLibrary} from "./CommonErrorLibrary.sol";

/**
 * @title YieldValidationLibrary
 * @notice Yield-specific validation functions for Quantillon Protocol
 * 
 * @dev Main characteristics:
 *      - Validation functions specific to yield operations
 *      - Yield shift mechanism validations
 *      - Slippage protection validations
 *      - Yield distribution validations
 * 
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
 * @custom:security-contact team@quantillon.money
 */
library YieldValidationLibrary {
    /**
     * @notice Validates yield shift percentage (0-100%)
     * @dev Ensures yield shift is within valid range of 0-10000 basis points
     * @param shift The yield shift percentage to validate (in basis points)
     * @custom:security Prevents invalid yield shifts that could destabilize yield distribution
     * @custom:validation Ensures yield shift is within valid percentage range
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors Throws InvalidParameter if shift exceeds 100%
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal library function
     * @custom:oracle No oracle dependencies
     */
    function validateYieldShift(uint256 shift) internal pure {
        if (shift > 10000) revert CommonErrorLibrary.InvalidParameter();
    }
    
    /**
     * @notice Validates adjustment speed for yield shift mechanisms
     * @dev Prevents excessively fast adjustments that could destabilize the system
     * @param speed The adjustment speed to validate
     * @param maxSpeed The maximum allowed adjustment speed
     * @custom:security Prevents rapid adjustments that could destabilize yield mechanisms
     * @custom:validation Ensures adjustment speed stays within safe bounds
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors Throws InvalidParameter if speed exceeds maximum
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal library function
     * @custom:oracle No oracle dependencies
     */
    function validateAdjustmentSpeed(uint256 speed, uint256 maxSpeed) internal pure {
        if (speed > maxSpeed) revert CommonErrorLibrary.InvalidParameter();
    }
    
    /**
     * @notice Validates target ratio for yield distribution mechanisms
     * @dev Ensures ratio is positive and within acceptable bounds
     * @param ratio The target ratio to validate
     * @param maxRatio The maximum allowed ratio
     * @custom:security Prevents invalid ratios that could break yield distribution
     * @custom:validation Ensures ratio is positive and within acceptable bounds
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors Throws InvalidParameter or AboveLimit based on validation
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal library function
     * @custom:oracle No oracle dependencies
     */
    function validateTargetRatio(uint256 ratio, uint256 maxRatio) internal pure {
        if (ratio == 0) revert CommonErrorLibrary.InvalidParameter();
        if (ratio > maxRatio) revert CommonErrorLibrary.AboveLimit();
    }
    
    /**
     * @notice Validates slippage protection for token swaps/trades
     * @dev Ensures received amount is within acceptable tolerance of expected
     * @param received The actual amount received
     * @param expected The expected amount
     * @param tolerance The slippage tolerance in basis points
     * @custom:security Prevents excessive slippage attacks in yield operations
     * @custom:validation Ensures received amount meets minimum expectations
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors Throws ExcessiveSlippage if slippage exceeds tolerance
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal library function
     * @custom:oracle No oracle dependencies
     */
    function validateSlippage(uint256 received, uint256 expected, uint256 tolerance) internal pure {
        if (received < expected * (10000 - tolerance) / 10000) revert CommonErrorLibrary.ExcessiveSlippage();
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
    
    /**
     * @notice Validates that an amount is positive (greater than zero)
     * @dev Essential for token amounts, deposits, withdrawals, etc.
     * @param amount The amount to validate
     * @custom:security Prevents zero-amount operations that could cause issues
     * @custom:validation Ensures amount is positive for meaningful operations
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors Throws InvalidAmount if amount is zero
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal library function
     * @custom:oracle No oracle dependencies
     */
    function validatePositiveAmount(uint256 amount) internal pure {
        if (amount == 0) revert CommonErrorLibrary.InvalidAmount();
    }
}
