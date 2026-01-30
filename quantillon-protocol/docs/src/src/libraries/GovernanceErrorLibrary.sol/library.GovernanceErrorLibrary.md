# GovernanceErrorLibrary
**Title:**
GovernanceErrorLibrary

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

Governance-specific errors for QTIToken governance system

Main characteristics:
- Errors specific to governance operations
- Voting and proposal management errors
- Timelock and execution errors
- MEV protection errors

**Note:**
security-contact: team@quantillon.money


## Errors
### InsufficientVotingPower

```solidity
error InsufficientVotingPower();
```

### ProposalNotFound

```solidity
error ProposalNotFound();
```

### VotingNotActive

```solidity
error VotingNotActive();
```

### ProposalThresholdNotMet

```solidity
error ProposalThresholdNotMet();
```

### ProposalExecutionFailed

```solidity
error ProposalExecutionFailed();
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

