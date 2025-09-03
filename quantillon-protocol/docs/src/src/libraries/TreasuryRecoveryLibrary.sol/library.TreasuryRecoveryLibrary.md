# TreasuryRecoveryLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/d412a0619acefb191468f4973a48348275c68bd9/src/libraries/TreasuryRecoveryLibrary.sol)

**Author:**
Quantillon Protocol Team

Library for secure token and ETH recovery to treasury addresses

*This library factorizes the recoverToken and recoverETH functionality used across all contracts
to save gas, reduce bytecode, and ensure consistent security implementation*

**Note:**
team@quantillon.money


## Functions
### recoverToken

Recover tokens accidentally sent to the contract to treasury only

*SECURITY: Prevents recovery of own tokens and sends only to treasury*

*Gas optimization: Uses library function to avoid code duplication*

*Security: Prevents recovery of own tokens and ensures treasury-only recovery*

*Error handling: Uses custom errors for gas efficiency*


```solidity
function recoverToken(address token, uint256 amount, address contractAddress, address treasury) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Token address to recover|
|`amount`|`uint256`|Amount to recover|
|`contractAddress`|`address`|Address of the calling contract (for own token check)|
|`treasury`|`address`|Treasury address to send recovered tokens to|


### recoverETH

Recover ETH to treasury address only

*SECURITY: Restricted to treasury to prevent arbitrary ETH transfers*

*Gas optimization: Uses library function to avoid code duplication*

*Security: Prevents arbitrary ETH transfers that could be exploited*

*Error handling: Uses custom errors for gas efficiency*


```solidity
function recoverETH(address treasury, address payable to) external;
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


