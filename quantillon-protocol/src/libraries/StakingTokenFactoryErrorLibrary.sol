// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// =============================================================================
// LIBRARY
// =============================================================================

/**
 * @title StakingTokenFactoryErrorLibrary
 * @notice Custom errors for the StakingTokenFactory contract
 *
 * @dev Main characteristics:
 *      - Errors specific to staking token factory operations
 *      - Token existence and registry errors
 *      - Implementation validation errors
 *
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
 * @custom:security-contact team@quantillon.money
 */
library StakingTokenFactoryErrorLibrary {
    /// @notice Thrown when a staking token for a given vault ID already exists
    /// @param vaultId The vault ID that already has a registered staking token
    error StakingTokenAlreadyExists(uint256 vaultId);

    /// @notice Thrown when no staking token is registered for the requested vault ID
    /// @param vaultId The vault ID that has no registered staking token
    error StakingTokenNotFound(uint256 vaultId);

    /// @notice Thrown when a vault address is already registered for another vault ID
    /// @param vault The vault address that is already registered
    error VaultAlreadyRegistered(address vault);

    /// @notice Thrown when the provided staking token implementation address is invalid
    error InvalidImplementation();
}
