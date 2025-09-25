# IPool
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/131c9dca87217f75290610df1bfcdddc851f5dc0/src/core/vaults/AaveVault.sol)

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

**Note:**
security-contact: team@quantillon.money


## Functions
### supply

Supply assets to Aave protocol

*Supplies assets to Aave protocol on behalf of a user*

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
function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|Address of the asset to supply|
|`amount`|`uint256`|Amount of assets to supply|
|`onBehalfOf`|`address`|Address to supply on behalf of|
|`referralCode`|`uint16`|Referral code for Aave protocol|


### withdraw

Withdraw assets from Aave protocol

*Withdraws assets from Aave protocol to a specified address*

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
function withdraw(address asset, uint256 amount, address to) external returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|Address of the asset to withdraw|
|`amount`|`uint256`|Amount of assets to withdraw|
|`to`|`address`|Address to withdraw to|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 Amount of assets withdrawn|


### getReserveData

Get reserve data for an asset

*Returns reserve data for a specific asset in Aave protocol*

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
function getReserveData(address asset) external view returns (ReserveData memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|Address of the asset|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`ReserveData`|ReserveData Reserve data structure|


