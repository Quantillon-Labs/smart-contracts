# AdminFunctionsLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/blob/6bcc4db60b18f8d613521e2d032b420a446221cb/src/libraries/AdminFunctionsLibrary.sol)

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

Library for rarely used admin functions to reduce contract size

*Main characteristics:
- Consolidates admin functions like recoverETH and recoverToken
- Reduces contract size by moving rarely used functions to library
- Maintains same API and behavior
- Uses custom errors for gas efficiency*

**Note:**
team@quantillon.money


## Functions
### recoverETH

Recover ETH to treasury address

*Emergency function to recover ETH sent to the contract*

**Notes:**
- Requires admin role

- None required

- Transfers ETH from contract to treasury

- Emits ETHRecovered event

- Throws NotAuthorized if caller lacks admin role

- Not protected - no external calls

- Restricted to admin role

- Not applicable


```solidity
function recoverETH(address contractInstance, address treasury, bytes32 adminRole) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`contractInstance`|`address`|The contract instance calling this function|
|`treasury`|`address`|The treasury address to send ETH to|
|`adminRole`|`bytes32`|The admin role required for this operation|


### recoverToken

Recover tokens to treasury address

*Emergency function to recover ERC20 tokens sent to the contract*

**Notes:**
- Requires admin role

- None required

- Transfers tokens from contract to treasury

- Emits TokenRecovered event

- Throws NotAuthorized if caller lacks admin role

- Not protected - library handles reentrancy

- Restricted to admin role

- Not applicable


```solidity
function recoverToken(address contractInstance, address token, uint256 amount, address treasury, bytes32 adminRole)
    external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`contractInstance`|`address`|The contract instance calling this function|
|`token`|`address`|Address of the token to recover|
|`amount`|`uint256`|Amount of tokens to recover|
|`treasury`|`address`|The treasury address to send tokens to|
|`adminRole`|`bytes32`|The admin role required for this operation|


## Events
### ETHRecovered
Event emitted when ETH is recovered


```solidity
event ETHRecovered(address indexed treasury, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`treasury`|`address`|The treasury address that received the ETH|
|`amount`|`uint256`|The amount of ETH recovered|

