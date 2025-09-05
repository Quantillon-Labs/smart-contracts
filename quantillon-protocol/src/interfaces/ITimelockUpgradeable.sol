// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title ITimelockUpgradeable
 * @author Quantillon Labs
 * @custom:security-contact team@quantillon.money
 * @notice Interface for the secure upgrade mechanism with timelock and multi-sig requirements
 */
interface ITimelockUpgradeable {
    
    // ============ Structs ============
    
    struct PendingUpgrade {
        address implementation;
        uint256 proposedAt;
        uint256 executableAt;
        string description;
        bool isEmergency;
        address proposer;
    }
    
    // ============ Events ============
    
    event UpgradeProposed(
        address indexed implementation,
        uint256 proposedAt,
        uint256 executableAt,
        string description,
        address indexed proposer
    );
    
    event UpgradeApproved(
        address indexed implementation,
        address indexed signer,
        uint256 approvalCount
    );
    
    event UpgradeExecuted(
        address indexed implementation,
        address indexed executor,
        uint256 executedAt
    );
    
    event UpgradeCancelled(
        address indexed implementation,
        address indexed canceller
    );
    
    event MultisigSignerAdded(address indexed signer);
    event MultisigSignerRemoved(address indexed signer);
    event EmergencyModeToggled(bool enabled, string reason);
    
    // ============ Upgrade Management ============
    
    /**
     * @notice Propose an upgrade with timelock
     * @param newImplementation Address of the new implementation
     * @param description Description of the upgrade
     * @param customDelay Optional custom delay (must be >= UPGRADE_DELAY)
     */
    function proposeUpgrade(
        address newImplementation,
        string calldata description,
        uint256 customDelay
    ) external;
    
    /**
     * @notice Approve a pending upgrade (multi-sig signer only)
     * @param implementation Address of the implementation to approve
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function approveUpgrade(address implementation) external;
    
    /**
     * @notice Revoke approval for a pending upgrade
     * @param implementation Address of the implementation to revoke approval for
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function revokeUpgradeApproval(address implementation) external;
    
    /**
     * @notice Execute an upgrade after timelock and multi-sig approval
     * @param implementation Address of the implementation to execute
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function executeUpgrade(address implementation) external;
    
    /**
     * @notice Cancel a pending upgrade (only proposer or admin)
     * @param implementation Address of the implementation to cancel
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function cancelUpgrade(address implementation) external;
    
    /**
     * @notice Emergency upgrade (bypasses timelock, requires emergency mode)
     * @param newImplementation Address of the new implementation
     * @param description Description of the emergency upgrade
     */
    function emergencyUpgrade(
        address newImplementation,
        string calldata description
    ) external;
    
    // ============ Multi-sig Management ============
    
    /**
     * @notice Add a multi-sig signer
     * @param signer Address of the signer to add
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function addMultisigSigner(address signer) external;
    
    /**
     * @notice Remove a multi-sig signer
     * @param signer Address of the signer to remove
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function removeMultisigSigner(address signer) external;
    
    // ============ Emergency Management ============
    
    /**
     * @notice Toggle emergency mode
     * @param enabled Whether to enable emergency mode
     * @param reason Reason for the emergency mode change
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function toggleEmergencyMode(bool enabled, string calldata reason) external;
    
    // ============ View Functions ============
    
    /**
     * @notice Get pending upgrade details
     * @param implementation Address of the implementation
     * @return upgrade Pending upgrade details
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getPendingUpgrade(address implementation) external view returns (PendingUpgrade memory upgrade);
    
    /**
     * @notice Check if an upgrade can be executed
     * @param implementation Address of the implementation
     * @return canExecute Whether the upgrade can be executed
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function canExecuteUpgrade(address implementation) external view returns (bool canExecute);
    
    /**
     * @notice Get upgrade approval status for a signer
     * @param signer Address of the signer
     * @param implementation Address of the implementation
     * @return approved Whether the signer has approved the upgrade
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function hasUpgradeApproval(address signer, address implementation) external view returns (bool approved);
    
    /**
     * @notice Get all multi-sig signers
     * @return signers Array of signer addresses
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getMultisigSigners() external view returns (address[] memory signers);
    
    // ============ State Variables ============
    
    function pendingUpgrades(address) external view returns (
        address implementation,
        uint256 proposedAt,
        uint256 executableAt,
        string memory description,
        bool isEmergency,
        address proposer
    );
    
    function multisigSigners(address) external view returns (bool);
    function multisigSignerCount() external view returns (uint256);
    function upgradeApprovals(address, address) external view returns (bool);
    function upgradeApprovalCount(address) external view returns (uint256);
    function emergencyMode() external view returns (bool);
    
    // ============ Constants ============
    
    function UPGRADE_DELAY() external view returns (uint256);
    function MAX_UPGRADE_DELAY() external view returns (uint256);
    function MIN_MULTISIG_APPROVALS() external view returns (uint256);
    function MAX_MULTISIG_SIGNERS() external view returns (uint256);
    
    // ============ Roles ============
    
    function UPGRADE_PROPOSER_ROLE() external view returns (bytes32);
    function UPGRADE_EXECUTOR_ROLE() external view returns (bytes32);
    function EMERGENCY_UPGRADER_ROLE() external view returns (bytes32);
    function MULTISIG_MANAGER_ROLE() external view returns (bytes32);
}
