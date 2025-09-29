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
    // Vault Operation Errors
    error TokenTransferFailed();
    error InsufficientCollateralization();
    error EmergencyModeActive();
    
    // Pool Health Errors
    error PoolNotHealthy();
    error PoolRatioInvalid();
    error PoolSizeZero();
    error PoolImbalance();
    
    // Yield Management Errors
    error YieldBelowThreshold();
    error YieldNotAvailable();
    error YieldDistributionFailed();
    error YieldCalculationError();
    error YieldClaimFailed();
    
    // Recovery Errors
    error CannotRecoverUSDC();
    error CannotRecoverAToken();
    error CannotRecoverOwnToken();
    error CannotRecoverCriticalToken(string tokenName);
    
    // External Integration Errors
    error InvalidOraclePrice();
    error AavePoolNotHealthy();
    
    // Additional Vault Errors
    error WouldExceedLimit();
    error InsufficientBalance();
    error WouldBreachMinimum();
    error InvalidAmount();
    error InvalidAddress();
    error BelowThreshold();
    error FeeTooHigh();
    error InvalidThreshold();
    error NoETHToRecover();
    error ExcessiveSlippage();
    error ConfigValueTooHigh();
}
