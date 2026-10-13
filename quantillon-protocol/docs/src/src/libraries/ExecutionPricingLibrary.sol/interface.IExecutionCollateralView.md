# IExecutionCollateralView
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/blob/083874330beb67c980851f48832ef5faa68973d3/src/libraries/ExecutionPricingLibrary.sol)

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
