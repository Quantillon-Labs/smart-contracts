# VaultErrorLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/0c6311949cabadbce9e79a7dafc6269035f6039e/src/libraries/VaultErrorLibrary.sol)

**Title:**
VaultErrorLibrary

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

Vault-specific errors for QuantillonVault and related operations

Main characteristics:
- Errors specific to vault operations
- Collateralization and emergency mode errors
- Pool health and balance errors
- Yield distribution errors

**Note:**
security-contact: team@quantillon.money


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

