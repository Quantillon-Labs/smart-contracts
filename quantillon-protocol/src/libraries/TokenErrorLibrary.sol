// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title TokenErrorLibrary
 * @notice Token-specific errors for QEURO, QTI, and stQEURO tokens
 * 
 * @dev Main characteristics:
 *      - Errors specific to token operations
 *      - Minting and burning errors
 *      - Blacklist and whitelist errors
 *      - Supply and cap management errors
 * 
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
 * @custom:security-contact team@quantillon.money
 */
library TokenErrorLibrary {
    // Token Operation Errors
    error MintingDisabled();
    error BlacklistedAddress();
    error NotWhitelisted();
    error WouldExceedLimit();
    error CannotRecoverQEURO();
    error CannotRecoverQTI();
    error NewCapBelowCurrentSupply();
    
    // Vote-Escrow Errors (QTI Token)
    error LockTimeTooShort();
    error LockTimeTooLong();
    error LockNotExpired();
    error NothingToUnlock();
    
    // Token Supply Errors
    error InsufficientBalance();
    error InvalidAmount();
    error InvalidTime();
    error RateLimitExceeded();
    error AlreadyBlacklisted();
    error NotBlacklisted();
    error AlreadyWhitelisted();
    error PrecisionTooHigh();
    error TooManyDecimals();
    
    // Token Transfer Errors
    error InvalidAddress();
    error TokenTransferFailed();
    error ArrayLengthMismatch();
    error BatchSizeTooLarge();
    error RateLimitTooHigh();
    error InsufficientVotingPower();
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
    error NotAuthorized();
    error ProposalAlreadyCanceled();
    error ZeroAddress();
    error CannotRecoverOwnToken();
    error NoETHToRecover();
    error InvalidAdmin();
    error InvalidToken();
    error InvalidTreasury();
    error AboveLimit();
}
