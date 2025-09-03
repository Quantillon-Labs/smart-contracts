# VaultLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/3822e8b8c39dab806b39c3963ee691f29eecba69/src/libraries/VaultLibrary.sol)

**Author:**
Quantillon Labs

Library for common vault operations to reduce contract bytecode size

*Main characteristics:
- Deposit and withdrawal validation functions
- Yield distribution and position validation
- Liquidation and emergency recovery validation
- Rebalancing and yield shift parameter validation*

**Note:**
team@quantillon.money


## Functions
### validateDeposit

Validates deposit parameters


```solidity
function validateDeposit(uint256 amount, address user) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Deposit amount|
|`user`|`address`|User address|


### validateWithdrawal

Validates withdrawal parameters


```solidity
function validateWithdrawal(uint256 amount, address user, uint256 balance) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Withdrawal amount|
|`user`|`address`|User address|
|`balance`|`uint256`|User balance|


### validateYieldDistribution

Validates yield distribution parameters


```solidity
function validateYieldDistribution(uint256 totalYield, uint256 yieldShiftBps) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`totalYield`|`uint256`|Total yield amount|
|`yieldShiftBps`|`uint256`|Yield shift in basis points|


### validatePosition

Validates position parameters


```solidity
function validatePosition(address hedger, uint256 amount, uint256 leverage, uint256 maxLeverage) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Hedger address|
|`amount`|`uint256`|Position amount|
|`leverage`|`uint256`|Leverage ratio|
|`maxLeverage`|`uint256`|Maximum leverage|


### validateLiquidation

Validates liquidation parameters


```solidity
function validateLiquidation(address position, address liquidator) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`position`|`address`|Position to liquidate|
|`liquidator`|`address`|Liquidator address|


### validateEmergencyRecovery

Validates emergency parameters


```solidity
function validateEmergencyRecovery(address admin, address token, uint256 amount) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|Admin address|
|`token`|`address`|Token address|
|`amount`|`uint256`|Amount to recover|


### validateRebalancing

Validates rebalancing parameters


```solidity
function validateRebalancing(address fromVault, address toVault, uint256 amount) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`fromVault`|`address`|Source vault|
|`toVault`|`address`|Target vault|
|`amount`|`uint256`|Rebalancing amount|


### validateYieldShift

Validates yield shift parameters


```solidity
function validateYieldShift(uint256 newYieldShiftBps, uint256 holdingPeriod) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newYieldShiftBps`|`uint256`|New yield shift in basis points|
|`holdingPeriod`|`uint256`|Required holding period|


