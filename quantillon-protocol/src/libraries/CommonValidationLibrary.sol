// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {CommonErrorLibrary} from "./CommonErrorLibrary.sol";

/**
 * @title CommonValidationLibrary
 * @notice Common validation functions used across multiple contracts
 * 
 * @dev Main characteristics:
 *      - Consolidates common validation patterns
 *      - Reduces code duplication across contracts
 *      - Uses custom errors for gas efficiency
 *      - Maintains same validation logic
 * 
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
 * @custom:security-contact team@quantillon.money
 */
library CommonValidationLibrary {
    /**
     * @notice Validates that an address is not zero
     * @dev Checks if the provided address is the zero address and reverts with appropriate error
     * @param addr The address to validate
     * @param errorType The type of address being validated (admin, treasury, token, oracle, vault)
     * @custom:security Prevents zero address vulnerabilities in critical operations
     * @custom:validation Ensures all addresses are properly initialized
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors Throws specific custom errors based on errorType
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal library function
     * @custom:oracle No oracle dependencies
     */
    function validateNonZeroAddress(address addr, string memory errorType) internal pure {
        if (addr == address(0)) {
            if (keccak256(bytes(errorType)) == keccak256("admin")) {
                revert CommonErrorLibrary.InvalidAdmin();
            } else if (keccak256(bytes(errorType)) == keccak256("treasury")) {
                revert CommonErrorLibrary.InvalidTreasury();
            } else if (keccak256(bytes(errorType)) == keccak256("token")) {
                revert CommonErrorLibrary.InvalidToken();
            } else if (keccak256(bytes(errorType)) == keccak256("oracle")) {
                revert CommonErrorLibrary.InvalidOracle();
            } else if (keccak256(bytes(errorType)) == keccak256("vault")) {
                revert CommonErrorLibrary.InvalidVault();
            } else {
                revert CommonErrorLibrary.InvalidAddress();
            }
        }
    }

    /**
     * @notice Validates that an amount is positive
     * @dev Ensures the amount is greater than zero to prevent zero-value operations
     * @param amount The amount to validate
     * @custom:security Prevents zero-amount vulnerabilities and invalid operations
     * @custom:validation Ensures amounts are meaningful for business logic
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors Throws InvalidAmount if amount is zero
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal library function
     * @custom:oracle No oracle dependencies
     */
    function validatePositiveAmount(uint256 amount) internal pure {
        if (amount == 0) {
            revert CommonErrorLibrary.InvalidAmount();
        }
    }

    /**
     * @notice Validates that an amount is above minimum threshold
     * @dev Ensures the amount meets the minimum requirement for the operation
     * @param amount The amount to validate
     * @param minAmount The minimum required amount
     * @custom:security Prevents operations with insufficient amounts
     * @custom:validation Ensures amounts meet business requirements
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors Throws InsufficientBalance if amount is below minimum
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal library function
     * @custom:oracle No oracle dependencies
     */
    function validateMinAmount(uint256 amount, uint256 minAmount) internal pure {
        if (amount < minAmount) {
            revert CommonErrorLibrary.InsufficientBalance();
        }
    }

    /**
     * @notice Validates that an amount is below maximum threshold
     * @dev Ensures the amount does not exceed the maximum allowed limit
     * @param amount The amount to validate
     * @param maxAmount The maximum allowed amount
     * @custom:security Prevents operations that exceed system limits
     * @custom:validation Ensures amounts stay within acceptable bounds
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors Throws AboveLimit if amount exceeds maximum
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal library function
     * @custom:oracle No oracle dependencies
     */
    function validateMaxAmount(uint256 amount, uint256 maxAmount) internal pure {
        if (amount > maxAmount) {
            revert CommonErrorLibrary.AboveLimit();
        }
    }

    /**
     * @notice Validates that a percentage is within valid range (0-100%)
     * @dev Ensures percentage values are within acceptable bounds for fees and rates
     * @param percentage The percentage to validate (in basis points)
     * @param maxPercentage The maximum allowed percentage (in basis points)
     * @custom:security Prevents invalid percentage values that could break system logic
     * @custom:validation Ensures percentages are within business rules
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors Throws AboveLimit if percentage exceeds maximum
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal library function
     * @custom:oracle No oracle dependencies
     */
    function validatePercentage(uint256 percentage, uint256 maxPercentage) internal pure {
        if (percentage > maxPercentage) {
            revert CommonErrorLibrary.AboveLimit();
        }
    }

    /**
     * @notice Validates that a duration is within valid range
     * @dev Ensures time-based parameters are within acceptable bounds
     * @param duration The duration to validate
     * @param minDuration The minimum allowed duration
     * @param maxDuration The maximum allowed duration
     * @custom:security Prevents invalid time parameters that could affect system stability
     * @custom:validation Ensures durations meet business requirements
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors Throws HoldingPeriodNotMet or AboveLimit based on validation failure
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal library function
     * @custom:oracle No oracle dependencies
     */
    function validateDuration(uint256 duration, uint256 minDuration, uint256 maxDuration) internal pure {
        if (duration < minDuration) {
            revert CommonErrorLibrary.HoldingPeriodNotMet();
        }
        if (duration > maxDuration) {
            revert CommonErrorLibrary.AboveLimit();
        }
    }

    /**
     * @notice Validates that a price is valid (greater than zero)
     * @dev Ensures price values are meaningful and not zero
     * @param price The price to validate
     * @custom:security Prevents zero-price vulnerabilities in financial operations
     * @custom:validation Ensures prices are valid for calculations
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors Throws InvalidPrice if price is zero
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal library function
     * @custom:oracle No oracle dependencies
     */
    function validatePrice(uint256 price) internal pure {
        if (price == 0) {
            revert CommonErrorLibrary.InvalidPrice();
        }
    }

    /**
     * @notice Validates that a boolean condition is true
     * @dev Generic condition validator that throws specific errors based on error type
     * @param condition The condition to validate
     * @param errorType The type of error to throw if condition is false
     * @custom:security Prevents invalid conditions from proceeding in critical operations
     * @custom:validation Ensures business logic conditions are met
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors Throws specific custom errors based on errorType
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal library function
     * @custom:oracle No oracle dependencies
     */
    function validateCondition(bool condition, string memory errorType) internal pure {
        if (!condition) {
            if (keccak256(bytes(errorType)) == keccak256("oracle")) {
                revert CommonErrorLibrary.InvalidOracle();
            } else if (keccak256(bytes(errorType)) == keccak256("collateralization")) {
                revert CommonErrorLibrary.InsufficientCollateralization();
            } else if (keccak256(bytes(errorType)) == keccak256("authorization")) {
                revert CommonErrorLibrary.NotAuthorized();
            } else {
                revert CommonErrorLibrary.InvalidCondition();
            }
        }
    }

    /**
     * @notice Validates that a count is within limits
     * @dev Ensures count-based operations don't exceed system limits
     * @param count The current count
     * @param maxCount The maximum allowed count
     * @custom:security Prevents operations that exceed system capacity limits
     * @custom:validation Ensures counts stay within acceptable bounds
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors Throws TooManyPositions if count exceeds maximum
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal library function
     * @custom:oracle No oracle dependencies
     */
    function validateCountLimit(uint256 count, uint256 maxCount) internal pure {
        if (count >= maxCount) {
            revert CommonErrorLibrary.TooManyPositions();
        }
    }

    /**
     * @notice Validates that a balance is sufficient
     * @dev Ensures there's enough balance to perform the required operation
     * @param balance The current balance
     * @param requiredAmount The required amount
     * @custom:security Prevents operations with insufficient funds
     * @custom:validation Ensures sufficient balance for operations
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors Throws InsufficientBalance if balance is below required amount
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal library function
     * @custom:oracle No oracle dependencies
     */
    function validateSufficientBalance(uint256 balance, uint256 requiredAmount) internal pure {
        if (balance < requiredAmount) {
            revert CommonErrorLibrary.InsufficientBalance();
        }
    }

    /**
     * @notice Validates that an address is not a contract (for security)
     * @dev Prevents sending funds to potentially malicious contracts
     * @param addr The address to validate
     * @param errorType The type of error to throw if validation fails
     * @custom:security Prevents arbitrary-send vulnerabilities
     * @custom:validation Ensures address is not a contract
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors Throws InvalidAddress if address is a contract
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal library function
     * @custom:oracle No oracle dependencies
     */
    function validateNotContract(address addr, string memory errorType) internal view {
        if (addr.code.length > 0) {
            if (keccak256(bytes(errorType)) == keccak256("treasury")) {
                revert CommonErrorLibrary.InvalidTreasury();
            } else {
                revert CommonErrorLibrary.InvalidAddress();
            }
        }
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
     * @notice Validates slippage protection for token swaps/trades
     * @dev Ensures received amount is within acceptable tolerance of expected
     * @param received The actual amount received
     * @param expected The expected amount
     * @param tolerance The slippage tolerance in basis points
     * @custom:security Prevents excessive slippage attacks in token operations
     * @custom:validation Ensures received amount meets minimum expectations
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors Throws InvalidParameter if slippage exceeds tolerance
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal library function
     * @custom:oracle No oracle dependencies
     */
    function validateSlippage(uint256 received, uint256 expected, uint256 tolerance) internal pure {
        if (received < expected * (10000 - tolerance) / 10000) revert CommonErrorLibrary.InvalidParameter();
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
     * @notice Validates fee amount against maximum allowed fee
     * @dev Ensures fees don't exceed protocol limits (typically in basis points)
     * @param fee The fee amount to validate
     * @param maxFee The maximum allowed fee
     * @custom:security Prevents excessive fees that could harm users
     * @custom:validation Ensures fees stay within protocol limits
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors Throws InvalidParameter if fee exceeds maximum
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal library function
     * @custom:oracle No oracle dependencies
     */
    function validateFee(uint256 fee, uint256 maxFee) internal pure {
        if (fee > maxFee) revert CommonErrorLibrary.InvalidParameter();
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
     * @custom:errors Throws InvalidParameter if threshold exceeds maximum
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal library function
     * @custom:oracle No oracle dependencies
     */
    function validateThreshold(uint256 threshold, uint256 maxThreshold) internal pure {
        if (threshold > maxThreshold) revert CommonErrorLibrary.InvalidParameter();
    }
}
