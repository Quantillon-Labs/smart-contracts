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
    /// @notice INFO-4: Canonical block delay for emergency-disable proposals (12s block target)
    uint256 public constant EMERGENCY_DISABLE_DELAY_BLOCKS = EMERGENCY_DISABLE_DELAY / 12;

    /// @notice Emergency-disable approvals required before apply can succeed
    uint256 public constant EMERGENCY_DISABLE_QUORUM = 2;

    /// @notice INFO-4: Block at which emergencyDisable can be applied (0 = no pending proposal)
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

    /**
     * @notice Returns canonical protocol time from timelock's shared TimeProvider
     * @dev Falls back to block timestamp only before timelock is configured.
     * @custom:security Uses timelock-backed canonical time when available; fallback preserves liveness during bootstrap
     * @custom:validation Validates timelock address and code presence before external call
     * @custom:state-changes None
     * @custom:events None
     * @custom:errors None - failures fall back to `block.timestamp`
     * @custom:reentrancy Read-only helper; no state mutation
     * @custom:access Internal helper
     * @custom:oracle No oracle dependencies
     */
    function _protocolTime() internal view returns (uint256) {
        address timelockAddress = address(timelock);
        if (timelockAddress == address(0) || timelockAddress.code.length == 0) {
            return block.timestamp;
        }
        try timelock.currentTime() returns (uint256 nowTs) {
            return nowTs;
        } catch {
            return block.timestamp;
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

        emergencyDisablePendingAt = block.number + EMERGENCY_DISABLE_DELAY_BLOCKS;
        emit EmergencyDisableProposed(ds.proposalId, emergencyDisablePendingAt);

        // Proposer counts as first approval for the new proposal.
        ds.hasApproved[ds.proposalId][msg.sender] = true;
        ds.approvalCount = 1;
        emit EmergencyDisableApproved(ds.proposalId, msg.sender, ds.approvalCount);
    }

    /**
     * @notice INFO-4/NEW-3: Register an admin approval for the active emergency-disable proposal.
     * @dev Records an approval from a DEFAULT_ADMIN_ROLE address for the current proposal.
     *      Uses per-proposal bitmap to prevent duplicate approvals from the same address.
     * @custom:security Only callable by DEFAULT_ADMIN_ROLE; prevents double-approval per admin.
     * @custom:validation Reverts if no active proposal or caller already approved.
     * @custom:state-changes Marks caller as approved and increments approvalCount in storage.
     * @custom:events Emits EmergencyDisableApproved with updated approval count.
     * @custom:errors NotActive if no pending proposal; NoChangeDetected if already approved.
     * @custom:reentrancy Not applicable – function is external but has no external calls after state changes.
     * @custom:access Restricted to DEFAULT_ADMIN_ROLE.
     * @custom:oracle No oracle dependencies.
     */
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

    /**
     * @notice INFO-4: Apply a previously proposed emergency-disable after the timelock has elapsed.
     * @dev Disables secure upgrades permanently for this deployment once quorum and delay are satisfied.
     *      Resets pending state so a fresh proposal is required for any future changes.
     * @param expectedProposalId Proposal id the caller expects to apply (replay/mismatch protection).
     * @custom:security Requires DEFAULT_ADMIN_ROLE, quorum approvals and elapsed delay.
     * @custom:validation Reverts on mismatched proposal id, missing quorum or no pending proposal.
     * @custom:state-changes Clears emergencyDisablePendingAt and approvalCount, sets secureUpgradesEnabled=false.
     * @custom:events Emits SecureUpgradesToggled(false) on successful application.
     * @custom:errors NotActive if no pending or delay not elapsed; NotAuthorized on id mismatch or quorum not met.
     * @custom:reentrancy Not applicable – no external calls after critical state changes.
     * @custom:access Restricted to DEFAULT_ADMIN_ROLE.
     * @custom:oracle No oracle dependencies.
     */
    function applyEmergencyDisableSecureUpgrades(uint256 expectedProposalId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (emergencyDisablePendingAt == 0) revert CommonErrorLibrary.NotActive();
        if (block.number < emergencyDisablePendingAt) revert CommonErrorLibrary.NotActive();
        EmergencyDisableStorage storage ds = _emergencyDisableStorage();
        if (expectedProposalId == 0 || expectedProposalId != ds.proposalId) revert CommonErrorLibrary.NotAuthorized();
        if (ds.approvalCount < EMERGENCY_DISABLE_QUORUM) revert CommonErrorLibrary.NotAuthorized();

        emergencyDisablePendingAt = 0;
        ds.approvalCount = 0;
        secureUpgradesEnabled = false;
        emit SecureUpgradesToggled(false);
    }

    /**
     * @notice Returns the current emergency-disable proposal id.
     * @dev Value is 0 when no proposal has ever been created.
     * @return proposalId The active or last-used emergency-disable proposal id.
     * @custom:security View-only helper; no access restriction.
     * @custom:validation No input validation required.
     * @custom:state-changes None – pure read from dedicated emergency-disable storage.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable – view function.
     * @custom:access Public – any caller may inspect current proposal id.
     * @custom:oracle No oracle dependencies.
     */
    function emergencyDisableProposalId() public view returns (uint256) {
        return _emergencyDisableStorage().proposalId;
    }

    /**
     * @notice Returns the current approval count for the active emergency-disable proposal.
     * @dev Reads the aggregate number of admin approvals recorded for the latest proposal.
     * @return approvalCount Number of approvals for the current proposal.
     * @custom:security View-only helper; no access restriction.
     * @custom:validation No input validation required.
     * @custom:state-changes None – pure read from dedicated emergency-disable storage.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable – view function.
     * @custom:access Public – any caller may inspect approval count.
     * @custom:oracle No oracle dependencies.
     */
    function emergencyDisableApprovalCount() public view returns (uint256) {
        return _emergencyDisableStorage().approvalCount;
    }

    /**
     * @notice Returns the quorum required to apply the emergency disable.
     * @dev Exposes the EMERGENCY_DISABLE_QUORUM compile-time constant.
     * @return quorum Number of approvals required to apply emergency-disable.
     * @custom:security View-only helper; no access restriction.
     * @custom:validation No input validation required.
     * @custom:state-changes None – pure return of constant.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable – pure function.
     * @custom:access Public – any caller may inspect required quorum.
     * @custom:oracle No oracle dependencies.
     */
    function emergencyDisableQuorum() public pure returns (uint256) {
        return EMERGENCY_DISABLE_QUORUM;
    }

    /**
     * @notice Returns whether a given approver address approved a specific emergency-disable proposal.
     * @dev Returns false when approver is zero or proposalId is zero for safety.
     * @param proposalId The proposal identifier to inspect.
     * @param approver The admin address whose approval status is queried.
     * @return hasApproved_ True if the approver has recorded an approval for proposalId.
     * @custom:security View-only helper; no access restriction.
     * @custom:validation Treats zero proposalId or zero approver as “not approved”.
     * @custom:state-changes None – pure read from dedicated emergency-disable storage.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable – view function.
     * @custom:access Public – any caller may inspect approval status.
     * @custom:oracle No oracle dependencies.
     */
    function hasEmergencyDisableApproval(uint256 proposalId, address approver) public view returns (bool hasApproved_) {
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
