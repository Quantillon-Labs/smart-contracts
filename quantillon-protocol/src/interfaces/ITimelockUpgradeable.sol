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
     * @dev Initiates a secure upgrade proposal with timelock delay and multi-sig requirements
     * @param newImplementation Address of the new implementation
     * @param description Description of the upgrade
     * @param customDelay Optional custom delay (must be >= UPGRADE_DELAY)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function proposeUpgrade(
        address newImplementation,
        string calldata description,
        uint256 customDelay
    ) external;
    
    /**
     * @notice Approve a pending upgrade (multi-sig signer only)
     * @dev Allows multi-sig signers to approve pending upgrades
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
     * @dev Allows multi-sig signers to revoke their approval for pending upgrades
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
     * @dev Executes a previously approved upgrade after timelock delay
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
     * @dev Allows proposer or admin to cancel a pending upgrade
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
     * @dev Performs immediate upgrade in emergency situations
     * @param newImplementation Address of the new implementation
     * @param description Description of the emergency upgrade
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function emergencyUpgrade(
        address newImplementation,
        string calldata description
    ) external;
    
    // ============ Multi-sig Management ============
    
    /**
     * @notice Add a multi-sig signer
     * @dev Adds a new multi-sig signer to the approval process
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
     * @dev Removes a multi-sig signer from the approval process
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
     * @dev Enables or disables emergency mode for immediate upgrades
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
     * @dev Returns detailed information about a pending upgrade
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
     * @dev Checks if the timelock delay has passed and upgrade can be executed
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
     * @dev Checks if a specific signer has approved a specific upgrade
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
     * @dev Returns array of all authorized multi-sig signers
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
    
    /**
     * @notice Returns pending upgrade details for an implementation
     * @dev Maps implementation address to pending upgrade information
     * @param implementation Address of the implementation
     * @return implementation Address of the new implementation
     * @return proposedAt Timestamp when upgrade was proposed
     * @return executableAt Timestamp when upgrade can be executed
     * @return description Description of the upgrade
     * @return isEmergency Whether this is an emergency upgrade
     * @return proposer Address of the proposer
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function pendingUpgrades(address) external view returns (
        address implementation,
        uint256 proposedAt,
        uint256 executableAt,
        string memory description,
        bool isEmergency,
        address proposer
    );
    
    /**
     * @notice Checks if an address is a multi-sig signer
     * @dev Returns true if the address is authorized as a multi-sig signer
     * @return True if the address is a multi-sig signer
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function multisigSigners(address) external view returns (bool);
    
    /**
     * @notice Returns the total number of multi-sig signers
     * @dev Returns the count of authorized multi-sig signers
     * @return Total number of multi-sig signers
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function multisigSignerCount() external view returns (uint256);
    
    /**
     * @notice Checks if a signer has approved an upgrade
     * @dev Returns true if the signer has approved the specific upgrade
     * @return True if the signer has approved the upgrade
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function upgradeApprovals(address, address) external view returns (bool);
    
    /**
     * @notice Returns the number of approvals for an upgrade
     * @dev Returns the count of approvals for a specific upgrade
     * @return Number of approvals for the upgrade
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function upgradeApprovalCount(address) external view returns (uint256);
    
    /**
     * @notice Returns whether emergency mode is enabled
     * @dev Indicates if emergency mode is currently active
     * @return True if emergency mode is enabled
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function emergencyMode() external view returns (bool);
    
    // ============ Constants ============
    
    /**
     * @notice Returns the default upgrade delay
     * @dev Minimum delay required for upgrades (in seconds)
     * @return Default upgrade delay in seconds
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function UPGRADE_DELAY() external view returns (uint256);
    
    /**
     * @notice Returns the maximum allowed upgrade delay
     * @dev Maximum delay that can be set for upgrades (in seconds)
     * @return Maximum upgrade delay in seconds
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function MAX_UPGRADE_DELAY() external view returns (uint256);
    
    /**
     * @notice Returns the minimum required multi-sig approvals
     * @dev Minimum number of approvals required to execute an upgrade
     * @return Minimum number of required approvals
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function MIN_MULTISIG_APPROVALS() external view returns (uint256);
    
    /**
     * @notice Returns the maximum allowed multi-sig signers
     * @dev Maximum number of multi-sig signers that can be added
     * @return Maximum number of multi-sig signers
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function MAX_MULTISIG_SIGNERS() external view returns (uint256);
    
    // ============ Roles ============
    
    /**
     * @notice Returns the upgrade proposer role identifier
     * @dev Role that can propose upgrades
     * @return The upgrade proposer role bytes32 identifier
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function UPGRADE_PROPOSER_ROLE() external view returns (bytes32);
    
    /**
     * @notice Returns the upgrade executor role identifier
     * @dev Role that can execute upgrades
     * @return The upgrade executor role bytes32 identifier
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function UPGRADE_EXECUTOR_ROLE() external view returns (bytes32);
    
    /**
     * @notice Returns the emergency upgrader role identifier
     * @dev Role that can perform emergency upgrades
     * @return The emergency upgrader role bytes32 identifier
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function EMERGENCY_UPGRADER_ROLE() external view returns (bytes32);
    
    /**
     * @notice Returns the multi-sig manager role identifier
     * @dev Role that can manage multi-sig signers
     * @return The multi-sig manager role bytes32 identifier
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function MULTISIG_MANAGER_ROLE() external view returns (bytes32);
}
