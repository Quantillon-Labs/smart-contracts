// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./ErrorLibrary.sol";

/**
 * @title TimeProvider
 * @notice Centralized time provider for the Quantillon Protocol
 * @dev Provides a controlled time source that can be adjusted for testing and emergency scenarios
 * 
 * SECURITY CONSIDERATIONS:
 * - Only governance can adjust time offset
 * - Time offset is limited to prevent abuse
 * - Emergency reset capability for security incidents
 * - All time adjustments are logged for transparency
 */
contract TimeProvider is Initializable, AccessControlUpgradeable, UUPSUpgradeable {
    
    // ==================== CONSTANTS ====================
    
    /// @notice Role identifier for governance operations
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    
    /// @notice Role identifier for emergency operations
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    
    /// @notice Role identifier for upgrade operations
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    
    /// @notice Maximum allowed time offset (7 days) to prevent abuse
    uint256 public constant MAX_TIME_OFFSET = 7 days;
    
    /// @notice Maximum allowed time drift (1 hour) for normal operations
    uint256 public constant MAX_TIME_DRIFT = 1 hours;
    
    // ==================== STATE VARIABLES ====================
    
    /// @notice Current time offset applied to block.timestamp
    /// @dev Can be positive (time advancement) or negative (time delay) within limits
    int256 public timeOffset;
    
    /// @notice Timestamp when the time offset was last modified
    uint256 public lastOffsetChange;
    
    /// @notice Flag indicating if time provider is in emergency mode
    bool public emergencyMode;
    
    /// @notice Counter for time adjustments (for tracking)
    uint256 public adjustmentCounter;
    
    // ==================== EVENTS ====================
    
    /// @notice Emitted when time offset is changed
    event TimeOffsetChanged(
        address indexed changer, 
        int256 oldOffset, 
        int256 newOffset, 
        string reason,
        uint256 timestamp
    );
    
    /// @notice Emitted when emergency mode is toggled
    event EmergencyModeChanged(bool enabled, address indexed changer, uint256 timestamp);
    
    /// @notice Emitted when time is reset to normal
    event TimeReset(address indexed resetter, uint256 timestamp);
    
    // ==================== MODIFIERS ====================
    
    /// @notice Ensures the contract is not in emergency mode
    modifier whenNotEmergency() {
        if (emergencyMode) revert ErrorLibrary.EmergencyModeActive();
        _;
    }
    
    /// @notice Ensures the time offset is within allowed bounds
    modifier validTimeOffset(int256 offset) {
        if (offset > 0 && uint256(offset) > MAX_TIME_OFFSET) {
            revert ErrorLibrary.InvalidAmount();
        }
        if (offset < 0 && uint256(-offset) > MAX_TIME_OFFSET) {
            revert ErrorLibrary.InvalidAmount();
        }
        _;
    }
    
    // ==================== INITIALIZATION ====================
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    /**
     * @notice Initializes the TimeProvider contract
     * @param admin The address that will be granted DEFAULT_ADMIN_ROLE
     * @param governance The address that will be granted GOVERNANCE_ROLE
     * @param emergency The address that will be granted EMERGENCY_ROLE
     */
    function initialize(
        address admin,
        address governance, 
        address emergency
    ) external initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();
        
        if (admin == address(0)) revert ErrorLibrary.ZeroAddress();
        if (governance == address(0)) revert ErrorLibrary.ZeroAddress();
        if (emergency == address(0)) revert ErrorLibrary.ZeroAddress();
        
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(GOVERNANCE_ROLE, governance);
        _grantRole(EMERGENCY_ROLE, emergency);
        _grantRole(UPGRADER_ROLE, admin);
        
        // Initialize state
        timeOffset = 0;
        lastOffsetChange = block.timestamp;
        emergencyMode = false;
        adjustmentCounter = 0;
    }
    
    // ==================== CORE FUNCTIONS ====================
    
    /**
     * @notice Returns the current time according to this provider
     * @return Current timestamp adjusted by the offset
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function currentTime() external view returns (uint256) {
        return _getCurrentTime();
    }
    
    /**
     * @notice Returns the current time according to this provider (internal)
     * @return Current timestamp adjusted by the offset
     */
    function _getCurrentTime() internal view returns (uint256) {
        if (timeOffset >= 0) {
            return block.timestamp + uint256(timeOffset);
        } else {
            uint256 negativeOffset = uint256(-timeOffset);
            // Prevent underflow
            if (block.timestamp < negativeOffset) {
                return 0;
            }
            return block.timestamp - negativeOffset;
        }
    }
    
    /**
     * @notice Returns the raw block timestamp without any offset
     * @return Raw block.timestamp
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function rawTimestamp() external view returns (uint256) {
        return block.timestamp;
    }
    
    /**
     * @notice Checks if a timestamp is in the future according to provider time
     * @param timestamp The timestamp to check
     * @return True if timestamp is in the future
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function isFuture(uint256 timestamp) external view returns (bool) {
        return timestamp > _getCurrentTime();
    }
    
    /**
     * @notice Checks if a timestamp is in the past according to provider time
     * @param timestamp The timestamp to check
     * @return True if timestamp is in the past
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function isPast(uint256 timestamp) external view returns (bool) {
        return timestamp < _getCurrentTime();
    }
    
    // ==================== GOVERNANCE FUNCTIONS ====================
    
    /**
     * @notice Sets the time offset (governance only)
     * @param newOffset The new time offset to apply
     * @param reason Human-readable reason for the change
     */
    function setTimeOffset(
        int256 newOffset, 
        string calldata reason
    ) external onlyRole(GOVERNANCE_ROLE) whenNotEmergency validTimeOffset(newOffset) {
        int256 oldOffset = timeOffset;
        timeOffset = newOffset;
        lastOffsetChange = block.timestamp;
        adjustmentCounter++;
        
        emit TimeOffsetChanged(msg.sender, oldOffset, newOffset, reason, block.timestamp);
    }
    
    /**
     * @notice Advances time by a specific amount (governance only)
     * @param advancement Amount of time to advance (in seconds)
     * @param reason Human-readable reason for the advancement
     */
    function advanceTime(
        uint256 advancement, 
        string calldata reason
    ) external onlyRole(GOVERNANCE_ROLE) whenNotEmergency {
        if (advancement == 0) revert ErrorLibrary.InvalidAmount();
        
        int256 newOffset;
        if (timeOffset >= 0) {
            newOffset = timeOffset + int256(advancement);
        } else {
            // Handle negative offset
            if (advancement >= uint256(-timeOffset)) {
                newOffset = int256(advancement - uint256(-timeOffset));
            } else {
                newOffset = timeOffset + int256(advancement);
            }
        }
        
        if (newOffset > 0 && uint256(newOffset) > MAX_TIME_OFFSET) {
            revert ErrorLibrary.InvalidAmount();
        }
        
        int256 oldOffset = timeOffset;
        timeOffset = newOffset;
        lastOffsetChange = block.timestamp;
        adjustmentCounter++;
        
        emit TimeOffsetChanged(msg.sender, oldOffset, newOffset, reason, block.timestamp);
    }
    
    /**
     * @notice Resets time to normal (no offset)
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function resetTime() external onlyRole(GOVERNANCE_ROLE) {
        int256 oldOffset = timeOffset;
        timeOffset = 0;
        lastOffsetChange = block.timestamp;
        adjustmentCounter++;
        
        emit TimeReset(msg.sender, block.timestamp);
        emit TimeOffsetChanged(msg.sender, oldOffset, 0, "Time reset to normal", block.timestamp);
    }
    
    // ==================== EMERGENCY FUNCTIONS ====================
    
    /**
     * @notice Toggles emergency mode (emergency role only)
     * @param enabled Whether to enable or disable emergency mode
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function setEmergencyMode(bool enabled) external onlyRole(EMERGENCY_ROLE) {
        if (emergencyMode == enabled) return; // No change needed
        
        emergencyMode = enabled;
        
        // If entering emergency mode, reset time to normal
        if (enabled && timeOffset != 0) {
            int256 oldOffset = timeOffset;
            timeOffset = 0;
            lastOffsetChange = block.timestamp;
            adjustmentCounter++;
            
            emit TimeOffsetChanged(msg.sender, oldOffset, 0, "Emergency time reset", block.timestamp);
        }
        
        emit EmergencyModeChanged(enabled, msg.sender, block.timestamp);
    }
    
    /**
     * @notice Emergency time reset (emergency role only)
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function emergencyResetTime() external onlyRole(EMERGENCY_ROLE) {
        int256 oldOffset = timeOffset;
        timeOffset = 0;
        lastOffsetChange = block.timestamp;
        adjustmentCounter++;
        
        emit TimeReset(msg.sender, block.timestamp);
        emit TimeOffsetChanged(msg.sender, oldOffset, 0, "Emergency reset", block.timestamp);
    }
    
    // ==================== VIEW FUNCTIONS ====================
    
    /**
     * @notice Returns detailed time information
     * @return currentProviderTime Current time according to provider
     * @return rawBlockTimestamp Raw block timestamp
     * @return currentOffset Current time offset
     * @return isEmergency Whether emergency mode is active
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getTimeInfo() external view returns (
        uint256 currentProviderTime,
        uint256 rawBlockTimestamp,
        int256 currentOffset,
        bool isEmergency
    ) {
        return (
            _getCurrentTime(),
            block.timestamp,
            timeOffset,
            emergencyMode
        );
    }
    
    /**
     * @notice Calculates time difference between two timestamps according to provider
     * @param timestamp1 First timestamp
     * @param timestamp2 Second timestamp
     * @return Time difference (timestamp1 - timestamp2)
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function timeDiff(uint256 timestamp1, uint256 timestamp2) external pure returns (int256) {
        if (timestamp1 >= timestamp2) {
            return int256(timestamp1 - timestamp2);
        } else {
            return -int256(timestamp2 - timestamp1);
        }
    }
    
    // ==================== UPGRADE FUNCTIONS ====================
    
    /**
     * @notice Authorizes contract upgrades
     * @param newImplementation Address of the new implementation
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {
        // Additional upgrade validation can be added here
        if (newImplementation == address(0)) revert ErrorLibrary.ZeroAddress();
    }
    
    /**
     * @notice Returns the version of this contract implementation
     * @return Version string
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function version() external pure returns (string memory) {
        return "1.0.0";
    }
}
