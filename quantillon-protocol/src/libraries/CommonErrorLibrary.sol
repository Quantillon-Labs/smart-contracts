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
    /// @notice Library version (semver); see deployments/{chainId}/versions.json for provenance.
    string internal constant VERSION = "1.0.0";

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
    error NotActive();
    error BelowThreshold();
    error NoChangeDetected();

    // Operation Errors (used by multiple contracts)
    error DivisionByZero();
    error PercentageTooHigh();
    error InvalidParameter();
    error InvalidCondition();

    // External Errors (used by multiple contracts)
    error ETHTransferFailed();

    // Recovery Errors (used by multiple contracts)
    error NoETHToRecover();
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
    error InvalidRatio();
    error NotGovernance();
    error NotEmergencyRole();
    error NotLiquidatorRole();
    error NotVaultManager();
    error NotYieldManager();
    error InsufficientYield();
    error InvalidShiftRange();

    // Yield Management Errors (used across multiple contracts)
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
    error ExecutionTimeNotReached();

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
}
