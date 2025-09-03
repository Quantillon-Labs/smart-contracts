# AccessControlLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/d412a0619acefb191468f4973a48348275c68bd9/src/libraries/AccessControlLibrary.sol)

**Author:**
Quantillon Labs

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


```solidity
function onlyGovernance(AccessControlUpgradeable accessControl) internal view;
```

### onlyVaultManager


```solidity
function onlyVaultManager(AccessControlUpgradeable accessControl) internal view;
```

### onlyEmergencyRole


```solidity
function onlyEmergencyRole(AccessControlUpgradeable accessControl) internal view;
```

### onlyLiquidatorRole


```solidity
function onlyLiquidatorRole(AccessControlUpgradeable accessControl) internal view;
```

### onlyYieldManager


```solidity
function onlyYieldManager(AccessControlUpgradeable accessControl) internal view;
```

### onlyAdmin


```solidity
function onlyAdmin(AccessControlUpgradeable accessControl) internal view;
```

### validateAddress


```solidity
function validateAddress(address addr) internal pure;
```

### validateAmount


```solidity
function validateAmount(uint256 amount) internal pure;
```

### validatePositiveAmount


```solidity
function validatePositiveAmount(uint256 amount) internal pure;
```

