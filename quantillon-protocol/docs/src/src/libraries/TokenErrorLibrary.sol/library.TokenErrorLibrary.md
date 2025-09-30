# TokenErrorLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/d4ff9dd61a04d59de40a8b136ac832356918d46a/src/libraries/TokenErrorLibrary.sol)

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

Token-specific errors for QEURO, QTI, and stQEURO tokens

*Main characteristics:
- Errors specific to token operations
- Minting and burning errors
- Blacklist and whitelist errors
- Supply and cap management errors*

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

### NotWhitelisted

```solidity
error NotWhitelisted();
```

### WouldExceedLimit

```solidity
error WouldExceedLimit();
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

### InsufficientBalance

```solidity
error InsufficientBalance();
```

### InvalidAmount

```solidity
error InvalidAmount();
```

### InvalidTime

```solidity
error InvalidTime();
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

### InvalidAddress

```solidity
error InvalidAddress();
```

### TokenTransferFailed

```solidity
error TokenTransferFailed();
```

### ArrayLengthMismatch

```solidity
error ArrayLengthMismatch();
```

### BatchSizeTooLarge

```solidity
error BatchSizeTooLarge();
```

### RateLimitTooHigh

```solidity
error RateLimitTooHigh();
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

### VotingNotStarted

```solidity
error VotingNotStarted();
```

### VotingEnded

```solidity
error VotingEnded();
```

### AlreadyVoted

```solidity
error AlreadyVoted();
```

### NoVotingPower

```solidity
error NoVotingPower();
```

### VotingNotEnded

```solidity
error VotingNotEnded();
```

### ProposalAlreadyExecuted

```solidity
error ProposalAlreadyExecuted();
```

### ProposalCanceled

```solidity
error ProposalCanceled();
```

### ProposalFailed

```solidity
error ProposalFailed();
```

### QuorumNotMet

```solidity
error QuorumNotMet();
```

### NotAuthorized

```solidity
error NotAuthorized();
```

### ProposalAlreadyCanceled

```solidity
error ProposalAlreadyCanceled();
```

### ZeroAddress

```solidity
error ZeroAddress();
```

### CannotRecoverOwnToken

```solidity
error CannotRecoverOwnToken();
```

### NoETHToRecover

```solidity
error NoETHToRecover();
```

### InvalidAdmin

```solidity
error InvalidAdmin();
```

### InvalidToken

```solidity
error InvalidToken();
```

### InvalidTreasury

```solidity
error InvalidTreasury();
```

### AboveLimit

```solidity
error AboveLimit();
```

