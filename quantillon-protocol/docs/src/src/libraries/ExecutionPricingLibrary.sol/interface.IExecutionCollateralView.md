# IExecutionCollateralView
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/blob/4b0ba41d0f77c5b737916e7f78951237651c4bdb/quantillon-protocol/src/libraries/ExecutionPricingLibrary.sol)

Reference collateral read used by linked vault calculations.


## Functions
### getTotalUsdcAvailable

Read reference-accounted collateral available to the vault.

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
function getTotalUsdcAvailable() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|result Value returned by the read interface.|
