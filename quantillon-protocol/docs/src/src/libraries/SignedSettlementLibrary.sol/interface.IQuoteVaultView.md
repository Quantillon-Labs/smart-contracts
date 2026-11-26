# IQuoteVaultView
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/blob/8d2039e2823d486678a185b0e5630b0a7677bddc/quantillon-protocol/src/libraries/SignedSettlementLibrary.sol)


## Functions
### signedExecutionEnabled

Read whether the vault requires signed settlement.

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
function signedExecutionEnabled() external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Value defined by this accessor or calculation.|


### userPool

Read the configured UserPool address.

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
function userPool() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|Value defined by this accessor or calculation.|


### executionPricing

Read the configured execution module address.

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
function executionPricing() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|Value defined by this accessor or calculation.|
