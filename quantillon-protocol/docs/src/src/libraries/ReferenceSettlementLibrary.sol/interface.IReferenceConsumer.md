# IReferenceConsumer
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/blob/083874330beb67c980851f48832ef5faa68973d3/src/libraries/ReferenceSettlementLibrary.sol)

Resolve the reference from the consumer's governed oracle binding.


## Functions
### oracle

Read the consumer's governed oracle address.

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
function oracle() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|Value defined by this accessor or calculation.|
