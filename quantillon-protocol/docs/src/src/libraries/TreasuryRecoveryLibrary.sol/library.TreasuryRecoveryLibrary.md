# TreasuryRecoveryLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/fc7270ac08cee183372c8ec5c5113dda66dad52e/src/libraries/TreasuryRecoveryLibrary.sol)

**Author:**
Quantillon Protocol Team

Library for secure ETH recovery to treasury addresses

*This library factorizes the recoverETH functionality used across all contracts
to save gas, reduce bytecode, and ensure consistent security implementation*

**Note:**
team@quantillon.money


## Functions
### recoverETHToTreasury

Recover ETH to treasury address only

*SECURITY: Restricted to treasury to prevent arbitrary ETH transfers*

*Gas optimization: Uses library function to avoid code duplication*

*Security: Prevents arbitrary ETH transfers that could be exploited*

*Error handling: Uses custom errors for gas efficiency*


```solidity
function recoverETHToTreasury(address treasury, address payable to) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`treasury`|`address`|The contract's treasury address|
|`to`|`address payable`|Recipient address (must match treasury)|


### validateTreasury

Validate treasury address

*Ensures treasury address is not zero address*


```solidity
function validateTreasury(address treasury) external pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`treasury`|`address`|Address to validate|


### updateTreasury

Update treasury address with validation

*Only callable by governance/admin roles*


```solidity
function updateTreasury(address currentTreasury, address newTreasury) external pure returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`currentTreasury`|`address`|Current treasury address|
|`newTreasury`|`address`|New treasury address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|Updated treasury address|


