# TokenLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/996f4133ba7998f0eb28738b06e228de221fcf63/src/libraries/TokenLibrary.sol)

**Author:**
Quantillon Labs

Library for common token operations to reduce contract bytecode size

*Main characteristics:
- Token transfer, mint, and burn validation functions
- Permit and delegation parameter validation
- Governance proposal and voting parameter validation
- Reduces duplication across QEURO, QTI, and stQEURO token contracts*

**Note:**
team@quantillon.money


## Functions
### validateTransfer

Validates token transfer parameters


```solidity
function validateTransfer(address from, address to, uint256 amount) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`address`|Address to transfer from|
|`to`|`address`|Address to transfer to|
|`amount`|`uint256`|Amount to transfer|


### validateMint

Validates mint parameters


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


```solidity
function validateBurn(address from, uint256 amount, uint256 balance) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`address`|Address to burn from|
|`amount`|`uint256`|Amount to burn|
|`balance`|`uint256`|Current balance|


### validatePermit

Validates permit parameters


```solidity
function validatePermit(address owner, address spender, uint256 value, uint256 deadline) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`owner`|`address`|Token owner|
|`spender`|`address`|Spender address|
|`value`|`uint256`|Permit value|
|`deadline`|`uint256`|Permit deadline|


### validateDelegation

Validates delegation parameters


```solidity
function validateDelegation(address delegator, address delegatee) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`delegator`|`address`|Delegator address|
|`delegatee`|`address`|Delegatee address|


### validateVote

Validates voting parameters


```solidity
function validateVote(uint256 proposalId, bool support) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`proposalId`|`uint256`|Proposal ID|
|`support`|`bool`|Support value|


### validateProposal

Validates proposal parameters


```solidity
function validateProposal(string memory description, uint256 votingPeriod, uint256 minPeriod, uint256 maxPeriod)
    internal
    pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`description`|`string`|Proposal description|
|`votingPeriod`|`uint256`|Voting period|
|`minPeriod`|`uint256`|Minimum voting period|
|`maxPeriod`|`uint256`|Maximum voting period|


