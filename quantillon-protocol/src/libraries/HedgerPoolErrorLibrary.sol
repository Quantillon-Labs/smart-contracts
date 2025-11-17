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
    error NotWhitelisted();
    error PendingLiquidationCommitment();
    error InvalidPosition();
    error PositionNotLiquidatable();
    error YieldClaimFailed();
    error InvalidHedger();
    error TooManyPositions();
    error MaxPositionsPerTx();
    error NotPaused();
    error ZeroAddress();
    error InvalidAmount();
    error ConfigValueTooLow();
    error ConfigInvalid();
    error ConfigValueTooHigh();
    error AlreadyWhitelisted();
    error InvalidOraclePrice();
    error InvalidAddress();
    error NotAuthorized();
    error OnlyVault();
    error RewardOverflow();
    error InsufficientMargin();
    error CannotRecoverOwnToken();
    error NoETHToRecover();
    
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
    error PositionNotActive();
    error PositionHasActiveFill();
    error InsufficientHedgerCapacity();
    error NoActiveHedgerLiquidity();
    
    // Liquidation Errors
    error LiquidationNotAllowed();
    error LiquidationRewardTooHigh();
    error LiquidationPenaltyTooHigh();
    error LiquidationThresholdInvalid();
    error LiquidationCooldown();
    error NoValidCommitment();
    error CommitmentAlreadyExists();
    error CommitmentDoesNotExist();
    
    // Fee Errors
    error FeeTooHigh();
    error EntryFeeTooHigh();
    error ExitFeeTooHigh();
    error MarginFeeTooHigh();
    error YieldFeeTooHigh();
    
    // Yield Errors
    error YieldBelowThreshold();
    error YieldNotAvailable();
    error YieldDistributionFailed();
    error YieldCalculationError();
    error InsufficientYield();
    error HoldingPeriodNotMet();
}
