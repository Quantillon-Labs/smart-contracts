# IExecutionPricing
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/blob/083874330beb67c980851f48832ef5faa68973d3/src/interfaces/IExecutionPricing.sol)

**Title:**
IExecutionPricing

Volume-dependent execution pricing and admission for a single vault.


## Functions
### vault

Vault authorized to consume quoted liquidity.

Uses the documented units and preserves reference-price accounting.

**Notes:**
- security: Uses explicit contract access boundaries and checked arithmetic.

- validation: Validates the documented preconditions; view interface reads delegate to the target contract.

- state-changes: None.

- events: None.

- errors: Propagates invalid input, freshness, capacity or downstream contract errors as applicable.

- reentrancy: No state changes.

- access: Public read access.

- oracle: Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.


```solidity
function vault() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|result Calculated result in the units described by this operation.|


### outstanding

Total admitted EUR exposure awaiting acknowledgment, in 18 decimals.

Uses the documented units and preserves reference-price accounting.

**Notes:**
- security: Uses explicit contract access boundaries and checked arithmetic.

- validation: Validates the documented preconditions; view interface reads delegate to the target contract.

- state-changes: None.

- events: None.

- errors: Propagates invalid input, freshness, capacity or downstream contract errors as applicable.

- reentrancy: No state changes.

- access: Public read access.

- oracle: Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.


```solidity
function outstanding() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|result Calculated result in the units described by this operation.|


### consumeMint

Consume buy liquidity for net USDC input (6 decimals).

Uses the documented units and preserves reference-price accounting.

**Notes:**
- security: Uses explicit contract access boundaries and checked arithmetic.

- validation: Validates the documented preconditions; view interface reads delegate to the target contract.

- state-changes: Updates consumed liquidity counters.

- events: LiquidityConsumed.

- errors: Propagates invalid input, freshness, capacity or downstream contract errors as applicable.

- reentrancy: Vault settlement is nonReentrant; publisher and reporter methods have no external state-changing callbacks.

- access: Configured vault only.

- oracle: Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.


```solidity
function consumeMint(uint256 netUsdc, uint256 referencePrice)
    external
    returns (uint256 qeuroOut, uint256 backingUsdc);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`netUsdc`|`uint256`|Input after protocol fees.|
|`referencePrice`|`uint256`|Reference USD per EUR in 18 decimals.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`qeuroOut`|`uint256`|Minted quantity in 18 decimals.|
|`backingUsdc`|`uint256`|Reference-valued backing in 6 decimals.|


### consumeRedeem

Consume sell liquidity for QEURO input (18 decimals).

Uses the documented units and preserves reference-price accounting.

**Notes:**
- security: Uses explicit contract access boundaries and checked arithmetic.

- validation: Validates the documented preconditions; view interface reads delegate to the target contract.

- state-changes: Updates consumed liquidity counters.

- events: LiquidityConsumed.

- errors: Propagates invalid input, freshness, capacity or downstream contract errors as applicable.

- reentrancy: Vault settlement is nonReentrant; publisher and reporter methods have no external state-changing callbacks.

- access: Configured vault only.

- oracle: Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.


```solidity
function consumeRedeem(uint256 qeuroIn, uint256 referencePrice) external returns (uint256 executionUsdc);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`qeuroIn`|`uint256`|Quantity redeemed.|
|`referencePrice`|`uint256`|Reference USD per EUR in 18 decimals.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`executionUsdc`|`uint256`|Payout before protocol fees, in 6 decimals.|
