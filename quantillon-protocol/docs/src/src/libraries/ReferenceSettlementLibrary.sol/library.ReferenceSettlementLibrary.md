# ReferenceSettlementLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/blob/083874330beb67c980851f48832ef5faa68973d3/src/libraries/ReferenceSettlementLibrary.sol)

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


### removeMarginWithReference

Deliver a reference and withdraw margin with explicit permissionable parameters.

Keeps calldata construction in the linked library to respect the consumer's EIP-170 limit.

**Notes:**
- security: Retains the consumer's owner, pause and collateral checks.

- validation: Report and withdrawal are validated atomically.

- state-changes: Reference and margin accounting, or none on revert.

- events: Underlying reference and margin events.

- errors: Propagates reference and margin errors.

- reentrancy: Underlying withdrawal guard remains active.

- access: Original hedger permissions.

- oracle: Uses the governed reference source.


```solidity
function removeMarginWithReference(uint256 positionId, uint256 amount, bytes calldata authorization)
    external
    returns (bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`positionId`|`uint256`|Position owned by the original caller.|
|`amount`|`uint256`|USDC margin to withdraw.|
|`authorization`|`bytes`|Signed valuation report.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|ABI-encoded result of the underlying withdrawal (empty on success).|


### _execute


```solidity
function _execute(bytes memory callData, bytes calldata authorization) private returns (bytes memory result);
```
