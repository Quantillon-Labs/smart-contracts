# MetaMorphoStakingVaultAdapter
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/blob/083874330beb67c980851f48832ef5faa68973d3/src/core/vaults/MetaMorphoStakingVaultAdapter.sol)

**Inherits:**
AccessControl, ReentrancyGuard, [IExternalStakingVault](/src/interfaces/IExternalStakingVault.sol/interface.IExternalStakingVault.md), [IVersioned](/src/interfaces/IVersioned.sol/interface.IVersioned.md)

**Title:**
MetaMorphoStakingVaultAdapter

Adapter for MetaMorpho ERC-4626 vaults such as 0xBEEFE94c8aD530842bfE7d8B397938fFc1cb83b2.


## Constants
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


## State Variables
### metaMorphoVault

```solidity
IERC4626 public metaMorphoVault
```


### principalDeposited

```solidity
uint256 public principalDeposited
```


## Functions
### version

Semantic version of this non-upgradeable adapter.

Version changes accompany adapter behavior changes.

**Notes:**
- security: Read-only metadata.

- validation: None.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: None.

- access: Public.

- oracle: None.


```solidity
function version() external pure override returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|Semantic version string.|


### constructor

Initializes MetaMorpho adapter dependencies and roles.

Configures governance/manager roles, immutable USDC reference, and validates that the
MetaMorpho ERC-4626 vault's asset matches USDC.

**Notes:**
- security: Validates non-zero dependencies and matching ERC-4626 asset.

- validation: Reverts on zero address or asset mismatch.

- state-changes: Initializes role assignments and adapter dependency pointers.

- events: No events emitted by constructor.

- errors: Reverts with `ZeroAddress` or `InvalidAddress`.

- reentrancy: Not applicable - constructor only.

- access: Public constructor.

- oracle: No oracle dependencies.


```solidity
constructor(address admin, address usdc_, address metaMorphoVault_) ;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|Admin address granted default-admin, governance, and manager roles.|
|`usdc_`|`address`|USDC token address.|
|`metaMorphoVault_`|`address`|MetaMorpho ERC-4626 vault address (asset must equal `usdc_`).|


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


### harvestYieldToVault

Harvests accrued ERC-4626 share yield and transfers it as USDC to the caller (the vault).

Transfers the realized USDC to `msg.sender` (the vault) so the caller can apply its own
distribution policy. Caps to the vault's liquid withdrawable amount and leaves tracked
principal unchanged.

**Notes:**
- security: Restricted to `VAULT_MANAGER_ROLE`; protected by nonReentrant.

- validation: Returns zero when no yield is available; reverts only on downstream failures.

- state-changes: Leaves `principalDeposited` unchanged; transfers realized USDC to the caller.

- events: Emits downstream transfer events from dependencies.

- errors: Reverts with `InvalidAmount` on withdrawal mismatch or downstream failures.

- reentrancy: Protected by `nonReentrant`.

- access: Restricted to vault manager role.

- oracle: No oracle dependencies.


```solidity
function harvestYieldToVault()
    external
    override
    onlyRole(VAULT_MANAGER_ROLE)
    nonReentrant
    returns (uint256 realizedYield);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`realizedYield`|`uint256`|USDC yield harvested and transferred to the caller (6 decimals).|


### writeDownPrincipal

Writes down tracked principal to the current ERC-4626 underlying value.

This records an externally observed loss so future withdrawals cannot rely on
unavailable principal. It never transfers funds or changes share ownership.

**Notes:**
- security: Governance-only loss recognition.

- validation: Requires current underlying to be below tracked principal.

- state-changes: Decreases `principalDeposited`.

- events: PrincipalWrittenDown.

- errors: InvalidCondition when no loss is present.

- reentrancy: Protected by `nonReentrant`.

- access: GOVERNANCE_ROLE.

- oracle: No oracle dependency.


```solidity
function writeDownPrincipal() external onlyRole(GOVERNANCE_ROLE) nonReentrant returns (uint256 writtenDown);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`writtenDown`|`uint256`|Amount removed from tracked principal.|


### totalUnderlying

Returns the USDC value of MetaMorpho shares plus idle USDC.

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


### _totalUnderlying

Returns the USDC-equivalent value of this adapter's MetaMorpho shares.

Converts the adapter's ERC-4626 shares and adds idle USDC, including any rounding buffer.

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
### PrincipalWrittenDown

```solidity
event PrincipalWrittenDown(uint256 previousPrincipal, uint256 currentPrincipal);
```

### MetaMorphoVaultUpdated

```solidity
event MetaMorphoVaultUpdated(address indexed oldVault, address indexed newVault);
```
