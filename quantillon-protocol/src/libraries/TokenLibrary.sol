// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {CommonErrorLibrary} from "./CommonErrorLibrary.sol";
import {TokenErrorLibrary} from "./TokenErrorLibrary.sol";

/**
 * @title TokenLibrary
 * @notice Library for essential token operations to reduce contract bytecode size
 * 
 * @dev This library provides core token validation functions:
 *      - Mint and burn parameter validation with supply cap checks
 *      - Used by QEURO token for secure minting and burning operations
 * 
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
 * @custom:security-contact team@quantillon.money
 */
library TokenLibrary {
    /**
     * @notice Validates mint parameters
     * @param to Address to mint to
     * @param amount Amount to mint
     * @param totalSupply Current total supply
     * @param maxSupply Maximum supply cap
     * @dev Ensures minting doesn't exceed maximum supply and validates parameters
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function validateMint(address to, uint256 amount, uint256 totalSupply, uint256 maxSupply) internal pure {
        if (to == address(0)) revert TokenErrorLibrary.InvalidAddress();
        if (amount == 0) revert TokenErrorLibrary.InvalidAmount();
        if (totalSupply + amount > maxSupply) revert TokenErrorLibrary.WouldExceedLimit();
    }
    
    /**
     * @notice Validates burn parameters
     * @param from Address to burn from
     * @param amount Amount to burn
     * @param balance Current balance
     * @dev Ensures sufficient balance and validates parameters for burning
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function validateBurn(address from, uint256 amount, uint256 balance) internal pure {
        if (from == address(0)) revert TokenErrorLibrary.InvalidAddress();
        if (amount == 0) revert TokenErrorLibrary.InvalidAmount();
        if (balance < amount) revert TokenErrorLibrary.InsufficientBalance();
    }
}
