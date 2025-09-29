// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title GovernanceErrorLibrary
 * @notice Governance-specific errors for QTIToken governance system
 * 
 * @dev Main characteristics:
 *      - Errors specific to governance operations
 *      - Voting and proposal management errors
 *      - Timelock and execution errors
 *      - MEV protection errors
 * 
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
 * @custom:security-contact team@quantillon.money
 */
library GovernanceErrorLibrary {
    // Voting Errors
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
    error VotingNotStarted();
    error VotingEnded();
    error NoVotingPower();
    error VotingNotEnded();
    error ProposalFailed();
    error ProposalExecutionFailed();
    error ProposalCanceled();
    
    // MEV Protection Errors
    error ProposalAlreadyScheduled();
    error ProposalNotScheduled();
    error InvalidExecutionHash();
    error ExecutionTimeNotReached();
    
    // Governance State Errors
    error InvalidDescription();
    error ExpiredDeadline();
    error InvalidRebalancing();
    error RateLimitTooHigh();
    error InvalidAmount();
    error InvalidTime();
    error LockTimeTooShort();
    error LockTimeTooLong();
}
