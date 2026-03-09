# SecureUpgradeable
**Inherits:**
UUPSUpgradeable, AccessControlUpgradeable

**Title:**
SecureUpgradeable

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

Secure base contract for upgradeable contracts with timelock protection

Replaces UUPSUpgradeable with timelock and multi-sig requirements

**Note:**
security-contact: team@quantillon.money


## State Variables
### UPGRADER_ROLE
Role for upgrade operations


```solidity
bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE")
```


### timelock
Timelock contract for secure upgrades


```solidity
ITimelockUpgradeable public timelock
```


### secureUpgradesEnabled
Whether the contract is using secure upgrades


```solidity
bool public secureUpgradesEnabled
```


### EMERGENCY_DISABLE_DELAY
INFO-4: Minimum delay before a proposed emergency-disable takes effect (24h)


```solidity
uint256 public constant EMERGENCY_DISABLE_DELAY = 24 hours
```


### EMERGENCY_DISABLE_QUORUM
Emergency-disable approvals required before apply can succeed


```solidity
uint256 public constant EMERGENCY_DISABLE_QUORUM = 2
```


### emergencyDisablePendingAt
INFO-4: Timestamp at which emergencyDisable can be applied (0 = no pending proposal)


```solidity
uint256 public emergencyDisablePendingAt
```


### EMERGENCY_DISABLE_STORAGE_SLOT
Unstructured storage slot to avoid shifting child storage layouts.


```solidity
bytes32 private constant EMERGENCY_DISABLE_STORAGE_SLOT =
    keccak256("quantillon.secure-upgradeable.emergency-disable.storage.v1")
```


## Functions
### _emergencyDisableStorage


```solidity
function _emergencyDisableStorage() private pure returns (EmergencyDisableStorage storage ds);
```

### onlyTimelock


```solidity
modifier onlyTimelock() ;
```

### _onlyTimelock

Reverts if caller is not the timelock contract

Used by onlyTimelock modifier; ensures upgrade execution comes from timelock only

**Notes:**
- security: Access control for upgrade execution

- validation: Timelock must be set and msg.sender must equal timelock

- state-changes: None

- events: None

- errors: NotAuthorized if timelock zero or caller not timelock

- reentrancy: No external calls

- access: Internal; used by modifier

- oracle: None


```solidity
function _onlyTimelock() internal view;
```

### __SecureUpgradeable_init

Initializes the SecureUpgradeable contract

Sets up the secure upgrade system with timelock protection

**Notes:**
- security: Validates timelock address and initializes secure upgrade system

- validation: Validates _timelock is not address(0)

- state-changes: Initializes timelock, enables secure upgrades, sets up access control

- events: Emits TimelockSet and SecureUpgradesToggled events

- errors: Throws "SecureUpgradeable: Invalid timelock" if _timelock is address(0)

- reentrancy: Protected by onlyInitializing modifier

- access: Internal function - only callable during initialization

- oracle: No oracle dependencies


```solidity
function __SecureUpgradeable_init(address _timelock) internal onlyInitializing;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_timelock`|`address`|Address of the timelock contract|


### setTimelock

Set the timelock contract

Configures the timelock contract for secure upgrade management

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

Enables or disables the secure upgrade mechanism

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

Initiates a secure upgrade proposal with timelock delay and multi-sig requirements

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

Executes a previously proposed upgrade after timelock delay

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

Allows emergency upgrades when secure upgrades are disabled or timelock is unavailable

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
function emergencyUpgrade(address newImplementation, string calldata description) external onlyRole(UPGRADER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newImplementation`|`address`|Address of the new implementation|
|`description`|`string`|Description of the emergency upgrade|


### _authorizeUpgrade

Authorize upgrade (overrides UUPSUpgradeable)

Internal function that determines upgrade authorization based on secure upgrade settings


```solidity
function _authorizeUpgrade(address newImplementation) internal view override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newImplementation`|`address`|Address of the new implementation|


### isUpgradePending

Check if an upgrade is pending

Checks if there is a pending upgrade for the specified implementation

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

Returns detailed information about a pending upgrade

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

Checks if a pending upgrade has passed the timelock delay and can be executed

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

Returns the current security configuration for upgrades

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


### proposeEmergencyDisableSecureUpgrades

Disable secure upgrades in emergency

INFO-4: Propose disabling secure upgrades; enforces a 24-hour timelock

Disables secure upgrades for emergency situations

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
function proposeEmergencyDisableSecureUpgrades() external onlyRole(DEFAULT_ADMIN_ROLE);
```

### approveEmergencyDisableSecureUpgrades

INFO-4/NEW-3: Register an admin approval for the active emergency-disable proposal.


```solidity
function approveEmergencyDisableSecureUpgrades() external onlyRole(DEFAULT_ADMIN_ROLE);
```

### applyEmergencyDisableSecureUpgrades

INFO-4: Apply a previously proposed emergency-disable after the timelock has elapsed


```solidity
function applyEmergencyDisableSecureUpgrades(uint256 expectedProposalId) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`expectedProposalId`|`uint256`|Proposal id the caller expects to apply (replay/mismatch protection)|


### emergencyDisableProposalId

Current emergency-disable proposal id (0 when no proposal has ever been created).


```solidity
function emergencyDisableProposalId() public view returns (uint256);
```

### emergencyDisableApprovalCount

Current approval count for the active proposal.


```solidity
function emergencyDisableApprovalCount() public view returns (uint256);
```

### emergencyDisableQuorum

Quorum required to apply the emergency disable.


```solidity
function emergencyDisableQuorum() public pure returns (uint256);
```

### hasEmergencyDisableApproval

Returns whether `approver` approved a given emergency-disable proposal.


```solidity
function hasEmergencyDisableApproval(uint256 proposalId, address approver) public view returns (bool);
```

### enableSecureUpgrades

Enable secure upgrades after emergency

Re-enables secure upgrades after emergency situations

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
event SecureUpgradeAuthorized(address indexed newImplementation, address indexed authorizedBy, string description);
```

### EmergencyDisableProposed
INFO-4: Emitted when an emergency-disable proposal is created


```solidity
event EmergencyDisableProposed(uint256 indexed proposalId, uint256 activatesAt);
```

### EmergencyDisableApproved

```solidity
event EmergencyDisableApproved(uint256 indexed proposalId, address indexed approver, uint256 approvalCount);
```

## Structs
### EmergencyDisableStorage

```solidity
struct EmergencyDisableStorage {
    uint256 proposalId;
    uint256 approvalCount;
    mapping(uint256 => mapping(address => bool)) hasApproved;
}
```

