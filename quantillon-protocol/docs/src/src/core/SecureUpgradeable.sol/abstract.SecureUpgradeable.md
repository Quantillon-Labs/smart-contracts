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

Records an approval from a DEFAULT_ADMIN_ROLE address for the current proposal.
Uses per-proposal bitmap to prevent duplicate approvals from the same address.

**Notes:**
- security: Only callable by DEFAULT_ADMIN_ROLE; prevents double-approval per admin.

- validation: Reverts if no active proposal or caller already approved.

- state-changes: Marks caller as approved and increments approvalCount in storage.

- events: Emits EmergencyDisableApproved with updated approval count.

- errors: NotActive if no pending proposal; NoChangeDetected if already approved.

- reentrancy: Not applicable – function is external but has no external calls after state changes.

- access: Restricted to DEFAULT_ADMIN_ROLE.

- oracle: No oracle dependencies.


```solidity
function approveEmergencyDisableSecureUpgrades() external onlyRole(DEFAULT_ADMIN_ROLE);
```

### applyEmergencyDisableSecureUpgrades

INFO-4: Apply a previously proposed emergency-disable after the timelock has elapsed.

Disables secure upgrades permanently for this deployment once quorum and delay are satisfied.
Resets pending state so a fresh proposal is required for any future changes.

**Notes:**
- security: Requires DEFAULT_ADMIN_ROLE, quorum approvals and elapsed delay.

- validation: Reverts on mismatched proposal id, missing quorum or no pending proposal.

- state-changes: Clears emergencyDisablePendingAt and approvalCount, sets secureUpgradesEnabled=false.

- events: Emits SecureUpgradesToggled(false) on successful application.

- errors: NotActive if no pending or delay not elapsed; NotAuthorized on id mismatch or quorum not met.

- reentrancy: Not applicable – no external calls after critical state changes.

- access: Restricted to DEFAULT_ADMIN_ROLE.

- oracle: No oracle dependencies.


```solidity
function applyEmergencyDisableSecureUpgrades(uint256 expectedProposalId) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`expectedProposalId`|`uint256`|Proposal id the caller expects to apply (replay/mismatch protection).|


### emergencyDisableProposalId

Returns the current emergency-disable proposal id.

Value is 0 when no proposal has ever been created.

**Notes:**
- security: View-only helper; no access restriction.

- validation: No input validation required.

- state-changes: None – pure read from dedicated emergency-disable storage.

- events: None.

- errors: None.

- reentrancy: Not applicable – view function.

- access: Public – any caller may inspect current proposal id.

- oracle: No oracle dependencies.


```solidity
function emergencyDisableProposalId() public view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|proposalId The active or last-used emergency-disable proposal id.|


### emergencyDisableApprovalCount

Returns the current approval count for the active emergency-disable proposal.

Reads the aggregate number of admin approvals recorded for the latest proposal.

**Notes:**
- security: View-only helper; no access restriction.

- validation: No input validation required.

- state-changes: None – pure read from dedicated emergency-disable storage.

- events: None.

- errors: None.

- reentrancy: Not applicable – view function.

- access: Public – any caller may inspect approval count.

- oracle: No oracle dependencies.


```solidity
function emergencyDisableApprovalCount() public view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|approvalCount Number of approvals for the current proposal.|


### emergencyDisableQuorum

Returns the quorum required to apply the emergency disable.

Exposes the EMERGENCY_DISABLE_QUORUM compile-time constant.

**Notes:**
- security: View-only helper; no access restriction.

- validation: No input validation required.

- state-changes: None – pure return of constant.

- events: None.

- errors: None.

- reentrancy: Not applicable – pure function.

- access: Public – any caller may inspect required quorum.

- oracle: No oracle dependencies.


```solidity
function emergencyDisableQuorum() public pure returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|quorum Number of approvals required to apply emergency-disable.|


### hasEmergencyDisableApproval

Returns whether a given approver address approved a specific emergency-disable proposal.

Returns false when approver is zero or proposalId is zero for safety.

**Notes:**
- security: View-only helper; no access restriction.

- validation: Treats zero proposalId or zero approver as “not approved”.

- state-changes: None – pure read from dedicated emergency-disable storage.

- events: None.

- errors: None.

- reentrancy: Not applicable – view function.

- access: Public – any caller may inspect approval status.

- oracle: No oracle dependencies.


```solidity
function hasEmergencyDisableApproval(uint256 proposalId, address approver) public view returns (bool hasApproved_);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`proposalId`|`uint256`|The proposal identifier to inspect.|
|`approver`|`address`|The admin address whose approval status is queried.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`hasApproved_`|`bool`|True if the approver has recorded an approval for proposalId.|


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

