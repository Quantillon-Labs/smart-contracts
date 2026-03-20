# IExternalStakingVault
**Title:**
IExternalStakingVault

Generic adapter interface for third-party staking/yield vaults.

QuantillonVault interacts with all external yield sources through this surface.


## Functions
### depositUnderlying

Deposits underlying USDC into the external vault.


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


```solidity
function harvestYield() external returns (uint256 harvestedYield);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`harvestedYield`|`uint256`|Yield harvested in USDC (6 decimals).|


### totalUnderlying

Returns total underlying value currently controlled by the adapter.


```solidity
function totalUnderlying() external view returns (uint256 underlyingBalance);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`underlyingBalance`|`uint256`|Underlying USDC-equivalent balance (6 decimals).|


