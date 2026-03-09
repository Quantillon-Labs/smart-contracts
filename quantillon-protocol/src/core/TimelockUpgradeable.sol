// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {TimeProvider} from "../libraries/TimeProviderLibrary.sol";
import {CommonValidationLibrary} from "../libraries/CommonValidationLibrary.sol";
import {CommonErrorLibrary} from "../libraries/CommonErrorLibrary.sol";
import {ISecureUpgradeable} from "../interfaces/ISecureUpgradeable.sol";

/**
 * @title TimelockUpgradeable
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
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

    /// @notice Maximum age of a pending upgrade proposal (LOW-6: prevents stale proposal execution)
    uint256 public constant MAX_PROPOSAL_AGE = 30 days;
    
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

    /// @notice Ordered list of multisig signers for approval clearing
    address[] internal _multisigSignersList;

    /// @notice Ordered list of pending upgrade addresses for signer clearing
    address[] internal _pendingUpgradesList;

    /// @notice TimeProvider contract for centralized time management
    /// @dev Used to replace direct block.timestamp usage for testability and consistency
    TimeProvider public immutable TIME_PROVIDER;
    
    // ============ Structs ============
    
    struct PendingUpgrade {
        address implementation;
        address proposingProxy;  // HIGH-1: proxy contract that initiated this upgrade proposal
        uint256 proposedAt;
        uint256 executableAt;
        uint256 expiryAt;        // LOW-6: proposal expires after MAX_PROPOSAL_AGE to prevent stale execution
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
        CommonValidationLibrary.validateCondition(multisigSigners[msg.sender], "authorization");
        _;
    }
    
    modifier onlyEmergencyUpgrader() {
        _onlyEmergencyUpgrader();
        _;
    }

    /**
     * @notice Reverts if caller is not emergency upgrader or emergency mode is not active
     * @dev Used by onlyEmergencyUpgrader modifier; allows emergency upgrades only when enabled
     * @custom:security Restricts emergency upgrade path to EMERGENCY_UPGRADER_ROLE when emergencyMode
     * @custom:validation Caller must have role and emergencyMode must be true
     * @custom:state-changes None
     * @custom:events None
     * @custom:errors NotEmergencyRole if not authorized or not emergency mode
     * @custom:reentrancy No external calls
     * @custom:access Internal; used by modifier
     * @custom:oracle None
     */
    function _onlyEmergencyUpgrader() internal view {
        if (!hasRole(EMERGENCY_UPGRADER_ROLE, msg.sender) || !emergencyMode) {
            revert CommonErrorLibrary.NotEmergencyRole();
        }
    }
    
    // ============ Initialization ============
    
    /**
     * @notice Initializes the timelock contract with admin privileges
     * @dev Sets up access control roles and pausability. Can only be called once.
     * @param admin The address that will receive admin and upgrade proposer roles
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to initializer modifier
     * @custom:oracle No oracle dependencies
     */
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
     * @dev Proposes an upgrade with timelock delay and multi-sig approval requirements
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to UPGRADE_PROPOSER_ROLE
     * @custom:oracle No oracle dependencies
     */
    function proposeUpgrade(
        address newImplementation,
        string calldata description,
        uint256 customDelay
    ) external onlyRole(UPGRADE_PROPOSER_ROLE) {
        CommonValidationLibrary.validateNonZeroAddress(newImplementation, "implementation");
        CommonValidationLibrary.validateCondition(pendingUpgrades[newImplementation].implementation == address(0), "duplicate");
        
        uint256 delay = customDelay >= UPGRADE_DELAY ? customDelay : UPGRADE_DELAY;
        CommonValidationLibrary.validateMaxAmount(delay, MAX_UPGRADE_DELAY);
        
        uint256 proposedAt = TIME_PROVIDER.currentTime();
        uint256 executableAt = proposedAt + delay;
        
        pendingUpgrades[newImplementation] = PendingUpgrade({
            implementation: newImplementation,
            proposingProxy: msg.sender,              // HIGH-1: caller is the proxy (via SecureUpgradeable.proposeUpgrade)
            proposedAt: proposedAt,
            executableAt: executableAt,
            expiryAt: proposedAt + MAX_PROPOSAL_AGE, // LOW-6: proposal expires after 30 days
            description: description,
            isEmergency: false,
            proposer: msg.sender
        });
        _pendingUpgradesList.push(newImplementation);

        emit UpgradeProposed(newImplementation, proposedAt, executableAt, description, msg.sender);
    }
    
    /**
     * @notice Approve a pending upgrade (multi-sig signer only)
     * @param implementation Address of the implementation to approve
     * @dev Allows multi-sig signers to approve pending upgrades
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to multi-sig signers
     * @custom:oracle No oracle dependencies
     */
    function approveUpgrade(address implementation) external onlyMultisigSigner {
        PendingUpgrade storage upgrade = pendingUpgrades[implementation];
        CommonValidationLibrary.validateCondition(upgrade.implementation != address(0), "pending");
        CommonValidationLibrary.validateCondition(!upgradeApprovals[msg.sender][implementation], "duplicate");
        
        upgradeApprovals[msg.sender][implementation] = true;
        upgradeApprovalCount[implementation]++;
        
        emit UpgradeApproved(implementation, msg.sender, upgradeApprovalCount[implementation]);
    }
    
    /**
     * @notice Revoke approval for a pending upgrade
     * @param implementation Address of the implementation to revoke approval for
     * @dev Allows multi-sig signers to revoke their approval for pending upgrades
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to multi-sig signers
     * @custom:oracle No oracle dependencies
     */
    function revokeUpgradeApproval(address implementation) external onlyMultisigSigner {
        CommonValidationLibrary.validateCondition(upgradeApprovals[msg.sender][implementation], "authorization");
        
        upgradeApprovals[msg.sender][implementation] = false;
        upgradeApprovalCount[implementation]--;
        
        emit UpgradeApproved(implementation, msg.sender, upgradeApprovalCount[implementation]);
    }
    
    /**
     * @notice Execute an upgrade after timelock and multi-sig approval
     * @param implementation Address of the implementation to execute
     * @dev Executes an upgrade after timelock delay and sufficient multi-sig approvals
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to UPGRADE_EXECUTOR_ROLE
     * @custom:oracle No oracle dependencies
     */
    function executeUpgrade(address implementation) external onlyRole(UPGRADE_EXECUTOR_ROLE) {
        PendingUpgrade storage upgrade = pendingUpgrades[implementation];
        CommonValidationLibrary.validateCondition(upgrade.implementation != address(0), "pending");
        CommonValidationLibrary.validateCondition(TIME_PROVIDER.currentTime() >= upgrade.executableAt, "timelock");
        CommonValidationLibrary.validateMinAmount(upgradeApprovalCount[implementation], MIN_MULTISIG_APPROVALS);
        // LOW-6: Reject stale proposals
        if (TIME_PROVIDER.currentTime() > upgrade.expiryAt) revert CommonErrorLibrary.NotActive();

        // Capture proxy address before clearing state (HIGH-1)
        address proxy = upgrade.proposingProxy;

        // Clear the pending upgrade
        delete pendingUpgrades[implementation];

        // Clear all approvals for this implementation
        _clearUpgradeApprovals(implementation);

        emit UpgradeExecuted(implementation, msg.sender, TIME_PROVIDER.currentTime());

        // HIGH-1: Actually perform the proxy upgrade — this was missing, causing upgrades to silently no-op.
        // SecureUpgradeable.executeUpgrade() checks msg.sender == address(timelock), which passes here
        // because this call originates from the TimelockUpgradeable contract itself.
        // Only call if proposingProxy is a contract (guards against EOA proposers in unit tests).
        if (proxy.code.length > 0) {
            ISecureUpgradeable(proxy).executeUpgrade(implementation);
        }
    }
    
    /**
     * @notice Cancel a pending upgrade (only proposer or admin)
     * @param implementation Address of the implementation to cancel
     * @dev Allows proposer or admin to cancel pending upgrades
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to proposer or admin
     * @custom:oracle No oracle dependencies
     */
    function cancelUpgrade(address implementation) external {
        PendingUpgrade storage upgrade = pendingUpgrades[implementation];
        CommonValidationLibrary.validateCondition(upgrade.implementation != address(0), "pending");
        CommonValidationLibrary.validateCondition(
            msg.sender == upgrade.proposer || hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "authorization"
        );
        
        delete pendingUpgrades[implementation];
        _clearUpgradeApprovals(implementation);
        
        emit UpgradeCancelled(implementation, msg.sender);
    }
    
    /**
     * @notice Emergency upgrade (bypasses timelock, requires emergency mode)
     * @param newImplementation Address of the new implementation
     * @param description Description of the emergency upgrade
     * @dev Performs emergency upgrade bypassing timelock and multi-sig requirements
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to emergency upgrader role
     * @custom:oracle No oracle dependencies
     */
    function emergencyUpgrade(
        address newImplementation,
        string calldata description
    ) external onlyEmergencyUpgrader {
        CommonValidationLibrary.validateNonZeroAddress(newImplementation, "implementation");
        
        // Clear any existing pending upgrade
        if (pendingUpgrades[newImplementation].implementation != address(0)) {
            delete pendingUpgrades[newImplementation];
            _clearUpgradeApprovals(newImplementation);
        }
        
        pendingUpgrades[newImplementation] = PendingUpgrade({
            implementation: newImplementation,
            proposingProxy: msg.sender,
            proposedAt: TIME_PROVIDER.currentTime(),
            executableAt: TIME_PROVIDER.currentTime(), // Immediate execution
            expiryAt: TIME_PROVIDER.currentTime() + MAX_PROPOSAL_AGE,
            description: description,
            isEmergency: true,
            proposer: msg.sender
        });
        
        emit UpgradeProposed(newImplementation, TIME_PROVIDER.currentTime(), TIME_PROVIDER.currentTime(), description, msg.sender);
        emit UpgradeExecuted(newImplementation, msg.sender, TIME_PROVIDER.currentTime());
    }
    
    // ============ Multi-sig Management ============
    
    /**
     * @notice Add a multi-sig signer
     * @param signer Address of the signer to add
     * @dev Adds a new multi-sig signer to the timelock system
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to MULTISIG_MANAGER_ROLE
     * @custom:oracle No oracle dependencies
     */
    function addMultisigSigner(address signer) external onlyRole(MULTISIG_MANAGER_ROLE) {
        CommonValidationLibrary.validateNonZeroAddress(signer, "signer");
        CommonValidationLibrary.validateCondition(!multisigSigners[signer], "duplicate");
        CommonValidationLibrary.validateCountLimit(multisigSignerCount, MAX_MULTISIG_SIGNERS);

        _addMultisigSigner(signer);
        
        emit MultisigSignerAdded(signer);
    }
    
    /**
     * @notice Remove a multi-sig signer
     * @param signer Address of the signer to remove
     * @dev Removes a multi-sig signer from the timelock system
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to MULTISIG_MANAGER_ROLE
     * @custom:oracle No oracle dependencies
     */
    function removeMultisigSigner(address signer) external onlyRole(MULTISIG_MANAGER_ROLE) {
        CommonValidationLibrary.validateCondition(multisigSigners[signer], "authorization");
        CommonValidationLibrary.validateMinAmount(multisigSignerCount, 2); // At least 2 signers required
        
        multisigSigners[signer] = false;
        multisigSignerCount--;

        // Remove from ordered list (swap-and-pop)
        uint256 len = _multisigSignersList.length;
        for (uint256 i = 0; i < len; i++) {
            if (_multisigSignersList[i] == signer) {
                _multisigSignersList[i] = _multisigSignersList[len - 1];
                _multisigSignersList.pop();
                break;
            }
        }

        // Clear any approvals from this signer
        _clearSignerApprovals(signer);

        emit MultisigSignerRemoved(signer);
    }
    
    // ============ Emergency Management ============
    
    /**
     * @notice Toggle emergency mode
     * @param enabled Whether to enable emergency mode
     * @param reason Reason for the emergency mode change
     * @dev Toggles emergency mode for emergency upgrades
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to EMERGENCY_UPGRADER_ROLE
     * @custom:oracle No oracle dependencies
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
     * @dev Returns pending upgrade details for a given implementation
     * @custom:security No security checks needed
     * @custom:validation No validation needed
     * @custom:state-changes No state changes
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy No reentrancy protection needed
     * @custom:access No access restrictions
     * @custom:oracle No oracle dependencies
     */
    function getPendingUpgrade(address implementation) external view returns (PendingUpgrade memory upgrade) {
        return pendingUpgrades[implementation];
    }
    
    /**
     * @notice Check if an upgrade can be executed
     * @param implementation Address of the implementation
     * @return canExecute Whether the upgrade can be executed
     * @dev Checks if an upgrade can be executed based on timelock and approval requirements
     * @custom:security No security checks needed
     * @custom:validation No validation needed
     * @custom:state-changes No state changes
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy No reentrancy protection needed
     * @custom:access No access restrictions
     * @custom:oracle No oracle dependencies
     */
    function canExecuteUpgrade(address implementation) external view returns (bool canExecute) {
        PendingUpgrade storage upgrade = pendingUpgrades[implementation];
        if (upgrade.implementation == address(0)) return false;
        
        return (
            TIME_PROVIDER.currentTime() >= upgrade.executableAt &&
            upgradeApprovalCount[implementation] >= MIN_MULTISIG_APPROVALS
        );
    }
    
    /**
     * @notice Get upgrade approval status for a signer
     * @param signer Address of the signer
     * @param implementation Address of the implementation
     * @return approved Whether the signer has approved the upgrade
     * @dev Returns whether a signer has approved a specific upgrade
     * @custom:security No security checks needed
     * @custom:validation No validation needed
     * @custom:state-changes No state changes
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy No reentrancy protection needed
     * @custom:access No access restrictions
     * @custom:oracle No oracle dependencies
     */
    function hasUpgradeApproval(address signer, address implementation) external view returns (bool approved) {
        return upgradeApprovals[signer][implementation];
    }
    
    /**
     * @notice Get all multi-sig signers
     * @return signers Array of signer addresses
     * @dev Returns array of all multi-sig signer addresses
     * @custom:security No security checks needed
     * @custom:validation No validation needed
     * @custom:state-changes No state changes
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy No reentrancy protection needed
     * @custom:access No access restrictions
     * @custom:oracle No oracle dependencies
     */
    function getMultisigSigners() external view returns (address[] memory signers) {
        uint256 len = _multisigSignersList.length;
        signers = new address[](len);
        for (uint256 i = 0; i < len; i++) {
            signers[i] = _multisigSignersList[i];
        }
    }
    
    // ============ Internal Functions ============
    
    /**
     * @notice Clear all approvals for an implementation
     * @param implementation Address of the implementation
     * @dev Clears all approvals for a specific implementation
     * @custom:security No security checks needed
     * @custom:validation No validation needed
     * @custom:state-changes Updates contract state variables
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy No reentrancy protection needed
     * @custom:access Internal function
     * @custom:oracle No oracle dependencies
     */
    /**
     * @notice Clear all approvals for a specific implementation
     * @param implementation Address of the implementation whose approvals should be cleared
     * @dev Resets approval counts for a pending upgrade and removes it from the ordered pending list
     * @custom:security Internal helper used after execute/cancel paths; assumes caller already validated upgrade existence
     * @custom:validation Assumes `implementation` is currently tracked in `_pendingUpgradesList`
     * @custom:state-changes Sets `upgradeApprovalCount[implementation]` to zero and clears all signer approvals
     * @custom:events No events emitted directly; caller is responsible for emitting high-level events
     * @custom:errors None - function is best-effort cleanup
     * @custom:reentrancy Not applicable - internal function with no external calls
     * @custom:access Internal function only
     * @custom:oracle No oracle dependencies
     */
    function _clearUpgradeApprovals(address implementation) internal {
        upgradeApprovalCount[implementation] = 0;
        for (uint256 i = 0; i < _multisigSignersList.length; i++) {
            upgradeApprovals[_multisigSignersList[i]][implementation] = false;
        }
        _removePendingUpgrade(implementation);
    }

    /**
     * @notice Remove an implementation from the ordered list of pending upgrades
     * @param implementation Address of the implementation to remove from `_pendingUpgradesList`
     * @dev Uses swap-and-pop to maintain a compact array of pending upgrades for efficient iteration
     * @custom:security Internal helper; assumes caller has already validated that the upgrade is pending
     * @custom:validation Performs a linear scan over `_pendingUpgradesList` and stops at first match
     * @custom:state-changes Updates `_pendingUpgradesList` by replacing the removed element with the last one and shrinking the array
     * @custom:events No events emitted directly; high-level events are emitted by caller functions
     * @custom:errors None - function silently returns if no match is found
     * @custom:reentrancy Not applicable - internal function with no external calls
     * @custom:access Internal function only
     * @custom:oracle No oracle dependencies
     */
    function _removePendingUpgrade(address implementation) internal {
        uint256 len = _pendingUpgradesList.length;
        for (uint256 i = 0; i < len; i++) {
            if (_pendingUpgradesList[i] == implementation) {
                _pendingUpgradesList[i] = _pendingUpgradesList[len - 1];
                _pendingUpgradesList.pop();
                break;
            }
        }
    }
    
    /**
     * @notice Clear all approvals from a specific signer
     * @param signer Address of the signer
     * @dev Clears all approvals from a specific signer
     * @custom:security No security checks needed
     * @custom:validation No validation needed
     * @custom:state-changes Updates contract state variables
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy No reentrancy protection needed
     * @custom:access Internal function
     * @custom:oracle No oracle dependencies
     */
    function _clearSignerApprovals(address signer) internal {
        for (uint256 i = 0; i < _pendingUpgradesList.length; i++) {
            address impl = _pendingUpgradesList[i];
            if (upgradeApprovals[signer][impl]) {
                upgradeApprovals[signer][impl] = false;
                upgradeApprovalCount[impl] -= 1;
            }
        }
    }
    
    /**
     * @notice Add a multisig signer (internal)
     * @param signer Address of the signer
     * @dev Adds a multisig signer internally
     * @custom:security No security checks needed
     * @custom:validation No validation needed
     * @custom:state-changes Updates contract state variables
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy No reentrancy protection needed
     * @custom:access Internal function
     * @custom:oracle No oracle dependencies
     */
    function _addMultisigSigner(address signer) internal {
        multisigSigners[signer] = true;
        multisigSignerCount++;
        _multisigSignersList.push(signer);
    }
    
    // ============ Override Functions ============
    
    /**
     * @notice Pause the timelock contract
     * @dev Pauses the timelock contract
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to DEFAULT_ADMIN_ROLE
     * @custom:oracle No oracle dependencies
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    
    /**
     * @notice Unpause the timelock contract
     * @dev Unpauses the timelock contract
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to DEFAULT_ADMIN_ROLE
     * @custom:oracle No oracle dependencies
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    // ============ Constructor ============

    /**
     * @notice Constructor for TimelockUpgradeable contract
     * @param _TIME_PROVIDER TimeProvider contract for centralized time management
     * @dev Sets up the time provider and disables initializers for security
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Disables initializers
     * @custom:events No events emitted
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy No reentrancy protection needed
     * @custom:access No access restrictions
     * @custom:oracle No oracle dependencies
     */
    constructor(TimeProvider _TIME_PROVIDER) {
        if (address(_TIME_PROVIDER) == address(0)) revert CommonErrorLibrary.ZeroAddress();
        TIME_PROVIDER = _TIME_PROVIDER;
        _disableInitializers();
    }
}
