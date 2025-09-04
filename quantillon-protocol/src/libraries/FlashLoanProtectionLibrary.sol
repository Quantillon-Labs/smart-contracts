// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title FlashLoanProtectionLibrary
 * @notice Library for protecting contracts against flash loan attacks
 * 
 * @dev This library provides functions to detect and prevent flash loan attacks
 *      by monitoring balance changes during function execution.
 * 
 * @dev Flash loan attacks can occur when:
 *      - An attacker borrows a large amount of tokens
 *      - Manipulates protocol state (e.g., governance votes, price oracles)
 *      - Repays the loan in the same transaction
 *      - Profits from the manipulated state
 * 
 * @dev Protection mechanism:
 *      - Balance checks before and after function execution
 *      - Validation that balances don't decrease unexpectedly
 * 
 * @author Quantillon Labs
 * @custom:security-contact team@quantillon.money
 */
library FlashLoanProtectionLibrary {
    
    /**
     * @notice Validates that a balance change is within acceptable limits
     * @param balanceBefore Balance before operation
     * @param balanceAfter Balance after operation
     * @param maxDecrease Maximum allowed decrease in balance
     * @return bool True if balance change is acceptable
     * @dev This function validates that balances don't decrease beyond acceptable limits.
     *      Currently used by all contract modifiers to prevent flash loan attacks.
     *      A maxDecrease of 0 means no decrease is allowed (strict protection).
     */
    function validateBalanceChange(
        uint256 balanceBefore,
        uint256 balanceAfter,
        uint256 maxDecrease
    ) internal pure returns (bool) {
        if (balanceAfter < balanceBefore) {
            uint256 decrease = balanceBefore - balanceAfter;
            return decrease <= maxDecrease;
        }
        return true;
    }
}
