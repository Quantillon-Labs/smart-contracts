# HedgerPoolErrorLibrary
**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

HedgerPool-specific errors for Quantillon Protocol

*Main characteristics:
- Errors specific to HedgerPool operations
- Trading position management errors
- Liquidation system errors
- Margin and leverage validation errors*

**Note:**
team@quantillon.money


## Errors
### FlashLoanAttackDetected

```solidity
error FlashLoanAttackDetected();
```

### PendingLiquidationCommitment

```solidity
error PendingLiquidationCommitment();
```

### InvalidPosition

```solidity
error InvalidPosition();
```

### PositionNotLiquidatable

```solidity
error PositionNotLiquidatable();
```

### InvalidHedger

```solidity
error InvalidHedger();
```

### MaxPositionsPerTx

```solidity
error MaxPositionsPerTx();
```

### AlreadyWhitelisted

```solidity
error AlreadyWhitelisted();
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

### PendingRewardsExceedMaximum

```solidity
error PendingRewardsExceedMaximum();
```

### InvalidLeverage

```solidity
error InvalidLeverage();
```

### LeverageTooHigh

```solidity
error LeverageTooHigh();
```

### LeverageTooLow

```solidity
error LeverageTooLow();
```

### MaxLeverageExceeded

```solidity
error MaxLeverageExceeded();
```

### MarginTooLow

```solidity
error MarginTooLow();
```

### MarginRatioTooLow

```solidity
error MarginRatioTooLow();
```

### MarginRatioTooHigh

```solidity
error MarginRatioTooHigh();
```

### MarginInsufficient

```solidity
error MarginInsufficient();
```

### MarginLimitExceeded

```solidity
error MarginLimitExceeded();
```

### PositionNotFound

```solidity
error PositionNotFound();
```

### PositionOwnerMismatch

```solidity
error PositionOwnerMismatch();
```

### PositionAlreadyClosed

```solidity
error PositionAlreadyClosed();
```

### PositionClosureRestricted

```solidity
error PositionClosureRestricted();
```

### PositionHasActiveFill

```solidity
error PositionHasActiveFill();
```

### InsufficientHedgerCapacity

```solidity
error InsufficientHedgerCapacity();
```

### NoActiveHedgerLiquidity

```solidity
error NoActiveHedgerLiquidity();
```

### LiquidationNotAllowed

```solidity
error LiquidationNotAllowed();
```

### LiquidationRewardTooHigh

```solidity
error LiquidationRewardTooHigh();
```

### LiquidationPenaltyTooHigh

```solidity
error LiquidationPenaltyTooHigh();
```

### LiquidationThresholdInvalid

```solidity
error LiquidationThresholdInvalid();
```

### NoValidCommitment

```solidity
error NoValidCommitment();
```

### CommitmentAlreadyExists

```solidity
error CommitmentAlreadyExists();
```

### CommitmentDoesNotExist

```solidity
error CommitmentDoesNotExist();
```

### EntryFeeTooHigh

```solidity
error EntryFeeTooHigh();
```

### ExitFeeTooHigh

```solidity
error ExitFeeTooHigh();
```

### MarginFeeTooHigh

```solidity
error MarginFeeTooHigh();
```

### YieldFeeTooHigh

```solidity
error YieldFeeTooHigh();
```

