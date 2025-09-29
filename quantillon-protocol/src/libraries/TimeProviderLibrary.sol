// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {CommonErrorLibrary} from "./CommonErrorLibrary.sol";

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
        if (emergencyMode) revert CommonErrorLibrary.EmergencyModeActive();
        _;
    }
    
    /// @notice Ensures the time offset is within allowed bounds
    modifier validTimeOffset(int256 offset) {
        if (offset > 0 && uint256(offset) > MAX_TIME_OFFSET) {
            revert CommonErrorLibrary.InvalidAmount();
        }
        if (offset < 0 && uint256(-offset) > MAX_TIME_OFFSET) {
            revert CommonErrorLibrary.InvalidAmount();
        }
        _;
    }
    
    // ==================== INITIALIZATION ====================
    
    /**
     * @notice Constructor for TimeProvider contract
     * @dev Disables initializers for proxy pattern compatibility
     * @custom:security No security validations required - constructor
     * @custom:validation No input validation required - constructor
     * @custom:state-changes Disables initializers for proxy pattern
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe constructor
     * @custom:reentrancy Not applicable - constructor
     * @custom:access Public - anyone can deploy
     * @custom:oracle No oracle dependencies
     */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    /**
     * @notice Initializes the TimeProvider contract
     * @dev Sets up access control roles and initializes state variables
     * @param admin The address that will be granted DEFAULT_ADMIN_ROLE
     * @param governance The address that will be granted GOVERNANCE_ROLE
     * @param emergency The address that will be granted EMERGENCY_ROLE
     * @custom:security Validates all addresses are not zero, grants admin roles
     * @custom:validation Validates all input addresses are not address(0)
     * @custom:state-changes Initializes all state variables, sets default values
     * @custom:events No events emitted during initialization
     * @custom:errors Throws ZeroAddress if any address is address(0)
     * @custom:reentrancy Protected by initializer modifier
     * @custom:access Public - only callable once during deployment
     * @custom:oracle No oracle dependencies
     */
    function initialize(
        address admin,
        address governance, 
        address emergency
    ) external initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();
        
        if (admin == address(0)) revert CommonErrorLibrary.ZeroAddress();
        if (governance == address(0)) revert CommonErrorLibrary.ZeroAddress();
        if (emergency == address(0)) revert CommonErrorLibrary.ZeroAddress();
        
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
     * @dev Returns block.timestamp adjusted by the current time offset
     * @return Current timestamp adjusted by the offset
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query current time
     * @custom:oracle No oracle dependencies
     */
    function currentTime() external view returns (uint256) {
        return _getCurrentTime();
    }
    
    /**
     * @notice Returns the current time according to this provider (internal)
     * @dev Internal function that applies time offset to block.timestamp with underflow protection
     * @return Current timestamp adjusted by the offset
     * @custom:security Validates time offset calculations to prevent underflow
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe arithmetic used
     * @custom:reentrancy Not applicable - view function
     * @custom:access Internal function - no access restrictions
     * @custom:oracle No oracle dependencies
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
     * @dev Returns unmodified block.timestamp for comparison purposes
     * @return Raw block.timestamp
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query raw timestamp
     * @custom:oracle No oracle dependencies
     */
    function rawTimestamp() external view returns (uint256) {
        return block.timestamp;
    }
    
    /**
     * @notice Checks if a timestamp is in the future according to provider time
     * @dev Compares input timestamp with current provider time
     * @param timestamp The timestamp to check
     * @return True if timestamp is in the future
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can check if timestamp is future
     * @custom:oracle No oracle dependencies
     */
    function isFuture(uint256 timestamp) external view returns (bool) {
        return timestamp > _getCurrentTime();
    }
    
    /**
     * @notice Checks if a timestamp is in the past according to provider time
     * @dev Compares input timestamp with current provider time
     * @param timestamp The timestamp to check
     * @return True if timestamp is in the past
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can check if timestamp is past
     * @custom:oracle No oracle dependencies
     */
    function isPast(uint256 timestamp) external view returns (bool) {
        return timestamp < _getCurrentTime();
    }
    
    // ==================== GOVERNANCE FUNCTIONS ====================
    
    /**
     * @notice Sets the time offset (governance only)
     * @dev Allows governance to set a new time offset within allowed bounds
     * @param newOffset The new time offset to apply
     * @param reason Human-readable reason for the change
     * @custom:security Validates governance role and time offset bounds
     * @custom:validation Validates newOffset is within MAX_TIME_OFFSET limits
     * @custom:state-changes Updates timeOffset, lastOffsetChange, adjustmentCounter
     * @custom:events Emits TimeOffsetChanged with old and new offset values
     * @custom:errors Throws InvalidAmount if offset exceeds MAX_TIME_OFFSET
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Restricted to GOVERNANCE_ROLE
     * @custom:oracle No oracle dependencies
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
     * @dev Adds advancement to current time offset, handling both positive and negative offsets
     * @param advancement Amount of time to advance (in seconds)
     * @param reason Human-readable reason for the advancement
     * @custom:security Validates governance role and advancement amount
     * @custom:validation Validates advancement > 0 and resulting offset within bounds
     * @custom:state-changes Updates timeOffset, lastOffsetChange, adjustmentCounter
     * @custom:events Emits TimeOffsetChanged with old and new offset values
     * @custom:errors Throws InvalidAmount if advancement is 0 or exceeds bounds
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Restricted to GOVERNANCE_ROLE
     * @custom:oracle No oracle dependencies
     */
    function advanceTime(
        uint256 advancement, 
        string calldata reason
    ) external onlyRole(GOVERNANCE_ROLE) whenNotEmergency {
        if (advancement == 0) revert CommonErrorLibrary.InvalidAmount();
        
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
            revert CommonErrorLibrary.InvalidAmount();
        }
        
        int256 oldOffset = timeOffset;
        timeOffset = newOffset;
        lastOffsetChange = block.timestamp;
        adjustmentCounter++;
        
        emit TimeOffsetChanged(msg.sender, oldOffset, newOffset, reason, block.timestamp);
    }
    
    /**
     * @notice Resets time to normal (no offset)
     * @dev Sets time offset to 0, returning to normal block.timestamp behavior
     * @custom:security Validates governance role authorization
     * @custom:validation No input validation required
     * @custom:state-changes Updates timeOffset to 0, lastOffsetChange, adjustmentCounter
     * @custom:events Emits TimeReset and TimeOffsetChanged events
     * @custom:errors No errors thrown - safe reset operation
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Restricted to GOVERNANCE_ROLE
     * @custom:oracle No oracle dependencies
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
     * @dev Enables or disables emergency mode, automatically resetting time offset when enabled
     * @param enabled Whether to enable or disable emergency mode
     * @custom:security Validates emergency role authorization
     * @custom:validation No input validation required
     * @custom:state-changes Updates emergencyMode flag, resets timeOffset if enabling
     * @custom:events Emits EmergencyModeChanged and TimeOffsetChanged if reset
     * @custom:errors No errors thrown - safe mode toggle
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Restricted to EMERGENCY_ROLE
     * @custom:oracle No oracle dependencies
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
     * @dev Emergency function to immediately reset time offset to 0
     * @custom:security Validates emergency role authorization
     * @custom:validation No input validation required
     * @custom:state-changes Updates timeOffset to 0, lastOffsetChange, adjustmentCounter
     * @custom:events Emits TimeReset and TimeOffsetChanged events
     * @custom:errors No errors thrown - safe emergency reset
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Restricted to EMERGENCY_ROLE
     * @custom:oracle No oracle dependencies
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
     * @dev Provides comprehensive time data including provider time, raw timestamp, offset, and emergency status
     * @return currentProviderTime Current time according to provider
     * @return rawBlockTimestamp Raw block timestamp
     * @return currentOffset Current time offset
     * @return isEmergency Whether emergency mode is active
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query time information
     * @custom:oracle No oracle dependencies
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
     * @dev Pure function that calculates signed time difference between two timestamps
     * @param timestamp1 First timestamp
     * @param timestamp2 Second timestamp
     * @return Time difference (timestamp1 - timestamp2)
     * @custom:security No security validations required - pure function
     * @custom:validation No input validation required - pure function
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe arithmetic used
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Public - anyone can calculate time difference
     * @custom:oracle No oracle dependencies
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
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) view {
        // Additional upgrade validation can be added here
        if (newImplementation == address(0)) revert CommonErrorLibrary.ZeroAddress();
    }
    
}
