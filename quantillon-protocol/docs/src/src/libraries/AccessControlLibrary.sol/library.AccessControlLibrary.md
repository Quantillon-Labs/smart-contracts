# AccessControlLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/e6d6ab67e05d161d0d4815c50b5213a2a6cbb873/src/libraries/AccessControlLibrary.sol)

**Title:**
AccessControlLibrary

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

Access control functions for Quantillon Protocol

Main characteristics:
- Role-based access control validation functions
- Address and amount validation utilities
- Reduces contract bytecode size through library extraction
- Provides standardized error handling for access control

**Note:**
security-contact: team@quantillon.money


## Constants
### VERSION
Library version (semver); see deployments/{chainId}/versions.json for provenance.


```solidity
string internal constant VERSION = "1.0.0"
```


## Functions
### onlyGovernance

Ensures the caller has governance role

Reverts with NotGovernance if caller lacks GOVERNANCE_ROLE

**Notes:**
- security: Validates caller has GOVERNANCE_ROLE before allowing access

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: Throws NotGovernance if caller lacks required role

- reentrancy: Not applicable - view function

- access: Internal function - no access restrictions

- oracle: No oracle dependencies


```solidity
function onlyGovernance(AccessControlUpgradeable accessControl) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`accessControl`|`AccessControlUpgradeable`|The access control contract to check roles against|


### onlyEmergencyRole

Ensures the caller has emergency role

Reverts with NotEmergencyRole if caller lacks EMERGENCY_ROLE

**Notes:**
- security: Validates caller has EMERGENCY_ROLE before allowing access

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: Throws NotEmergencyRole if caller lacks required role

- reentrancy: Not applicable - view function

- access: Internal function - no access restrictions

- oracle: No oracle dependencies


```solidity
function onlyEmergencyRole(AccessControlUpgradeable accessControl) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`accessControl`|`AccessControlUpgradeable`|The access control contract to check roles against|


### onlyYieldManager

Ensures the caller has yield manager role

Reverts with NotYieldManager if caller lacks YIELD_MANAGER_ROLE

**Notes:**
- security: Validates caller has YIELD_MANAGER_ROLE before allowing access

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: Throws NotYieldManager if caller lacks required role

- reentrancy: Not applicable - view function

- access: Internal function - no access restrictions

- oracle: No oracle dependencies


```solidity
function onlyYieldManager(AccessControlUpgradeable accessControl) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`accessControl`|`AccessControlUpgradeable`|The access control contract to check roles against|


### onlyAdmin

Ensures the caller has admin role

Reverts with NotAdmin if caller lacks DEFAULT_ADMIN_ROLE

**Notes:**
- security: Validates caller has DEFAULT_ADMIN_ROLE before allowing access

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: Throws NotAdmin if caller lacks required role

- reentrancy: Not applicable - view function

- access: Internal function - no access restrictions

- oracle: No oracle dependencies


```solidity
function onlyAdmin(AccessControlUpgradeable accessControl) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`accessControl`|`AccessControlUpgradeable`|The access control contract to check roles against|


### validateAddress

Validates that an address is not the zero address

Reverts with InvalidAddress if address is zero

**Notes:**
- security: Prevents zero address usage which could cause loss of funds

- validation: Validates addr != address(0)

- state-changes: No state changes - pure function

- events: No events emitted

- errors: Throws InvalidAddress if address is zero

- reentrancy: Not applicable - pure function

- access: Internal function - no access restrictions

- oracle: No oracle dependencies


```solidity
function validateAddress(address addr) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`addr`|`address`|The address to validate|


