// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./ITimelockUpgradeable.sol";

/**
 * @title ISecureUpgradeable
 * @notice Interface for the SecureUpgradeable base contract
 * @author Quantillon Labs
 * @custom:security-contact team@quantillon.money
 */
interface ISecureUpgradeable {
    /**
     * @notice Set the timelock contract
     * @param _timelock Address of the timelock contract
     */
    function setTimelock(address _timelock) external;

    /**
     * @notice Toggle secure upgrades
     * @param enabled Whether to enable secure upgrades
     */
    function toggleSecureUpgrades(bool enabled) external;

    /**
     * @notice Propose an upgrade through the timelock
     * @param newImplementation Address of the new implementation
     * @param description Description of the upgrade
     * @param customDelay Optional custom delay
     */
    function proposeUpgrade(
        address newImplementation,
        string calldata description,
        uint256 customDelay
    ) external;

    /**
     * @notice Execute an upgrade through the timelock
     * @param newImplementation Address of the new implementation
     */
    function executeUpgrade(address newImplementation) external;

    /**
     * @notice Emergency upgrade (bypasses timelock, requires emergency mode)
     * @param newImplementation Address of the new implementation
     * @param description Description of the emergency upgrade
     */
    function emergencyUpgrade(
        address newImplementation,
        string calldata description
    ) external;

    /**
     * @notice Check if an upgrade is pending
     * @param implementation Address of the implementation
     * @return isPending Whether the upgrade is pending
     */
    function isUpgradePending(address implementation) external view returns (bool isPending);

    /**
     * @notice Get pending upgrade details
     * @param implementation Address of the implementation
     * @return upgrade Pending upgrade details
     */
    function getPendingUpgrade(address implementation) external view returns (ITimelockUpgradeable.PendingUpgrade memory upgrade);

    /**
     * @notice Check if an upgrade can be executed
     * @param implementation Address of the implementation
     * @return canExecute Whether the upgrade can be executed
     */
    function canExecuteUpgrade(address implementation) external view returns (bool canExecute);

    /**
     * @notice Get upgrade security status
     * @return timelockAddress Address of the timelock contract
     * @return secureUpgradesEnabled_ Whether secure upgrades are enabled
     * @return hasTimelock Whether timelock is set
     */
    function getUpgradeSecurityStatus() external view returns (
        address timelockAddress,
        bool secureUpgradesEnabled_,
        bool hasTimelock
    );

    /**
     * @notice Disable secure upgrades in emergency
     */
    function emergencyDisableSecureUpgrades() external;

    /**
     * @notice Enable secure upgrades after emergency
     */
    function enableSecureUpgrades() external;

    // View functions
    function timelock() external view returns (ITimelockUpgradeable);
    function secureUpgradesEnabled() external view returns (bool);
    function UPGRADER_ROLE() external view returns (bytes32);

    // AccessControl functions
    function hasRole(bytes32 role, address account) external view returns (bool);
    function getRoleAdmin(bytes32 role) external view returns (bytes32);
    function grantRole(bytes32 role, address account) external;
    function revokeRole(bytes32 role, address account) external;
    function renounceRole(bytes32 role, address callerConfirmation) external;

    // UUPS functions
    function upgradeTo(address newImplementation) external;
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable;
}
