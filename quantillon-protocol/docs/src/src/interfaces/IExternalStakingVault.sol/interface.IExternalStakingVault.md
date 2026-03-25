# IExternalStakingVault
**Title:**
IExternalStakingVault

Generic adapter interface for third-party staking/yield vaults.

QuantillonVault interacts with all external yield sources through this surface.


## Functions
### depositUnderlying

Deposits underlying USDC into the external vault.

Adapter entrypoint used by QuantillonVault for principal deployment.

**Notes:**
- security: Implementations should restrict unauthorized callers.

- validation: Implementations should validate non-zero amount and integration readiness.

- state-changes: Typically increases adapter-held principal and downstream vault position.

- events: Implementations should emit deposit/accounting events.

- errors: Reverts on invalid input or downstream integration failure.

- reentrancy: Implementations should enforce CEI/nonReentrant where needed.

- access: Access control is implementation-defined.

- oracle: No mandatory oracle dependency at interface level.


```solidity
function depositUnderlying(uint256 usdcAmount) external returns (uint256 sharesReceived);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdcAmount`|`uint256`|Amount of USDC to deposit (6 decimals).|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`sharesReceived`|`uint256`|Adapter-specific share amount or accounting units received.|


### withdrawUnderlying

Withdraws underlying USDC from the external vault.

Adapter entrypoint used by QuantillonVault for redemption liquidity.

**Notes:**
- security: Implementations should restrict unauthorized callers.

- validation: Implementations should validate amount and available liquidity.

- state-changes: Typically decreases adapter-held principal and returns USDC.

- events: Implementations should emit withdrawal/accounting events.

- errors: Reverts on invalid input or downstream integration failure.

- reentrancy: Implementations should enforce CEI/nonReentrant where needed.

- access: Access control is implementation-defined.

- oracle: No mandatory oracle dependency at interface level.


```solidity
function withdrawUnderlying(uint256 usdcAmount) external returns (uint256 usdcWithdrawn);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdcAmount`|`uint256`|Amount of USDC to withdraw (6 decimals).|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`usdcWithdrawn`|`uint256`|Actual USDC withdrawn.|


### harvestYield

Harvests yield and routes it to YieldShift using adapter-defined source semantics.

Realizes accrued yield without withdrawing tracked principal.

**Notes:**
- security: Implementations should restrict unauthorized callers.

- validation: Implementations should validate source state before harvesting.

- state-changes: Typically realizes yield and routes it to downstream distribution logic.

- events: Implementations should emit harvest/yield-routing events.

- errors: Reverts on invalid state or downstream integration failure.

- reentrancy: Implementations should enforce CEI/nonReentrant where needed.

- access: Access control is implementation-defined.

- oracle: No mandatory oracle dependency at interface level.


```solidity
function harvestYield() external returns (uint256 harvestedYield);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`harvestedYield`|`uint256`|Yield harvested in USDC (6 decimals).|


### totalUnderlying

Returns total underlying value currently controlled by the adapter.

View helper for exposure accounting (principal + accrued yield).

**Notes:**
- security: Read-only helper.

- validation: No input validation required.

- state-changes: No state changes.

- events: No events emitted.

- errors: Implementations may revert on unavailable downstream reads.

- reentrancy: Not applicable for view function.

- access: Public view.

- oracle: Oracle use is implementation-defined.


```solidity
function totalUnderlying() external view returns (uint256 underlyingBalance);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`underlyingBalance`|`uint256`|Underlying USDC-equivalent balance (6 decimals).|


