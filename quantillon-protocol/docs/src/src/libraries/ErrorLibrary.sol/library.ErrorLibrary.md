# ErrorLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/07b6c9d21c3d2b99aa95cee2e6cc9c3f00f0009a/src/libraries/ErrorLibrary.sol)

**Author:**
Quantillon Labs

Custom errors for Quantillon Protocol

*Main characteristics:
- Comprehensive error definitions for all protocol operations
- Replaces require statements with custom errors to reduce gas costs
- Categorized errors for access control, validation, state, operations
- Supports governance, vault, yield, and liquidation operations*

**Note:**
security-contact: team@quantillon.money


## Errors
### NotAuthorized

```solidity
error NotAuthorized();
```

### NotGovernance

```solidity
error NotGovernance();
```

### NotVaultManager

```solidity
error NotVaultManager();
```

### NotEmergencyRole

```solidity
error NotEmergencyRole();
```

### NotLiquidatorRole

```solidity
error NotLiquidatorRole();
```

### NotYieldManager

```solidity
error NotYieldManager();
```

### NotAdmin

```solidity
error NotAdmin();
```

### InvalidAddress

```solidity
error InvalidAddress();
```

### ZeroAddress

```solidity
error ZeroAddress();
```

### InvalidTreasuryAddress

```solidity
error InvalidTreasuryAddress();
```

### InvalidAmount

```solidity
error InvalidAmount();
```

### InvalidParameter

```solidity
error InvalidParameter();
```

### InvalidLeverage

```solidity
error InvalidLeverage();
```

### InvalidMarginRatio

```solidity
error InvalidMarginRatio();
```

### InvalidThreshold

```solidity
error InvalidThreshold();
```

### InvalidFee

```solidity
error InvalidFee();
```

### InvalidRate

```solidity
error InvalidRate();
```

### InvalidRatio

```solidity
error InvalidRatio();
```

### InvalidTime

```solidity
error InvalidTime();
```

### InvalidPosition

```solidity
error InvalidPosition();
```

### InvalidHedger

```solidity
error InvalidHedger();
```

### InvalidCommitment

```solidity
error InvalidCommitment();
```

### AlreadyInitialized

```solidity
error AlreadyInitialized();
```

### NotInitialized

```solidity
error NotInitialized();
```

### AlreadyActive

```solidity
error AlreadyActive();
```

### NotActive

```solidity
error NotActive();
```

### AlreadyPaused

```solidity
error AlreadyPaused();
```

### NotPaused

```solidity
error NotPaused();
```

### EmergencyModeActive

```solidity
error EmergencyModeActive();
```

### PositionNotActive

```solidity
error PositionNotActive();
```

### InsufficientBalance

```solidity
error InsufficientBalance();
```

### InsufficientMargin

```solidity
error InsufficientMargin();
```

### InsufficientYield

```solidity
error InsufficientYield();
```

### InsufficientCollateral

```solidity
error InsufficientCollateral();
```

### ExcessiveSlippage

```solidity
error ExcessiveSlippage();
```

### BelowThreshold

```solidity
error BelowThreshold();
```

### AboveLimit

```solidity
error AboveLimit();
```

### WouldExceedLimit

```solidity
error WouldExceedLimit();
```

### WouldBreachMinimum

```solidity
error WouldBreachMinimum();
```

### NoChangeDetected

```solidity
error NoChangeDetected();
```

### DivisionByZero

```solidity
error DivisionByZero();
```

### MultiplicationOverflow

```solidity
error MultiplicationOverflow();
```

### PercentageTooHigh

```solidity
error PercentageTooHigh();
```

### InvalidYieldShift

```solidity
error InvalidYieldShift();
```

### InvalidShiftRange

```solidity
error InvalidShiftRange();
```

### AdjustmentSpeedTooHigh

```solidity
error AdjustmentSpeedTooHigh();
```

### TargetRatioTooHigh

```solidity
error TargetRatioTooHigh();
```

### HoldingPeriodNotMet

```solidity
error HoldingPeriodNotMet();
```

### LiquidationCooldown

```solidity
error LiquidationCooldown();
```

### PendingLiquidationCommitment

```solidity
error PendingLiquidationCommitment();
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

### InvalidOraclePrice

```solidity
error InvalidOraclePrice();
```

### AavePoolNotHealthy

```solidity
error AavePoolNotHealthy();
```

### ETHTransferFailed

```solidity
error ETHTransferFailed();
```

### TokenTransferFailed

```solidity
error TokenTransferFailed();
```

### CannotRecoverUSDC

```solidity
error CannotRecoverUSDC();
```

### CannotRecoverAToken

```solidity
error CannotRecoverAToken();
```

### CannotRecoverOwnToken

```solidity
error CannotRecoverOwnToken();
```

### CannotRecoverCriticalToken

```solidity
error CannotRecoverCriticalToken(string tokenName);
```

### CannotSendToZero

```solidity
error CannotSendToZero();
```

### NoETHToRecover

```solidity
error NoETHToRecover();
```

### NoTokensToRecover

```solidity
error NoTokensToRecover();
```

### TimeElapsedTooHigh

```solidity
error TimeElapsedTooHigh();
```

### InvalidTimestamp

```solidity
error InvalidTimestamp();
```

### FutureTimestamp

```solidity
error FutureTimestamp();
```

### ArrayLengthMismatch

```solidity
error ArrayLengthMismatch();
```

### IndexOutOfBounds

```solidity
error IndexOutOfBounds();
```

### EmptyArray

```solidity
error EmptyArray();
```

### BatchSizeTooLarge

```solidity
error BatchSizeTooLarge();
```

### PoolNotHealthy

```solidity
error PoolNotHealthy();
```

### PoolRatioInvalid

```solidity
error PoolRatioInvalid();
```

### PoolSizeZero

```solidity
error PoolSizeZero();
```

### PoolImbalance

```solidity
error PoolImbalance();
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

