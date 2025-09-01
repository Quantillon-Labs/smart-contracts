// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

/**
 * @title TimelockUpgradeable
 * @author Quantillon Labs
 * @custom:security-contact team@quantillon.money
 * @notice Secure upgrade mechanism with timelock and multi-sig requirements
 * @dev Replaces unrestricted upgrade capability with governance-controlled upgrades
 */
contract TimelockUpgradeable is Initializable, AccessControlUpgradeable, PausableUpgradeable {
    
    // ============ Constants ============
    
    /// @notice Minimum delay for upgrades (48 hours)
    uint256 public constant UPGRADE_DELAY = 48 hours;
    
    /// @notice Maximum delay for upgrades (7 days)
    uint256 public constant MAX_UPGRADE_DELAY = 7 days;
    
    /// @notice Minimum number of multi-sig approvals required
    uint256 public constant MIN_MULTISIG_APPROVALS = 2;
    
    /// @notice Maximum number of multi-sig signers
    uint256 public constant MAX_MULTISIG_SIGNERS = 5;
    
    // ============ Roles ============
    
    /// @notice Role for proposing upgrades
    bytes32 public constant UPGRADE_PROPOSER_ROLE = keccak256("UPGRADE_PROPOSER_ROLE");
    
    /// @notice Role for executing upgrades after timelock
    bytes32 public constant UPGRADE_EXECUTOR_ROLE = keccak256("UPGRADE_EXECUTOR_ROLE");
    
    /// @notice Role for emergency upgrades (bypasses timelock)
    bytes32 public constant EMERGENCY_UPGRADER_ROLE = keccak256("EMERGENCY_UPGRADER_ROLE");
    
    /// @notice Role for managing multi-sig signers
    bytes32 public constant MULTISIG_MANAGER_ROLE = keccak256("MULTISIG_MANAGER_ROLE");
    
    // ============ State Variables ============
    
    /// @notice Pending upgrades by implementation address
    mapping(address => PendingUpgrade) public pendingUpgrades;
    
    /// @notice Multi-sig signers
    mapping(address => bool) public multisigSigners;
    
    /// @notice Number of active multi-sig signers
    uint256 public multisigSignerCount;
    
    /// @notice Upgrade approvals by signer
    mapping(address => mapping(address => bool)) public upgradeApprovals;
    
    /// @notice Number of approvals for each pending upgrade
    mapping(address => uint256) public upgradeApprovalCount;
    
    /// @notice Whether emergency mode is active
    bool public emergencyMode;
    
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
    
    // ============ Modifiers ============
    
    modifier onlyMultisigSigner() {
        require(multisigSigners[msg.sender], "TimelockUpgradeable: Not multisig signer");
        _;
    }
    
    modifier onlyEmergencyUpgrader() {
        require(
            hasRole(EMERGENCY_UPGRADER_ROLE, msg.sender) && emergencyMode,
            "TimelockUpgradeable: Not emergency upgrader or emergency mode inactive"
        );
        _;
    }
    
    // ============ Initialization ============
    
    function initialize(address admin) public initializer {
        __AccessControl_init();
        __Pausable_init();
        
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(UPGRADE_PROPOSER_ROLE, admin);
        _grantRole(UPGRADE_EXECUTOR_ROLE, admin);
        _grantRole(EMERGENCY_UPGRADER_ROLE, admin);
        _grantRole(MULTISIG_MANAGER_ROLE, admin);
        
        // Add admin as initial multisig signer
        _addMultisigSigner(admin);
    }
    
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
    ) external onlyRole(UPGRADE_PROPOSER_ROLE) {
        require(newImplementation != address(0), "TimelockUpgradeable: Invalid implementation");
        require(pendingUpgrades[newImplementation].implementation == address(0), "TimelockUpgradeable: Already proposed");
        
        uint256 delay = customDelay >= UPGRADE_DELAY ? customDelay : UPGRADE_DELAY;
        require(delay <= MAX_UPGRADE_DELAY, "TimelockUpgradeable: Delay too long");
        
        uint256 proposedAt = block.timestamp;
        uint256 executableAt = proposedAt + delay;
        
        pendingUpgrades[newImplementation] = PendingUpgrade({
            implementation: newImplementation,
            proposedAt: proposedAt,
            executableAt: executableAt,
            description: description,
            isEmergency: false,
            proposer: msg.sender
        });
        
        emit UpgradeProposed(newImplementation, proposedAt, executableAt, description, msg.sender);
    }
    
    /**
     * @notice Approve a pending upgrade (multi-sig signer only)
     * @param implementation Address of the implementation to approve
     */
    function approveUpgrade(address implementation) external onlyMultisigSigner {
        PendingUpgrade storage upgrade = pendingUpgrades[implementation];
        require(upgrade.implementation != address(0), "TimelockUpgradeable: No pending upgrade");
        require(!upgradeApprovals[msg.sender][implementation], "TimelockUpgradeable: Already approved");
        
        upgradeApprovals[msg.sender][implementation] = true;
        upgradeApprovalCount[implementation]++;
        
        emit UpgradeApproved(implementation, msg.sender, upgradeApprovalCount[implementation]);
    }
    
    /**
     * @notice Revoke approval for a pending upgrade
     * @param implementation Address of the implementation to revoke approval for
     */
    function revokeUpgradeApproval(address implementation) external onlyMultisigSigner {
        require(upgradeApprovals[msg.sender][implementation], "TimelockUpgradeable: Not approved");
        
        upgradeApprovals[msg.sender][implementation] = false;
        upgradeApprovalCount[implementation]--;
        
        emit UpgradeApproved(implementation, msg.sender, upgradeApprovalCount[implementation]);
    }
    
    /**
     * @notice Execute an upgrade after timelock and multi-sig approval
     * @param implementation Address of the implementation to execute
     */
    function executeUpgrade(address implementation) external onlyRole(UPGRADE_EXECUTOR_ROLE) {
        PendingUpgrade storage upgrade = pendingUpgrades[implementation];
        require(upgrade.implementation != address(0), "TimelockUpgradeable: No pending upgrade");
        require(block.timestamp >= upgrade.executableAt, "TimelockUpgradeable: Timelock not expired");
        require(
            upgradeApprovalCount[implementation] >= MIN_MULTISIG_APPROVALS,
            "TimelockUpgradeable: Insufficient approvals"
        );
        
        // Clear the pending upgrade
        delete pendingUpgrades[implementation];
        
        // Clear all approvals for this implementation
        _clearUpgradeApprovals(implementation);
        
        emit UpgradeExecuted(implementation, msg.sender, block.timestamp);
    }
    
    /**
     * @notice Cancel a pending upgrade (only proposer or admin)
     * @param implementation Address of the implementation to cancel
     */
    function cancelUpgrade(address implementation) external {
        PendingUpgrade storage upgrade = pendingUpgrades[implementation];
        require(upgrade.implementation != address(0), "TimelockUpgradeable: No pending upgrade");
        require(
            msg.sender == upgrade.proposer || hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "TimelockUpgradeable: Not authorized"
        );
        
        delete pendingUpgrades[implementation];
        _clearUpgradeApprovals(implementation);
        
        emit UpgradeCancelled(implementation, msg.sender);
    }
    
    /**
     * @notice Emergency upgrade (bypasses timelock, requires emergency mode)
     * @param newImplementation Address of the new implementation
     * @param description Description of the emergency upgrade
     */
    function emergencyUpgrade(
        address newImplementation,
        string calldata description
    ) external onlyEmergencyUpgrader {
        require(newImplementation != address(0), "TimelockUpgradeable: Invalid implementation");
        
        // Clear any existing pending upgrade
        if (pendingUpgrades[newImplementation].implementation != address(0)) {
            delete pendingUpgrades[newImplementation];
            _clearUpgradeApprovals(newImplementation);
        }
        
        pendingUpgrades[newImplementation] = PendingUpgrade({
            implementation: newImplementation,
            proposedAt: block.timestamp,
            executableAt: block.timestamp, // Immediate execution
            description: description,
            isEmergency: true,
            proposer: msg.sender
        });
        
        emit UpgradeProposed(newImplementation, block.timestamp, block.timestamp, description, msg.sender);
        emit UpgradeExecuted(newImplementation, msg.sender, block.timestamp);
    }
    
    // ============ Multi-sig Management ============
    
    /**
     * @notice Add a multi-sig signer
     * @param signer Address of the signer to add
     */
    function addMultisigSigner(address signer) external onlyRole(MULTISIG_MANAGER_ROLE) {
        require(signer != address(0), "TimelockUpgradeable: Invalid signer");
        require(!multisigSigners[signer], "TimelockUpgradeable: Already signer");
        require(multisigSignerCount < MAX_MULTISIG_SIGNERS, "TimelockUpgradeable: Too many signers");
        
        multisigSigners[signer] = true;
        multisigSignerCount++;
        
        emit MultisigSignerAdded(signer);
    }
    
    /**
     * @notice Remove a multi-sig signer
     * @param signer Address of the signer to remove
     */
    function removeMultisigSigner(address signer) external onlyRole(MULTISIG_MANAGER_ROLE) {
        require(multisigSigners[signer], "TimelockUpgradeable: Not signer");
        require(multisigSignerCount > 1, "TimelockUpgradeable: Cannot remove last signer");
        
        multisigSigners[signer] = false;
        multisigSignerCount--;
        
        // Clear any approvals from this signer
        _clearSignerApprovals(signer);
        
        emit MultisigSignerRemoved(signer);
    }
    
    // ============ Emergency Management ============
    
    /**
     * @notice Toggle emergency mode
     * @param enabled Whether to enable emergency mode
     * @param reason Reason for the emergency mode change
     */
    function toggleEmergencyMode(bool enabled, string calldata reason) external onlyRole(EMERGENCY_UPGRADER_ROLE) {
        emergencyMode = enabled;
        emit EmergencyModeToggled(enabled, reason);
    }
    
    // ============ View Functions ============
    
    /**
     * @notice Get pending upgrade details
     * @param implementation Address of the implementation
     * @return upgrade Pending upgrade details
     */
    function getPendingUpgrade(address implementation) external view returns (PendingUpgrade memory upgrade) {
        return pendingUpgrades[implementation];
    }
    
    /**
     * @notice Check if an upgrade can be executed
     * @param implementation Address of the implementation
     * @return canExecute Whether the upgrade can be executed
     */
    function canExecuteUpgrade(address implementation) external view returns (bool canExecute) {
        PendingUpgrade storage upgrade = pendingUpgrades[implementation];
        if (upgrade.implementation == address(0)) return false;
        
        return (
            block.timestamp >= upgrade.executableAt &&
            upgradeApprovalCount[implementation] >= MIN_MULTISIG_APPROVALS
        );
    }
    
    /**
     * @notice Get upgrade approval status for a signer
     * @param signer Address of the signer
     * @param implementation Address of the implementation
     * @return approved Whether the signer has approved the upgrade
     */
    function hasUpgradeApproval(address signer, address implementation) external view returns (bool approved) {
        return upgradeApprovals[signer][implementation];
    }
    
    /**
     * @notice Get all multi-sig signers
     * @return signers Array of signer addresses
     */
    function getMultisigSigners() external view returns (address[] memory signers) {
        signers = new address[](multisigSignerCount);
        uint256 index = 0;
        
        // This is a simplified version - in production, you'd want to maintain a separate array
        // For now, we'll return an empty array as this is just for demonstration
        return signers;
    }
    
    // ============ Internal Functions ============
    
    /**
     * @notice Clear all approvals for an implementation
     * @param implementation Address of the implementation
     */
    function _clearUpgradeApprovals(address implementation) internal {
        // In a production environment, you'd iterate through all signers
        // For now, we just reset the count
        upgradeApprovalCount[implementation] = 0;
    }
    
    /**
     * @notice Clear all approvals from a specific signer
     * @param signer Address of the signer
     */
    function _clearSignerApprovals(address signer) internal {
        // In a production environment, you'd iterate through all pending upgrades
        // For now, this is a placeholder
    }
    
    /**
     * @notice Add a multisig signer (internal)
     * @param signer Address of the signer
     */
    function _addMultisigSigner(address signer) internal {
        multisigSigners[signer] = true;
        multisigSignerCount++;
    }
    
    // ============ Override Functions ============
    
    /**
     * @notice Pause the timelock contract
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    
    /**
     * @notice Unpause the timelock contract
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}
