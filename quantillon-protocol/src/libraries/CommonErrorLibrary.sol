// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title CommonErrorLibrary
 * @notice Common errors used across multiple contracts in Quantillon Protocol
 * 
 * @dev Main characteristics:
 *      - Most frequently used errors across all contracts
 *      - Reduces contract size by importing only needed errors
 *      - Replaces require statements with custom errors for gas efficiency
 *      - Used by 15+ contracts
 * 
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
 * @custom:security-contact team@quantillon.money
 */
library CommonErrorLibrary {
    // Most Common Validation Errors (used by 10+ contracts)
    error InvalidAmount();
    error ZeroAddress();
    error InvalidAddress();
    error InsufficientBalance();
    error NotAuthorized();
    error ArrayLengthMismatch();
    error BatchSizeTooLarge();
    error EmptyArray();
    error InvalidTime();
    error AboveLimit();
    error WouldExceedLimit();
    error ExcessiveSlippage();
    error ConfigValueTooHigh();
    error ConfigValueTooLow();
    error ConfigInvalid();
    
    // Access Control Errors (used by multiple contracts)
    error NotAdmin();
    error InvalidAdmin();
    error InvalidTreasury();
    error InvalidToken();
    error InvalidOracle();
    error InvalidVault();
    
    // State Errors (used by multiple contracts)
    error AlreadyInitialized();
    error NotInitialized();
    error AlreadyActive();
    error NotActive();
    error AlreadyPaused();
    error NotPaused();
    error BelowThreshold();
    error NoChangeDetected();
    
    // Operation Errors (used by multiple contracts)
    error DivisionByZero();
    error MultiplicationOverflow();
    error PercentageTooHigh();
    error InvalidParameter();
    error InvalidCondition();
    
    // External Errors (used by multiple contracts)
    error ETHTransferFailed();
    error TokenTransferFailed();
    
    // Recovery Errors (used by multiple contracts)
    error CannotSendToZero();
    error NoETHToRecover();
    error NoTokensToRecover();
    error CannotRecoverOwnToken();
    
    // Emergency Errors (used by multiple contracts)
    error EmergencyModeActive();
    
    // Additional Common Errors
    error HoldingPeriodNotMet();
    error InvalidPrice();
    error InsufficientCollateralization();
    error TooManyPositions();
    error PositionNotActive();
    error LiquidationCooldown();
    error InvalidYieldShift();
    error AdjustmentSpeedTooHigh();
    error TargetRatioTooHigh();
    error InvalidRatio();
    error NotGovernance();
    error NotEmergency();
    error NotEmergencyRole();
    error NotLiquidator();
    error NotLiquidatorRole();
    error NotHedger();
    error NotVaultManager();
    error NotYieldManager();
    error InsufficientYield();
    error InvalidShiftRange();
    
    // Yield Management Errors (used across multiple contracts)
    error YieldBelowThreshold();
    error YieldNotAvailable();
    error YieldDistributionFailed();
    error YieldCalculationError();
    
    // Governance/Voting Errors (used across multiple contracts)
    error VotingPeriodTooShort();
    error VotingPeriodTooLong();
    error VotingNotStarted();
    error VotingEnded();
    error AlreadyVoted();
    error NoVotingPower();
    error VotingNotEnded();
    error ProposalAlreadyExecuted();
    error ProposalCanceled();
    error ProposalFailed();
    error QuorumNotMet();
    error ProposalAlreadyCanceled();
    
    // Lock/Time Errors (used across multiple contracts)
    error LockTimeTooShort();
    error LockTimeTooLong();
    
    // Rate Limit Errors (used across multiple contracts)
    error RateLimitTooHigh();
    
    // Additional Common Errors (consolidated from other libraries)
    error InvalidOraclePrice();
    error YieldClaimFailed();
    error InvalidThreshold();
    error NotWhitelisted();
    error InsufficientVotingPower();
    
    // Protocol Liquidation Mode Errors
    error NotInLiquidationMode();
}
