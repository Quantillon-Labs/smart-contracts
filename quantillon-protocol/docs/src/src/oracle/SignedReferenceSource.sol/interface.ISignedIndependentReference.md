# ISignedIndependentReference
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/blob/54366a1075ba6db39540a3d83709a310c26d1723/src/oracle/SignedReferenceSource.sol)

Independent reference source that never substitutes cached data for an invalid round.


## Functions
### peekEurUsdPrice

Read an independent reference, its original observation time and validity.

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
function peekEurUsdPrice() external view returns (uint256, uint256, bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Value defined by this accessor or calculation.|
|`<none>`|`uint256`|Value defined by this accessor or calculation.|
|`<none>`|`bool`|Value defined by this accessor or calculation.|
