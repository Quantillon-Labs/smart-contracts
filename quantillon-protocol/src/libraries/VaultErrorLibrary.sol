// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title VaultErrorLibrary
 * @notice Vault-specific errors for QuantillonVault and related operations
 * 
 * @dev Main characteristics:
 *      - Errors specific to vault operations
 *      - Collateralization and emergency mode errors
 *      - Pool health and balance errors
 *      - Yield distribution errors
 * 
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
 * @custom:security-contact team@quantillon.money
 */
library VaultErrorLibrary {
    // Pool Health Errors
    error PoolNotHealthy();
    error PoolRatioInvalid();
    error PoolSizeZero();
    error PoolImbalance();
    
    // Recovery Errors
    error CannotRecoverUSDC();
    error CannotRecoverAToken();
    error CannotRecoverCriticalToken(string tokenName);
    
    // External Integration Errors
    error AavePoolNotHealthy();
    
    // Additional Vault Errors
    error WouldBreachMinimum();
    error FeeTooHigh();
}
