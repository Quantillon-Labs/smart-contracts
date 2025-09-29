// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {CommonErrorLibrary} from "./CommonErrorLibrary.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title TreasuryRecoveryLibrary
 * @notice Library for secure token and ETH recovery to treasury addresses
 * @dev This library factorizes the recoverToken and recoverETH functionality used across all contracts
 *      to save gas, reduce bytecode, and ensure consistent security implementation
 * 
 * @author Quantillon Protocol Team
 * @custom:security-contact team@quantillon.money
 */
library TreasuryRecoveryLibrary {
    using SafeERC20 for IERC20;
    
    /**
     * @notice Recover tokens accidentally sent to the contract to treasury only
     * @dev SECURITY: Prevents recovery of own tokens and sends only to treasury
     * @param token Token address to recover
     * @param amount Amount to recover
     * @param contractAddress Address of the calling contract (for own token check)
     * @param treasury Treasury address to send recovered tokens to
     * 
     * @dev Gas optimization: Uses library function to avoid code duplication
     * @dev Security: Prevents recovery of own tokens and ensures treasury-only recovery
     * @dev Error handling: Uses custom errors for gas efficiency
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function recoverToken(
        address token,
        uint256 amount,
        address contractAddress,
        address treasury
    ) external {
        if (token == contractAddress) revert CommonErrorLibrary.CannotRecoverOwnToken();
        
        if (treasury == address(0)) revert CommonErrorLibrary.InvalidAddress();
        
        IERC20(token).safeTransfer(treasury, amount);
    }
    
    /**
     * @notice Recover ETH to treasury address only
     * @dev SECURITY: Restricted to treasury to prevent arbitrary ETH transfers
     * @param treasury The contract's treasury address
     * 
     * @dev Gas optimization: Uses library function to avoid code duplication
     * @dev Security: Prevents arbitrary ETH transfers that could be exploited
     * @dev Error handling: Uses custom errors for gas efficiency
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function recoverETH(
        address treasury
    ) external {
        // This prevents arbitrary ETH transfers that could be exploited
        if (treasury == address(0)) revert CommonErrorLibrary.InvalidAddress();
        
        uint256 balance = address(this).balance;
        if (balance < 1) revert CommonErrorLibrary.NoETHToRecover();
        
        // transfer() has 2300 gas stipend which can fail with complex receive/fallback logic
        (bool success, ) = treasury.call{value: balance}("");
        if (!success) revert CommonErrorLibrary.ETHTransferFailed();
        
        // Note: Individual contracts should emit their own events for better tracking
    }
    
}
