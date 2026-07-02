// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {CommonErrorLibrary} from "./CommonErrorLibrary.sol";

/**
 * @title TokenValidationLibrary
 * @notice Token-specific validation functions for Quantillon Protocol
 * 
 * @dev Main characteristics:
 *      - Validation functions specific to token operations
 *      - Treasury address validations
 *
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
 * @custom:security-contact team@quantillon.money
 */
library TokenValidationLibrary {
    /// @notice Library version (semver); see deployments/{chainId}/versions.json for provenance.
    string internal constant VERSION = "1.0.0";

    /**
     * @notice Validates treasury address is not zero address
     * @dev Prevents setting treasury to zero address which could cause loss of funds
     * @param treasury The treasury address to validate
     * @custom:security Prevents loss of funds by ensuring treasury is properly set
     * @custom:validation Ensures treasury address is valid for fund operations
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors Throws ZeroAddress if treasury is zero address
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal library function
     * @custom:oracle No oracle dependencies
     */
    function validateTreasuryAddress(address treasury) internal pure {
        if (treasury == address(0)) revert CommonErrorLibrary.ZeroAddress();
    }
    
    // Note: validatePositiveAmount moved to CommonValidationLibrary to avoid duplication.
    // Use CommonValidationLibrary.validatePositiveAmount() instead.
}
