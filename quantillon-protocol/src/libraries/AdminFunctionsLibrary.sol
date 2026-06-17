// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {CommonErrorLibrary} from "./CommonErrorLibrary.sol";
import {TreasuryRecoveryLibrary} from "./TreasuryRecoveryLibrary.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

/**
 * @title AdminFunctionsLibrary
 * @notice Library for rarely used admin functions to reduce contract size
 * 
 * @dev Main characteristics:
 *      - Consolidates admin functions like recoverToken
 *      - Reduces contract size by moving rarely used functions to library
 *      - Maintains same API and behavior
 *      - Uses custom errors for gas efficiency
 * 
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
 * @custom:security-contact team@quantillon.money
 */
library AdminFunctionsLibrary {
    /**
     * @notice Returns the semantic version of this linked library.
     * @dev On-chain version of the standalone deployed library; bump per semver on any change.
     *      See deployments/{chainId}/versions.json for deployed-address provenance.
     * @return Semantic version string (e.g. "1.0.0").
     * @custom:security No security implications - returns a compile-time constant.
     * @custom:validation No input validation required.
     * @custom:state-changes None - pure function.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable - pure function.
     * @custom:access Public - anyone can read the version.
     * @custom:oracle No oracle dependencies.
     */
    function version() external pure returns (string memory) {
        return "1.0.0";
    }

    /**
     * @notice Recover tokens to treasury address
     * @dev Emergency function to recover ERC20 tokens sent to the contract
     * @param contractInstance The contract instance calling this function
     * @param token Address of the token to recover
     * @param amount Amount of tokens to recover
     * @param treasury The treasury address to send tokens to
     * @param adminRole The admin role required for this operation
     * @custom:security Requires admin role
     * @custom:validation None required
     * @custom:state-changes Transfers tokens from contract to treasury
     * @custom:events Emits TokenRecovered event
     * @custom:errors Throws NotAuthorized if caller lacks admin role
     * @custom:reentrancy Not protected - library handles reentrancy
     * @custom:access Restricted to admin role
     * @custom:oracle Not applicable
     */
    function recoverToken(
        address contractInstance,
        address token,
        uint256 amount,
        address treasury,
        bytes32 adminRole
    ) external {
        AccessControlUpgradeable accessControl = AccessControlUpgradeable(contractInstance);
        
        if (!accessControl.hasRole(adminRole, msg.sender)) {
            revert CommonErrorLibrary.NotAuthorized();
        }
        
        TreasuryRecoveryLibrary.recoverToken(token, amount, contractInstance, treasury);
    }

}
