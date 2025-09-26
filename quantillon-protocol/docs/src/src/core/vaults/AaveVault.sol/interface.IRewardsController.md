# IRewardsController
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/e9c5d3b52c0c2fb1a1c72e3e33cbf9fa6d077fa8/src/core/vaults/AaveVault.sol)


## Functions
### claimRewards

Claim rewards from Aave protocol

*Claims rewards for specified assets and amount*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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


