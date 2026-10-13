# IReferenceRouter
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/blob/083874330beb67c980851f48832ef5faa68973d3/src/libraries/ReferenceSettlementLibrary.sol)

Router reference bindings, independent of execution quotes.


## Functions
### activeOracle

Read the router's active oracle slot.

Returns the declared configuration or derived value without updating state.

**Notes:**
- security: Read-only; does not authorize settlement.

- validation: Uses the declared input types; target interface calls may revert.

- state-changes: None.

- events: None.

- errors: Propagates invalid input or target read failures.

- reentrancy: Read-only.

- access: Public.

- oracle: No fresh observation is created; reference getters expose existing source data.


```solidity
function activeOracle() external view returns (uint8);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint8`|Value defined by this accessor or calculation.|


### marketOracle

Read the router's market-oracle address.

Returns the declared configuration or derived value without updating state.

**Notes:**
- security: Read-only; does not authorize settlement.

- validation: Uses the declared input types; target interface calls may revert.

- state-changes: None.

- events: None.

- errors: Propagates invalid input or target read failures.

- reentrancy: Read-only.

- access: Public.

- oracle: No fresh observation is created; reference getters expose existing source data.


```solidity
function marketOracle() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|Value defined by this accessor or calculation.|
