# AccessControlLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/f178a58601862e43db9a3df30d13d692e003e51c/src/libraries/AccessControlLibrary.sol)

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

Access control functions for Quantillon Protocol

*Main characteristics:
- Role-based access control validation functions
- Address and amount validation utilities
- Reduces contract bytecode size through library extraction
- Provides standardized error handling for access control*

**Note:**
team@quantillon.money


## Functions
### onlyGovernance

Ensures the caller has governance role

*Reverts with NotGovernance if caller lacks GOVERNANCE_ROLE*

**Notes:**
- Validates caller has GOVERNANCE_ROLE before allowing access

- No input validation required - view function

- No state changes - view function only

- No events emitted

- Throws NotGovernance if caller lacks required role

- Not applicable - view function

- Internal function - no access restrictions

- No oracle dependencies


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

**Notes:**
- Validates caller has VAULT_MANAGER_ROLE before allowing access

- No input validation required - view function

- No state changes - view function only

- No events emitted

- Throws NotVaultManager if caller lacks required role

- Not applicable - view function

- Internal function - no access restrictions

- No oracle dependencies


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

**Notes:**
- Validates caller has EMERGENCY_ROLE before allowing access

- No input validation required - view function

- No state changes - view function only

- No events emitted

- Throws NotEmergencyRole if caller lacks required role

- Not applicable - view function

- Internal function - no access restrictions

- No oracle dependencies


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

**Notes:**
- Validates caller has LIQUIDATOR_ROLE before allowing access

- No input validation required - view function

- No state changes - view function only

- No events emitted

- Throws NotLiquidatorRole if caller lacks required role

- Not applicable - view function

- Internal function - no access restrictions

- No oracle dependencies


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

**Notes:**
- Validates caller has YIELD_MANAGER_ROLE before allowing access

- No input validation required - view function

- No state changes - view function only

- No events emitted

- Throws NotYieldManager if caller lacks required role

- Not applicable - view function

- Internal function - no access restrictions

- No oracle dependencies


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

**Notes:**
- Validates caller has DEFAULT_ADMIN_ROLE before allowing access

- No input validation required - view function

- No state changes - view function only

- No events emitted

- Throws NotAdmin if caller lacks required role

- Not applicable - view function

- Internal function - no access restrictions

- No oracle dependencies


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

**Notes:**
- Prevents zero address usage which could cause loss of funds

- Validates addr != address(0)

- No state changes - pure function

- No events emitted

- Throws InvalidAddress if address is zero

- Not applicable - pure function

- Internal function - no access restrictions

- No oracle dependencies


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

**Notes:**
- Prevents zero amount operations which could cause unexpected behavior

- Validates amount > 0

- No state changes - pure function

- No events emitted

- Throws InvalidAmount if amount is zero

- Not applicable - pure function

- Internal function - no access restrictions

- No oracle dependencies


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

**Notes:**
- Prevents zero or negative amount operations which could cause unexpected behavior

- Validates amount > 0

- No state changes - pure function

- No events emitted

- Throws InvalidAmount if amount is zero or negative

- Not applicable - pure function

- Internal function - no access restrictions

- No oracle dependencies


```solidity
function validatePositiveAmount(uint256 amount) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount to validate|


