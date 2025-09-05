# SecureUpgradeable
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/07b6c9d21c3d2b99aa95cee2e6cc9c3f00f0009a/src/core/SecureUpgradeable.sol)

**Inherits:**
UUPSUpgradeable, AccessControlUpgradeable

**Author:**
Quantillon Labs

Secure base contract for upgradeable contracts with timelock protection

*Replaces UUPSUpgradeable with timelock and multi-sig requirements*

**Note:**
security-contact: team@quantillon.money


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


```solidity
function __SecureUpgradeable_init(address _timelock) internal onlyInitializing;
```

### setTimelock

Set the timelock contract

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
function setTimelock(address _timelock) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_timelock`|`address`|Address of the timelock contract|


### toggleSecureUpgrades

Toggle secure upgrades

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
function toggleSecureUpgrades(bool enabled) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`enabled`|`bool`|Whether to enable secure upgrades|


### proposeUpgrade

Propose an upgrade through the timelock


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
function executeUpgrade(address newImplementation) external onlyTimelock;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newImplementation`|`address`|Address of the new implementation|


### emergencyUpgrade

Emergency upgrade (bypasses timelock, requires emergency mode)


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


```solidity
function _authorizeUpgrade(address newImplementation) internal override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newImplementation`|`address`|Address of the new implementation|


### isUpgradePending

Check if an upgrade is pending

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
function emergencyDisableSecureUpgrades() external onlyRole(DEFAULT_ADMIN_ROLE);
```

### enableSecureUpgrades

Enable secure upgrades after emergency

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
event SecureUpgradeAuthorized(address indexed newImplementation, address indexed authorizedBy);
```

