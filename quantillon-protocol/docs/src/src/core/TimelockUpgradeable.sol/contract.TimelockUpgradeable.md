# TimelockUpgradeable
**Inherits:**
Initializable, AccessControlUpgradeable, PausableUpgradeable

**Title:**
TimelockUpgradeable

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

Secure upgrade mechanism with timelock and multi-sig requirements

Replaces unrestricted upgrade capability with governance-controlled upgrades

**Note:**
security-contact: team@quantillon.money


## State Variables
### UPGRADE_DELAY
Minimum delay for upgrades (48 hours)


```solidity
uint256 public constant UPGRADE_DELAY = 48 hours
```


### MAX_UPGRADE_DELAY
Maximum delay for upgrades (7 days)


```solidity
uint256 public constant MAX_UPGRADE_DELAY = 7 days
```


### MIN_MULTISIG_APPROVALS
Minimum number of multi-sig approvals required


```solidity
uint256 public constant MIN_MULTISIG_APPROVALS = 2
```


### MAX_MULTISIG_SIGNERS
Maximum number of multi-sig signers


```solidity
uint256 public constant MAX_MULTISIG_SIGNERS = 5
```


### MAX_PROPOSAL_AGE
Maximum age of a pending upgrade proposal (LOW-6: prevents stale proposal execution)


```solidity
uint256 public constant MAX_PROPOSAL_AGE = 30 days
```


### UPGRADE_PROPOSER_ROLE
Role for proposing upgrades


```solidity
bytes32 public constant UPGRADE_PROPOSER_ROLE = keccak256("UPGRADE_PROPOSER_ROLE")
```


### UPGRADE_EXECUTOR_ROLE
Role for executing upgrades after timelock


```solidity
bytes32 public constant UPGRADE_EXECUTOR_ROLE = keccak256("UPGRADE_EXECUTOR_ROLE")
```


### EMERGENCY_UPGRADER_ROLE
Role for emergency upgrades (bypasses timelock)


```solidity
bytes32 public constant EMERGENCY_UPGRADER_ROLE = keccak256("EMERGENCY_UPGRADER_ROLE")
```


### MULTISIG_MANAGER_ROLE
Role for managing multi-sig signers


```solidity
bytes32 public constant MULTISIG_MANAGER_ROLE = keccak256("MULTISIG_MANAGER_ROLE")
```


### pendingUpgrades
Pending upgrades by implementation address


```solidity
mapping(address => PendingUpgrade) public pendingUpgrades
```


### multisigSigners
Multi-sig signers


```solidity
mapping(address => bool) public multisigSigners
```


### multisigSignerCount
Number of active multi-sig signers


```solidity
uint256 public multisigSignerCount
```


### upgradeApprovals
Upgrade approvals by signer


```solidity
mapping(address => mapping(address => bool)) public upgradeApprovals
```


### upgradeApprovalCount
Number of approvals for each pending upgrade


```solidity
mapping(address => uint256) public upgradeApprovalCount
```


### emergencyMode
Whether emergency mode is active


```solidity
bool public emergencyMode
```


### _multisigSignersList
Ordered list of multisig signers for approval clearing


```solidity
address[] internal _multisigSignersList
```


### _multisigSignerIndexPlusOne
1-based index mapping for O(1) signer removal from `_multisigSignersList`


```solidity
mapping(address => uint256) internal _multisigSignerIndexPlusOne
```


### _pendingUpgradesList
Ordered list of pending upgrade addresses for signer clearing


```solidity
address[] internal _pendingUpgradesList
```


### TIME_PROVIDER
TimeProvider contract for centralized time management

Used to replace direct block.timestamp usage for testability and consistency


```solidity
TimeProvider public immutable TIME_PROVIDER
```


## Functions
### onlyMultisigSigner


```solidity
modifier onlyMultisigSigner() ;
```

### onlyEmergencyUpgrader


```solidity
modifier onlyEmergencyUpgrader() ;
```

### _onlyEmergencyUpgrader

