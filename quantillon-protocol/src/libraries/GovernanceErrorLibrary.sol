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
    /// @notice Library version (semver); see deployments/{chainId}/versions.json for provenance.
    string internal constant VERSION = "1.0.0";

    // Voting Errors
    error InsufficientVotingPower();
    error ProposalNotFound();
    error VotingNotActive();
    error ProposalThresholdNotMet();
    error ProposalExecutionFailed();
    
    // MEV Protection Errors
    error ProposalAlreadyScheduled();
    error ProposalNotScheduled();
    error InvalidExecutionHash();
    error ExecutionTimeNotReached();
    
    // Governance State Errors
    error InvalidDescription();
    error ExpiredDeadline();
    error InvalidRebalancing();
}
