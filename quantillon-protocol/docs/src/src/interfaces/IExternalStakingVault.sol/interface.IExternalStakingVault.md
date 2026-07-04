# IExternalStakingVault
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/973bc7b9b5281df753b9c9569aff01d589239043/src/interfaces/IExternalStakingVault.sol)

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


### harvestYieldToVault

Harvests accrued yield and transfers it as USDC to the caller (the vault).

Routes the realized yield back to `msg.sender` (the vault) so the caller can apply the
protocol's own distribution policy (hedger/user/treasury split).
Realizes only the amount above tracked principal; principal is left untouched.

**Notes:**
- security: Implementations should restrict unauthorized callers.

- validation: Implementations should validate source state before harvesting.

- state-changes: Realizes yield and transfers USDC out to the caller; principal unchanged.

- events: Implementations should emit harvest/transfer events.

- errors: Reverts on invalid state or downstream integration failure.

- reentrancy: Implementations should enforce CEI/nonReentrant where needed.

- access: Access control is implementation-defined.

- oracle: No mandatory oracle dependency at interface level.


```solidity
function harvestYieldToVault() external returns (uint256 realizedYield);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`realizedYield`|`uint256`|Yield realized and transferred to the caller in USDC (6 decimals).|


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