Reverts if caller is not emergency upgrader or emergency mode is not active

Used by onlyEmergencyUpgrader modifier; allows emergency upgrades only when enabled

**Notes:**
- security: Restricts emergency upgrade path to EMERGENCY_UPGRADER_ROLE when emergencyMode

- validation: Caller must have role and emergencyMode must be true

- state-changes: None

- events: None

- errors: NotEmergencyRole if not authorized or not emergency mode

- reentrancy: No external calls

- access: Internal; used by modifier

- oracle: None


```solidity
function _onlyEmergencyUpgrader() internal view;
```

### initialize

Initializes the timelock contract with admin privileges

Sets up access control roles and pausability. Can only be called once.

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to initializer modifier

- oracle: No oracle dependencies


```solidity
function initialize(address admin) public initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|The address that will receive admin and upgrade proposer roles|


### proposeUpgrade

Propose an upgrade with timelock

Proposes an upgrade with timelock delay and multi-sig approval requirements

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to UPGRADE_PROPOSER_ROLE

- oracle: No oracle dependencies


```solidity
function proposeUpgrade(address newImplementation, string calldata description, uint256 customDelay)
    external
    onlyRole(UPGRADE_PROPOSER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newImplementation`|`address`|Address of the new implementation|
|`description`|`string`|Description of the upgrade|
|`customDelay`|`uint256`|Optional custom delay (must be >= UPGRADE_DELAY)|


### approveUpgrade

Approve a pending upgrade (multi-sig signer only)

Allows multi-sig signers to approve pending upgrades

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to multi-sig signers

- oracle: No oracle dependencies


```solidity
function approveUpgrade(address implementation) external onlyMultisigSigner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`implementation`|`address`|Address of the implementation to approve|


### revokeUpgradeApproval

Revoke approval for a pending upgrade

Allows multi-sig signers to revoke their approval for pending upgrades

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to multi-sig signers

- oracle: No oracle dependencies


```solidity
function revokeUpgradeApproval(address implementation) external onlyMultisigSigner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`implementation`|`address`|Address of the implementation to revoke approval for|


### executeUpgrade

Execute an upgrade after timelock and multi-sig approval

Executes an upgrade after timelock delay and sufficient multi-sig approvals

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to UPGRADE_EXECUTOR_ROLE

- oracle: No oracle dependencies


```solidity
function executeUpgrade(address implementation) external onlyRole(UPGRADE_EXECUTOR_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`implementation`|`address`|Address of the implementation to execute|


### cancelUpgrade

Cancel a pending upgrade (only proposer or admin)

Allows proposer or admin to cancel pending upgrades

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to proposer or admin

- oracle: No oracle dependencies


```solidity
function cancelUpgrade(address implementation) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`implementation`|`address`|Address of the implementation to cancel|


### emergencyUpgrade

Emergency upgrade (bypasses timelock, requires emergency mode)

Performs emergency upgrade bypassing timelock and multi-sig requirements

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to emergency upgrader role

- oracle: No oracle dependencies


```solidity
function emergencyUpgrade(address newImplementation, string calldata description) external onlyEmergencyUpgrader;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newImplementation`|`address`|Address of the new implementation|
|`description`|`string`|Description of the emergency upgrade|


### addMultisigSigner

Add a multi-sig signer

Adds a new multi-sig signer to the timelock system

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to MULTISIG_MANAGER_ROLE

- oracle: No oracle dependencies


```solidity
function addMultisigSigner(address signer) external onlyRole(MULTISIG_MANAGER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`signer`|`address`|Address of the signer to add|


### removeMultisigSigner

Remove a multi-sig signer

Removes a multi-sig signer from the timelock system

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to MULTISIG_MANAGER_ROLE

- oracle: No oracle dependencies


```solidity
function removeMultisigSigner(address signer) external onlyRole(MULTISIG_MANAGER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`signer`|`address`|Address of the signer to remove|


### toggleEmergencyMode

Toggle emergency mode

Toggles emergency mode for emergency upgrades

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to EMERGENCY_UPGRADER_ROLE

- oracle: No oracle dependencies


```solidity
function toggleEmergencyMode(bool enabled, string calldata reason) external onlyRole(EMERGENCY_UPGRADER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`enabled`|`bool`|Whether to enable emergency mode|
|`reason`|`string`|Reason for the emergency mode change|


### getPendingUpgrade

Get pending upgrade details

Returns pending upgrade details for a given implementation

**Notes:**
- security: No security checks needed

- validation: No validation needed

- state-changes: No state changes

- events: No events emitted

- errors: No errors thrown

- reentrancy: No reentrancy protection needed

- access: No access restrictions

- oracle: No oracle dependencies


```solidity
function getPendingUpgrade(address implementation) external view returns (PendingUpgrade memory upgrade);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`implementation`|`address`|Address of the implementation|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`upgrade`|`PendingUpgrade`|Pending upgrade details|


### canExecuteUpgrade

Check if an upgrade can be executed

Checks if an upgrade can be executed based on timelock and approval requirements

**Notes:**
- security: No security checks needed

- validation: No validation needed

- state-changes: No state changes

- events: No events emitted

- errors: No errors thrown

- reentrancy: No reentrancy protection needed

- access: No access restrictions

- oracle: No oracle dependencies


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


### hasUpgradeApproval

Get upgrade approval status for a signer

Returns whether a signer has approved a specific upgrade

**Notes:**
- security: No security checks needed

- validation: No validation needed

- state-changes: No state changes

- events: No events emitted

- errors: No errors thrown

- reentrancy: No reentrancy protection needed

- access: No access restrictions

- oracle: No oracle dependencies


```solidity
function hasUpgradeApproval(address signer, address implementation) external view returns (bool approved);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`signer`|`address`|Address of the signer|
|`implementation`|`address`|Address of the implementation|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`approved`|`bool`|Whether the signer has approved the upgrade|


### getMultisigSigners

Get all multi-sig signers

Returns array of all multi-sig signer addresses

**Notes:**
- security: No security checks needed

- validation: No validation needed

- state-changes: No state changes

- events: No events emitted

- errors: No errors thrown

- reentrancy: No reentrancy protection needed

- access: No access restrictions

- oracle: No oracle dependencies


```solidity
function getMultisigSigners() external view returns (address[] memory signers);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`signers`|`address[]`|Array of signer addresses|


### currentTime

Returns protocol time from the shared TimeProvider

Exposes the canonical time source to dependent contracts (e.g. SecureUpgradeable)

**Notes:**
- security: Returns canonical protocol time managed by immutable shared provider

- validation: No input validation required

- state-changes: None

- events: None

- errors: None

- reentrancy: No external state mutation

- access: Public view utility

- oracle: No oracle dependencies


```solidity
function currentTime() external view returns (uint256);
```

### _clearUpgradeApprovals

Clear all approvals for an implementation

Clear all approvals for a specific implementation

Clears all approvals for a specific implementation

Resets approval counts for a pending upgrade and removes it from the ordered pending list

**Notes:**
- security: No security checks needed

- validation: No validation needed

- state-changes: Updates contract state variables

- events: No events emitted

- errors: No errors thrown

- reentrancy: No reentrancy protection needed

- access: Internal function

- oracle: No oracle dependencies

- security: Internal helper used after execute/cancel paths; assumes caller already validated upgrade existence

- validation: Assumes `implementation` is currently tracked in `_pendingUpgradesList`

- state-changes: Sets `upgradeApprovalCount[implementation]` to zero and clears all signer approvals

- events: No events emitted directly; caller is responsible for emitting high-level events

- errors: None - function is best-effort cleanup

- reentrancy: Not applicable - internal function with no external calls

- access: Internal function only

- oracle: No oracle dependencies


```solidity
function _clearUpgradeApprovals(address implementation) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`implementation`|`address`|Address of the implementation|


### _removePendingUpgrade

Remove an implementation from the ordered list of pending upgrades

Uses swap-and-pop to maintain a compact array of pending upgrades for efficient iteration

**Notes:**
- security: Internal helper; assumes caller has already validated that the upgrade is pending

- validation: Performs a linear scan over `_pendingUpgradesList` and stops at first match

- state-changes: Updates `_pendingUpgradesList` by replacing the removed element with the last one and shrinking the array

- events: No events emitted directly; high-level events are emitted by caller functions

- errors: None - function silently returns if no match is found

- reentrancy: Not applicable - internal function with no external calls

- access: Internal function only

- oracle: No oracle dependencies


```solidity
function _removePendingUpgrade(address implementation) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`implementation`|`address`|Address of the implementation to remove from `_pendingUpgradesList`|


### _clearSignerApprovals

Clear all approvals from a specific signer

Clears all approvals from a specific signer

**Notes:**
- security: No security checks needed

- validation: No validation needed

- state-changes: Updates contract state variables

- events: No events emitted

- errors: No errors thrown

- reentrancy: No reentrancy protection needed

- access: Internal function

- oracle: No oracle dependencies


```solidity
function _clearSignerApprovals(address signer) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`signer`|`address`|Address of the signer|


### _addMultisigSigner

Add a multisig signer (internal)

Adds a multisig signer internally

**Notes:**
- security: No security checks needed

- validation: No validation needed

- state-changes: Updates contract state variables

- events: No events emitted

- errors: No errors thrown

- reentrancy: No reentrancy protection needed

- access: Internal function

- oracle: No oracle dependencies


```solidity
function _addMultisigSigner(address signer) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`signer`|`address`|Address of the signer|


### pause

Pause the timelock contract

Pauses the timelock contract

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to DEFAULT_ADMIN_ROLE

- oracle: No oracle dependencies


```solidity
function pause() external onlyRole(DEFAULT_ADMIN_ROLE);
```

### unpause

Unpause the timelock contract

Unpauses the timelock contract

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to DEFAULT_ADMIN_ROLE

- oracle: No oracle dependencies


```solidity
function unpause() external onlyRole(DEFAULT_ADMIN_ROLE);
```

### constructor

Constructor for TimelockUpgradeable contract

Sets up the time provider and disables initializers for security

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Disables initializers

- events: No events emitted

- errors: Throws custom errors for invalid conditions

- reentrancy: No reentrancy protection needed

- access: No access restrictions

- oracle: No oracle dependencies


```solidity
constructor(TimeProvider _TIME_PROVIDER) ;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_TIME_PROVIDER`|`TimeProvider`|TimeProvider contract for centralized time management|


## Events
### UpgradeProposed

```solidity
event UpgradeProposed(
    address indexed implementation,
    uint256 proposedAt,
    uint256 executableAt,
    string description,
    address indexed proposer
);
```

### UpgradeApproved

```solidity
event UpgradeApproved(address indexed implementation, address indexed signer, uint256 approvalCount);
```

### UpgradeExecuted

```solidity
event UpgradeExecuted(address indexed implementation, address indexed executor, uint256 executedAt);
```

### UpgradeCancelled

```solidity
event UpgradeCancelled(address indexed implementation, address indexed canceller);
```

### MultisigSignerAdded

```solidity
event MultisigSignerAdded(address indexed signer);
```

### MultisigSignerRemoved

```solidity
event MultisigSignerRemoved(address indexed signer);
```

### EmergencyModeToggled

```solidity
event EmergencyModeToggled(bool enabled, string reason);
```

## Structs
### PendingUpgrade

```solidity
struct PendingUpgrade {
    address implementation;
    address proposingProxy; // HIGH-1: proxy contract that initiated this upgrade proposal
    uint256 proposedAt;
    uint256 executableAt;
    uint256 expiryAt; // LOW-6: proposal expires after MAX_PROPOSAL_AGE to prevent stale execution
    string description;
    bool isEmergency;
    address proposer;
}
```

