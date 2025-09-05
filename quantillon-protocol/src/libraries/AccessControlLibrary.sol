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
    /**
     * @notice Ensures the caller has governance role
     * @dev Reverts with NotGovernance if caller lacks GOVERNANCE_ROLE
     * @param accessControl The access control contract to check roles against
     * @custom:security Validates caller has GOVERNANCE_ROLE before allowing access
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors Throws NotGovernance if caller lacks required role
     * @custom:reentrancy Not applicable - view function
     * @custom:access Internal function - no access restrictions
     * @custom:oracle No oracle dependencies
     */
    function onlyGovernance(AccessControlUpgradeable accessControl) internal view {
        if (!accessControl.hasRole(keccak256("GOVERNANCE_ROLE"), msg.sender)) {
            revert ErrorLibrary.NotGovernance();
        }
    }
    
    /**
     * @notice Ensures the caller has vault manager role
     * @dev Reverts with NotVaultManager if caller lacks VAULT_MANAGER_ROLE
     * @param accessControl The access control contract to check roles against
     * @custom:security Validates caller has VAULT_MANAGER_ROLE before allowing access
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors Throws NotVaultManager if caller lacks required role
     * @custom:reentrancy Not applicable - view function
     * @custom:access Internal function - no access restrictions
     * @custom:oracle No oracle dependencies
     */
    function onlyVaultManager(AccessControlUpgradeable accessControl) internal view {
        if (!accessControl.hasRole(keccak256("VAULT_MANAGER_ROLE"), msg.sender)) {
            revert ErrorLibrary.NotVaultManager();
        }
    }
    
    /**
     * @notice Ensures the caller has emergency role
     * @dev Reverts with NotEmergencyRole if caller lacks EMERGENCY_ROLE
     * @param accessControl The access control contract to check roles against
     * @custom:security Validates caller has EMERGENCY_ROLE before allowing access
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors Throws NotEmergencyRole if caller lacks required role
     * @custom:reentrancy Not applicable - view function
     * @custom:access Internal function - no access restrictions
     * @custom:oracle No oracle dependencies
     */
    function onlyEmergencyRole(AccessControlUpgradeable accessControl) internal view {
        if (!accessControl.hasRole(keccak256("EMERGENCY_ROLE"), msg.sender)) {
            revert ErrorLibrary.NotEmergencyRole();
        }
    }
    
    /**
     * @notice Ensures the caller has liquidator role
     * @dev Reverts with NotLiquidatorRole if caller lacks LIQUIDATOR_ROLE
     * @param accessControl The access control contract to check roles against
     * @custom:security Validates caller has LIQUIDATOR_ROLE before allowing access
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors Throws NotLiquidatorRole if caller lacks required role
     * @custom:reentrancy Not applicable - view function
     * @custom:access Internal function - no access restrictions
     * @custom:oracle No oracle dependencies
     */
    function onlyLiquidatorRole(AccessControlUpgradeable accessControl) internal view {
        if (!accessControl.hasRole(keccak256("LIQUIDATOR_ROLE"), msg.sender)) {
            revert ErrorLibrary.NotLiquidatorRole();
        }
    }
    
    /**
     * @notice Ensures the caller has yield manager role
     * @dev Reverts with NotYieldManager if caller lacks YIELD_MANAGER_ROLE
     * @param accessControl The access control contract to check roles against
     * @custom:security Validates caller has YIELD_MANAGER_ROLE before allowing access
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors Throws NotYieldManager if caller lacks required role
     * @custom:reentrancy Not applicable - view function
     * @custom:access Internal function - no access restrictions
     * @custom:oracle No oracle dependencies
     */
    function onlyYieldManager(AccessControlUpgradeable accessControl) internal view {
        if (!accessControl.hasRole(keccak256("YIELD_MANAGER_ROLE"), msg.sender)) {
            revert ErrorLibrary.NotYieldManager();
        }
    }
    
    /**
     * @notice Ensures the caller has admin role
     * @dev Reverts with NotAdmin if caller lacks DEFAULT_ADMIN_ROLE
     * @param accessControl The access control contract to check roles against
     * @custom:security Validates caller has DEFAULT_ADMIN_ROLE before allowing access
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors Throws NotAdmin if caller lacks required role
     * @custom:reentrancy Not applicable - view function
     * @custom:access Internal function - no access restrictions
     * @custom:oracle No oracle dependencies
     */
    function onlyAdmin(AccessControlUpgradeable accessControl) internal view {
        if (!accessControl.hasRole(accessControl.DEFAULT_ADMIN_ROLE(), msg.sender)) {
            revert ErrorLibrary.NotAdmin();
        }
    }
    
    /**
     * @notice Validates that an address is not the zero address
     * @dev Reverts with InvalidAddress if address is zero
     * @param addr The address to validate
     * @custom:security Prevents zero address usage which could cause loss of funds
     * @custom:validation Validates addr != address(0)
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors Throws InvalidAddress if address is zero
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal function - no access restrictions
     */
    function validateAddress(address addr) internal pure {
        if (addr == address(0)) {
            revert ErrorLibrary.InvalidAddress();
        }
    }
    
    /**
     * @notice Validates that an amount is not zero
     * @dev Reverts with InvalidAmount if amount is zero
     * @param amount The amount to validate
     * @custom:security Prevents zero amount operations which could cause unexpected behavior
     * @custom:validation Validates amount > 0
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors Throws InvalidAmount if amount is zero
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal function - no access restrictions
     * @custom:oracle No oracle dependencies
     */
    function validateAmount(uint256 amount) internal pure {
        if (amount == 0) {
            revert ErrorLibrary.InvalidAmount();
        }
    }
    
    /**
     * @notice Validates that an amount is positive (> 0)
     * @dev Reverts with InvalidAmount if amount is zero or negative
     * @param amount The amount to validate
     * @custom:security Prevents zero or negative amount operations which could cause unexpected behavior
     * @custom:validation Validates amount > 0
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors Throws InvalidAmount if amount is zero or negative
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal function - no access restrictions
     * @custom:oracle No oracle dependencies
     */
    function validatePositiveAmount(uint256 amount) internal pure {
        if (amount <= 0) {
            revert ErrorLibrary.InvalidAmount();
        }
    }
}
