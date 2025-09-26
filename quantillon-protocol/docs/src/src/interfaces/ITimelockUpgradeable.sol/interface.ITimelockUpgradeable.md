# ITimelockUpgradeable
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/486f19261aef0b99ac5330b56bb5ad5bbdda41eb/src/interfaces/ITimelockUpgradeable.sol)

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

Interface for the secure upgrade mechanism with timelock and multi-sig requirements

**Note:**
security-contact: team@quantillon.money


## Functions
### initialize

Initializes the timelock upgradeable contract

*Sets up the timelock with initial configuration and assigns roles to admin*

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
function initialize(address admin) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|Address that receives admin and upgrade proposer roles|


### proposeUpgrade

Propose an upgrade with timelock

*Initiates a secure upgrade proposal with timelock delay and multi-sig requirements*

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
function proposeUpgrade(address newImplementation, string calldata description, uint256 customDelay) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newImplementation`|`address`|Address of the new implementation|
|`description`|`string`|Description of the upgrade|
|`customDelay`|`uint256`|Optional custom delay (must be >= UPGRADE_DELAY)|


### approveUpgrade

Approve a pending upgrade (multi-sig signer only)

*Allows multi-sig signers to approve pending upgrades*

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
function approveUpgrade(address implementation) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`implementation`|`address`|Address of the implementation to approve|


### revokeUpgradeApproval

Revoke approval for a pending upgrade

*Allows multi-sig signers to revoke their approval for pending upgrades*

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
function revokeUpgradeApproval(address implementation) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`implementation`|`address`|Address of the implementation to revoke approval for|


### executeUpgrade

Execute an upgrade after timelock and multi-sig approval

*Executes a previously approved upgrade after timelock delay*

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
function executeUpgrade(address implementation) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`implementation`|`address`|Address of the implementation to execute|


### cancelUpgrade

Cancel a pending upgrade (only proposer or admin)

*Allows proposer or admin to cancel a pending upgrade*

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
function cancelUpgrade(address implementation) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`implementation`|`address`|Address of the implementation to cancel|


### emergencyUpgrade

Emergency upgrade (bypasses timelock, requires emergency mode)

*Performs immediate upgrade in emergency situations*

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
function emergencyUpgrade(address newImplementation, string calldata description) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newImplementation`|`address`|Address of the new implementation|
|`description`|`string`|Description of the emergency upgrade|


### addMultisigSigner

Add a multi-sig signer

*Adds a new multi-sig signer to the approval process*

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
function addMultisigSigner(address signer) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`signer`|`address`|Address of the signer to add|


### removeMultisigSigner

Remove a multi-sig signer

*Removes a multi-sig signer from the approval process*

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
function removeMultisigSigner(address signer) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`signer`|`address`|Address of the signer to remove|


### toggleEmergencyMode

Toggle emergency mode

*Enables or disables emergency mode for immediate upgrades*

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
function toggleEmergencyMode(bool enabled, string calldata reason) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`enabled`|`bool`|Whether to enable emergency mode|
|`reason`|`string`|Reason for the emergency mode change|


### getPendingUpgrade

Get pending upgrade details

*Returns detailed information about a pending upgrade*

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

*Checks if the timelock delay has passed and upgrade can be executed*

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


### hasUpgradeApproval

Get upgrade approval status for a signer

*Checks if a specific signer has approved a specific upgrade*

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

*Returns array of all authorized multi-sig signers*

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
function getMultisigSigners() external view returns (address[] memory signers);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`signers`|`address[]`|Array of signer addresses|


### pendingUpgrades

Returns pending upgrade details for an implementation

*Maps implementation address to pending upgrade information*

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
function pendingUpgrades(address)
    external
    view
    returns (
        address implementation,
        uint256 proposedAt,
        uint256 executableAt,
        string memory description,
        bool isEmergency,
        address proposer
    );
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`implementation`|`address`|Address of the new implementation|
|`proposedAt`|`uint256`|Timestamp when upgrade was proposed|
|`executableAt`|`uint256`|Timestamp when upgrade can be executed|
|`description`|`string`|Description of the upgrade|
|`isEmergency`|`bool`|Whether this is an emergency upgrade|
|`proposer`|`address`|Address of the proposer|


### multisigSigners

Checks if an address is a multi-sig signer

*Returns true if the address is authorized as a multi-sig signer*

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
function multisigSigners(address signer) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`signer`|`address`|The address to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if the address is a multi-sig signer|


### multisigSignerCount

Returns the total number of multi-sig signers

*Returns the count of authorized multi-sig signers*

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
function multisigSignerCount() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Total number of multi-sig signers|


### upgradeApprovals

Checks if a signer has approved an upgrade

*Returns true if the signer has approved the specific upgrade*

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
function upgradeApprovals(address signer, address newImplementation) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`signer`|`address`|The address of the signer|
|`newImplementation`|`address`|The address of the new implementation|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if the signer has approved the upgrade|


### upgradeApprovalCount

Returns the number of approvals for an upgrade

*Returns the count of approvals for a specific upgrade*

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
function upgradeApprovalCount(address newImplementation) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newImplementation`|`address`|The address of the new implementation|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Number of approvals for the upgrade|


### emergencyMode

Returns whether emergency mode is enabled

*Indicates if emergency mode is currently active*

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
function emergencyMode() external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if emergency mode is enabled|


### UPGRADE_DELAY

Returns the default upgrade delay

*Minimum delay required for upgrades (in seconds)*

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
function UPGRADE_DELAY() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Default upgrade delay in seconds|


### MAX_UPGRADE_DELAY

Returns the maximum allowed upgrade delay

*Maximum delay that can be set for upgrades (in seconds)*

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
function MAX_UPGRADE_DELAY() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Maximum upgrade delay in seconds|


### MIN_MULTISIG_APPROVALS

Returns the minimum required multi-sig approvals

*Minimum number of approvals required to execute an upgrade*

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
function MIN_MULTISIG_APPROVALS() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Minimum number of required approvals|


### MAX_MULTISIG_SIGNERS

Returns the maximum allowed multi-sig signers

*Maximum number of multi-sig signers that can be added*

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
function MAX_MULTISIG_SIGNERS() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Maximum number of multi-sig signers|


### UPGRADE_PROPOSER_ROLE

Returns the upgrade proposer role identifier

*Role that can propose upgrades*

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
function UPGRADE_PROPOSER_ROLE() external view returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The upgrade proposer role bytes32 identifier|


### UPGRADE_EXECUTOR_ROLE

Returns the upgrade executor role identifier

*Role that can execute upgrades*

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
function UPGRADE_EXECUTOR_ROLE() external view returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The upgrade executor role bytes32 identifier|


### EMERGENCY_UPGRADER_ROLE

Returns the emergency upgrader role identifier

*Role that can perform emergency upgrades*

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
function EMERGENCY_UPGRADER_ROLE() external view returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The emergency upgrader role bytes32 identifier|


### MULTISIG_MANAGER_ROLE

Returns the multi-sig manager role identifier

*Role that can manage multi-sig signers*

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
function MULTISIG_MANAGER_ROLE() external view returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The multi-sig manager role bytes32 identifier|


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
    uint256 proposedAt;
    uint256 executableAt;
    string description;
    bool isEmergency;
    address proposer;
}
```

