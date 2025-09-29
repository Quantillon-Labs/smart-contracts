# SecureUpgradeable
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/d29e599f54c502dc53514fc1959eef42e6ef819c/src/core/SecureUpgradeable.sol)

**Inherits:**
UUPSUpgradeable, AccessControlUpgradeable

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

Secure base contract for upgradeable contracts with timelock protection

*Replaces UUPSUpgradeable with timelock and multi-sig requirements*

**Note:**
team@quantillon.money


## State Variables
### UPGRADER_ROLE
Role for upgrade operations


```solidity
bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
```


### timelock
Timelock contract for secure upgrades


```solidity
ITimelockUpgradeable public timelock;
```


### secureUpgradesEnabled
Whether the contract is using secure upgrades


```solidity
bool public secureUpgradesEnabled;
```


## Functions
### onlyTimelock


```solidity
modifier onlyTimelock();
```

### __SecureUpgradeable_init

Initializes the SecureUpgradeable contract

*Sets up the secure upgrade system with timelock protection*

**Notes:**
- Validates timelock address and initializes secure upgrade system

- Validates _timelock is not address(0)

- Initializes timelock, enables secure upgrades, sets up access control

- Emits TimelockSet and SecureUpgradesToggled events

- Throws "SecureUpgradeable: Invalid timelock" if _timelock is address(0)

- Protected by onlyInitializing modifier

- Internal function - only callable during initialization

- No oracle dependencies


```solidity
function __SecureUpgradeable_init(address _timelock) internal onlyInitializing;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_timelock`|`address`|Address of the timelock contract|


### setTimelock

Set the timelock contract

*Configures the timelock contract for secure upgrade management*

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
function setTimelock(address _timelock) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_timelock`|`address`|Address of the timelock contract|


### toggleSecureUpgrades

Toggle secure upgrades

*Enables or disables the secure upgrade mechanism*

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
function toggleSecureUpgrades(bool enabled) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`enabled`|`bool`|Whether to enable secure upgrades|


### proposeUpgrade

Propose an upgrade through the timelock

*Initiates a secure upgrade proposal with timelock delay and multi-sig requirements*

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
function proposeUpgrade(address newImplementation, string calldata description, uint256 customDelay)
    external
    onlyRole(UPGRADER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newImplementation`|`address`|Address of the new implementation|
|`description`|`string`|Description of the upgrade|
|`customDelay`|`uint256`|Optional custom delay|


### executeUpgrade

Execute an upgrade through the timelock

*Executes a previously proposed upgrade after timelock delay*

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
function executeUpgrade(address newImplementation) external onlyTimelock;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newImplementation`|`address`|Address of the new implementation|


### emergencyUpgrade

Emergency upgrade (bypasses timelock, requires emergency mode)

*Allows emergency upgrades when secure upgrades are disabled or timelock is unavailable*

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
function emergencyUpgrade(address newImplementation, string calldata description) external onlyRole(UPGRADER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newImplementation`|`address`|Address of the new implementation|
|`description`|`string`|Description of the emergency upgrade|


### _authorizeUpgrade

Authorize upgrade (overrides UUPSUpgradeable)

*Internal function that determines upgrade authorization based on secure upgrade settings*


```solidity
function _authorizeUpgrade(address newImplementation) internal view override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newImplementation`|`address`|Address of the new implementation|


### isUpgradePending

Check if an upgrade is pending

*Checks if there is a pending upgrade for the specified implementation*

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
function isUpgradePending(address implementation) external view returns (bool isPending);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`implementation`|`address`|Address of the implementation|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`isPending`|`bool`|Whether the upgrade is pending|


### getPendingUpgrade

Get pending upgrade details

*Returns detailed information about a pending upgrade*

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
function getPendingUpgrade(address implementation)
    external
    view
    returns (ITimelockUpgradeable.PendingUpgrade memory upgrade);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`implementation`|`address`|Address of the implementation|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`upgrade`|`ITimelockUpgradeable.PendingUpgrade`|Pending upgrade details|


### canExecuteUpgrade

Check if an upgrade can be executed

*Checks if a pending upgrade has passed the timelock delay and can be executed*

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
function canExecuteUpgrade(address implementation) external view returns (bool canExecute);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`implementation`|`address`|Address of the implementation|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`canExecute`|`bool`|Whether the upgrade can be executed|


### getUpgradeSecurityStatus

Get upgrade security status

*Returns the current security configuration for upgrades*

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
function getUpgradeSecurityStatus()
    external
    view
    returns (address timelockAddress, bool secureUpgradesEnabled_, bool hasTimelock);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`timelockAddress`|`address`|Address of the timelock contract|
|`secureUpgradesEnabled_`|`bool`|Whether secure upgrades are enabled|
|`hasTimelock`|`bool`|Whether timelock is set|


### emergencyDisableSecureUpgrades

Disable secure upgrades in emergency

*Disables secure upgrades for emergency situations*

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
function emergencyDisableSecureUpgrades() external onlyRole(DEFAULT_ADMIN_ROLE);
```

### enableSecureUpgrades

Enable secure upgrades after emergency

*Re-enables secure upgrades after emergency situations*

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
function enableSecureUpgrades() external onlyRole(DEFAULT_ADMIN_ROLE);
```

## Events
### TimelockSet

```solidity
event TimelockSet(address indexed timelock);
```

### SecureUpgradesToggled

```solidity
event SecureUpgradesToggled(bool enabled);
```

### SecureUpgradeAuthorized

```solidity
event SecureUpgradeAuthorized(address indexed newImplementation, address indexed authorizedBy, string description);
```

