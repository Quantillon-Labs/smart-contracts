# AccessControlLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/872c40203709a592ab12a8276b4170d2d29fd99f/src/libraries/AccessControlLibrary.sol)

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

**Notes:**
- security: Validates caller has GOVERNANCE_ROLE before allowing access

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: Throws NotGovernance if caller lacks required role

- reentrancy: Not applicable - view function

- access: Internal function - no access restrictions


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
- security: Validates caller has VAULT_MANAGER_ROLE before allowing access

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: Throws NotVaultManager if caller lacks required role

- reentrancy: Not applicable - view function

- access: Internal function - no access restrictions


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

**Notes:**
- security: Prevents zero address usage which could cause loss of funds

- validation: Validates addr != address(0)

- state-changes: No state changes - pure function

- events: No events emitted

- errors: Throws InvalidAddress if address is zero

- reentrancy: Not applicable - pure function

- access: Internal function - no access restrictions


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


