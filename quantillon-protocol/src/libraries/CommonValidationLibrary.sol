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
     * @dev Checks if the provided address is the zero address and reverts with appropriate error.
     *      Uses string comparison which is gas-intensive but maintains backward compatibility.
     *      For new code, prefer using validateNonZeroAddressWithType() with AddressType enum.
     * @param addr The address to validate
     * @param errorType The type of address being validated (admin, treasury, token, oracle, vault)
     * @custom:security Pure; no state change
     * @custom:validation Reverts if addr is zero
     * @custom:state-changes None
     * @custom:events None
     * @custom:errors InvalidAdmin, InvalidTreasury, InvalidToken, InvalidOracle, InvalidVault, InvalidAddress
     * @custom:reentrancy No external calls
     * @custom:access Internal library
     * @custom:oracle None
     */
    function validateNonZeroAddress(address addr, string memory errorType) internal pure {
        if (addr == address(0)) {
            bytes32 errorHash = _keccak256Bytes(errorType);

            if (errorHash == _keccak256Bytes("admin")) {
                revert CommonErrorLibrary.InvalidAdmin();
            }
            if (errorHash == _keccak256Bytes("treasury")) {
                revert CommonErrorLibrary.InvalidTreasury();
            }
            if (errorHash == _keccak256Bytes("token")) {
                revert CommonErrorLibrary.InvalidToken();
            }
            if (errorHash == _keccak256Bytes("oracle")) {
                revert CommonErrorLibrary.InvalidOracle();
            }
            if (errorHash == _keccak256Bytes("vault")) {
                revert CommonErrorLibrary.InvalidVault();
            }
            revert CommonErrorLibrary.InvalidAddress();
        }
    }

    /**
     * @notice Validates that an amount is positive
     * @dev Reverts with InvalidAmount if amount is zero
     * @param amount The amount to validate
     * @custom:security Pure; no state change
     * @custom:validation Reverts if amount is zero
     * @custom:state-changes None
     * @custom:events None
     * @custom:errors InvalidAmount
     * @custom:reentrancy No external calls
     * @custom:access Internal library
     * @custom:oracle None
     */
    function validatePositiveAmount(uint256 amount) internal pure {
        if (amount == 0) {
            revert CommonErrorLibrary.InvalidAmount();
        }
    }

    /**
     * @notice Validates that an amount is above minimum threshold
     * @dev Reverts with InsufficientBalance if amount is below minimum
     * @param amount The amount to validate
     * @param minAmount The minimum required amount
     * @custom:security Pure; no state change
     * @custom:validation Reverts if amount < minAmount
     * @custom:state-changes None
     * @custom:events None
     * @custom:errors InsufficientBalance
     * @custom:reentrancy No external calls
     * @custom:access Internal library
     * @custom:oracle None
     */
    function validateMinAmount(uint256 amount, uint256 minAmount) internal pure {
        if (amount < minAmount) {
            revert CommonErrorLibrary.InsufficientBalance();
        }
    }

    /**
     * @notice Validates that an amount is below maximum threshold
     * @dev Reverts with AboveLimit if amount exceeds maximum
     * @param amount The amount to validate
     * @param maxAmount The maximum allowed amount
     * @custom:security Pure; no state change
     * @custom:validation Reverts if amount > maxAmount
     * @custom:state-changes None
     * @custom:events None
     * @custom:errors AboveLimit
     * @custom:reentrancy No external calls
     * @custom:access Internal library
     * @custom:oracle None
     */
    function validateMaxAmount(uint256 amount, uint256 maxAmount) internal pure {
        if (amount > maxAmount) {
            revert CommonErrorLibrary.AboveLimit();
        }
    }

    /**
     * @notice Validates that a percentage is within valid range
     * @dev Reverts with AboveLimit if percentage exceeds maximum
     * @param percentage The percentage to validate (in basis points)
     * @param maxPercentage The maximum allowed percentage (in basis points)
     * @custom:security Pure; no state change
     * @custom:validation Reverts if percentage > maxPercentage
     * @custom:state-changes None
     * @custom:events None
     * @custom:errors AboveLimit
     * @custom:reentrancy No external calls
     * @custom:access Internal library
     * @custom:oracle None
     */
    function validatePercentage(uint256 percentage, uint256 maxPercentage) internal pure {
        if (percentage > maxPercentage) {
            revert CommonErrorLibrary.AboveLimit();
        }
    }

    /**
     * @notice Validates that a duration is within valid range
     * @dev Reverts with HoldingPeriodNotMet if too short, AboveLimit if too long
     * @param duration The duration to validate
     * @param minDuration The minimum allowed duration
     * @param maxDuration The maximum allowed duration
     * @custom:security Pure; no state change
     * @custom:validation Reverts if duration out of [minDuration, maxDuration]
     * @custom:state-changes None
     * @custom:events None
     * @custom:errors HoldingPeriodNotMet, AboveLimit
     * @custom:reentrancy No external calls
     * @custom:access Internal library
     * @custom:oracle None
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
     * @dev Reverts with InvalidPrice if price is zero
     * @param price The price to validate
     * @custom:security Pure; no state change
     * @custom:validation Reverts if price is zero
     * @custom:state-changes None
     * @custom:events None
     * @custom:errors InvalidPrice
     * @custom:reentrancy No external calls
     * @custom:access Internal library
     * @custom:oracle None
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
     * @custom:security Pure; no state change
     * @custom:validation Reverts if condition is false
     * @custom:state-changes None
     * @custom:events None
     * @custom:errors InvalidOracle, InsufficientCollateralization, NotAuthorized, InvalidCondition
     * @custom:reentrancy No external calls
     * @custom:access Internal library
     * @custom:oracle None
     */
    function validateCondition(bool condition, string memory errorType) internal pure {
        if (!condition) {
            bytes32 errorHash = _keccak256Bytes(errorType);

            if (errorHash == _keccak256Bytes("oracle")) {
                revert CommonErrorLibrary.InvalidOracle();
            }
            if (errorHash == _keccak256Bytes("collateralization")) {
                revert CommonErrorLibrary.InsufficientCollateralization();
            }
            if (errorHash == _keccak256Bytes("authorization")) {
                revert CommonErrorLibrary.NotAuthorized();
            }
            revert CommonErrorLibrary.InvalidCondition();
        }
    }

    /// @notice Internal keccak256 of string using inline assembly (gas-efficient)
    function _keccak256Bytes(string memory s) private pure returns (bytes32) {
        bytes memory b = bytes(s);
        bytes32 result;
        assembly {
            result := keccak256(add(b, 32), mload(b))
        }
        return result;
    }

    /**
     * @notice Validates that a count is within limits
     * @dev Reverts with TooManyPositions if count exceeds or equals maximum
     * @param count The current count
     * @param maxCount The maximum allowed count
     * @custom:security Pure; no state change
     * @custom:validation Reverts if count >= maxCount
     * @custom:state-changes None
     * @custom:events None
     * @custom:errors TooManyPositions
     * @custom:reentrancy No external calls
     * @custom:access Internal library
     * @custom:oracle None
     */
    function validateCountLimit(uint256 count, uint256 maxCount) internal pure {
        if (count >= maxCount) {
            revert CommonErrorLibrary.TooManyPositions();
        }
    }

    /**
     * @notice Validates that a balance is sufficient
     * @dev Reverts with InsufficientBalance if balance is below required amount
     * @param balance The current balance
     * @param requiredAmount The required amount
     * @custom:security Pure; no state change
     * @custom:validation Reverts if balance < requiredAmount
     * @custom:state-changes None
     * @custom:events None
     * @custom:errors InsufficientBalance
     * @custom:reentrancy No external calls
     * @custom:access Internal library
     * @custom:oracle None
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
     * @custom:security View; checks extcodesize
     * @custom:validation Reverts if addr has code
     * @custom:state-changes None
     * @custom:events None
     * @custom:errors InvalidTreasury, InvalidAddress
     * @custom:reentrancy No external calls
     * @custom:access Internal library
     * @custom:oracle None
     */
    function validateNotContract(address addr, string memory errorType) internal view {
        if (addr.code.length > 0) {
            if (keccak256(bytes(errorType)) == keccak256("treasury")) {
                revert CommonErrorLibrary.InvalidTreasury();
            }
            revert CommonErrorLibrary.InvalidAddress();
        }
    }

    /**
     * @notice Validates treasury address is not zero address
     * @dev Reverts with ZeroAddress if treasury is zero address
     * @param treasury The treasury address to validate
     * @custom:security Pure; no state change
     * @custom:validation Reverts if treasury is zero
     * @custom:state-changes None
     * @custom:events None
     * @custom:errors ZeroAddress
     * @custom:reentrancy No external calls
     * @custom:access Internal library
     * @custom:oracle None
     */
    function validateTreasuryAddress(address treasury) internal pure {
        if (treasury == address(0)) revert CommonErrorLibrary.ZeroAddress();
    }

    /**
     * @notice Validates slippage protection for token swaps/trades
     * @dev Reverts with InvalidParameter if slippage exceeds tolerance
     * @param received The actual amount received
     * @param expected The expected amount
     * @param tolerance The slippage tolerance in basis points
     * @custom:security Pure; no state change
     * @custom:validation Reverts if received below expected minus tolerance
     * @custom:state-changes None
     * @custom:events None
     * @custom:errors InvalidParameter
     * @custom:reentrancy No external calls
     * @custom:access Internal library
     * @custom:oracle None
     */
    function validateSlippage(uint256 received, uint256 expected, uint256 tolerance) internal pure {
        if (received < expected * (10000 - tolerance) / 10000) revert CommonErrorLibrary.InvalidParameter();
    }

    /**
     * @notice Validates that a value meets minimum threshold requirements
     * @dev Reverts with BelowThreshold if value is below minimum
     * @param value The value to validate
     * @param threshold The minimum required threshold
     * @custom:security Pure; no state change
     * @custom:validation Reverts if value < threshold
     * @custom:state-changes None
     * @custom:events None
     * @custom:errors BelowThreshold
     * @custom:reentrancy No external calls
     * @custom:access Internal library
     * @custom:oracle None
     */
    function validateThresholdValue(uint256 value, uint256 threshold) internal pure {
        if (value < threshold) revert CommonErrorLibrary.BelowThreshold();
    }

    /**
     * @notice Validates fee amount against maximum allowed fee
     * @dev Reverts with InvalidParameter if fee exceeds maximum
     * @param fee The fee amount to validate
     * @param maxFee The maximum allowed fee
     * @custom:security Pure; no state change
     * @custom:validation Reverts if fee > maxFee
     * @custom:state-changes None
     * @custom:events None
     * @custom:errors InvalidParameter
     * @custom:reentrancy No external calls
     * @custom:access Internal library
     * @custom:oracle None
     */
    function validateFee(uint256 fee, uint256 maxFee) internal pure {
        if (fee > maxFee) revert CommonErrorLibrary.InvalidParameter();
    }

    /**
     * @notice Validates threshold value against maximum limit
     * @dev Reverts with InvalidParameter if threshold exceeds maximum
     * @param threshold The threshold value to validate
     * @param maxThreshold The maximum allowed threshold
     * @custom:security Pure; no state change
     * @custom:validation Reverts if threshold > maxThreshold
     * @custom:state-changes None
     * @custom:events None
     * @custom:errors InvalidParameter
     * @custom:reentrancy No external calls
     * @custom:access Internal library
     * @custom:oracle None
     */
    function validateThreshold(uint256 threshold, uint256 maxThreshold) internal pure {
        if (threshold > maxThreshold) revert CommonErrorLibrary.InvalidParameter();
    }
}
