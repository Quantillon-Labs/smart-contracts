# ReferenceSettlementLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/blob/54366a1075ba6db39540a3d83709a310c26d1723/src/libraries/ReferenceSettlementLibrary.sol)

**Title:**
ReferenceSettlementLibrary

Carry a signed valuation report with a hedger operation without changing its caller.

Linked delegatecall preserves Safe, hedger ownership, role and existing reentrancy checks.


## Functions
### version

Return the semantic version of this implementation.

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
function version() external pure returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|Value defined by this accessor or calculation.|


### executeWithReference

Deliver a signed reference and execute one permitted hedger operation atomically.

Invoked through the consumer; delegatecall retains its storage and original sender.

**Notes:**
- security: Consumer permissions and accounting checks remain in force.

- validation: Applies the selected operation's bounds; failures revert the entire call.

- state-changes: Updates the calling consumer and downstream contracts as described above.

- events: Underlying operation and token events when applicable.

- errors: Reverts on invalid inputs, permissions or failed downstream calls.

- reentrancy: The consuming operation retains its existing reentrancy guards.

- access: Consumer entrypoint permissions; this helper grants no additional authority.

- oracle: Uses the consumer's configured reference and execution paths where the operation requires pricing.


```solidity
function executeWithReference(bytes calldata callData, bytes calldata authorization)
    external
    returns (bytes memory result);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`callData`|`bytes`|Complete ABI-encoded operation, including route and output bounds.|
|`authorization`|`bytes`|ABI-encoded report or quote authorization required by this entrypoint.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`result`|`bytes`|ABI-encoded return data of the dispatched operation.|
