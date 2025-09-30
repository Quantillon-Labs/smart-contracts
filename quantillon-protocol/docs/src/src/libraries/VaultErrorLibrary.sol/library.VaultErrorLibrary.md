# VaultErrorLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/8526548ebebe4cec60f21492516bc5894f11137e/src/libraries/VaultErrorLibrary.sol)

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

Vault-specific errors for QuantillonVault and related operations

*Main characteristics:
- Errors specific to vault operations
- Collateralization and emergency mode errors
- Pool health and balance errors
- Yield distribution errors*

**Note:**
security-contact: team@quantillon.money


## Errors
### TokenTransferFailed

```solidity
error TokenTransferFailed();
```

### InsufficientCollateralization

```solidity
error InsufficientCollateralization();
```

### EmergencyModeActive

```solidity
error EmergencyModeActive();
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

### InvalidOraclePrice

```solidity
error InvalidOraclePrice();
```

### AavePoolNotHealthy

```solidity
error AavePoolNotHealthy();
```

### WouldExceedLimit

```solidity
error WouldExceedLimit();
```

### InsufficientBalance

```solidity
error InsufficientBalance();
```

### WouldBreachMinimum

```solidity
error WouldBreachMinimum();
```

### InvalidAmount

```solidity
error InvalidAmount();
```

### InvalidAddress

```solidity
error InvalidAddress();
```

### BelowThreshold

```solidity
error BelowThreshold();
```

### FeeTooHigh

```solidity
error FeeTooHigh();
```

### InvalidThreshold

```solidity
error InvalidThreshold();
```

### NoETHToRecover

```solidity
error NoETHToRecover();
```

### ExcessiveSlippage

```solidity
error ExcessiveSlippage();
```

### ConfigValueTooHigh

```solidity
error ConfigValueTooHigh();
```

