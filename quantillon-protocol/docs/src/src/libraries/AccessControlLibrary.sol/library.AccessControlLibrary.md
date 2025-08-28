# AccessControlLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/9eefa03bf794fa559e611658208a6e8b169d2d57/src/libraries/AccessControlLibrary.sol)

Access control functions for Quantillon Protocol

*Extracts role checking logic to reduce contract size*


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

