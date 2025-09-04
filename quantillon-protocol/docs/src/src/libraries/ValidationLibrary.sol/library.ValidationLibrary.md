# ValidationLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/d7c48fdd1629827b7afa681d6fa8df870ef46184/src/libraries/ValidationLibrary.sol)

**Author:**
Quantillon Labs

Validation functions for Quantillon Protocol

*Main characteristics:
- Comprehensive parameter validation for leverage, margin, fees, and rates
- Time-based validation for holding periods and liquidation cooldowns
- Balance and exposure validation functions
- Array and position validation utilities*

**Note:**
security-contact: team@quantillon.money


## Functions
### validateLeverage


```solidity
function validateLeverage(uint256 leverage, uint256 maxLeverage) internal pure;
```

### validateMarginRatio


```solidity
function validateMarginRatio(uint256 marginRatio, uint256 minRatio) internal pure;
```

### validateFee


```solidity
function validateFee(uint256 fee, uint256 maxFee) internal pure;
```

### validateThreshold


```solidity
function validateThreshold(uint256 threshold, uint256 maxThreshold) internal pure;
```

### validatePositiveAmount


```solidity
function validatePositiveAmount(uint256 amount) internal pure;
```

### validateYieldShift


```solidity
function validateYieldShift(uint256 shift) internal pure;
```

### validateAdjustmentSpeed


```solidity
function validateAdjustmentSpeed(uint256 speed, uint256 maxSpeed) internal pure;
```

### validateTargetRatio


```solidity
function validateTargetRatio(uint256 ratio, uint256 maxRatio) internal pure;
```

### validateLiquidationCooldown


```solidity
function validateLiquidationCooldown(uint256 lastAttempt, uint256 cooldown) internal view;
```

### validateSlippage


```solidity
function validateSlippage(uint256 received, uint256 expected, uint256 tolerance) internal pure;
```

### validateThresholdValue


```solidity
function validateThresholdValue(uint256 value, uint256 threshold) internal pure;
```

### validatePositionActive


```solidity
function validatePositionActive(bool isActive) internal pure;
```

### validatePositionOwner


```solidity
function validatePositionOwner(address owner, address caller) internal pure;
```

### validatePositionCount


```solidity
function validatePositionCount(uint256 count, uint256 max) internal pure;
```

### validateCommitmentNotExists


```solidity
function validateCommitmentNotExists(bool exists) internal pure;
```

### validateCommitment


```solidity
function validateCommitment(bool exists) internal pure;
```

### validateOraclePrice


```solidity
function validateOraclePrice(bool isValid) internal pure;
```

