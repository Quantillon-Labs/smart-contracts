# GovernanceErrorLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/8526548ebebe4cec60f21492516bc5894f11137e/src/libraries/GovernanceErrorLibrary.sol)

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

Governance-specific errors for QTIToken governance system

*Main characteristics:
- Errors specific to governance operations
- Voting and proposal management errors
- Timelock and execution errors
- MEV protection errors*

**Note:**
security-contact: team@quantillon.money


## Errors
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

### RateLimitTooHigh

```solidity
error RateLimitTooHigh();
```

### InvalidAmount

```solidity
error InvalidAmount();
```

### InvalidTime

```solidity
error InvalidTime();
```

### LockTimeTooShort

```solidity
error LockTimeTooShort();
```

### LockTimeTooLong

```solidity
error LockTimeTooLong();
```

