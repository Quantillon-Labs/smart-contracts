// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title ErrorLibrary
 * @notice Custom errors for Quantillon Protocol
 * 
 * @dev Main characteristics:
 *      - Comprehensive error definitions for all protocol operations
 *      - Replaces require statements with custom errors to reduce gas costs
 *      - Categorized errors for access control, validation, state, operations
 *      - Supports governance, vault, yield, and liquidation operations
 * 
 * @author Quantillon Labs
 * @custom:security-contact team@quantillon.money
 */
library ErrorLibrary {
    // Access Control Errors
    error NotAuthorized();
    error NotGovernance();
    error NotVaultManager();
    error NotEmergencyRole();
    error NotLiquidatorRole();
    error NotYieldManager();
    error NotAdmin();
    
    // Validation Errors
    error InvalidAddress();
    error ZeroAddress();
    error InvalidAmount();
    error InvalidParameter();
    error InvalidLeverage();
    error InvalidMarginRatio();
    error InvalidThreshold();
    error InvalidFee();
    error InvalidRate();
    error InvalidRatio();
    error InvalidTime();
    error InvalidPosition();
    error InvalidHedger();
    error InvalidCommitment();
    
    // State Errors
    error AlreadyInitialized();
    error NotInitialized();
    error AlreadyActive();
    error NotActive();
    error AlreadyPaused();
    error NotPaused();
    error EmergencyModeActive();
    error PositionNotActive();
    error InsufficientBalance();
    error InsufficientMargin();
    error InsufficientYield();
    error InsufficientCollateral();
    error ExcessiveSlippage();
    error BelowThreshold();
    error AboveLimit();
    error WouldExceedLimit();
    error WouldBreachMinimum();
    error NoChangeDetected();
    
    // Operation Errors
    error DivisionByZero();
    error MultiplicationOverflow();
    error PercentageTooHigh();
    error InvalidYieldShift();
    error InvalidShiftRange();
    error AdjustmentSpeedTooHigh();
    error TargetRatioTooHigh();
    error HoldingPeriodNotMet();
    error LiquidationCooldown();
    error PendingLiquidationCommitment();
    error NoValidCommitment();
    error CommitmentAlreadyExists();
    error CommitmentDoesNotExist();
    
    // External Errors
    error InvalidOraclePrice();
    error AavePoolNotHealthy();
    error ETHTransferFailed();
    error TokenTransferFailed();
    
    // Recovery Errors
    error CannotRecoverUSDC();
    error CannotRecoverAToken();
    error CannotRecoverOwnToken();
    error CannotRecoverCriticalToken(string tokenName);
    error CannotSendToZero();
    error NoETHToRecover();
    error NoTokensToRecover();
    
    // Time Errors
    error TimeElapsedTooHigh();
    error InvalidTimestamp();
    error FutureTimestamp();
    
    // Array Errors
    error ArrayLengthMismatch();
    error IndexOutOfBounds();
    error EmptyArray();
    error BatchSizeTooLarge();
    
    // Pool Errors
    error PoolNotHealthy();
    error PoolRatioInvalid();
    error PoolSizeZero();
    error PoolImbalance();
    
    // Yield Errors
    error YieldBelowThreshold();
    error YieldNotAvailable();
    error YieldDistributionFailed();
    error YieldCalculationError();
    error YieldClaimFailed();
    
    // Liquidation Errors
    error LiquidationNotAllowed();
    error LiquidationRewardTooHigh();
    error LiquidationPenaltyTooHigh();
    error LiquidationThresholdInvalid();
    
    // Fee Errors
    error FeeTooHigh();
    error EntryFeeTooHigh();
    error ExitFeeTooHigh();
    error MarginFeeTooHigh();
    error YieldFeeTooHigh();
    
    // Leverage Errors
    error LeverageTooHigh();
    error LeverageTooLow();
    error MaxLeverageExceeded();
    
    // Margin Errors
    error MarginTooLow();
    error MarginRatioTooLow();
    error MarginInsufficient();
    error MarginLimitExceeded();
    
    // Position Errors
    error TooManyPositions();
    error PositionNotFound();
    error PositionOwnerMismatch();
    error PositionAlreadyClosed();
    error PositionNotLiquidatable();
    
    // Governance Errors
    error InsufficientVotingPower();
    error VotingPeriodTooShort();
    error VotingPeriodTooLong();
    error ProposalNotFound();
    error ProposalAlreadyExecuted();
    error ProposalAlreadyCanceled();
    error VotingNotActive();
    error AlreadyVoted();
    error QuorumNotMet();
    error ProposalThresholdNotMet();
    
    // Reward Errors
    error RewardOverflow();
    error RewardCalculationError();
    error RewardPeriodExpired();
    error RewardNotAvailable();
    
    // History Errors
    error HistoryTooLong();
    error InvalidHistoryIndex();
    error HistoryNotAvailable();
    
    // TWAP Errors
    error TWAPCalculationError();
    error TWAPPeriodInvalid();
    error TWAPDataInsufficient();
    
    // Configuration Errors
    error ConfigInvalid();
    error ConfigNotSet();
    error ConfigUpdateFailed();
    error ConfigValueTooHigh();
    error ConfigValueTooLow();
    
    // Additional Errors for Libraries
    error InvalidDescription();
    error ExpiredDeadline();
    error InvalidRebalancing();
    error RateLimitExceeded();
    error BlacklistedAddress();
    error NotWhitelisted();
    error RateLimitTooHigh();
    error AlreadyBlacklisted();
    error NotBlacklisted();
    error AlreadyWhitelisted();
    error PrecisionTooHigh();
    error TooManyDecimals();
    error CannotRecoverQEURO();
    error NewCapBelowCurrentSupply();
    
    // Vote-Escrow Errors
    error LockTimeTooShort();
    error LockTimeTooLong();
    error LockNotExpired();
    error NothingToUnlock();
    
    // Voting Errors
    error VotingNotStarted();
    error VotingEnded();
    error NoVotingPower();
    error VotingNotEnded();
    error ProposalFailed();
    error ProposalExecutionFailed();
    error CannotRecoverQTI();
    error ProposalCanceled();
    
    // MEV Protection Errors
    error ProposalAlreadyScheduled();
    error ProposalNotScheduled();
    error InvalidExecutionHash();
    error ExecutionTimeNotReached();
    
    // HedgerPool Specific Errors
    error MarginExceedsMaximum();
    error PositionSizeExceedsMaximum();
    error EntryPriceExceedsMaximum();
    error LeverageExceedsMaximum();
    error TimestampOverflow();
    error TotalMarginExceedsMaximum();
    error TotalExposureExceedsMaximum();
    error TooManyPositionsPerTx();
    error MaxPositionsPerTx();
    error NewMarginExceedsMaximum();
    error PendingRewardsExceedMaximum();
    error FlashLoanAttackDetected();
}
