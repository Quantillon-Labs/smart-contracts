# VaultYieldSettlementLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/blob/083874330beb67c980851f48832ef5faa68973d3/src/libraries/VaultYieldSettlementLibrary.sol)

Linked yield validation and token interactions, retaining principal and share accounting.


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


### prepare

Validate staking recipients, reference pricing and projected yield collateralization.

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
function prepare(uint256 id, uint256 amount, uint256 cached, uint256 lastBlock) external returns (Credit memory c);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`id`|`uint256`|External vault identifier.|
|`amount`|`uint256`|Amount in the token units of the selected operation.|
|`cached`|`uint256`|Previous cached EUR/USD reference in 1e18 precision.|
|`lastBlock`|`uint256`|Block of the previous reference-cache update.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`c`|`Credit`|Validated staking-yield credit.|


### prepareMint

Validate reference price, eligibility, output and projected mint collateralization.

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
function prepareMint(uint256 amount, uint256 minimum, uint256 cached, uint256 lastBlock)
    external
    returns (Mint memory m);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Amount in the token units of the selected operation.|
|`minimum`|`uint256`|Minimum acceptable output in the output token's raw units.|
|`cached`|`uint256`|Previous cached EUR/USD reference in 1e18 precision.|
|`lastBlock`|`uint256`|Block of the previous reference-cache update.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`m`|`Mint`|Validated mint fee, backing, output and reference price.|


### commit

Synchronize hedger accounting and mint the validated yield credit to stQEURO.

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
function commit(uint256 amount, Credit memory c) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Amount in the token units of the selected operation.|
|`c`|`Credit`|Validated yield credit with output, backing, price and recipient.|


## Structs
### Credit

```solidity
struct Credit {
    uint256 quantity;
    uint256 backing;
    uint256 price;
    address recipient;
}
```

### Mint

```solidity
struct Mint {
    uint256 fee;
    uint256 backing;
    uint256 quantity;
    uint256 price;
}
```
