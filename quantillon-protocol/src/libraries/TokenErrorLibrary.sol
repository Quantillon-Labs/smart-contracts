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
    /// @notice Library version (semver); see deployments/{chainId}/versions.json for provenance.
    string internal constant VERSION = "1.0.0";

    // Token Operation Errors
    error MintingDisabled();
    error BlacklistedAddress();
    error NewCapBelowCurrentSupply();

    // Vote-Escrow Errors (QTI Token)
    error LockNotExpired();
    error NothingToUnlock();

    // Token Supply Errors
    error RateLimitExceeded();
    error AlreadyBlacklisted();
    error NotBlacklisted();
    error AlreadyWhitelisted();
    error PrecisionTooHigh();
    error TooManyDecimals();
}
