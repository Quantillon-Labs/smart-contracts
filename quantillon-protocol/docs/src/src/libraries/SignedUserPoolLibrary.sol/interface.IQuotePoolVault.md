# IQuotePoolVault
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/blob/54366a1075ba6db39540a3d83709a310c26d1723/src/libraries/SignedUserPoolLibrary.sol)


## Functions
### preparePoolQuote

Begin an atomic pool route bound to its original user and complete calldata.

Invoked through the consumer; delegatecall retains its storage and original sender.

**Notes:**
- security: Consumer permissions and accounting checks remain in force.

- validation: Applies the selected operation's bounds; failures revert the entire call.

- state-changes: Updates the calling consumer and downstream contracts as described above.

- events: None.

- errors: Reverts on invalid inputs, permissions or failed downstream calls.

- reentrancy: The consuming operation retains its existing reentrancy guards.

- access: Consumer entrypoint permissions; this helper grants no additional authority.

- oracle: Uses the consumer's configured reference and execution paths where the operation requires pricing.


```solidity
function preparePoolQuote(address user, bytes calldata callData, bytes calldata authorization) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Original payer whose nonce and settlement are bound.|
|`callData`|`bytes`|Complete ABI-encoded operation, including route and output bounds.|
|`authorization`|`bytes`|ABI-encoded report or quote authorization required by this entrypoint.|


### finishPoolQuote

Finish the atomic pool route after its conversion has been consumed.

Invoked through the consumer; delegatecall retains its storage and original sender.

**Notes:**
- security: Consumer permissions and accounting checks remain in force.

- validation: Applies the selected operation's bounds; failures revert the entire call.

- state-changes: Updates the calling consumer and downstream contracts as described above.

- events: None.

- errors: Reverts on invalid inputs, permissions or failed downstream calls.

- reentrancy: The consuming operation retains its existing reentrancy guards.

- access: Consumer entrypoint permissions; this helper grants no additional authority.

- oracle: Uses the consumer's configured reference and execution paths where the operation requires pricing.


```solidity
function finishPoolQuote() external;
```
