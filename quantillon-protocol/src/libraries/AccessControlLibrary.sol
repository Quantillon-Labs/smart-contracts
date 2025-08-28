// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./ErrorLibrary.sol";

/**
 * @title AccessControlLibrary
 * @notice Access control functions for Quantillon Protocol
 * 
 * @dev Main characteristics:
 *      - Role-based access control validation functions
 *      - Address and amount validation utilities
 *      - Reduces contract bytecode size through library extraction
 *      - Provides standardized error handling for access control
 * 
 * @author Quantillon Labs
 * @custom:security-contact team@quantillon.money
 */
library AccessControlLibrary {
    function onlyGovernance(AccessControlUpgradeable accessControl) internal view {
        if (!accessControl.hasRole(keccak256("GOVERNANCE_ROLE"), msg.sender)) {
            revert ErrorLibrary.NotGovernance();
        }
    }
    
    function onlyVaultManager(AccessControlUpgradeable accessControl) internal view {
        if (!accessControl.hasRole(keccak256("VAULT_MANAGER_ROLE"), msg.sender)) {
            revert ErrorLibrary.NotVaultManager();
        }
    }
    
    function onlyEmergencyRole(AccessControlUpgradeable accessControl) internal view {
        if (!accessControl.hasRole(keccak256("EMERGENCY_ROLE"), msg.sender)) {
            revert ErrorLibrary.NotEmergencyRole();
        }
    }
    
    function onlyLiquidatorRole(AccessControlUpgradeable accessControl) internal view {
        if (!accessControl.hasRole(keccak256("LIQUIDATOR_ROLE"), msg.sender)) {
            revert ErrorLibrary.NotLiquidatorRole();
        }
    }
    
    function onlyYieldManager(AccessControlUpgradeable accessControl) internal view {
        if (!accessControl.hasRole(keccak256("YIELD_MANAGER_ROLE"), msg.sender)) {
            revert ErrorLibrary.NotYieldManager();
        }
    }
    
    function onlyAdmin(AccessControlUpgradeable accessControl) internal view {
        if (!accessControl.hasRole(accessControl.DEFAULT_ADMIN_ROLE(), msg.sender)) {
            revert ErrorLibrary.NotAdmin();
        }
    }
    
    function validateAddress(address addr) internal pure {
        if (addr == address(0)) {
            revert ErrorLibrary.InvalidAddress();
        }
    }
    
    function validateAmount(uint256 amount) internal pure {
        if (amount == 0) {
            revert ErrorLibrary.InvalidAmount();
        }
    }
    
    function validatePositiveAmount(uint256 amount) internal pure {
        if (amount <= 0) {
            revert ErrorLibrary.InvalidAmount();
        }
    }
}
