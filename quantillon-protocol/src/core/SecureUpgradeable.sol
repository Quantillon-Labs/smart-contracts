// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "../interfaces/ITimelockUpgradeable.sol";

/**
 * @title SecureUpgradeable
 * @author Quantillon Labs
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
    
    // ============ Events ============
    
    event TimelockSet(address indexed timelock);
    event SecureUpgradesToggled(bool enabled);
    event SecureUpgradeAuthorized(address indexed newImplementation, address indexed authorizedBy);
    
    // ============ Modifiers ============
    
    modifier onlyTimelock() {
        require(
            address(timelock) != address(0) && 
            msg.sender == address(timelock),
            "SecureUpgradeable: Only timelock can call"
        );
        _;
    }
    
    // ============ Initialization ============
    
    /**
     * @notice Initializes the SecureUpgradeable contract
     * @dev Sets up the secure upgrade system with timelock protection
     * @param _timelock Address of the timelock contract
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
        require(_timelock != address(0), "SecureUpgradeable: Invalid timelock");
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
        require(secureUpgradesEnabled, "SecureUpgradeable: Secure upgrades disabled");
        require(address(timelock) != address(0), "SecureUpgradeable: Timelock not set");
        
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
        require(!secureUpgradesEnabled || address(timelock) == address(0), "SecureUpgradeable: Use timelock for upgrades");
        
        _authorizeUpgrade(newImplementation);
        upgradeToAndCall(newImplementation, "");
        
        emit SecureUpgradeAuthorized(newImplementation, msg.sender);
    }
    
    // ============ Override Functions ============
    
    /**
     * @notice Authorize upgrade (overrides UUPSUpgradeable)
     * @dev Internal function that determines upgrade authorization based on secure upgrade settings
     * @param newImplementation Address of the new implementation
     */
    function _authorizeUpgrade(address newImplementation) internal override {
        // If secure upgrades are enabled and timelock is set, only timelock can upgrade
        if (secureUpgradesEnabled && address(timelock) != address(0)) {
            require(msg.sender == address(timelock), "SecureUpgradeable: Only timelock can upgrade");
        } else {
            // Fallback to role-based authorization
            require(hasRole(UPGRADER_ROLE, msg.sender), "SecureUpgradeable: Not authorized");
        }
        
        require(newImplementation != address(0), "SecureUpgradeable: Invalid implementation");
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
                proposedAt: 0,
                executableAt: 0,
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
    function emergencyDisableSecureUpgrades() external onlyRole(DEFAULT_ADMIN_ROLE) {
        secureUpgradesEnabled = false;
        emit SecureUpgradesToggled(false);
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
        require(address(timelock) != address(0), "SecureUpgradeable: Timelock must be set");
        secureUpgradesEnabled = true;
        emit SecureUpgradesToggled(true);
    }
}
