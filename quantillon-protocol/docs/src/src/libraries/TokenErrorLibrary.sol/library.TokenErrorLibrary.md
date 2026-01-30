# TokenErrorLibrary
**Title:**
TokenErrorLibrary

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

Token-specific errors for QEURO, QTI, and stQEURO tokens

Main characteristics:
- Errors specific to token operations
- Minting and burning errors
- Blacklist and whitelist errors
- Supply and cap management errors

**Note:**
security-contact: team@quantillon.money


## Errors
### MintingDisabled

```solidity
error MintingDisabled();
```

### BlacklistedAddress

```solidity
error BlacklistedAddress();
```

### CannotRecoverQEURO

```solidity
error CannotRecoverQEURO();
```

### CannotRecoverQTI

```solidity
error CannotRecoverQTI();
```

### NewCapBelowCurrentSupply

```solidity
error NewCapBelowCurrentSupply();
```

### LockNotExpired

```solidity
error LockNotExpired();
```

### NothingToUnlock

```solidity
error NothingToUnlock();
```

### RateLimitExceeded

```solidity
error RateLimitExceeded();
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

