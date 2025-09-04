# TimeProvider
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/8586bf0c799c78a35c463b66cf8c6beb85e48666/src/libraries/TimeProviderLibrary.sol)

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

**Note:**
oz-upgrades-unsafe-allow: constructor


```solidity
constructor();
```

### initialize

Initializes the TimeProvider contract


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


```solidity
function currentTime() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Current timestamp adjusted by the offset|


### _getCurrentTime

Returns the current time according to this provider (internal)


```solidity
function _getCurrentTime() internal view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Current timestamp adjusted by the offset|


### rawTimestamp

Returns the raw block timestamp without any offset


```solidity
function rawTimestamp() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Raw block.timestamp|


### isFuture

Checks if a timestamp is in the future according to provider time


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


```solidity
function resetTime() external onlyRole(GOVERNANCE_ROLE);
```

### setEmergencyMode

Toggles emergency mode (emergency role only)


```solidity
function setEmergencyMode(bool enabled) external onlyRole(EMERGENCY_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`enabled`|`bool`|Whether to enable or disable emergency mode|


### emergencyResetTime

Emergency time reset (emergency role only)


```solidity
function emergencyResetTime() external onlyRole(EMERGENCY_ROLE);
```

### getTimeInfo

Returns detailed time information


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


```solidity
function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newImplementation`|`address`|Address of the new implementation|


### version

Returns the version of this contract implementation


```solidity
function version() external pure returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|Version string|


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

