# IstQEURO
**Title:**
IstQEURO

Minimal ERC-4626-oriented interface for stQEURO vault tokens.


## Functions
### asset

Returns the underlying ERC-20 asset managed by the vault.

Implementations should return the QEURO token address used by the ERC-4626 vault.

**Notes:**
- security: Read-only helper.

- validation: None.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: Not applicable.

- access: Public.

- oracle: Not applicable.


```solidity
function asset() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|underlyingAsset Address of the underlying QEURO asset.|


### totalAssets

Returns the total QEURO assets currently backing the vault.

Implementations should include principal and compounded yield held by the ERC-4626 vault.

**Notes:**
- security: Read-only helper.

- validation: None.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: Not applicable.

- access: Public.

- oracle: Not applicable.


```solidity
function totalAssets() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|managedAssets Total QEURO assets managed by the vault.|


### convertToShares

Converts a QEURO asset amount into the equivalent share amount.

Mirrors ERC-4626 share-conversion math using the current vault exchange rate.

**Notes:**
- security: Read-only helper.

- validation: Uses the current vault accounting model and rounding rules.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: Not applicable.

- access: Public.

- oracle: Not applicable.


```solidity
function convertToShares(uint256 assets) external view returns (uint256 shares);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`assets`|`uint256`|Amount of QEURO assets to convert.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`shares`|`uint256`|Equivalent stQEURO shares for `assets`.|


### convertToAssets

Converts a stQEURO share amount into the equivalent asset amount.

Mirrors ERC-4626 asset-conversion math using the current vault exchange rate.

**Notes:**
- security: Read-only helper.

- validation: Uses the current vault accounting model and rounding rules.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: Not applicable.

- access: Public.

- oracle: Not applicable.


```solidity
function convertToAssets(uint256 shares) external view returns (uint256 assets);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`shares`|`uint256`|Amount of stQEURO shares to convert.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`assets`|`uint256`|Equivalent QEURO assets for `shares`.|


### previewDeposit

Previews how many shares a deposit would mint.

Mirrors ERC-4626 preview math without transferring assets.

**Notes:**
- security: Read-only helper.

- validation: Uses current vault accounting and rounding behavior.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: Not applicable.

- access: Public.

- oracle: Not applicable.


```solidity
function previewDeposit(uint256 assets) external view returns (uint256 shares);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`assets`|`uint256`|Amount of QEURO assets to preview.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`shares`|`uint256`|Estimated stQEURO shares for the deposit.|


### previewMint

Previews how many assets would be required to mint a target share amount.

Mirrors ERC-4626 preview math without transferring assets.

**Notes:**
- security: Read-only helper.

- validation: Uses current vault accounting and rounding behavior.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: Not applicable.

- access: Public.

- oracle: Not applicable.


```solidity
function previewMint(uint256 shares) external view returns (uint256 assets);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`shares`|`uint256`|Amount of stQEURO shares to preview.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`assets`|`uint256`|Estimated QEURO assets required to mint `shares`.|


### previewWithdraw

Previews how many shares would be burned to withdraw a target asset amount.

Mirrors ERC-4626 preview math without transferring assets.

**Notes:**
- security: Read-only helper.

- validation: Uses current vault accounting and rounding behavior.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: Not applicable.

- access: Public.

- oracle: Not applicable.


```solidity
function previewWithdraw(uint256 assets) external view returns (uint256 shares);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`assets`|`uint256`|Amount of QEURO assets to preview.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`shares`|`uint256`|Estimated stQEURO shares burned for the withdrawal.|


### previewRedeem

Previews how many assets would be returned for a target share redemption.

Mirrors ERC-4626 preview math without transferring assets.

**Notes:**
- security: Read-only helper.

- validation: Uses current vault accounting and rounding behavior.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: Not applicable.

- access: Public.

- oracle: Not applicable.


```solidity
function previewRedeem(uint256 shares) external view returns (uint256 assets);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`shares`|`uint256`|Amount of stQEURO shares to preview.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`assets`|`uint256`|Estimated QEURO assets returned for redeeming `shares`.|


### deposit

Deposits QEURO and mints stQEURO shares to a receiver.

Implementations should follow ERC-4626 deposit semantics and emit a `Deposit` event.

**Notes:**
- security: Implementations should apply pause, allowance, and asset-transfer protections.

- validation: Implementations validate deposit amount, receiver, and available limits.

- state-changes: Transfers QEURO into the vault and mints stQEURO shares.

- events: Emits the standard ERC-4626 `Deposit` event in implementation.

- errors: Reverts on invalid input, paused state, or ERC-20/ERC-4626 failures.

- reentrancy: Implementation should guard integrated transfer flows as needed.

- access: Public.

- oracle: Not applicable.


