# CommonErrorLibrary
**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

Common errors used across multiple contracts in Quantillon Protocol

*Main characteristics:
- Most frequently used errors across all contracts
- Reduces contract size by importing only needed errors
- Replaces require statements with custom errors for gas efficiency
- Used by 15+ contracts*

**Note:**
security-contact: team@quantillon.money


## Errors
### InvalidAmount

```solidity
error InvalidAmount();
```

### ZeroAddress

```solidity
error ZeroAddress();
```

### InvalidAddress

```solidity
error InvalidAddress();
```

### InsufficientBalance

```solidity
error InsufficientBalance();
```

### NotAuthorized

```solidity
error NotAuthorized();
```

### ArrayLengthMismatch

```solidity
error ArrayLengthMismatch();
```

### BatchSizeTooLarge

```solidity
error BatchSizeTooLarge();
```

### EmptyArray

```solidity
error EmptyArray();
```

### InvalidTime

```solidity
error InvalidTime();
```

### AboveLimit

```solidity
error AboveLimit();
```

### WouldExceedLimit

```solidity
error WouldExceedLimit();
```

### ExcessiveSlippage

```solidity
error ExcessiveSlippage();
```

### ConfigValueTooHigh

```solidity
error ConfigValueTooHigh();
```

### ConfigValueTooLow

```solidity
error ConfigValueTooLow();
```

### ConfigInvalid

```solidity
error ConfigInvalid();
```

### NotAdmin

```solidity
error NotAdmin();
```

### InvalidAdmin

```solidity
error InvalidAdmin();
```

### InvalidTreasury

```solidity
error InvalidTreasury();
```

### InvalidToken

```solidity
error InvalidToken();
```

### InvalidOracle

```solidity
error InvalidOracle();
```

### InvalidVault

```solidity
error InvalidVault();
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

### BelowThreshold

```solidity
error BelowThreshold();
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

### InvalidParameter

```solidity
error InvalidParameter();
```

### InvalidCondition

```solidity
error InvalidCondition();
```

### ETHTransferFailed

```solidity
error ETHTransferFailed();
```

### TokenTransferFailed

```solidity
error TokenTransferFailed();
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

### CannotRecoverOwnToken

```solidity
error CannotRecoverOwnToken();
```

### EmergencyModeActive

```solidity
error EmergencyModeActive();
```

### HoldingPeriodNotMet

```solidity
error HoldingPeriodNotMet();
```

### InvalidPrice

```solidity
error InvalidPrice();
```

### InsufficientCollateralization

```solidity
error InsufficientCollateralization();
```

### TooManyPositions

```solidity
error TooManyPositions();
```

### PositionNotActive

```solidity
error PositionNotActive();
```

### LiquidationCooldown

```solidity
error LiquidationCooldown();
```

### InvalidYieldShift

```solidity
error InvalidYieldShift();
```

### AdjustmentSpeedTooHigh

```solidity
error AdjustmentSpeedTooHigh();
```

### TargetRatioTooHigh

```solidity
error TargetRatioTooHigh();
```

### InvalidRatio

```solidity
error InvalidRatio();
```

### NotGovernance

```solidity
error NotGovernance();
```

### NotEmergency

```solidity
error NotEmergency();
```

### NotEmergencyRole

```solidity
error NotEmergencyRole();
```

### NotLiquidator

```solidity
error NotLiquidator();
```

### NotLiquidatorRole

```solidity
error NotLiquidatorRole();
```

### NotHedger

```solidity
error NotHedger();
```

### NotVaultManager

```solidity
error NotVaultManager();
```

### NotYieldManager

```solidity
error NotYieldManager();
```

### InsufficientYield

```solidity
error InsufficientYield();
```

### InvalidShiftRange

```solidity
error InvalidShiftRange();
```

