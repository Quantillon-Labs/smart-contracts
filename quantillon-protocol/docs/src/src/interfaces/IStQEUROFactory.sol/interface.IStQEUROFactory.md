# IStQEUROFactory

## Functions
### registerVault

Registers caller vault and deploys a dedicated stQEURO proxy.

Implementation enforces vault uniqueness and deterministic token deployment.

**Notes:**
- security: Restricted by implementation access control.

- validation: Implementations should validate vault id/name and uniqueness.

- state-changes: Updates factory registry mappings and deploys token proxy.

- events: Emits registration event in implementation.

- errors: Reverts on invalid input or duplicate registration.

- reentrancy: Implementation should use CEI-safe ordering for external deployment call.

- access: Access controlled by implementation.

- oracle: No oracle dependencies.


```solidity
function registerVault(uint256 vaultId, string calldata vaultName) external returns (address stQEUROToken);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vaultId`|`uint256`|Vault identifier to register.|
|`vaultName`|`string`|Uppercase alphanumeric vault name.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`stQEUROToken`|`address`|Registered stQEURO token address.|


### previewVaultToken

Previews deterministic stQEURO address for a vault registration tuple.

Read-only helper used before registration to bind expected token address.

**Notes:**
- security: Read-only helper.

- validation: Implementations should validate vault inputs and name format.

- state-changes: No state changes.

- events: No events emitted.

- errors: Reverts on invalid preview inputs.

- reentrancy: Not applicable for view function.

- access: Public view.

- oracle: No oracle dependencies.


```solidity
function previewVaultToken(address vault, uint256 vaultId, string calldata vaultName)
    external
    view
    returns (address stQEUROToken);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|Vault address that will register.|
|`vaultId`|`uint256`|Vault identifier to register.|
|`vaultName`|`string`|Uppercase alphanumeric vault name.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`stQEUROToken`|`address`|Predicted token address for registration tuple.|


### getStQEUROByVaultId

Returns registered stQEURO token by vault id.

Read-only registry lookup.

**Notes:**
- security: Read-only accessor.

- validation: No input validation required.

- state-changes: No state changes.

- events: No events emitted.

- errors: No errors expected.

- reentrancy: Not applicable for view function.

- access: Public view.

- oracle: No oracle dependencies.


```solidity
function getStQEUROByVaultId(uint256 vaultId) external view returns (address stQEUROToken);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vaultId`|`uint256`|Vault identifier.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`stQEUROToken`|`address`|Registered token address (or zero if unset).|


### getStQEUROByVault

Returns registered stQEURO token by vault address.

Read-only registry lookup.

**Notes:**
- security: Read-only accessor.

- validation: No input validation required.

- state-changes: No state changes.

- events: No events emitted.

- errors: No errors expected.

- reentrancy: Not applicable for view function.

- access: Public view.

- oracle: No oracle dependencies.


```solidity
function getStQEUROByVault(address vault) external view returns (address stQEUROToken);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|Vault contract address.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`stQEUROToken`|`address`|Registered token address (or zero if unset).|


### getVaultById

Returns vault address mapped to a vault id.

Read-only registry lookup.

**Notes:**
- security: Read-only accessor.

- validation: No input validation required.

- state-changes: No state changes.

- events: No events emitted.

- errors: No errors expected.

- reentrancy: Not applicable for view function.

- access: Public view.

- oracle: No oracle dependencies.


```solidity
function getVaultById(uint256 vaultId) external view returns (address vault);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vaultId`|`uint256`|Vault identifier.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|Vault address (or zero if unset).|


### getVaultIdByStQEURO

Returns vault id mapped to an stQEURO token address.

Read-only reverse-registry lookup.

**Notes:**
- security: Read-only accessor.

- validation: No input validation required.

- state-changes: No state changes.

- events: No events emitted.

- errors: No errors expected.

- reentrancy: Not applicable for view function.

- access: Public view.

- oracle: No oracle dependencies.


```solidity
function getVaultIdByStQEURO(address stQEUROToken) external view returns (uint256 vaultId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`stQEUROToken`|`address`|Registered token address.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`vaultId`|`uint256`|Vault identifier (or zero if unset).|


### getVaultName

Returns canonical vault name string for a vault id.

Read-only registry lookup.

**Notes:**
- security: Read-only accessor.

- validation: No input validation required.

- state-changes: No state changes.

- events: No events emitted.

- errors: No errors expected.

- reentrancy: Not applicable for view function.

- access: Public view.

- oracle: No oracle dependencies.


```solidity
function getVaultName(uint256 vaultId) external view returns (string memory vaultName);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vaultId`|`uint256`|Vault identifier.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`vaultName`|`string`|Registered vault name string.|