### YieldClaimFailed

```solidity
error YieldClaimFailed();
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

### MarginInsufficient

```solidity
error MarginInsufficient();
```

### MarginLimitExceeded

```solidity
error MarginLimitExceeded();
```

### TooManyPositions

```solidity
error TooManyPositions();
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

### PositionNotLiquidatable

```solidity
error PositionNotLiquidatable();
```

### InsufficientVotingPower

```solidity
error InsufficientVotingPower();
```

### VotingPeriodTooShort

```solidity
error VotingPeriodTooShort();
```

### VotingPeriodTooLong

```solidity
error VotingPeriodTooLong();
```

### ProposalNotFound

```solidity
error ProposalNotFound();
```

### ProposalAlreadyExecuted

```solidity
error ProposalAlreadyExecuted();
```

### ProposalAlreadyCanceled

```solidity
error ProposalAlreadyCanceled();
```

### VotingNotActive

```solidity
error VotingNotActive();
```

### AlreadyVoted

```solidity
error AlreadyVoted();
```

### QuorumNotMet

```solidity
error QuorumNotMet();
```

### ProposalThresholdNotMet

```solidity
error ProposalThresholdNotMet();
```

### RewardOverflow

```solidity
error RewardOverflow();
```

### RewardCalculationError

```solidity
error RewardCalculationError();
```

### RewardPeriodExpired

```solidity
error RewardPeriodExpired();
```

### RewardNotAvailable

```solidity
error RewardNotAvailable();
```

### HistoryTooLong

```solidity
error HistoryTooLong();
```

### InvalidHistoryIndex

```solidity
error InvalidHistoryIndex();
```

### HistoryNotAvailable

```solidity
error HistoryNotAvailable();
```

### TWAPCalculationError

```solidity
error TWAPCalculationError();
```

### TWAPPeriodInvalid

```solidity
error TWAPPeriodInvalid();
```

### TWAPDataInsufficient

```solidity
error TWAPDataInsufficient();
```

### ConfigInvalid

```solidity
error ConfigInvalid();
```

### ConfigNotSet

```solidity
error ConfigNotSet();
```

### ConfigUpdateFailed

```solidity
error ConfigUpdateFailed();
```

### ConfigValueTooHigh

```solidity
error ConfigValueTooHigh();
```

### ConfigValueTooLow

```solidity
error ConfigValueTooLow();
```

### InvalidDescription

```solidity
error InvalidDescription();
```

### ExpiredDeadline

```solidity
error ExpiredDeadline();
```

### InvalidRebalancing

```solidity
error InvalidRebalancing();
```

### RateLimitExceeded

```solidity
error RateLimitExceeded();
```

### BlacklistedAddress

```solidity
error BlacklistedAddress();
```

### NotWhitelisted

```solidity
error NotWhitelisted();
```

### RateLimitTooHigh

```solidity
error RateLimitTooHigh();
```

### AlreadyBlacklisted

```solidity
error AlreadyBlacklisted();
```

### NotBlacklisted

```solidity
error NotBlacklisted();
```

### AlreadyWhitelisted

```solidity
error AlreadyWhitelisted();
```

### PrecisionTooHigh

```solidity
error PrecisionTooHigh();
```

### TooManyDecimals

```solidity
error TooManyDecimals();
```

### CannotRecoverQEURO

```solidity
error CannotRecoverQEURO();
```

### NewCapBelowCurrentSupply

```solidity
error NewCapBelowCurrentSupply();
```

### LockTimeTooShort

```solidity
error LockTimeTooShort();
```

### LockTimeTooLong

```solidity
error LockTimeTooLong();
```

### LockNotExpired

```solidity
error LockNotExpired();
```

### NothingToUnlock

```solidity
error NothingToUnlock();
```

### VotingNotStarted

```solidity
error VotingNotStarted();
```

### VotingEnded

```solidity
error VotingEnded();
```

### NoVotingPower

```solidity
error NoVotingPower();
```

### VotingNotEnded

```solidity
error VotingNotEnded();
```

### ProposalFailed

```solidity
error ProposalFailed();
```

### ProposalExecutionFailed

```solidity
error ProposalExecutionFailed();
```

### CannotRecoverQTI

```solidity
error CannotRecoverQTI();
```

### ProposalCanceled

```solidity
error ProposalCanceled();
```

### ProposalAlreadyScheduled

```solidity
error ProposalAlreadyScheduled();
```

### ProposalNotScheduled

```solidity
error ProposalNotScheduled();
```

### InvalidExecutionHash

```solidity
error InvalidExecutionHash();
```

### ExecutionTimeNotReached

```solidity
error ExecutionTimeNotReached();
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

### TooManyPositionsPerTx

```solidity
error TooManyPositionsPerTx();
```

### MaxPositionsPerTx

```solidity
error MaxPositionsPerTx();
```

### NewMarginExceedsMaximum

```solidity
error NewMarginExceedsMaximum();
```

### PendingRewardsExceedMaximum

```solidity
error PendingRewardsExceedMaximum();
```

### FlashLoanAttackDetected

```solidity
error FlashLoanAttackDetected();
```

