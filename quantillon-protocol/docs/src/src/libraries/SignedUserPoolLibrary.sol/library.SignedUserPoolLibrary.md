# SignedUserPoolLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/blob/54366a1075ba6db39540a3d83709a310c26d1723/src/libraries/SignedUserPoolLibrary.sol)

Linked UserPool wrapper, preserving sender, existing guards and storage layout.


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


### execute

Dispatch the permitted operation while preserving the consumer's original caller.

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
function execute(address vault, bytes calldata callData, bytes calldata authorization)
    external
    returns (bytes memory result);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|Configured vault that owns execution authorization.|
|`callData`|`bytes`|Complete ABI-encoded operation, including route and output bounds.|
|`authorization`|`bytes`|ABI-encoded report or quote authorization required by this entrypoint.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`result`|`bytes`|ABI-encoded return data of the dispatched operation.|
