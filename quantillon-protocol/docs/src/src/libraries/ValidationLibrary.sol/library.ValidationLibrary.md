# ValidationLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/3822e8b8c39dab806b39c3963ee691f29eecba69/src/libraries/ValidationLibrary.sol)

**Author:**
Quantillon Labs

Validation functions for Quantillon Protocol

*Main characteristics:
- Comprehensive parameter validation for leverage, margin, fees, and rates
- Time-based validation for holding periods and liquidation cooldowns
- Balance and exposure validation functions
- Array and position validation utilities*

**Note:**
team@quantillon.money


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

### validateRate


```solidity
function validateRate(uint256 rate, uint256 maxRate) internal pure;
```

### validateThreshold


```solidity
function validateThreshold(uint256 threshold, uint256 maxThreshold) internal pure;
```

### validateRatio


```solidity
function validateRatio(uint256 ratio, uint256 maxRatio) internal pure;
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

### validateHoldingPeriod


```solidity
function validateHoldingPeriod(uint256 depositTime, uint256 minPeriod) internal view;
```

### validateLiquidationCooldown


```solidity
function validateLiquidationCooldown(uint256 lastAttempt, uint256 cooldown) internal view;
```

### validateBalance


```solidity
function validateBalance(uint256 balance, uint256 required) internal pure;
```

### validateExposure


```solidity
function validateExposure(uint256 current, uint256 max) internal pure;
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

### validateCommitment


```solidity
function validateCommitment(bool exists) internal pure;
```

### validateCommitmentNotExists


```solidity
function validateCommitmentNotExists(bool exists) internal pure;
```

### validateOraclePrice


```solidity
function validateOraclePrice(bool isValid) internal pure;
```

### validateAaveHealth


```solidity
function validateAaveHealth(bool isHealthy) internal pure;
```

### validateTimeElapsed


```solidity
function validateTimeElapsed(uint256 elapsed, uint256 max) internal pure;
```

### validateArrayLength


```solidity
function validateArrayLength(uint256 length, uint256 expected) internal pure;
```

### validateArrayNotEmpty


```solidity
function validateArrayNotEmpty(uint256 length) internal pure;
```

### validateIndex


```solidity
function validateIndex(uint256 index, uint256 length) internal pure;
```

