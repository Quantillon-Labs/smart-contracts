# MetaMorphoStakingVaultAdapter
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/0c6311949cabadbce9e79a7dafc6269035f6039e/src/core/vaults/MetaMorphoStakingVaultAdapter.sol)

**Inherits:**
AccessControl, ReentrancyGuard, [IExternalStakingVault](/src/interfaces/IExternalStakingVault.sol/interface.IExternalStakingVault.md)

**Title:**
MetaMorphoStakingVaultAdapter

Adapter for MetaMorpho ERC-4626 vaults such as 0xBEEFE94c8aD530842bfE7d8B397938fFc1cb83b2.


## State Variables
### GOVERNANCE_ROLE

```solidity
bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE")
```


### VAULT_MANAGER_ROLE

```solidity
bytes32 public constant VAULT_MANAGER_ROLE = keccak256("VAULT_MANAGER_ROLE")
```


### USDC

```solidity
IERC20 public immutable USDC
```


### metaMorphoVault

```solidity
IERC4626 public metaMorphoVault
```


### yieldShift

```solidity
IYieldShift public yieldShift
```


### yieldVaultId

```solidity
uint256 public yieldVaultId
```


### yieldSource

```solidity
bytes32 public yieldSource
```


### principalDeposited

```solidity
uint256 public principalDeposited
```


## Functions
### constructor

Initializes MetaMorpho adapter dependencies, roles, and yield routing config.

Configures governance/manager roles, immutable USDC reference, and validates that the
MetaMorpho ERC-4626 vault's asset matches USDC.

**Notes:**
- security: Validates non-zero dependencies, non-zero ids, and matching ERC-4626 asset.

- validation: Reverts on zero address, zero vault id, zero yield source, or asset mismatch.

- state-changes: Initializes role assignments and adapter dependency/config pointers.

- events: No events emitted by constructor.

- errors: Reverts with `ZeroAddress`, `InvalidVault`, `InvalidAmount`, or `InvalidAddress`.

- reentrancy: Not applicable - constructor only.

- access: Public constructor.

- oracle: No oracle dependencies.


```solidity
constructor(
    address admin,
    address usdc_,
    address metaMorphoVault_,
    address yieldShift_,
    uint256 yieldVaultId_,
    bytes32 yieldSource_
) ;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|Admin address granted default-admin, governance, and manager roles.|
|`usdc_`|`address`|USDC token address.|
|`metaMorphoVault_`|`address`|MetaMorpho ERC-4626 vault address (asset must equal `usdc_`).|
|`yieldShift_`|`address`|YieldShift contract address.|
|`yieldVaultId_`|`uint256`|YieldShift vault id used when routing harvested yield.|
|`yieldSource_`|`bytes32`|Yield source tag forwarded to YieldShift accounting.|


### depositUnderlying

Deposits USDC into the MetaMorpho ERC-4626 vault and tracks principal.

Pulls USDC from caller, deposits into the ERC-4626 vault using a scoped approval, and
increases tracked principal by the deposited amount.

**Notes:**
- security: Restricted to `VAULT_MANAGER_ROLE`; protected by nonReentrant.

- validation: Reverts on zero amount, insufficient deposit capacity, or zero-share outcome.

- state-changes: Increases `principalDeposited` and updates the ERC-4626 vault position.

- events: Emits downstream transfer/deposit events from dependencies.

- errors: Reverts with `InvalidAmount` or `InsufficientBalance` on failed checks.

- reentrancy: Protected by `nonReentrant`.

- access: Restricted to vault manager role.

- oracle: No oracle dependencies.


```solidity
function depositUnderlying(uint256 usdcAmount)
    external
    override
    onlyRole(VAULT_MANAGER_ROLE)
    nonReentrant
    returns (uint256 sharesReceived);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdcAmount`|`uint256`|Amount of USDC to deposit (6 decimals).|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`sharesReceived`|`uint256`|MetaMorpho shares minted to this adapter.|


### withdrawUnderlying

Withdraws tracked principal from MetaMorpho and returns USDC to the caller.

Caps the withdrawal to tracked principal, redeems from the ERC-4626 vault, verifies the
received amount, decreases tracked principal, then transfers USDC to the caller.

**Notes:**
- security: Restricted to `VAULT_MANAGER_ROLE`; protected by nonReentrant.

- validation: Reverts on zero amount, no tracked principal, insufficient liquidity, or shortfall.

- state-changes: Decreases `principalDeposited` and updates the ERC-4626 vault position.

- events: Emits downstream transfer/withdrawal events from dependencies.

- errors: Reverts with `InvalidAmount` or `InsufficientBalance` on failed checks.

- reentrancy: Protected by `nonReentrant`.

- access: Restricted to vault manager role.

- oracle: No oracle dependencies.


```solidity
function withdrawUnderlying(uint256 usdcAmount)
    external
    override
    onlyRole(VAULT_MANAGER_ROLE)
    nonReentrant
    returns (uint256 usdcWithdrawn);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdcAmount`|`uint256`|Requested USDC amount (6 decimals).|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`usdcWithdrawn`|`uint256`|Actual USDC amount withdrawn and transferred to the caller.|


### harvestYield

Harvests accrued ERC-4626 share yield and routes it to YieldShift.

Computes yield as the underlying balance above tracked principal, caps it to the vault's
liquid withdrawable amount, redeems it, and forwards it to YieldShift with the configured
vault id and source tag. Returns zero when no yield is available.

**Notes:**
- security: Restricted to `VAULT_MANAGER_ROLE`; protected by nonReentrant.

- validation: Returns zero when no yield is available; reverts only on downstream failures.

- state-changes: Leaves `principalDeposited` unchanged and routes yield through YieldShift.

- events: Emits downstream transfer/yield events from dependencies.

- errors: Reverts with `InvalidAmount` on withdrawal mismatch or downstream failures.

- reentrancy: Protected by `nonReentrant`.

- access: Restricted to vault manager role.

- oracle: No oracle dependencies.


```solidity
function harvestYield()
    external
    override
    onlyRole(VAULT_MANAGER_ROLE)
    nonReentrant
    returns (uint256 harvestedYield);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`harvestedYield`|`uint256`|Yield harvested and routed in USDC (6 decimals).|


