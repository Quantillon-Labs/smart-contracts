# IMockAaveVault

## Functions
### depositUnderlying

Deposits underlying assets into the mock Aave vault.

Forwards parameters to the underlying vault and relies on the adapter-level
access control and `nonReentrant` protection in the main adapter.

**Notes:**
- security: External dependency call; trust model is environment-specific.

- validation: Reverts on invalid amount or vault-side checks.

- state-changes: Updates vault share/asset accounting.

- events: Vault implementation may emit deposit events.

- errors: Reverts on vault-side failures.

- reentrancy: Interface declaration only.

- access: Access control defined by vault implementation.

- oracle: No oracle dependencies.


```solidity
function depositUnderlying(uint256 assets, address onBehalfOf) external returns (uint256 shares);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`assets`|`uint256`|Amount of USDC to deposit.|
|`onBehalfOf`|`address`|Account credited with vault shares.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`shares`|`uint256`|Vault shares minted for the deposit.|


### withdrawUnderlying

Withdraws underlying assets from the mock Aave vault.

Forwards parameters to the underlying vault.
Reverts and/or returns values are handled by the calling adapter.

**Notes:**
- security: External dependency call; trust model is environment-specific.

- validation: Reverts on insufficient balance or vault-side checks.

- state-changes: Updates vault share/asset accounting.

- events: Vault implementation may emit withdrawal events.

- errors: Reverts on vault-side failures.

- reentrancy: Interface declaration only.

- access: Access control defined by vault implementation.

- oracle: No oracle dependencies.


```solidity
function withdrawUnderlying(uint256 assets, address to) external returns (uint256 withdrawn);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`assets`|`uint256`|Amount of USDC requested.|
|`to`|`address`|Recipient of withdrawn USDC.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`withdrawn`|`uint256`|Actual USDC withdrawn.|


### totalUnderlyingOf

Returns underlying assets held for an account.

View helper used by the adapter to compute available yield.

**Notes:**
- security: Read-only helper.

- validation: No input validation required at interface level.

- state-changes: No state changes.

- events: No events emitted.

- errors: May revert if implementation cannot service read.

- reentrancy: Not applicable for view function.

- access: Public view at implementation level.

- oracle: No oracle dependencies.


```solidity
function totalUnderlyingOf(address account) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|Account to query.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Underlying USDC-equivalent amount for `account`.|


