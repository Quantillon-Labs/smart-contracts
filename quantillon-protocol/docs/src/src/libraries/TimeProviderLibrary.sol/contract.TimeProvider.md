# TimeProvider
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/5aee937988a17532c1c3fcdcebf45d2f03a0c08d/src/libraries/TimeProviderLibrary.sol)

**Inherits:**
Initializable, AccessControlUpgradeable, UUPSUpgradeable

Centralized time provider for the Quantillon Protocol

*Provides a controlled time source that can be adjusted for testing and emergency scenarios
SECURITY CONSIDERATIONS:
- Only governance can adjust time offset
- Time offset is limited to prevent abuse
- Emergency reset capability for security incidents
- All time adjustments are logged for transparency*


## State Variables
### GOVERNANCE_ROLE
Role identifier for governance operations


```solidity
bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
```


### EMERGENCY_ROLE
Role identifier for emergency operations


```solidity
bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
```


### UPGRADER_ROLE
Role identifier for upgrade operations


```solidity
bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
```


### MAX_TIME_OFFSET
Maximum allowed time offset (7 days) to prevent abuse


```solidity
uint256 public constant MAX_TIME_OFFSET = 7 days;
```


### MAX_TIME_DRIFT
Maximum allowed time drift (1 hour) for normal operations


```solidity
uint256 public constant MAX_TIME_DRIFT = 1 hours;
```


### timeOffset
Current time offset applied to block.timestamp

*Can be positive (time advancement) or negative (time delay) within limits*


```solidity
int256 public timeOffset;
```


### lastOffsetChange
Timestamp when the time offset was last modified


```solidity
uint256 public lastOffsetChange;
```


### emergencyMode
Flag indicating if time provider is in emergency mode


```solidity
bool public emergencyMode;
```


### adjustmentCounter
Counter for time adjustments (for tracking)


```solidity
uint256 public adjustmentCounter;
```


## Functions
### whenNotEmergency

Ensures the contract is not in emergency mode


```solidity
modifier whenNotEmergency();
```

### validTimeOffset

Ensures the time offset is within allowed bounds


```solidity
modifier validTimeOffset(int256 offset);
```

### constructor

Constructor for TimeProvider contract

*Disables initializers for proxy pattern compatibility*

**Notes:**
- security: No security validations required - constructor

- validation: No input validation required - constructor

- state-changes: Disables initializers for proxy pattern

- events: No events emitted

- errors: No errors thrown - safe constructor

- reentrancy: Not applicable - constructor

- access: Public - anyone can deploy

- oracle: No oracle dependencies

- oz-upgrades-unsafe-allow: constructor


```solidity
constructor();
```

### initialize

Initializes the TimeProvider contract

*Sets up access control roles and initializes state variables*

**Notes:**
- security: Validates all addresses are not zero, grants admin roles

- validation: Validates all input addresses are not address(0)

- state-changes: Initializes all state variables, sets default values

- events: No events emitted during initialization

- errors: Throws ZeroAddress if any address is address(0)

- reentrancy: Protected by initializer modifier

- access: Public - only callable once during deployment

- oracle: No oracle dependencies


```solidity
function initialize(address admin, address governance, address emergency) external initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|The address that will be granted DEFAULT_ADMIN_ROLE|
|`governance`|`address`|The address that will be granted GOVERNANCE_ROLE|
|`emergency`|`address`|The address that will be granted EMERGENCY_ROLE|


### currentTime

Returns the current time according to this provider

*Returns block.timestamp adjusted by the current time offset*

**Notes:**
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query current time

- oracle: No oracle dependencies


```solidity
function currentTime() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Current timestamp adjusted by the offset|


### _getCurrentTime

Returns the current time according to this provider (internal)

*Internal function that applies time offset to block.timestamp with underflow protection*

**Notes:**
- security: Validates time offset calculations to prevent underflow

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe arithmetic used

- reentrancy: Not applicable - view function

- access: Internal function - no access restrictions

- oracle: No oracle dependencies


```solidity
function _getCurrentTime() internal view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Current timestamp adjusted by the offset|


### rawTimestamp

Returns the raw block timestamp without any offset

*Returns unmodified block.timestamp for comparison purposes*

**Notes:**
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query raw timestamp

- oracle: No oracle dependencies


```solidity
function rawTimestamp() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Raw block.timestamp|


### isFuture

Checks if a timestamp is in the future according to provider time

*Compares input timestamp with current provider time*

**Notes:**
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can check if timestamp is future

- oracle: No oracle dependencies


```solidity
function isFuture(uint256 timestamp) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`timestamp`|`uint256`|The timestamp to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if timestamp is in the future|


### isPast

Checks if a timestamp is in the past according to provider time

*Compares input timestamp with current provider time*

**Notes:**
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can check if timestamp is past

- oracle: No oracle dependencies


```solidity
function isPast(uint256 timestamp) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`timestamp`|`uint256`|The timestamp to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if timestamp is in the past|


### setTimeOffset

Sets the time offset (governance only)

*Allows governance to set a new time offset within allowed bounds*

**Notes:**
- security: Validates governance role and time offset bounds

- validation: Validates newOffset is within MAX_TIME_OFFSET limits

- state-changes: Updates timeOffset, lastOffsetChange, adjustmentCounter

- events: Emits TimeOffsetChanged with old and new offset values