```solidity
function deposit(uint256 assets, address receiver) external returns (uint256 shares);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`assets`|`uint256`|Amount of QEURO assets to deposit.|
|`receiver`|`address`|Address receiving the minted stQEURO shares.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`shares`|`uint256`|Amount of stQEURO shares minted.|


### mint

Mints a target share amount by supplying the required QEURO assets.

Implementations should follow ERC-4626 mint semantics and emit a `Deposit` event.

**Notes:**
- security: Implementations should apply pause, allowance, and asset-transfer protections.

- validation: Implementations validate share amount, receiver, and available limits.

- state-changes: Transfers QEURO into the vault and mints stQEURO shares.

- events: Emits the standard ERC-4626 `Deposit` event in implementation.

- errors: Reverts on invalid input, paused state, or ERC-20/ERC-4626 failures.

- reentrancy: Implementation should guard integrated transfer flows as needed.

- access: Public.

- oracle: Not applicable.


```solidity
function mint(uint256 shares, address receiver) external returns (uint256 assets);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`shares`|`uint256`|Amount of stQEURO shares to mint.|
|`receiver`|`address`|Address receiving the minted stQEURO shares.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`assets`|`uint256`|Amount of QEURO assets required for the mint.|


### withdraw

Withdraws QEURO assets from the vault.

Implementations should follow ERC-4626 withdraw semantics and emit a `Withdraw` event.

**Notes:**
- security: Implementations should apply pause, allowance, and asset-transfer protections.

- validation: Implementations validate asset amount, receiver/owner, and available limits.

- state-changes: Burns stQEURO shares and transfers QEURO assets out of the vault.

- events: Emits the standard ERC-4626 `Withdraw` event in implementation.

- errors: Reverts on invalid input, paused state, insufficient balances, or ERC-20/ERC-4626 failures.

- reentrancy: Implementation should guard integrated transfer flows as needed.

- access: Public.

- oracle: Not applicable.


```solidity
function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`assets`|`uint256`|Amount of QEURO assets to withdraw.|
|`receiver`|`address`|Address receiving the withdrawn QEURO.|
|`owner`|`address`|Share owner whose balance and allowance are consumed.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`shares`|`uint256`|Amount of stQEURO shares burned.|


### redeem

Redeems stQEURO shares for the underlying QEURO assets.

Implementations should follow ERC-4626 redeem semantics and emit a `Withdraw` event.

**Notes:**
- security: Implementations should apply pause, allowance, and asset-transfer protections.

- validation: Implementations validate share amount, receiver/owner, and available limits.

- state-changes: Burns stQEURO shares and transfers QEURO assets out of the vault.

- events: Emits the standard ERC-4626 `Withdraw` event in implementation.

- errors: Reverts on invalid input, paused state, insufficient balances, or ERC-20/ERC-4626 failures.

- reentrancy: Implementation should guard integrated transfer flows as needed.

- access: Public.

- oracle: Not applicable.


```solidity
function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`shares`|`uint256`|Amount of stQEURO shares to redeem.|
|`receiver`|`address`|Address receiving the redeemed QEURO.|
|`owner`|`address`|Share owner whose balance and allowance are consumed.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`assets`|`uint256`|Amount of QEURO assets returned.|


### balanceOf

Returns the current share balance for an owner.

Mirrors the ERC-20 balance view for stQEURO shares.

**Notes:**
- security: Read-only helper.

- validation: None.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: Not applicable.

- access: Public.

- oracle: Not applicable.


```solidity
function balanceOf(address owner) external view returns (uint256 shares);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`owner`|`address`|Account whose share balance is being queried.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`shares`|`uint256`|Current stQEURO share balance of `owner`.|


### totalSupply

Returns the total outstanding supply of stQEURO shares.

Mirrors the ERC-20 total supply view for the vault share token.

**Notes:**
- security: Read-only helper.

- validation: None.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: Not applicable.

- access: Public.

- oracle: Not applicable.


```solidity
function totalSupply() external view returns (uint256 sharesSupply);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`sharesSupply`|`uint256`|Total stQEURO shares currently issued.|


### yieldFee

Returns the configured yield fee for compounded vault yield.

Implementations generally express the fee in basis points.

**Notes:**
- security: Read-only helper.

- validation: None.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: Not applicable.

- access: Public.

- oracle: Not applicable.


```solidity
function yieldFee() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|feeBps Current yield fee in basis points.|


### updateYieldParameters

Updates the yield fee applied to compounded vault yield.

Implementations typically restrict this governance action and validate basis-point caps.

**Notes:**
- security: Restricted in implementation to governance or admin roles.

- validation: Implementations validate `_yieldFee` against configured fee limits.

- state-changes: Updates the stored yield-fee configuration.

- events: Emits implementation-defined yield-parameter update events.

- errors: Reverts on invalid fee values or missing privileges in implementation.

- reentrancy: Not applicable.

- access: Restricted in implementation to governance or admin roles.

- oracle: Not applicable.


```solidity
function updateYieldParameters(uint256 _yieldFee) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_yieldFee`|`uint256`|New yield fee in basis points.|


### vaultName

Returns the human-readable vault name associated with the share series.

Used by frontends and admin tooling to distinguish vault-specific stQEURO series.

**Notes:**
- security: Read-only helper.

- validation: None.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: Not applicable.

- access: Public.

- oracle: Not applicable.


```solidity
function vaultName() external view returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|name Vault name or suffix configured for the share token.|


