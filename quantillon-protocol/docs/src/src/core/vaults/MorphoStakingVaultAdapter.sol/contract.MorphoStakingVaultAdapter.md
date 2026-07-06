# MorphoStakingVaultAdapter
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/e6d6ab67e05d161d0d4815c50b5213a2a6cbb873/src/core/vaults/MorphoStakingVaultAdapter.sol)

**Inherits:**
AccessControl, ReentrancyGuard, [IExternalStakingVault](/src/interfaces/IExternalStakingVault.sol/interface.IExternalStakingVault.md)

**Title:**
MorphoStakingVaultAdapter

Generic external vault adapter for Morpho-like third-party vaults.


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
### morphoVault

```solidity
IMockMorphoVault public morphoVault
```


### principalDeposited

```solidity
uint256 public principalDeposited
```


## Functions
### constructor

Initializes Morpho adapter dependencies and roles.

Configures governance/operator roles and immutable USDC reference.

**Notes:**
- security: Validates non-zero dependency addresses.

- validation: Reverts on zero address.

- state-changes: Initializes role assignments and adapter dependency pointers.

- events: No events emitted by constructor.

- errors: Reverts with `ZeroAddress` on invalid inputs.

- reentrancy: Not applicable - constructor only.

- access: Public constructor.

- oracle: No oracle dependencies.


```solidity
constructor(address admin, address usdc_, address morphoVault_) ;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|Admin address granted governance and manager roles.|
|`usdc_`|`address`|USDC token address.|
|`morphoVault_`|`address`|Mock Morpho vault address.|


### depositUnderlying

Deposits USDC into the configured Morpho vault.

Pulls USDC from caller, deposits to Morpho, and increases tracked principal.

**Notes:**
- security: Restricted to `VAULT_MANAGER_ROLE`; protected by nonReentrant.

- validation: Reverts on zero amount or zero-share deposit outcome.

- state-changes: Increases `principalDeposited` and updates vault position.

- events: Emits downstream transfer/deposit events from dependencies.

- errors: Reverts on transfer/approval/deposit failures.

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
|`sharesReceived`|`uint256`|Morpho vault shares received for the deposit.|


### withdrawUnderlying

Withdraws USDC principal from the configured Morpho vault.

Caps withdrawal to tracked principal, redeems from Morpho, then returns USDC to caller.

**Notes:**
- security: Restricted to `VAULT_MANAGER_ROLE`; protected by nonReentrant.

- validation: Reverts on zero amount or when no principal is tracked.

- state-changes: Decreases `principalDeposited` and updates vault position.

- events: Emits downstream transfer/withdrawal events from dependencies.

- errors: Reverts on withdrawal mismatch or transfer failures.

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
|`usdcAmount`|`uint256`|Requested USDC withdrawal amount (6 decimals).|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`usdcWithdrawn`|`uint256`|Actual USDC withdrawn and transferred to caller.|


### harvestYieldToVault

Harvests accrued yield from Morpho and transfers it as USDC to the caller (the vault).

Withdraws only the amount above tracked principal, then transfers it to `msg.sender`
(the vault) so the caller can apply its own distribution policy.

**Notes:**
- security: Restricted to `VAULT_MANAGER_ROLE`; protected by nonReentrant.

- validation: Returns zero when no yield is available; reverts only on downstream failures.

- state-changes: Leaves `principalDeposited` unchanged; transfers realized USDC to the caller.

- events: Emits downstream transfer events from dependencies.

- errors: Reverts on downstream withdrawal or transfer failures.

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


### totalUnderlying

Returns current underlying balance controlled by this adapter.

Read helper used by QuantillonVault for exposure accounting.

**Notes:**
- security: Read-only helper.

- validation: No input validation required.

- state-changes: No state changes.

- events: No events emitted.

- errors: May revert if downstream vault read fails.

- reentrancy: Not applicable for view function.

- access: Public view.

- oracle: No oracle dependencies.


```solidity
function totalUnderlying() external view override returns (uint256 underlyingBalance);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`underlyingBalance`|`uint256`|Underlying USDC-equivalent balance in Morpho.|


### setMorphoVault

Updates the configured Morpho vault endpoint.

Governance maintenance hook for swapping vault implementation/address.

**Notes:**
- security: Restricted to `GOVERNANCE_ROLE`.

- validation: Reverts on zero address input.

- state-changes: Updates `morphoVault` pointer.

- events: Emits `MorphoVaultUpdated`.

- errors: Reverts with `ZeroAddress` for invalid input.

- reentrancy: No external calls after state change.

- access: Restricted to governance role.

- oracle: No oracle dependencies.


```solidity
function setMorphoVault(address newMorphoVault) external onlyRole(GOVERNANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newMorphoVault`|`address`|New Morpho vault address.|


## Events
### MorphoVaultUpdated

```solidity
event MorphoVaultUpdated(address indexed oldVault, address indexed newVault);
```