### totalUnderlying

Returns the USDC value of this adapter's MetaMorpho shares.

Read helper used by QuantillonVault for exposure accounting; delegates to `_totalUnderlying`.

**Notes:**
- security: Read-only helper.

- validation: No input validation required.

- state-changes: No state changes.

- events: No events emitted.

- errors: May revert if the downstream ERC-4626 read fails.

- reentrancy: Not applicable for view function.

- access: Public view.

- oracle: No oracle dependencies.


```solidity
function totalUnderlying() external view override returns (uint256 underlyingBalance);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`underlyingBalance`|`uint256`|Underlying USDC-equivalent balance held via ERC-4626 shares.|


### setMetaMorphoVault

Updates the configured MetaMorpho ERC-4626 vault endpoint.

Governance maintenance hook; validates the new vault's asset matches USDC before swapping.

**Notes:**
- security: Restricted to `GOVERNANCE_ROLE`.

- validation: Reverts on zero address or asset mismatch with USDC.

- state-changes: Updates `metaMorphoVault` pointer.

- events: Emits `MetaMorphoVaultUpdated`.

- errors: Reverts with `ZeroAddress` or `InvalidAddress` for invalid input.

- reentrancy: No external calls after state change.

- access: Restricted to governance role.

- oracle: No oracle dependencies.


```solidity
function setMetaMorphoVault(address newMetaMorphoVault) external onlyRole(GOVERNANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newMetaMorphoVault`|`address`|New MetaMorpho ERC-4626 vault address.|


### setYieldShift

Updates YieldShift destination contract.

Governance maintenance hook for yield routing dependency changes.

**Notes:**
- security: Restricted to `GOVERNANCE_ROLE`.

- validation: Reverts on zero address input.

- state-changes: Updates `yieldShift` dependency pointer.

- events: Emits `YieldShiftUpdated`.

- errors: Reverts with `ZeroAddress` for invalid input.

- reentrancy: No external calls after state change.

- access: Restricted to governance role.

- oracle: No oracle dependencies.


```solidity
function setYieldShift(address newYieldShift) external onlyRole(GOVERNANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newYieldShift`|`address`|New YieldShift contract address.|


### setYieldVaultId

Updates destination vault id used when routing harvested yield.

Governance maintenance hook aligning adapter output with YieldShift vault mapping.

**Notes:**
- security: Restricted to `GOVERNANCE_ROLE`.

- validation: Reverts when `newYieldVaultId` is zero.

- state-changes: Updates `yieldVaultId`.

- events: Emits `YieldVaultIdUpdated`.

- errors: Reverts with `InvalidVault` for zero id.

- reentrancy: No external calls after state change.

- access: Restricted to governance role.

- oracle: No oracle dependencies.


```solidity
function setYieldVaultId(uint256 newYieldVaultId) external onlyRole(GOVERNANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newYieldVaultId`|`uint256`|New YieldShift vault id.|


### setYieldSource

Updates the yield source tag forwarded to YieldShift accounting.

Governance maintenance hook for adjusting the source label used in yield routing.

**Notes:**
- security: Restricted to `GOVERNANCE_ROLE`.

- validation: Reverts when `newYieldSource` is zero.

- state-changes: Updates `yieldSource`.

- events: Emits `YieldSourceUpdated`.

- errors: Reverts with `InvalidAmount` for a zero source tag.

- reentrancy: No external calls after state change.

- access: Restricted to governance role.

- oracle: No oracle dependencies.


```solidity
function setYieldSource(bytes32 newYieldSource) external onlyRole(GOVERNANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newYieldSource`|`bytes32`|New non-zero yield source tag.|


### _totalUnderlying

Returns the USDC-equivalent value of this adapter's MetaMorpho shares.

Converts the adapter's ERC-4626 share balance to assets via `convertToAssets`.

**Notes:**
- security: Internal read-only helper.

- validation: No input validation required.

- state-changes: No state changes.

- events: No events emitted.

- errors: May revert if the downstream ERC-4626 read fails.

- reentrancy: Not applicable for view function.

- access: Internal.

- oracle: No oracle dependencies.


```solidity
function _totalUnderlying() internal view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Underlying USDC-equivalent amount held via ERC-4626 shares.|


## Events
### MetaMorphoVaultUpdated

```solidity
event MetaMorphoVaultUpdated(address indexed oldVault, address indexed newVault);
```

### YieldShiftUpdated

```solidity
event YieldShiftUpdated(address indexed oldYieldShift, address indexed newYieldShift);
```

### YieldVaultIdUpdated

```solidity
event YieldVaultIdUpdated(uint256 indexed oldVaultId, uint256 indexed newVaultId);
```

### YieldSourceUpdated

```solidity
event YieldSourceUpdated(bytes32 indexed oldSource, bytes32 indexed newSource);
```

