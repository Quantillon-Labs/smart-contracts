# HedgerPoolErrorLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/fdf5f8f6194f4b414785cf5d6e2e583cb790646c/src/libraries/HedgerPoolErrorLibrary.sol)

**Title:**
HedgerPoolErrorLibrary

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

HedgerPool-specific errors for Quantillon Protocol

Main characteristics:
- Errors specific to HedgerPool operations
- Trading position management errors
- Liquidation system errors
- Margin and leverage validation errors

**Note:**
security-contact: team@quantillon.money


## Constants
### VERSION
Library version (semver); see deployments/{chainId}/versions.json for provenance.


```solidity
string internal constant VERSION = "1.0.0"
```


## Errors
### FlashLoanAttackDetected

```solidity
error FlashLoanAttackDetected();
```

### InvalidPosition

```solidity
error InvalidPosition();
```

### InvalidHedger

```solidity
error InvalidHedger();
```

### OnlyVault

```solidity
error OnlyVault();
```

### RewardOverflow

```solidity
error RewardOverflow();
```

### InsufficientMargin

```solidity
error InsufficientMargin();
```

### MarginExceedsMaximum

```solidity
error MarginExceedsMaximum();
```

### PositionSizeExceedsMaximum

```solidity
error PositionSizeExceedsMaximum();
```

### EntryPriceExceedsMaximum

```solidity
error EntryPriceExceedsMaximum();
```

### LeverageExceedsMaximum

```solidity
error LeverageExceedsMaximum();
```

### TimestampOverflow

```solidity
error TimestampOverflow();
```

### TotalMarginExceedsMaximum

```solidity
error TotalMarginExceedsMaximum();
```

### TotalExposureExceedsMaximum

```solidity
error TotalExposureExceedsMaximum();
```

### NewMarginExceedsMaximum

```solidity
error NewMarginExceedsMaximum();
```

### InvalidLeverage

```solidity
error InvalidLeverage();
```

### LeverageTooHigh

```solidity
error LeverageTooHigh();
```

### MarginRatioTooLow

```solidity
error MarginRatioTooLow();
```

### MarginRatioTooHigh

```solidity
error MarginRatioTooHigh();
```

### PositionOwnerMismatch

```solidity
error PositionOwnerMismatch();
```

### PositionClosureRestricted

```solidity
error PositionClosureRestricted();
```

### InsufficientHedgerCapacity

```solidity
error InsufficientHedgerCapacity();
```

### NoActiveHedgerLiquidity

```solidity
error NoActiveHedgerLiquidity();
```

### HedgerHasActivePosition

```solidity
error HedgerHasActivePosition();
```

### MinHoldPeriodNotElapsed

```solidity
error MinHoldPeriodNotElapsed();
```

