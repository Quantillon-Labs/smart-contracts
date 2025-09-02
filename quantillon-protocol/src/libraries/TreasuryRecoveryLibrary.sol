// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ErrorLibrary.sol";

/**
 * @title TreasuryRecoveryLibrary
 * @notice Library for secure ETH recovery to treasury addresses
 * @dev This library factorizes the recoverETH functionality used across all contracts
 *      to save gas, reduce bytecode, and ensure consistent security implementation
 * 
 * @author Quantillon Protocol Team
 * @custom:security-contact team@quantillon.money
 */
library TreasuryRecoveryLibrary {
    
    /**
     * @notice Recover ETH to treasury address only
     * @dev SECURITY: Restricted to treasury to prevent arbitrary ETH transfers
     * @param treasury The contract's treasury address
     * @param to Recipient address (must match treasury)
     * 
     * @dev Gas optimization: Uses library function to avoid code duplication
     * @dev Security: Prevents arbitrary ETH transfers that could be exploited
     * @dev Error handling: Uses custom errors for gas efficiency
     */
    function recoverETHToTreasury(
        address treasury,
        address payable to
    ) external {
        // SECURITY: Only allow recovery to the contract's treasury address
        // This prevents arbitrary ETH transfers that could be exploited
        if (to != treasury) revert ErrorLibrary.InvalidAddress();
        
        uint256 balance = address(this).balance;
        // SECURITY: Check if there's ETH to recover (safe equality check)
        if (balance == 0) revert ErrorLibrary.NoETHToRecover();
        
        // SECURITY: Use call() instead of transfer() for reliable ETH transfers
        // transfer() has 2300 gas stipend which can fail with complex receive/fallback logic
        (bool success, ) = to.call{value: balance}("");
        if (!success) revert ErrorLibrary.ETHTransferFailed();
        
        // Note: Individual contracts should emit their own events for better tracking
    }
    
    /**
     * @notice Validate treasury address
     * @dev Ensures treasury address is not zero address
     * @param treasury Address to validate
     */
    function validateTreasury(address treasury) external pure {
        if (treasury == address(0)) revert ErrorLibrary.InvalidAddress();
    }
    
    /**
     * @notice Update treasury address with validation
     * @dev Only callable by governance/admin roles
     * @param currentTreasury Current treasury address
     * @param newTreasury New treasury address
     * @return Updated treasury address
     */
    function updateTreasury(
        address currentTreasury,
        address newTreasury
    ) external pure returns (address) {
        if (newTreasury == address(0)) revert ErrorLibrary.InvalidAddress();
        if (newTreasury == currentTreasury) revert ErrorLibrary.NoChangeDetected();
        
        return newTreasury;
    }
}
