// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ITimelockUpgradeable} from "../interfaces/ITimelockUpgradeable.sol";

/// @title SecureUpgradeLibrary
/// @notice Linked compatibility helpers for the protocol's custom timelock interface.
/// @dev The production OZ controller is scheduled directly using operation ids.
library SecureUpgradeLibrary {
    /**
     * @notice Semantic version of this linked library.
     * @dev Preserves custom-controller compatibility through delegatecall.
     * @return Semantic version.
     * @custom:security Caller enforces proposal authorization.
     * @custom:validation The configured controller validates proposals.
     * @custom:state-changes Only propose modifies controller state.
     * @custom:events Controller proposal events when applicable.
     * @custom:errors Propagates controller errors.
     * @custom:reentrancy Calls only the configured controller.
     * @custom:access Linked helper.
     * @custom:oracle None.
     */
    function version() external pure returns (string memory) {
        return "1.0.1";
    }

    /**
     * @notice Forwards a proposal to a custom timelock.
     * @dev Preserves custom-controller compatibility through delegatecall.
     * @param controller Configured custom timelock.
     * @param implementation Proposed implementation.
     * @param description Proposal description.
     * @param delay Requested delay.
     * @custom:security Caller enforces proposal authorization.
     * @custom:validation The configured controller validates proposals.
     * @custom:state-changes Only propose modifies controller state.
     * @custom:events Controller proposal events when applicable.
     * @custom:errors Propagates controller errors.
     * @custom:reentrancy Calls only the configured controller.
     * @custom:access Linked helper.
     * @custom:oracle None.
     */
    function propose(ITimelockUpgradeable controller, address implementation, string calldata description, uint256 delay) external {
        controller.proposeUpgrade(implementation, description, delay);
    }

    /**
     * @notice Returns custom timelock proposal details.
     * @dev Preserves custom-controller compatibility through delegatecall.
     * @param controller Configured custom timelock.
     * @param implementation Proposed implementation.
     * @return proposal Proposal details or an empty record.
     * @custom:security Caller enforces proposal authorization.
     * @custom:validation The configured controller validates proposals.
     * @custom:state-changes Only propose modifies controller state.
     * @custom:events Controller proposal events when applicable.
     * @custom:errors Propagates controller errors.
     * @custom:reentrancy Calls only the configured controller.
     * @custom:access Linked helper.
     * @custom:oracle None.
     */
    function pending(ITimelockUpgradeable controller, address implementation) external view returns (ITimelockUpgradeable.PendingUpgrade memory proposal) {
        if (address(controller) != address(0)) return controller.getPendingUpgrade(implementation);
    }

    /**
     * @notice Reports whether a custom proposal exists.
     * @dev Preserves custom-controller compatibility through delegatecall.
     * @param controller Configured custom timelock.
     * @param implementation Proposed implementation.
     * @return Whether a proposal exists.
     * @custom:security Caller enforces proposal authorization.
     * @custom:validation The configured controller validates proposals.
     * @custom:state-changes Only propose modifies controller state.
     * @custom:events Controller proposal events when applicable.
     * @custom:errors Propagates controller errors.
     * @custom:reentrancy Calls only the configured controller.
     * @custom:access Linked helper.
     * @custom:oracle None.
     */
    function isPending(ITimelockUpgradeable controller, address implementation) external view returns (bool) {
        if (address(controller) == address(0)) return false;
        return controller.getPendingUpgrade(implementation).implementation != address(0);
    }

    /**
     * @notice Reports whether a custom proposal is executable.
     * @dev Preserves custom-controller compatibility through delegatecall.
     * @param controller Configured custom timelock.
     * @param implementation Proposed implementation.
     * @return Whether the controller permits execution.
     * @custom:security Caller enforces proposal authorization.
     * @custom:validation The configured controller validates proposals.
     * @custom:state-changes Only propose modifies controller state.
     * @custom:events Controller proposal events when applicable.
     * @custom:errors Propagates controller errors.
     * @custom:reentrancy Calls only the configured controller.
     * @custom:access Linked helper.
     * @custom:oracle None.
     */
    function canExecute(ITimelockUpgradeable controller, address implementation) external view returns (bool) {
        if (address(controller) == address(0)) return false;
        return controller.canExecuteUpgrade(implementation);
    }

}
