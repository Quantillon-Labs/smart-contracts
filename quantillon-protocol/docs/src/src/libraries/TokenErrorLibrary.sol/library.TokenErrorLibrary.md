# TokenErrorLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/blob/54366a1075ba6db39540a3d83709a310c26d1723/src/libraries/TokenErrorLibrary.sol)

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
