# AaveStakingVaultAdapter
**Inherits:**
AccessControl, ReentrancyGuard, [IExternalStakingVault](/src/interfaces/IExternalStakingVault.sol/interface.IExternalStakingVault.md)

**Title:**
AaveStakingVaultAdapter

Generic external vault adapter for Aave-like third-party vaults.

Mirrors MorphoStakingVaultAdapter structure for symmetric localhost testing.
Wraps a MockAaveVault (simple share-accounting mock) and routes yield to YieldShift.


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


### aaveVault

```solidity
IMockAaveVault public aaveVault
```


### yieldShift

```solidity
IYieldShift public yieldShift
```


### yieldVaultId

```solidity
uint256 public yieldVaultId
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
- security: Validates non-zero dependency addresses and vault id.

- validation: Reverts on zero address or zero `yieldVaultId_`.

- state-changes: Initializes role assignments and adapter dependency pointers.

- events: No events emitted by constructor.

- errors: Reverts with `ZeroAddress` or `InvalidVault` on invalid inputs.

- reentrancy: Not applicable - constructor only.

- access: Public constructor.

- oracle: No oracle dependencies.


```solidity
constructor(address admin, address usdc_, address aaveVault_, address yieldShift_, uint256 yieldVaultId_) ;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|Admin address granted governance and manager roles.|
|`usdc_`|`address`|USDC token address.|
|`aaveVault_`|`address`|Mock Aave vault address.|
|`yieldShift_`|`address`|YieldShift contract address.|
|`yieldVaultId_`|`uint256`|YieldShift vault id used when routing harvested yield.|


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


### harvestYield

Harvests accrued yield from the Aave vault and routes it to YieldShift.

Computes yield as `totalUnderlyingOf(this) - principalDeposited`, withdraws it,
and routes it to `yieldShift.addYield`.

**Notes:**
- security: Restricted to `VAULT_MANAGER_ROLE`; protected by nonReentrant.

- validation: Reverts only on downstream failures; returns zero when no yield is available.

- state-changes: Leaves principal unchanged and routes yield through YieldShift.

- events: Emits downstream transfer/yield events from dependencies.

- errors: Reverts on downstream withdrawal, approval, or addYield failures.

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
|`harvestedYield`|`uint256`|USDC yield harvested and routed (6 decimals).|


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


### setYieldShift

Updates YieldShift destination contract.

Updates the `yieldShift` pointer; future harvested yield is routed to the new contract.

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

Updates the `yieldVaultId` used by `harvestYield` when calling `yieldShift.addYield`.

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


## Events
### AaveVaultUpdated

```solidity
event AaveVaultUpdated(address indexed oldVault, address indexed newVault);
```

### YieldShiftUpdated

```solidity
event YieldShiftUpdated(address indexed oldYieldShift, address indexed newYieldShift);
```

### YieldVaultIdUpdated

```solidity
event YieldVaultIdUpdated(uint256 indexed oldVaultId, uint256 indexed newVaultId);
```

