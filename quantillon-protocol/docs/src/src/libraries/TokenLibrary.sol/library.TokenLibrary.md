# TokenLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/bbddbedca72271d4260ea804101124f3dc71302c/src/libraries/TokenLibrary.sol)

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

Library for essential token operations to reduce contract bytecode size

*This library provides core token validation functions:
- Mint and burn parameter validation with supply cap checks
- Used by QEURO token for secure minting and burning operations*

**Note:**
team@quantillon.money


## Functions
### validateMint

Validates mint parameters

*Ensures minting doesn't exceed maximum supply and validates parameters*

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
function validateMint(address to, uint256 amount, uint256 totalSupply, uint256 maxSupply) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|Address to mint to|
|`amount`|`uint256`|Amount to mint|
|`totalSupply`|`uint256`|Current total supply|
|`maxSupply`|`uint256`|Maximum supply cap|


### validateBurn

Validates burn parameters

*Ensures sufficient balance and validates parameters for burning*

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
function validateBurn(address from, uint256 amount, uint256 balance) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`address`|Address to burn from|
|`amount`|`uint256`|Amount to burn|
|`balance`|`uint256`|Current balance|


