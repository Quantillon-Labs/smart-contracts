// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./ErrorLibrary.sol";
import "./ValidationLibrary.sol";

/**
 * @title VaultLibrary
 * @notice Library for common vault operations to reduce contract bytecode size
 * @dev Extracts common vault logic to reduce duplication across vault contracts
 */
library VaultLibrary {
    
    /**
     * @notice Validates deposit parameters
     * @param amount Deposit amount
     * @param user User address
     */
    function validateDeposit(uint256 amount, address user) internal pure {
        ValidationLibrary.validatePositiveAmount(amount);
        if (user == address(0)) revert ErrorLibrary.InvalidAddress();
    }
    
    /**
     * @notice Validates withdrawal parameters
     * @param amount Withdrawal amount
     * @param user User address
     * @param balance User balance
     */
    function validateWithdrawal(uint256 amount, address user, uint256 balance) internal pure {
        ValidationLibrary.validatePositiveAmount(amount);
        if (user == address(0)) revert ErrorLibrary.InvalidAddress();
        if (balance < amount) revert ErrorLibrary.InsufficientBalance();
    }
    
    /**
     * @notice Validates yield distribution parameters
     * @param totalYield Total yield amount
     * @param yieldShiftBps Yield shift in basis points
     */
    function validateYieldDistribution(uint256 totalYield, uint256 yieldShiftBps) internal pure {
        ValidationLibrary.validatePositiveAmount(totalYield);
        ValidationLibrary.validateThreshold(yieldShiftBps, 10000); // Max 100%
    }
    
    /**
     * @notice Validates position parameters
     * @param hedger Hedger address
     * @param amount Position amount
     * @param leverage Leverage ratio
     * @param maxLeverage Maximum leverage
     */
    function validatePosition(address hedger, uint256 amount, uint256 leverage, uint256 maxLeverage) internal pure {
        if (hedger == address(0)) revert ErrorLibrary.InvalidAddress();
        ValidationLibrary.validatePositiveAmount(amount);
        ValidationLibrary.validateLeverage(leverage, maxLeverage);
    }
    
    /**
     * @notice Validates liquidation parameters
     * @param position Position to liquidate
     * @param liquidator Liquidator address
     */
    function validateLiquidation(address position, address liquidator) internal pure {
        if (position == address(0)) revert ErrorLibrary.InvalidAddress();
        if (liquidator == address(0)) revert ErrorLibrary.InvalidAddress();
    }
    
    /**
     * @notice Validates emergency parameters
     * @param admin Admin address
     * @param token Token address
     * @param amount Amount to recover
     */
    function validateEmergencyRecovery(address admin, address token, uint256 amount) internal pure {
        if (admin == address(0)) revert ErrorLibrary.InvalidAddress();
        if (token == address(0)) revert ErrorLibrary.InvalidAddress();
        ValidationLibrary.validatePositiveAmount(amount);
    }
    
    /**
     * @notice Validates rebalancing parameters
     * @param fromVault Source vault
     * @param toVault Target vault
     * @param amount Rebalancing amount
     */
    function validateRebalancing(address fromVault, address toVault, uint256 amount) internal pure {
        if (fromVault == address(0)) revert ErrorLibrary.InvalidAddress();
        if (toVault == address(0)) revert ErrorLibrary.InvalidAddress();
        if (fromVault == toVault) revert ErrorLibrary.InvalidRebalancing();
        ValidationLibrary.validatePositiveAmount(amount);
    }
    
    /**
     * @notice Validates yield shift parameters
     * @param newYieldShiftBps New yield shift in basis points
     * @param holdingPeriod Required holding period
     */
    function validateYieldShift(uint256 newYieldShiftBps, uint256 holdingPeriod) internal pure {
        ValidationLibrary.validateThreshold(newYieldShiftBps, 10000); // Max 100%
        ValidationLibrary.validatePositiveAmount(holdingPeriod);
    }
}
