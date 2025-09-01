// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./ErrorLibrary.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title FlashLoanProtection
 * @notice Library for protecting contracts against flash loan attacks
 * 
 * @dev This library provides modifiers and functions to detect and prevent flash loan attacks
 *      by monitoring balance changes during function execution.
 * 
 * @dev Flash loan attacks can occur when:
 *      - An attacker borrows a large amount of tokens
 *      - Manipulates protocol state (e.g., governance votes, price oracles)
 *      - Repays the loan in the same transaction
 *      - Profits from the manipulated state
 * 
 * @dev Protection mechanisms:
 *      - Balance checks before and after function execution
 *      - State validation to ensure no unexpected changes
 *      - Rate limiting for sensitive operations
 *      - Timestamp-based cooldowns for critical functions
 * 
 * @author Quantillon Labs
 * @custom:security-contact team@quantillon.money
 */
library FlashLoanProtection {
    
    // =============================================================================
    // EVENTS
    // =============================================================================
    
    /**
     * @notice Emitted when flash loan protection is triggered
     * @param contractAddress Address of the contract where protection was triggered
     * @param functionName Name of the function that triggered protection
     * @param balanceBefore Balance before function execution
     * @param balanceAfter Balance after function execution
     * @param timestamp Timestamp when protection was triggered
     */
    event FlashLoanProtectionTriggered(
        address indexed contractAddress,
        string indexed functionName,
        uint256 balanceBefore,
        uint256 balanceAfter,
        uint256 timestamp
    );
    
    // =============================================================================
    // FLASH LOAN PROTECTION MODIFIERS
    // =============================================================================
    
    /**
     * @notice Modifier to protect against flash loan attacks using ETH balance
     * @dev Checks that the contract's ETH balance doesn't decrease during execution
     * @dev This prevents flash loans that would drain ETH from the contract
     */
    modifier flashLoanProtectionETH() {
        uint256 balanceBefore = address(this).balance;
        _;
        require(address(this).balance >= balanceBefore, "Flash loan detected: ETH balance decreased");
    }
    
    /**
     * @notice Modifier to protect against flash loan attacks using token balance
     * @param token Address of the token to monitor
     * @dev Checks that the contract's token balance doesn't decrease during execution
     * @dev This prevents flash loans that would drain tokens from the contract
     */
    modifier flashLoanProtectionToken(address token) {
        uint256 balanceBefore = IERC20(token).balanceOf(address(this));
        _;
        uint256 balanceAfter = IERC20(token).balanceOf(address(this));
        require(balanceAfter >= balanceBefore, "Flash loan detected: Token balance decreased");
    }
    
    /**
     * @notice Modifier to protect against flash loan attacks with custom validation
     * @param token Address of the token to monitor
     * @param minBalance Minimum balance that must be maintained
     * @dev Checks that the contract's token balance doesn't fall below minimum
     * @dev This prevents flash loans that would reduce balance below safe threshold
     */
    modifier flashLoanProtectionWithMinimum(address token, uint256 minBalance) {
        uint256 balanceBefore = IERC20(token).balanceOf(address(this));
        _;
        uint256 balanceAfter = IERC20(token).balanceOf(address(this));
        require(balanceAfter >= minBalance, "Flash loan detected: Balance below minimum");
        require(balanceAfter >= balanceBefore, "Flash loan detected: Token balance decreased");
    }
    
    /**
     * @notice Modifier to protect against flash loan attacks with state validation
     * @param token Address of the token to monitor
     * @param stateValidator Function to validate state consistency
     * @dev Checks balance and validates state consistency
     * @dev This prevents flash loans that manipulate protocol state
     */
    modifier flashLoanProtectionWithState(
        address token, 
        function() internal view returns (bool) stateValidator
    ) {
        uint256 balanceBefore = IERC20(token).balanceOf(address(this));
        bool stateBefore = stateValidator();
        _;
        uint256 balanceAfter = IERC20(token).balanceOf(address(this));
        bool stateAfter = stateValidator();
        
        require(balanceAfter >= balanceBefore, "Flash loan detected: Token balance decreased");
        require(stateAfter == stateBefore, "Flash loan detected: State inconsistency");
    }
    
    // =============================================================================
    // FLASH LOAN PROTECTION FUNCTIONS
    // =============================================================================
    
    /**
     * @notice Validates that a balance change is within acceptable limits
     * @param balanceBefore Balance before operation
     * @param balanceAfter Balance after operation
     * @param maxDecrease Maximum allowed decrease in balance
     * @return bool True if balance change is acceptable
     * @dev This function can be used for custom validation logic
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
    
    /**
     * @notice Validates that a percentage change is within acceptable limits
     * @param valueBefore Value before operation
     * @param valueAfter Value after operation
     * @param maxPercentageDecrease Maximum allowed percentage decrease (in basis points)
     * @return bool True if percentage change is acceptable
     * @dev This function can be used for custom validation logic
     */
    function validatePercentageChange(
        uint256 valueBefore,
        uint256 valueAfter,
        uint256 maxPercentageDecrease
    ) internal pure returns (bool) {
        if (valueAfter < valueBefore) {
            uint256 decrease = valueBefore - valueAfter;
            uint256 percentageDecrease = (decrease * 10000) / valueBefore;
            return percentageDecrease <= maxPercentageDecrease;
        }
        return true;
    }
    
    /**
     * @notice Checks for potential flash loan attack patterns
     * @param balanceBefore Balance before operation
     * @param balanceAfter Balance after operation
     * @param operationType Type of operation being performed
     * @return bool True if no flash loan attack detected
     * @dev This function implements heuristic detection of flash loan attacks
     */
    function detectFlashLoanAttack(
        uint256 balanceBefore,
        uint256 balanceAfter,
        string memory operationType
    ) internal pure returns (bool) {
        // Check for suspicious balance decreases
        if (balanceAfter < balanceBefore) {
            uint256 decrease = balanceBefore - balanceAfter;
            uint256 percentageDecrease = (decrease * 10000) / balanceBefore;
            
            // Flag large percentage decreases as potential attacks
            if (percentageDecrease > 5000) { // 50% or more
                return false;
            }
            
            // Flag large absolute decreases as potential attacks
            if (decrease > 1e20) { // 100 tokens or more (assuming 18 decimals)
                return false;
            }
        }
        
        return true;
    }
    
    /**
     * @notice Emits flash loan protection event
     * @param contractAddress Address of the contract
     * @param functionName Name of the function
     * @param balanceBefore Balance before operation
     * @param balanceAfter Balance after operation
     * @dev This function is used to log flash loan protection events
     */
    function emitFlashLoanProtectionEvent(
        address contractAddress,
        string memory functionName,
        uint256 balanceBefore,
        uint256 balanceAfter
    ) internal {
        emit FlashLoanProtectionTriggered(
            contractAddress,
            functionName,
            balanceBefore,
            balanceAfter,
            block.timestamp
        );
    }
    
    /**
     * @notice Validates that a timestamp-based cooldown has passed
     * @param lastExecutionTime Last time the function was executed
     * @param cooldownPeriod Cooldown period in seconds
     * @return bool True if cooldown has passed
     * @dev This function prevents rapid successive calls that could be part of an attack
     */
    function validateCooldown(
        uint256 lastExecutionTime,
        uint256 cooldownPeriod
    ) internal view returns (bool) {
        return block.timestamp >= lastExecutionTime + cooldownPeriod;
    }
    
    /**
     * @notice Validates that a rate limit hasn't been exceeded
     * @param currentAmount Current amount in the period
     * @param maxAmount Maximum allowed amount in the period
     * @return bool True if rate limit hasn't been exceeded
     * @dev This function prevents rapid successive operations that could be part of an attack
     */
    function validateRateLimit(
        uint256 currentAmount,
        uint256 maxAmount
    ) internal pure returns (bool) {
        return currentAmount <= maxAmount;
    }
}

// =============================================================================
// INTERFACES
// =============================================================================

// Using OpenZeppelin's IERC20 interface instead of defining our own
