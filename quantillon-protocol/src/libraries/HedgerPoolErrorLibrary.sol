// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title HedgerPoolErrorLibrary
 * @notice HedgerPool-specific errors for Quantillon Protocol
 * 
 * @dev Main characteristics:
 *      - Errors specific to HedgerPool operations
 *      - Trading position management errors
 *      - Liquidation system errors
 *      - Margin and leverage validation errors
 * 
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
 * @custom:security-contact team@quantillon.money
 */
library HedgerPoolErrorLibrary {
    // HedgerPool Specific Errors
    error FlashLoanAttackDetected();
    error InvalidPosition();
    error InvalidHedger();
    error MaxPositionsPerTx();
    error AlreadyWhitelisted();
    error OnlyVault();
    error RewardOverflow();
    error InsufficientMargin();
    
    // Position Limit Errors
    error MarginExceedsMaximum();
    error PositionSizeExceedsMaximum();
    error EntryPriceExceedsMaximum();
    error LeverageExceedsMaximum();
    error TimestampOverflow();
    error TotalMarginExceedsMaximum();
    error TotalExposureExceedsMaximum();
    error NewMarginExceedsMaximum();
    error PendingRewardsExceedMaximum();
    
    // Leverage and Margin Errors
    error InvalidLeverage();
    error LeverageTooHigh();
    error LeverageTooLow();
    error MaxLeverageExceeded();
    error MarginTooLow();
    error MarginRatioTooLow();
    error MarginRatioTooHigh();
    error MarginInsufficient();
    error MarginLimitExceeded();
    
    // Position Management Errors
    error PositionNotFound();
    error PositionOwnerMismatch();
    error PositionAlreadyClosed();
    error PositionClosureRestricted();
    error PositionHasActiveFill();
    error InsufficientHedgerCapacity();
    error NoActiveHedgerLiquidity();
    error HedgerHasActivePosition();
    
    
    // Fee Errors
    error EntryFeeTooHigh();
    error ExitFeeTooHigh();
    error MarginFeeTooHigh();
    error YieldFeeTooHigh();
}
