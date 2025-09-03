# ITimelockUpgradeable
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/e5c3f7e74d800a0a930892672bba2f0c381c0a8d/src/interfaces/ITimelockUpgradeable.sol)

**Author:**
Quantillon Labs

Interface for the secure upgrade mechanism with timelock and multi-sig requirements

**Note:**
team@quantillon.money


## Functions
### proposeUpgrade

Propose an upgrade with timelock


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


```solidity
function approveUpgrade(address implementation) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`implementation`|`address`|Address of the implementation to approve|


### revokeUpgradeApproval

Revoke approval for a pending upgrade


```solidity
function revokeUpgradeApproval(address implementation) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`implementation`|`address`|Address of the implementation to revoke approval for|


### executeUpgrade

Execute an upgrade after timelock and multi-sig approval


```solidity
function executeUpgrade(address implementation) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`implementation`|`address`|Address of the implementation to execute|


### cancelUpgrade

Cancel a pending upgrade (only proposer or admin)


```solidity
function cancelUpgrade(address implementation) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`implementation`|`address`|Address of the implementation to cancel|


### emergencyUpgrade

Emergency upgrade (bypasses timelock, requires emergency mode)


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


```solidity
function addMultisigSigner(address signer) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`signer`|`address`|Address of the signer to add|


### removeMultisigSigner

Remove a multi-sig signer


```solidity
function removeMultisigSigner(address signer) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`signer`|`address`|Address of the signer to remove|


### toggleEmergencyMode

Toggle emergency mode


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


```solidity
function getMultisigSigners() external view returns (address[] memory signers);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`signers`|`address[]`|Array of signer addresses|


### pendingUpgrades


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

### multisigSigners


```solidity
function multisigSigners(address) external view returns (bool);
```

### multisigSignerCount


```solidity
function multisigSignerCount() external view returns (uint256);
```

### upgradeApprovals


```solidity
function upgradeApprovals(address, address) external view returns (bool);
```

### upgradeApprovalCount


```solidity
function upgradeApprovalCount(address) external view returns (uint256);
```

### emergencyMode


```solidity
function emergencyMode() external view returns (bool);
```

### UPGRADE_DELAY


```solidity
function UPGRADE_DELAY() external view returns (uint256);
```

### MAX_UPGRADE_DELAY


```solidity
function MAX_UPGRADE_DELAY() external view returns (uint256);
```

### MIN_MULTISIG_APPROVALS


```solidity
function MIN_MULTISIG_APPROVALS() external view returns (uint256);
```

### MAX_MULTISIG_SIGNERS


```solidity
function MAX_MULTISIG_SIGNERS() external view returns (uint256);
```

### UPGRADE_PROPOSER_ROLE


```solidity
function UPGRADE_PROPOSER_ROLE() external view returns (bytes32);
```

### UPGRADE_EXECUTOR_ROLE


```solidity
function UPGRADE_EXECUTOR_ROLE() external view returns (bytes32);
```

### EMERGENCY_UPGRADER_ROLE


```solidity
function EMERGENCY_UPGRADER_ROLE() external view returns (bytes32);
```

### MULTISIG_MANAGER_ROLE


```solidity
function MULTISIG_MANAGER_ROLE() external view returns (bytes32);
```

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

