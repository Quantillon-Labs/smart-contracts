# TokenLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/d7c48fdd1629827b7afa681d6fa8df870ef46184/src/libraries/TokenLibrary.sol)

**Author:**
Quantillon Labs

Library for essential token operations to reduce contract bytecode size

*This library provides core token validation functions:
- Mint and burn parameter validation with supply cap checks
- Used by QEURO token for secure minting and burning operations*

**Note:**
security-contact: team@quantillon.money


## Functions
### validateMint

Validates mint parameters

*Ensures minting doesn't exceed maximum supply and validates parameters*


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


```solidity
function validateBurn(address from, uint256 amount, uint256 balance) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`address`|Address to burn from|
|`amount`|`uint256`|Amount to burn|
|`balance`|`uint256`|Current balance|


