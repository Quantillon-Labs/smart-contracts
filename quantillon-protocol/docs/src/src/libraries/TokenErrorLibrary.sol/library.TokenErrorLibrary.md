# TokenErrorLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/blob/8d2039e2823d486678a185b0e5630b0a7677bddc/quantillon-protocol/src/libraries/TokenErrorLibrary.sol)

**Title:**
TokenErrorLibrary

Token-specific errors for QEURO, QTI, and stQEURO tokens

Main characteristics:
- Errors specific to token operations
- Minting and burning errors
- Blacklist and whitelist errors
- Supply and cap management errors

**Note:**
security-contact: team@quantillon.money


## Constants
### VERSION
Library version (semver); see deployments/{chainId}/versions.json for provenance.


```solidity
string internal constant VERSION = "1.0.0"
```


## Errors
### MintingDisabled

```solidity
error MintingDisabled();
```

### BlacklistedAddress

```solidity
error BlacklistedAddress();
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
