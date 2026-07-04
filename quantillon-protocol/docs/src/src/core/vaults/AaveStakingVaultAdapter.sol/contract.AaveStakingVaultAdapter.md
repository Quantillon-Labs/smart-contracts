# AaveStakingVaultAdapter
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/973bc7b9b5281df753b9c9569aff01d589239043/src/core/vaults/AaveStakingVaultAdapter.sol)

**Inherits:**
AccessControl, ReentrancyGuard, [IExternalStakingVault](/src/interfaces/IExternalStakingVault.sol/interface.IExternalStakingVault.md)

**Title:**
AaveStakingVaultAdapter

Generic external vault adapter for Aave-like third-party vaults.

Mirrors MorphoStakingVaultAdapter structure for symmetric localhost testing.
Wraps a MockAaveVault (simple share-accounting mock) and routes yield to YieldShift.


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
### aaveVault

```solidity
IMockAaveVault public aaveVault
```


### principalDeposited

```solidity
uint256 public principalDeposited
```


## Functions
### constructor

Initializes Aave adapter dependencies and roles.

Grants `DEFAULT_ADMIN_ROLE`, `GOVERNANCE_ROLE`, and `VAULT_MANAGER_ROLE`,
then stores dependency pointers used by the adapter functions.

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
constructor(address admin, address usdc_, address aaveVault_) ;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|Admin address granted governance and manager roles.|
|`usdc_`|`address`|USDC token address.|
|`aaveVault_`|`address`|Mock Aave vault address.|


### depositUnderlying

Deposits USDC into the configured Aave vault.

Tracks principal and forwards the deposit to `aaveVault.depositUnderlying`.

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
|`sharesReceived`|`uint256`|Aave vault shares received for the deposit.|


### withdrawUnderlying

Withdraws USDC principal from the configured Aave vault.

Withdraws up to the tracked principal, then transfers the withdrawn USDC to `msg.sender`.

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

Harvests accrued yield from the Aave vault and transfers it as USDC to the caller (the vault).

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

Reads the underlying amount from the configured `aaveVault`.

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
|`underlyingBalance`|`uint256`|Underlying USDC-equivalent balance in the Aave vault.|


### setAaveVault

Updates the configured Aave vault endpoint.

Updates the `aaveVault` pointer; the adapter uses the new vault for future deposits/withdrawals.

**Notes:**
- security: Restricted to `GOVERNANCE_ROLE`.

- validation: Reverts on zero address input.

- state-changes: Updates `aaveVault` pointer.

- events: Emits `AaveVaultUpdated`.

- errors: Reverts with `ZeroAddress` for invalid input.

- reentrancy: No external calls after state change.

- access: Restricted to governance role.

- oracle: No oracle dependencies.


```solidity
function setAaveVault(address newAaveVault) external onlyRole(GOVERNANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newAaveVault`|`address`|New Aave vault address.|


## Events
### AaveVaultUpdated

```solidity
event AaveVaultUpdated(address indexed oldVault, address indexed newVault);
```

