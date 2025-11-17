# HedgerPoolErrorLibrary
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


## Errors
### FlashLoanAttackDetected

```solidity
error FlashLoanAttackDetected();
```

### NotWhitelisted

```solidity
error NotWhitelisted();
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

### YieldClaimFailed

```solidity
error YieldClaimFailed();
```

### InvalidHedger

```solidity
error InvalidHedger();
```

### TooManyPositions

```solidity
error TooManyPositions();
```

### MaxPositionsPerTx

```solidity
error MaxPositionsPerTx();
```

### NotPaused

```solidity
error NotPaused();
```

### ZeroAddress

```solidity
error ZeroAddress();
```

### InvalidAmount

```solidity
error InvalidAmount();
```

### ConfigValueTooLow

```solidity
error ConfigValueTooLow();
```

### ConfigInvalid

```solidity
error ConfigInvalid();
```

### ConfigValueTooHigh

```solidity
error ConfigValueTooHigh();
```

### AlreadyWhitelisted

```solidity
error AlreadyWhitelisted();
```

### InvalidOraclePrice

```solidity
error InvalidOraclePrice();
```

### InvalidAddress

```solidity
error InvalidAddress();
```

### NotAuthorized

```solidity
error NotAuthorized();
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

### CannotRecoverOwnToken

```solidity
error CannotRecoverOwnToken();
```

### NoETHToRecover

```solidity
error NoETHToRecover();
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

### PositionNotActive

```solidity
error PositionNotActive();
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

### LiquidationCooldown

```solidity
error LiquidationCooldown();
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

### FeeTooHigh

```solidity
error FeeTooHigh();
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

### YieldBelowThreshold

```solidity
error YieldBelowThreshold();
```

### YieldNotAvailable

```solidity
error YieldNotAvailable();
```

### YieldDistributionFailed

```solidity
error YieldDistributionFailed();
```

### YieldCalculationError

```solidity
error YieldCalculationError();
```

### InsufficientYield

```solidity
error InsufficientYield();
```

### HoldingPeriodNotMet

```solidity
error HoldingPeriodNotMet();
```

