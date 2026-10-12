# VaultTransferLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/blob/54366a1075ba6db39540a3d83709a310c26d1723/src/libraries/VaultTransferLibrary.sol)

Linked token interactions after the vault has persisted its accounting effects.


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


### mint

Receive USDC, route fees and spread, mint QEURO and deploy selected backing.

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
function mint(
    address payer,
    address recipient,
    uint256 input,
    uint256 fee,
    uint256 backing,
    uint256 output,
    uint256 route
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`payer`|`address`|Address from which input tokens are collected.|
|`recipient`|`address`|Address receiving the output transfer.|
|`input`|`uint256`|Gross input amount in input-token raw units.|
|`fee`|`uint256`|Protocol fee in six-decimal USDC units.|
|`backing`|`uint256`|Reference-valued collateral in six-decimal USDC units.|
|`output`|`uint256`|Validated output amount in output-token raw units.|
|`route`|`uint256`|External vault ID, or zero for liquid collateral.|


### redeem

Burn QEURO and pay the user, fees and execution spread.

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
function redeem(address recipient, uint256 input, uint256 backing, uint256 output, uint256 fee) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`recipient`|`address`|Address receiving the output transfer.|
|`input`|`uint256`|Gross input amount in input-token raw units.|
|`backing`|`uint256`|Reference-valued collateral in six-decimal USDC units.|
|`output`|`uint256`|Validated output amount in output-token raw units.|
|`fee`|`uint256`|Protocol fee in six-decimal USDC units.|


### _fees


```solidity
function _fees(ITransferVault v, IERC20 token, uint256 fee, string memory source) private;
```

### deploy

Deposit backing into the configured external adapter.

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
function deploy(uint256 id, uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`id`|`uint256`|External vault identifier.|
|`amount`|`uint256`|Amount in the token units of the selected operation.|


### _deploy


```solidity
function _deploy(ITransferVault v, IERC20 token, uint256 id, uint256 amount) private;
```

## Events
### UsdcDeployedToExternalVault

```solidity
event UsdcDeployedToExternalVault(uint256 indexed vaultId, uint256 indexed usdcAmount, uint256 principalAfter);
```