- errors: Throws InvalidAmount if offset exceeds MAX_TIME_OFFSET

- reentrancy: Not protected - no external calls

- access: Restricted to GOVERNANCE_ROLE

- oracle: No oracle dependencies


```solidity
function setTimeOffset(int256 newOffset, string calldata reason)
    external
    onlyRole(GOVERNANCE_ROLE)
    whenNotEmergency
    validTimeOffset(newOffset);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newOffset`|`int256`|The new time offset to apply|
|`reason`|`string`|Human-readable reason for the change|


### advanceTime

Advances time by a specific amount (governance only)

*Adds advancement to current time offset, handling both positive and negative offsets*

**Notes:**
- security: Validates governance role and advancement amount

- validation: Validates advancement > 0 and resulting offset within bounds

- state-changes: Updates timeOffset, lastOffsetChange, adjustmentCounter

- events: Emits TimeOffsetChanged with old and new offset values

- errors: Throws InvalidAmount if advancement is 0 or exceeds bounds

- reentrancy: Not protected - no external calls

- access: Restricted to GOVERNANCE_ROLE

- oracle: No oracle dependencies


```solidity
function advanceTime(uint256 advancement, string calldata reason) external onlyRole(GOVERNANCE_ROLE) whenNotEmergency;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`advancement`|`uint256`|Amount of time to advance (in seconds)|
|`reason`|`string`|Human-readable reason for the advancement|


### resetTime

Resets time to normal (no offset)

*Sets time offset to 0, returning to normal block.timestamp behavior*

**Notes:**
- security: Validates governance role authorization

- validation: No input validation required

- state-changes: Updates timeOffset to 0, lastOffsetChange, adjustmentCounter

- events: Emits TimeReset and TimeOffsetChanged events

- errors: No errors thrown - safe reset operation

- reentrancy: Not protected - no external calls

- access: Restricted to GOVERNANCE_ROLE

- oracle: No oracle dependencies


```solidity
function resetTime() external onlyRole(GOVERNANCE_ROLE);
```

### setEmergencyMode

Toggles emergency mode (emergency role only)

*Enables or disables emergency mode, automatically resetting time offset when enabled*

**Notes:**
- security: Validates emergency role authorization

- validation: No input validation required

- state-changes: Updates emergencyMode flag, resets timeOffset if enabling

- events: Emits EmergencyModeChanged and TimeOffsetChanged if reset

- errors: No errors thrown - safe mode toggle

- reentrancy: Not protected - no external calls

- access: Restricted to EMERGENCY_ROLE

- oracle: No oracle dependencies


```solidity
function setEmergencyMode(bool enabled) external onlyRole(EMERGENCY_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`enabled`|`bool`|Whether to enable or disable emergency mode|


### emergencyResetTime

Emergency time reset (emergency role only)

*Emergency function to immediately reset time offset to 0*

**Notes:**
- security: Validates emergency role authorization

- validation: No input validation required

- state-changes: Updates timeOffset to 0, lastOffsetChange, adjustmentCounter

- events: Emits TimeReset and TimeOffsetChanged events

- errors: No errors thrown - safe emergency reset

- reentrancy: Not protected - no external calls

- access: Restricted to EMERGENCY_ROLE

- oracle: No oracle dependencies


```solidity
function emergencyResetTime() external onlyRole(EMERGENCY_ROLE);
```

### getTimeInfo

Returns detailed time information

*Provides comprehensive time data including provider time, raw timestamp, offset, and emergency status*

**Notes:**
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query time information

- oracle: No oracle dependencies


```solidity
function getTimeInfo()
    external
    view
    returns (uint256 currentProviderTime, uint256 rawBlockTimestamp, int256 currentOffset, bool isEmergency);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`currentProviderTime`|`uint256`|Current time according to provider|
|`rawBlockTimestamp`|`uint256`|Raw block timestamp|
|`currentOffset`|`int256`|Current time offset|
|`isEmergency`|`bool`|Whether emergency mode is active|


### timeDiff

Calculates time difference between two timestamps according to provider

*Pure function that calculates signed time difference between two timestamps*

**Notes:**
- security: No security validations required - pure function

- validation: No input validation required - pure function

- state-changes: No state changes - pure function

- events: No events emitted

- errors: No errors thrown - safe arithmetic used

- reentrancy: Not applicable - pure function

- access: Public - anyone can calculate time difference

- oracle: No oracle dependencies


```solidity
function timeDiff(uint256 timestamp1, uint256 timestamp2) external pure returns (int256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`timestamp1`|`uint256`|First timestamp|
|`timestamp2`|`uint256`|Second timestamp|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`int256`|Time difference (timestamp1 - timestamp2)|


### _authorizeUpgrade

Authorizes contract upgrades

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function _authorizeUpgrade(address newImplementation) internal view override onlyRole(UPGRADER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newImplementation`|`address`|Address of the new implementation|


## Events
### TimeOffsetChanged
Emitted when time offset is changed


```solidity
event TimeOffsetChanged(address indexed changer, int256 oldOffset, int256 newOffset, string reason, uint256 timestamp);
```

### EmergencyModeChanged
Emitted when emergency mode is toggled


```solidity
event EmergencyModeChanged(bool enabled, address indexed changer, uint256 timestamp);
```

### TimeReset
Emitted when time is reset to normal


```solidity
event TimeReset(address indexed resetter, uint256 timestamp);
```

