# TimeProvider
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/e9c5d3b52c0c2fb1a1c72e3e33cbf9fa6d077fa8/src/libraries/TimeProviderLibrary.sol)

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
- No security validations required - constructor

- No input validation required - constructor

- Disables initializers for proxy pattern

- No events emitted

- No errors thrown - safe constructor

- Not applicable - constructor

- Public - anyone can deploy

- No oracle dependencies

- constructor


```solidity
constructor();
```

### initialize

Initializes the TimeProvider contract

*Sets up access control roles and initializes state variables*

**Notes:**
- Validates all addresses are not zero, grants admin roles

- Validates all input addresses are not address(0)

- Initializes all state variables, sets default values

- No events emitted during initialization

- Throws ZeroAddress if any address is address(0)

- Protected by initializer modifier

- Public - only callable once during deployment

- No oracle dependencies


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
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query current time

- No oracle dependencies


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
- Validates time offset calculations to prevent underflow

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe arithmetic used

- Not applicable - view function

- Internal function - no access restrictions

- No oracle dependencies


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
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query raw timestamp

- No oracle dependencies


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
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can check if timestamp is future

- No oracle dependencies


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
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can check if timestamp is past

- No oracle dependencies


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
- Validates governance role and time offset bounds

- Validates newOffset is within MAX_TIME_OFFSET limits

- Updates timeOffset, lastOffsetChange, adjustmentCounter

- Emits TimeOffsetChanged with old and new offset values

- Throws InvalidAmount if offset exceeds MAX_TIME_OFFSET

- Not protected - no external calls

- Restricted to GOVERNANCE_ROLE

- No oracle dependencies


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
- Validates governance role and advancement amount

- Validates advancement > 0 and resulting offset within bounds

- Updates timeOffset, lastOffsetChange, adjustmentCounter

- Emits TimeOffsetChanged with old and new offset values

- Throws InvalidAmount if advancement is 0 or exceeds bounds

- Not protected - no external calls

- Restricted to GOVERNANCE_ROLE

- No oracle dependencies


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
- Validates governance role authorization

- No input validation required

- Updates timeOffset to 0, lastOffsetChange, adjustmentCounter

- Emits TimeReset and TimeOffsetChanged events

- No errors thrown - safe reset operation

- Not protected - no external calls

- Restricted to GOVERNANCE_ROLE

- No oracle dependencies


```solidity
function resetTime() external onlyRole(GOVERNANCE_ROLE);
```

### setEmergencyMode

Toggles emergency mode (emergency role only)

*Enables or disables emergency mode, automatically resetting time offset when enabled*

**Notes:**
- Validates emergency role authorization

- No input validation required

- Updates emergencyMode flag, resets timeOffset if enabling

- Emits EmergencyModeChanged and TimeOffsetChanged if reset

- No errors thrown - safe mode toggle

- Not protected - no external calls

- Restricted to EMERGENCY_ROLE

- No oracle dependencies


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
- Validates emergency role authorization

- No input validation required

- Updates timeOffset to 0, lastOffsetChange, adjustmentCounter

- Emits TimeReset and TimeOffsetChanged events

- No errors thrown - safe emergency reset

- Not protected - no external calls

- Restricted to EMERGENCY_ROLE

- No oracle dependencies


```solidity
function emergencyResetTime() external onlyRole(EMERGENCY_ROLE);
```

### getTimeInfo

Returns detailed time information

*Provides comprehensive time data including provider time, raw timestamp, offset, and emergency status*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query time information

- No oracle dependencies


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
- No security validations required - pure function

- No input validation required - pure function

- No state changes - pure function

- No events emitted

- No errors thrown - safe arithmetic used

- Not applicable - pure function

- Public - anyone can calculate time difference

- No oracle dependencies


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
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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

