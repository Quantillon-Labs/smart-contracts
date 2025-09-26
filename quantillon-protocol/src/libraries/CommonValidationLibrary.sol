// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ErrorLibrary} from "./ErrorLibrary.sol";

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
     * @param addr The address to validate
     * @param errorType The type of address being validated
     */
    function validateNonZeroAddress(address addr, string memory errorType) internal pure {
        if (addr == address(0)) {
            if (keccak256(bytes(errorType)) == keccak256("admin")) {
                revert ErrorLibrary.InvalidAdmin();
            } else if (keccak256(bytes(errorType)) == keccak256("treasury")) {
                revert ErrorLibrary.InvalidTreasury();
            } else if (keccak256(bytes(errorType)) == keccak256("token")) {
                revert ErrorLibrary.InvalidToken();
            } else if (keccak256(bytes(errorType)) == keccak256("oracle")) {
                revert ErrorLibrary.InvalidOracle();
            } else if (keccak256(bytes(errorType)) == keccak256("vault")) {
                revert ErrorLibrary.InvalidVault();
            } else {
                revert ErrorLibrary.InvalidAddress();
            }
        }
    }

    /**
     * @notice Validates that an amount is positive
     * @param amount The amount to validate
     */
    function validatePositiveAmount(uint256 amount) internal pure {
        if (amount == 0) {
            revert ErrorLibrary.InvalidAmount();
        }
    }

    /**
     * @notice Validates that an amount is above minimum threshold
     * @param amount The amount to validate
     * @param minAmount The minimum required amount
     */
    function validateMinAmount(uint256 amount, uint256 minAmount) internal pure {
        if (amount < minAmount) {
            revert ErrorLibrary.InsufficientBalance();
        }
    }

    /**
     * @notice Validates that an amount is below maximum threshold
     * @param amount The amount to validate
     * @param maxAmount The maximum allowed amount
     */
    function validateMaxAmount(uint256 amount, uint256 maxAmount) internal pure {
        if (amount > maxAmount) {
            revert ErrorLibrary.AboveLimit();
        }
    }

    /**
     * @notice Validates that a percentage is within valid range (0-100%)
     * @param percentage The percentage to validate (in basis points)
     * @param maxPercentage The maximum allowed percentage (in basis points)
     */
    function validatePercentage(uint256 percentage, uint256 maxPercentage) internal pure {
        if (percentage > maxPercentage) {
            revert ErrorLibrary.AboveLimit();
        }
    }

    /**
     * @notice Validates that a duration is within valid range
     * @param duration The duration to validate
     * @param minDuration The minimum allowed duration
     * @param maxDuration The maximum allowed duration
     */
    function validateDuration(uint256 duration, uint256 minDuration, uint256 maxDuration) internal pure {
        if (duration < minDuration) {
            revert ErrorLibrary.HoldingPeriodNotMet();
        }
        if (duration > maxDuration) {
            revert ErrorLibrary.AboveLimit();
        }
    }

    /**
     * @notice Validates that a price is valid (greater than zero)
     * @param price The price to validate
     */
    function validatePrice(uint256 price) internal pure {
        if (price == 0) {
            revert ErrorLibrary.InvalidPrice();
        }
    }

    /**
     * @notice Validates that a boolean condition is true
     * @param condition The condition to validate
     * @param errorType The type of error to throw if condition is false
     */
    function validateCondition(bool condition, string memory errorType) internal pure {
        if (!condition) {
            if (keccak256(bytes(errorType)) == keccak256("oracle")) {
                revert ErrorLibrary.InvalidOracle();
            } else if (keccak256(bytes(errorType)) == keccak256("collateralization")) {
                revert ErrorLibrary.InsufficientCollateralization();
            } else if (keccak256(bytes(errorType)) == keccak256("authorization")) {
                revert ErrorLibrary.NotAuthorized();
            } else {
                revert ErrorLibrary.InvalidCondition();
            }
        }
    }

    /**
     * @notice Validates that a count is within limits
     * @param count The current count
     * @param maxCount The maximum allowed count
     */
    function validateCountLimit(uint256 count, uint256 maxCount) internal pure {
        if (count >= maxCount) {
            revert ErrorLibrary.TooManyPositions();
        }
    }

    /**
     * @notice Validates that a balance is sufficient
     * @param balance The current balance
     * @param requiredAmount The required amount
     */
    function validateSufficientBalance(uint256 balance, uint256 requiredAmount) internal pure {
        if (balance < requiredAmount) {
            revert ErrorLibrary.InsufficientBalance();
        }
    }
}
