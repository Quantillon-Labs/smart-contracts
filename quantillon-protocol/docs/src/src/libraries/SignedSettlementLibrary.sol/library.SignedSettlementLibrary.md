# SignedSettlementLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/blob/083874330beb67c980851f48832ef5faa68973d3/src/libraries/SignedSettlementLibrary.sol)

**Title:**
SignedSettlementLibrary

Linked entrypoint that keeps signature decoding outside the size-constrained vault.

Delegatecall retains the original payer and the existing guarded settlement functions.


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


### executeWithQuote

Dispatch one signed operation with the original caller and existing accounting.

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
function executeWithQuote(bytes calldata callData, bytes calldata authorization)
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


### preparePoolQuote

Begin an atomic pool route bound to its original user and complete calldata.

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

- events: Underlying operation and token events when applicable.

- errors: Reverts on invalid inputs, permissions or failed downstream calls.

- reentrancy: The consuming operation retains its existing reentrancy guards.

- access: Consumer entrypoint permissions; this helper grants no additional authority.

- oracle: Uses the consumer's configured reference and execution paths where the operation requires pricing.


```solidity
function finishPoolQuote() external;
```

### emergencyRedeemQEURO

Run the governed budgeted emergency redemption path.

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
function emergencyRedeemQEURO(uint256 amount, uint256 minimum) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Amount in the token units of the selected operation.|
|`minimum`|`uint256`|Minimum acceptable output in the output token's raw units.|


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
function execute(address module, bytes calldata callData, bytes calldata authorization)
    external
    returns (bytes memory result);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`module`|`address`|Execution module already bound by the calling vault.|
|`callData`|`bytes`|Complete ABI-encoded operation, including route and output bounds.|
|`authorization`|`bytes`|ABI-encoded report or quote authorization required by this entrypoint.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`result`|`bytes`|ABI-encoded return data of the dispatched operation.|


### _execute


```solidity
function _execute(address module, bytes calldata callData, bytes calldata authorization)
    private
    returns (bytes memory result);
```

### _preparePool


```solidity
function _preparePool(address module, address user, bytes calldata callData, bytes calldata authorization) private;
```

### emergencyRedeem

Run the vault redemption with a bounded emergency context.

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
function emergencyRedeem(address module, uint256 amount, uint256 minimum) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`module`|`address`|Execution module already bound by the calling vault.|
|`amount`|`uint256`|Amount in the token units of the selected operation.|
|`minimum`|`uint256`|Minimum acceptable output in the output token's raw units.|


### _emergencyRedeem


```solidity
function _emergencyRedeem(address module, uint256 amount, uint256 minimum) private;
```

### _finishPool


```solidity
function _finishPool(address module) private;
```

### stake

Deposit newly minted QEURO and enforce the actual minimum share output.

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
function stake(address token, address shares, uint256 amount, uint256 minimum) external returns (uint256 minted);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Token whose balances and transfers are checked.|
|`shares`|`address`|stQEURO share token receiving the deposit.|
|`amount`|`uint256`|Amount in the token units of the selected operation.|
|`minimum`|`uint256`|Minimum acceptable output in the output token's raw units.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`minted`|`uint256`|Value defined by this accessor or calculation.|


### _dispatch


```solidity
function _dispatch(bytes memory callData) private returns (bytes memory result);
```
