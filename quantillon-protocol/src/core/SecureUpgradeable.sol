// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "../interfaces/ITimelockUpgradeable.sol";

/**
 * @title SecureUpgradeable
 * @author Quantillon Labs
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
     * @param _timelock Address of the timelock contract
     */
    function setTimelock(address _timelock) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_timelock != address(0), "SecureUpgradeable: Invalid timelock");
        timelock = ITimelockUpgradeable(_timelock);
        emit TimelockSet(_timelock);
    }
    
    /**
     * @notice Toggle secure upgrades
     * @param enabled Whether to enable secure upgrades
     */
    function toggleSecureUpgrades(bool enabled) external onlyRole(DEFAULT_ADMIN_ROLE) {
        secureUpgradesEnabled = enabled;
        emit SecureUpgradesToggled(enabled);
    }
    
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
    ) external onlyRole(UPGRADER_ROLE) {
        require(secureUpgradesEnabled, "SecureUpgradeable: Secure upgrades disabled");
        require(address(timelock) != address(0), "SecureUpgradeable: Timelock not set");
        
        timelock.proposeUpgrade(newImplementation, description, customDelay);
    }
    
    /**
     * @notice Execute an upgrade through the timelock
     * @param newImplementation Address of the new implementation
     */
    function executeUpgrade(address newImplementation) external onlyTimelock {
        _authorizeUpgrade(newImplementation);
        upgradeToAndCall(newImplementation, "");
    }
    
    /**
     * @notice Emergency upgrade (bypasses timelock, requires emergency mode)
     * @param newImplementation Address of the new implementation
     * @param description Description of the emergency upgrade
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
     * @param implementation Address of the implementation
     * @return isPending Whether the upgrade is pending
     */
    function isUpgradePending(address implementation) external view returns (bool isPending) {
        if (address(timelock) == address(0)) return false;
        
        ITimelockUpgradeable.PendingUpgrade memory upgrade = timelock.getPendingUpgrade(implementation);
        return upgrade.implementation != address(0);
    }
    
    /**
     * @notice Get pending upgrade details
     * @param implementation Address of the implementation
     * @return upgrade Pending upgrade details
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
     * @param implementation Address of the implementation
     * @return canExecute Whether the upgrade can be executed
     */
    function canExecuteUpgrade(address implementation) external view returns (bool canExecute) {
        if (address(timelock) == address(0)) return false;
        return timelock.canExecuteUpgrade(implementation);
    }
    
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
     */
    function emergencyDisableSecureUpgrades() external onlyRole(DEFAULT_ADMIN_ROLE) {
        secureUpgradesEnabled = false;
        emit SecureUpgradesToggled(false);
    }
    
    /**
     * @notice Enable secure upgrades after emergency
     */
    function enableSecureUpgrades() external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(address(timelock) != address(0), "SecureUpgradeable: Timelock must be set");
        secureUpgradesEnabled = true;
        emit SecureUpgradesToggled(true);
    }
}
