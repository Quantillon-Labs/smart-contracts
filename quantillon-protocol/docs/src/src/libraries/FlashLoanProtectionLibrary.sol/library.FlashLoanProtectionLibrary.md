# FlashLoanProtectionLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/d7c48fdd1629827b7afa681d6fa8df870ef46184/src/libraries/FlashLoanProtectionLibrary.sol)

**Author:**
Quantillon Labs

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


