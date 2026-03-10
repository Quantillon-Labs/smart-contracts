# AdminFunctionsLibrary
**Title:**
AdminFunctionsLibrary

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

Library for rarely used admin functions to reduce contract size

Main characteristics:
- Consolidates admin functions like recoverToken
- Reduces contract size by moving rarely used functions to library
- Maintains same API and behavior
- Uses custom errors for gas efficiency

**Note:**
security-contact: team@quantillon.money


## Functions
### recoverToken

Recover tokens to treasury address

Emergency function to recover ERC20 tokens sent to the contract

**Notes:**
- security: Requires admin role

- validation: None required

- state-changes: Transfers tokens from contract to treasury

- events: Emits TokenRecovered event

- errors: Throws NotAuthorized if caller lacks admin role

- reentrancy: Not protected - library handles reentrancy

- access: Restricted to admin role

- oracle: Not applicable


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


