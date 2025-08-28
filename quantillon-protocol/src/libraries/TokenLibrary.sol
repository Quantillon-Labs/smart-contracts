// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import "./ErrorLibrary.sol";

/**
 * @title TokenLibrary
 * @notice Library for common token operations to reduce contract bytecode size
 * 
 * @dev Main characteristics:
 *      - Token transfer, mint, and burn validation functions
 *      - Permit and delegation parameter validation
 *      - Governance proposal and voting parameter validation
 *      - Reduces duplication across QEURO, QTI, and stQEURO token contracts
 * 
 * @author Quantillon Labs
 * @custom:security-contact team@quantillon.money
 */
library TokenLibrary {
    
    /**
     * @notice Validates token transfer parameters
     * @param from Address to transfer from
     * @param to Address to transfer to
     * @param amount Amount to transfer
     */
    function validateTransfer(address from, address to, uint256 amount) internal pure {
        if (from == address(0)) revert ErrorLibrary.InvalidAddress();
        if (to == address(0)) revert ErrorLibrary.InvalidAddress();
        if (amount == 0) revert ErrorLibrary.InvalidAmount();
    }
    
    /**
     * @notice Validates mint parameters
     * @param to Address to mint to
     * @param amount Amount to mint
     * @param totalSupply Current total supply
     * @param maxSupply Maximum supply cap
     */
    function validateMint(address to, uint256 amount, uint256 totalSupply, uint256 maxSupply) internal pure {
        if (to == address(0)) revert ErrorLibrary.InvalidAddress();
        if (amount == 0) revert ErrorLibrary.InvalidAmount();
        if (totalSupply + amount > maxSupply) revert ErrorLibrary.WouldExceedLimit();
    }
    
    /**
     * @notice Validates burn parameters
     * @param from Address to burn from
     * @param amount Amount to burn
     * @param balance Current balance
     */
    function validateBurn(address from, uint256 amount, uint256 balance) internal pure {
        if (from == address(0)) revert ErrorLibrary.InvalidAddress();
        if (amount == 0) revert ErrorLibrary.InvalidAmount();
        if (balance < amount) revert ErrorLibrary.InsufficientBalance();
    }
    
    /**
     * @notice Validates permit parameters
     * @param owner Token owner
     * @param spender Spender address
     * @param value Permit value
     * @param deadline Permit deadline
     */
    function validatePermit(address owner, address spender, uint256 value, uint256 deadline) internal view {
        if (owner == address(0)) revert ErrorLibrary.InvalidAddress();
        if (spender == address(0)) revert ErrorLibrary.InvalidAddress();
        if (block.timestamp > deadline) revert ErrorLibrary.ExpiredDeadline();
    }
    
    /**
     * @notice Validates delegation parameters
     * @param delegator Delegator address
     * @param delegatee Delegatee address
     */
    function validateDelegation(address delegator, address delegatee) internal pure {
        if (delegator == address(0)) revert ErrorLibrary.InvalidAddress();
        if (delegatee == address(0)) revert ErrorLibrary.InvalidAddress();
    }
    
    /**
     * @notice Validates voting parameters
     * @param proposalId Proposal ID
     * @param support Support value
     */
    function validateVote(uint256 proposalId, bool support) internal pure {
        // Basic validation - specific logic handled by contracts
    }
    
    /**
     * @notice Validates proposal parameters
     * @param description Proposal description
     * @param votingPeriod Voting period
     * @param minPeriod Minimum voting period
     * @param maxPeriod Maximum voting period
     */
    function validateProposal(string memory description, uint256 votingPeriod, uint256 minPeriod, uint256 maxPeriod) internal pure {
        if (bytes(description).length == 0) revert ErrorLibrary.InvalidDescription();
        if (votingPeriod < minPeriod) revert ErrorLibrary.VotingPeriodTooShort();
        if (votingPeriod > maxPeriod) revert ErrorLibrary.VotingPeriodTooLong();
    }
}
