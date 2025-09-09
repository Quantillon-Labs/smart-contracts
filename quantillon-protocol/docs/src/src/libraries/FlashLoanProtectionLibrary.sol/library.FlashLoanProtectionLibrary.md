# FlashLoanProtectionLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/5f58ae9c97abfaa14690edd65751159b391dbc7c/src/libraries/FlashLoanProtectionLibrary.sol)

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

Library for protecting contracts against flash loan attacks

*This library provides functions to detect and prevent flash loan attacks
by monitoring balance changes during function execution.*

*Flash loan attacks can occur when:
- An attacker borrows a large amount of tokens
- Manipulates protocol state (e.g., governance votes, price oracles)
- Repays the loan in the same transaction
- Profits from the manipulated state*

*Protection mechanism:
- Balance checks before and after function execution
- Validation that balances don't decrease unexpectedly*

**Note:**
security-contact: team@quantillon.money


## Functions
### validateBalanceChange

Validates that a balance change is within acceptable limits

*This function validates that balances don't decrease beyond acceptable limits.
Currently used by all contract modifiers to prevent flash loan attacks.
A maxDecrease of 0 means no decrease is allowed (strict protection).*

**Notes:**
- security: Prevents flash loan attacks by validating balance changes

- validation: Validates balance changes are within acceptable limits

- state-changes: No state changes - pure function

- events: No events emitted

- errors: No custom errors thrown

- reentrancy: Not applicable - pure function

- access: Internal function - no access restrictions

- oracle: No oracle dependencies


```solidity
function validateBalanceChange(uint256 balanceBefore, uint256 balanceAfter, uint256 maxDecrease)
    internal
    pure
    returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`balanceBefore`|`uint256`|Balance before operation|
|`balanceAfter`|`uint256`|Balance after operation|
|`maxDecrease`|`uint256`|Maximum allowed decrease in balance|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|bool True if balance change is acceptable|


