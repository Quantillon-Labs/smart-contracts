# IRewardsController
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/d4ff9dd61a04d59de40a8b136ac832356918d46a/src/core/vaults/AaveVault.sol)


## Functions
### claimRewards

Claim rewards from Aave protocol

*Claims rewards for specified assets and amount*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function claimRewards(address[] calldata assets, uint256 amount, address to) external returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`assets`|`address[]`|Array of asset addresses|
|`amount`|`uint256`|Amount of rewards to claim|
|`to`|`address`|Address to send rewards to|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 Amount of rewards claimed|


### getUserRewards

Get user rewards for specified assets

*Returns the rewards for a user across specified assets*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function getUserRewards(address[] calldata assets, address user) external view returns (uint256[] memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`assets`|`address[]`|Array of asset addresses|
|`user`|`address`|Address of the user|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256[]`|uint256[] Array of reward amounts for each asset|


