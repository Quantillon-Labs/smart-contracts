# VaultCollateralLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/blob/083874330beb67c980851f48832ef5faa68973d3/src/libraries/VaultCollateralLibrary.sol)

Linked collateral helpers preserving loss-aware principal accounting.


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


### collateral

Sum external principal capped by each adapter's recoverable underlying.

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
function collateral(
    mapping(uint256 => IExternalStakingVault) storage adapters,
    mapping(uint256 => uint256) storage principal,
    uint256[] storage priority,
    uint256 defaultId
) external view returns (uint256 total);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`adapters`|`mapping(uint256 => IExternalStakingVault)`|Vault storage mapping from IDs to adapters.|
|`principal`|`mapping(uint256 => uint256)`|Vault storage mapping of tracked USDC principal.|
|`priority`|`uint256[]`|Configured redemption order in vault storage.|
|`defaultId`|`uint256`|Default vault used when no explicit redemption order exists.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`total`|`uint256`|Value defined by this accessor or calculation.|


### validateRouting

Require an enabled adapter belonging to the configured redemption set.

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
function validateRouting(
    mapping(uint256 => IExternalStakingVault) storage adapters,
    mapping(uint256 => bool) storage enabled,
    uint256[] storage priority,
    uint256 defaultId,
    uint256 id
) external view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`adapters`|`mapping(uint256 => IExternalStakingVault)`|Vault storage mapping from IDs to adapters.|
|`enabled`|`mapping(uint256 => bool)`|Enabled-vault mapping, or requested emergency state for the reference source.|
|`priority`|`uint256[]`|Configured redemption order in vault storage.|
|`defaultId`|`uint256`|Default vault used when no explicit redemption order exists.|
|`id`|`uint256`|External vault identifier.|


### inSet

Check whether an external vault belongs to the redemption set.

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
function inSet(uint256[] storage priority, uint256 defaultId, uint256 id) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`priority`|`uint256[]`|Configured redemption order in vault storage.|
|`defaultId`|`uint256`|Default vault used when no explicit redemption order exists.|
|`id`|`uint256`|External vault identifier.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Value defined by this accessor or calculation.|


### _inSet


```solidity
function _inSet(uint256[] storage priority, uint256 defaultId, uint256 id) private view returns (bool);
```

### _value


```solidity
function _value(IExternalStakingVault adapter, uint256 principal) private view returns (uint256);
```

### withdrawFees

Transfer only the vault token balance exceeding accounted collateral.

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
function withdrawFees(IERC20 token, address recipient, uint256 held) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`IERC20`|Token whose balances and transfers are checked.|
|`recipient`|`address`|Address receiving the output transfer.|
|`held`|`uint256`|Accounted collateral that cannot be withdrawn as fees.|
