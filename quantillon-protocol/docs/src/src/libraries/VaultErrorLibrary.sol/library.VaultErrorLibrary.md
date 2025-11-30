# VaultErrorLibrary
**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

Vault-specific errors for QuantillonVault and related operations

*Main characteristics:
- Errors specific to vault operations
- Collateralization and emergency mode errors
- Pool health and balance errors
- Yield distribution errors*

**Note:**
team@quantillon.money


## Errors
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

### CannotRecoverUSDC

```solidity
error CannotRecoverUSDC();
```

### CannotRecoverAToken

```solidity
error CannotRecoverAToken();
```

### CannotRecoverCriticalToken

```solidity
error CannotRecoverCriticalToken(string tokenName);
```

### AavePoolNotHealthy

```solidity
error AavePoolNotHealthy();
```

### WouldBreachMinimum

```solidity
error WouldBreachMinimum();
```

### FeeTooHigh

```solidity
error FeeTooHigh();
```

