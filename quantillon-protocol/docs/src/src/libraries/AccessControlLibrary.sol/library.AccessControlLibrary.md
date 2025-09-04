# AccessControlLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/8586bf0c799c78a35c463b66cf8c6beb85e48666/src/libraries/AccessControlLibrary.sol)

**Author:**
Quantillon Labs

Access control functions for Quantillon Protocol

*Main characteristics:
- Role-based access control validation functions
- Address and amount validation utilities
- Reduces contract bytecode size through library extraction
- Provides standardized error handling for access control*

**Note:**
security-contact: team@quantillon.money


## Functions
### onlyGovernance

Ensures the caller has governance role

*Reverts with NotGovernance if caller lacks GOVERNANCE_ROLE*


```solidity
function onlyGovernance(AccessControlUpgradeable accessControl) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`accessControl`|`AccessControlUpgradeable`|The access control contract to check roles against|


### onlyVaultManager

Ensures the caller has vault manager role

*Reverts with NotVaultManager if caller lacks VAULT_MANAGER_ROLE*


```solidity
function onlyVaultManager(AccessControlUpgradeable accessControl) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`accessControl`|`AccessControlUpgradeable`|The access control contract to check roles against|


### onlyEmergencyRole

Ensures the caller has emergency role

*Reverts with NotEmergencyRole if caller lacks EMERGENCY_ROLE*


```solidity
function onlyEmergencyRole(AccessControlUpgradeable accessControl) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`accessControl`|`AccessControlUpgradeable`|The access control contract to check roles against|


### onlyLiquidatorRole

Ensures the caller has liquidator role

*Reverts with NotLiquidatorRole if caller lacks LIQUIDATOR_ROLE*


```solidity
function onlyLiquidatorRole(AccessControlUpgradeable accessControl) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`accessControl`|`AccessControlUpgradeable`|The access control contract to check roles against|


### onlyYieldManager

Ensures the caller has yield manager role

*Reverts with NotYieldManager if caller lacks YIELD_MANAGER_ROLE*


```solidity
function onlyYieldManager(AccessControlUpgradeable accessControl) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`accessControl`|`AccessControlUpgradeable`|The access control contract to check roles against|


### onlyAdmin

Ensures the caller has admin role

*Reverts with NotAdmin if caller lacks DEFAULT_ADMIN_ROLE*


```solidity
function onlyAdmin(AccessControlUpgradeable accessControl) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`accessControl`|`AccessControlUpgradeable`|The access control contract to check roles against|


### validateAddress

Validates that an address is not the zero address

*Reverts with InvalidAddress if address is zero*


```solidity
function validateAddress(address addr) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`addr`|`address`|The address to validate|


### validateAmount

Validates that an amount is not zero

*Reverts with InvalidAmount if amount is zero*


```solidity
function validateAmount(uint256 amount) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount to validate|


### validatePositiveAmount

Validates that an amount is positive (> 0)

*Reverts with InvalidAmount if amount is zero or negative*


```solidity
function validatePositiveAmount(uint256 amount) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount to validate|


