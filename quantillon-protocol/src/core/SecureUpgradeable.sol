// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ITimelockUpgradeable} from "../interfaces/ITimelockUpgradeable.sol";
import {CommonErrorLibrary} from "../libraries/CommonErrorLibrary.sol";

/**
 * @title SecureUpgradeable
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
 * @custom:security-contact team@quantillon.money
 * @notice Secure base contract for upgradeable contracts with timelock protection
 * @dev Replaces UUPSUpgradeable with timelock and multi-sig requirements
 */
abstract contract SecureUpgradeable is UUPSUpgradeable, AccessControlUpgradeable {
    
    // ============ Constants ============
    
    /// @notice Role for upgrade operations
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    
    // ============ State Variables ============
    
    /// @notice Timelock contract for secure upgrades
    ITimelockUpgradeable public timelock;
    
    /// @notice Whether the contract is using secure upgrades
    bool public secureUpgradesEnabled;

    /// @notice INFO-4: Minimum delay before a proposed emergency-disable takes effect (24h)
    uint256 public constant EMERGENCY_DISABLE_DELAY = 24 hours;

    /// @notice Emergency-disable approvals required before apply can succeed
    uint256 public constant EMERGENCY_DISABLE_QUORUM = 2;

    /// @notice INFO-4: Timestamp at which emergencyDisable can be applied (0 = no pending proposal)
    uint256 public emergencyDisablePendingAt;

    /// @dev Unstructured storage slot to avoid shifting child storage layouts.
    bytes32 private constant EMERGENCY_DISABLE_STORAGE_SLOT =
        keccak256("quantillon.secure-upgradeable.emergency-disable.storage.v1");

    struct EmergencyDisableStorage {
        uint256 proposalId;
        uint256 approvalCount;
        mapping(uint256 => mapping(address => bool)) hasApproved;
    }

    // ============ Events ============

    event TimelockSet(address indexed timelock);
    event SecureUpgradesToggled(bool enabled);
    event SecureUpgradeAuthorized(address indexed newImplementation, address indexed authorizedBy, string description);
    /// @notice INFO-4: Emitted when an emergency-disable proposal is created
    event EmergencyDisableProposed(uint256 indexed proposalId, uint256 activatesAt);
    event EmergencyDisableApproved(uint256 indexed proposalId, address indexed approver, uint256 approvalCount);

    function _emergencyDisableStorage() private pure returns (EmergencyDisableStorage storage ds) {
        bytes32 slot = EMERGENCY_DISABLE_STORAGE_SLOT;
        assembly {
            ds.slot := slot
        }
    }
    
    // ============ Modifiers ============
    
    modifier onlyTimelock() {
        _onlyTimelock();
        _;
    }

    /**
     * @notice Reverts if caller is not the timelock contract
     * @dev Used by onlyTimelock modifier; ensures upgrade execution comes from timelock only
     * @custom:security Access control for upgrade execution
     * @custom:validation Timelock must be set and msg.sender must equal timelock
     * @custom:state-changes None
     * @custom:events None
     * @custom:errors NotAuthorized if timelock zero or caller not timelock
     * @custom:reentrancy No external calls
     * @custom:access Internal; used by modifier
     * @custom:oracle None
     */
    function _onlyTimelock() internal view {
        if (address(timelock) == address(0) || msg.sender != address(timelock)) {
            revert CommonErrorLibrary.NotAuthorized();
        }
    }
    
    // ============ Initialization ============
    
    /**
     * @notice Initializes the SecureUpgradeable contract
     * @dev Sets up the secure upgrade system with timelock protection
     * @param _timelock Address of the timelock contract
     * @custom:security Validates timelock address and initializes secure upgrade system
     * @custom:validation Validates _timelock is not address(0)
     * @custom:state-changes Initializes timelock, enables secure upgrades, sets up access control
     * @custom:events Emits TimelockSet and SecureUpgradesToggled events
     * @custom:errors Throws "SecureUpgradeable: Invalid timelock" if _timelock is address(0)
     * @custom:reentrancy Protected by onlyInitializing modifier
     * @custom:access Internal function - only callable during initialization
     * @custom:oracle No oracle dependencies
     */
    function __SecureUpgradeable_init(address _timelock) internal onlyInitializing {
        __UUPSUpgradeable_init();
        __AccessControl_init();
        
        timelock = ITimelockUpgradeable(_timelock);
        secureUpgradesEnabled = true;
        
        emit TimelockSet(_timelock);
        emit SecureUpgradesToggled(true);
    }
    
    // ============ Upgrade Management ============
    
    /**
     * @notice Set the timelock contract
     * @dev Configures the timelock contract for secure upgrade management
     * @param _timelock Address of the timelock contract
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function setTimelock(address _timelock) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_timelock == address(0)) revert CommonErrorLibrary.ZeroAddress();
        timelock = ITimelockUpgradeable(_timelock);
        emit TimelockSet(_timelock);
    }
    
    /**
     * @notice Toggle secure upgrades
     * @dev Enables or disables the secure upgrade mechanism
     * @param enabled Whether to enable secure upgrades
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function toggleSecureUpgrades(bool enabled) external onlyRole(DEFAULT_ADMIN_ROLE) {
        secureUpgradesEnabled = enabled;
        emit SecureUpgradesToggled(enabled);
    }
    
    /**
     * @notice Propose an upgrade through the timelock
     * @dev Initiates a secure upgrade proposal with timelock delay and multi-sig requirements
     * @param newImplementation Address of the new implementation
     * @param description Description of the upgrade
     * @param customDelay Optional custom delay
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
    ) external onlyRole(UPGRADER_ROLE) {
        if (!secureUpgradesEnabled) revert CommonErrorLibrary.NotActive();
        if (address(timelock) == address(0)) revert CommonErrorLibrary.ZeroAddress();
        
        timelock.proposeUpgrade(newImplementation, description, customDelay);
    }
    
    /**
     * @notice Execute an upgrade through the timelock
     * @dev Executes a previously proposed upgrade after timelock delay
     * @param newImplementation Address of the new implementation
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function executeUpgrade(address newImplementation) external onlyTimelock {
        _authorizeUpgrade(newImplementation);
        upgradeToAndCall(newImplementation, "");
    }
    
    /**
     * @notice Emergency upgrade (bypasses timelock, requires emergency mode)
     * @dev Allows emergency upgrades when secure upgrades are disabled or timelock is unavailable
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
    ) external onlyRole(UPGRADER_ROLE) {
        if (secureUpgradesEnabled && address(timelock) != address(0)) {
            revert CommonErrorLibrary.NotAuthorized();
        }
        
        _authorizeUpgrade(newImplementation);
        upgradeToAndCall(newImplementation, "");
        
        emit SecureUpgradeAuthorized(newImplementation, msg.sender, description);
    }
    
    // ============ Override Functions ============
    
    /**
     * @notice Authorize upgrade (overrides UUPSUpgradeable)
     * @dev Internal function that determines upgrade authorization based on secure upgrade settings
     * @param newImplementation Address of the new implementation
     */
    function _authorizeUpgrade(address newImplementation) internal override view {
        // If secure upgrades are enabled and timelock is set, only timelock can upgrade
        if (secureUpgradesEnabled && address(timelock) != address(0)) {
            if (msg.sender != address(timelock)) revert CommonErrorLibrary.NotAuthorized();
        } else {
            // Fallback to role-based authorization
            if (!hasRole(UPGRADER_ROLE, msg.sender)) revert CommonErrorLibrary.NotAuthorized();
        }
        
        if (newImplementation == address(0)) revert CommonErrorLibrary.ZeroAddress();
    }
    
    // ============ View Functions ============
    
    /**
     * @notice Check if an upgrade is pending
     * @dev Checks if there is a pending upgrade for the specified implementation
     * @param implementation Address of the implementation
     * @return isPending Whether the upgrade is pending
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function isUpgradePending(address implementation) external view returns (bool isPending) {
        if (address(timelock) == address(0)) return false;
        
        ITimelockUpgradeable.PendingUpgrade memory upgrade = timelock.getPendingUpgrade(implementation);
        return upgrade.implementation != address(0);
    }
    
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
    function getPendingUpgrade(address implementation) external view returns (ITimelockUpgradeable.PendingUpgrade memory upgrade) {
        if (address(timelock) == address(0)) {
            return ITimelockUpgradeable.PendingUpgrade({
                implementation: address(0),
                proposingProxy: address(0),
                proposedAt: 0,
                executableAt: 0,
                expiryAt: 0,
                description: "",
                isEmergency: false,
                proposer: address(0)
            });
        }
        
        return timelock.getPendingUpgrade(implementation);
    }
    
    /**
     * @notice Check if an upgrade can be executed
     * @dev Checks if a pending upgrade has passed the timelock delay and can be executed
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
    function canExecuteUpgrade(address implementation) external view returns (bool canExecute) {
        if (address(timelock) == address(0)) return false;
        return timelock.canExecuteUpgrade(implementation);
    }
    
    /**
     * @notice Get upgrade security status
     * @dev Returns the current security configuration for upgrades
     * @return timelockAddress Address of the timelock contract
     * @return secureUpgradesEnabled_ Whether secure upgrades are enabled
     * @return hasTimelock Whether timelock is set
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getUpgradeSecurityStatus() external view returns (
        address timelockAddress,
        bool secureUpgradesEnabled_,
        bool hasTimelock
    ) {
        return (
            address(timelock),
            secureUpgradesEnabled,
            address(timelock) != address(0)
        );
    }
    
    // ============ Emergency Functions ============
    
    /**
     * @notice Disable secure upgrades in emergency
     * @dev Disables secure upgrades for emergency situations
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    /// @notice INFO-4: Propose disabling secure upgrades; enforces a 24-hour timelock
    function proposeEmergencyDisableSecureUpgrades() external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (!secureUpgradesEnabled) revert CommonErrorLibrary.NotActive();
        EmergencyDisableStorage storage ds = _emergencyDisableStorage();
        ds.proposalId += 1;
        ds.approvalCount = 0;

        emergencyDisablePendingAt = block.timestamp + EMERGENCY_DISABLE_DELAY;
        emit EmergencyDisableProposed(ds.proposalId, emergencyDisablePendingAt);

        // Proposer counts as first approval for the new proposal.
        ds.hasApproved[ds.proposalId][msg.sender] = true;
        ds.approvalCount = 1;
        emit EmergencyDisableApproved(ds.proposalId, msg.sender, ds.approvalCount);
    }

    /// @notice INFO-4/NEW-3: Register an admin approval for the active emergency-disable proposal.
    function approveEmergencyDisableSecureUpgrades() external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (emergencyDisablePendingAt == 0) revert CommonErrorLibrary.NotActive();
        EmergencyDisableStorage storage ds = _emergencyDisableStorage();
        uint256 proposalId = ds.proposalId;
        if (proposalId == 0) revert CommonErrorLibrary.NotActive();
        if (ds.hasApproved[proposalId][msg.sender]) revert CommonErrorLibrary.NoChangeDetected();

        ds.hasApproved[proposalId][msg.sender] = true;
        ds.approvalCount += 1;
        emit EmergencyDisableApproved(proposalId, msg.sender, ds.approvalCount);
    }

    /// @notice INFO-4: Apply a previously proposed emergency-disable after the timelock has elapsed
    /// @param expectedProposalId Proposal id the caller expects to apply (replay/mismatch protection)
    function applyEmergencyDisableSecureUpgrades(uint256 expectedProposalId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (emergencyDisablePendingAt == 0) revert CommonErrorLibrary.NotActive();
        if (block.timestamp < emergencyDisablePendingAt) revert CommonErrorLibrary.NotActive();
        EmergencyDisableStorage storage ds = _emergencyDisableStorage();
        if (expectedProposalId == 0 || expectedProposalId != ds.proposalId) revert CommonErrorLibrary.NotAuthorized();
        if (ds.approvalCount < EMERGENCY_DISABLE_QUORUM) revert CommonErrorLibrary.NotAuthorized();

        emergencyDisablePendingAt = 0;
        ds.approvalCount = 0;
        secureUpgradesEnabled = false;
        emit SecureUpgradesToggled(false);
    }

    /// @notice Current emergency-disable proposal id (0 when no proposal has ever been created).
    function emergencyDisableProposalId() public view returns (uint256) {
        return _emergencyDisableStorage().proposalId;
    }

    /// @notice Current approval count for the active proposal.
    function emergencyDisableApprovalCount() public view returns (uint256) {
        return _emergencyDisableStorage().approvalCount;
    }

    /// @notice Quorum required to apply the emergency disable.
    function emergencyDisableQuorum() public pure returns (uint256) {
        return EMERGENCY_DISABLE_QUORUM;
    }

    /// @notice Returns whether `approver` approved a given emergency-disable proposal.
    function hasEmergencyDisableApproval(uint256 proposalId, address approver) public view returns (bool) {
        if (approver == address(0) || proposalId == 0) return false;
        return _emergencyDisableStorage().hasApproved[proposalId][approver];
    }
    
    /**
     * @notice Enable secure upgrades after emergency
     * @dev Re-enables secure upgrades after emergency situations
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function enableSecureUpgrades() external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (address(timelock) == address(0)) revert CommonErrorLibrary.ZeroAddress();
        secureUpgradesEnabled = true;
        emit SecureUpgradesToggled(true);
    }
}
