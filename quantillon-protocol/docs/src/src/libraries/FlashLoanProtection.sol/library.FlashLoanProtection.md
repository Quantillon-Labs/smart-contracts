# FlashLoanProtection
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/3822e8b8c39dab806b39c3963ee691f29eecba69/src/libraries/FlashLoanProtection.sol)

**Author:**
Quantillon Labs

Library for protecting contracts against flash loan attacks

*This library provides modifiers and functions to detect and prevent flash loan attacks
by monitoring balance changes during function execution.*

*Flash loan attacks can occur when:
- An attacker borrows a large amount of tokens
- Manipulates protocol state (e.g., governance votes, price oracles)
- Repays the loan in the same transaction
- Profits from the manipulated state*

*Protection mechanisms:
- Balance checks before and after function execution
- State validation to ensure no unexpected changes
- Rate limiting for sensitive operations
- Timestamp-based cooldowns for critical functions*

**Note:**
team@quantillon.money


## Functions
### flashLoanProtectionETH

Modifier to protect against flash loan attacks using ETH balance

*Checks that the contract's ETH balance doesn't decrease during execution*

*This prevents flash loans that would drain ETH from the contract*


```solidity
modifier flashLoanProtectionETH();
```

### flashLoanProtectionToken

Modifier to protect against flash loan attacks using token balance

*Checks that the contract's token balance doesn't decrease during execution*

*This prevents flash loans that would drain tokens from the contract*


```solidity
modifier flashLoanProtectionToken(address token);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Address of the token to monitor|


### flashLoanProtectionWithMinimum

Modifier to protect against flash loan attacks with custom validation

*Checks that the contract's token balance doesn't fall below minimum*

*This prevents flash loans that would reduce balance below safe threshold*


```solidity
modifier flashLoanProtectionWithMinimum(address token, uint256 minBalance);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Address of the token to monitor|
|`minBalance`|`uint256`|Minimum balance that must be maintained|


### flashLoanProtectionWithState

Modifier to protect against flash loan attacks with state validation

*Checks balance and validates state consistency*

*This prevents flash loans that manipulate protocol state*


```solidity
modifier flashLoanProtectionWithState(address token, function() internal view returns (bool) stateValidator);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Address of the token to monitor|
|`stateValidator`|`function () internal view returns (bool)`|Function to validate state consistency|


### validateBalanceChange

Validates that a balance change is within acceptable limits

*This function can be used for custom validation logic*


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


### validatePercentageChange

Validates that a percentage change is within acceptable limits

*This function can be used for custom validation logic*


```solidity
function validatePercentageChange(uint256 valueBefore, uint256 valueAfter, uint256 maxPercentageDecrease)
    internal
    pure
    returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`valueBefore`|`uint256`|Value before operation|
|`valueAfter`|`uint256`|Value after operation|
|`maxPercentageDecrease`|`uint256`|Maximum allowed percentage decrease (in basis points)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|bool True if percentage change is acceptable|


### detectFlashLoanAttack

Checks for potential flash loan attack patterns

*This function implements heuristic detection of flash loan attacks*


```solidity
function detectFlashLoanAttack(uint256 balanceBefore, uint256 balanceAfter, string memory operationType)
    internal
    pure
    returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`balanceBefore`|`uint256`|Balance before operation|
|`balanceAfter`|`uint256`|Balance after operation|
|`operationType`|`string`|Type of operation being performed|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|bool True if no flash loan attack detected|


### emitFlashLoanProtectionEvent

Emits flash loan protection event

*This function is used to log flash loan protection events*


```solidity
function emitFlashLoanProtectionEvent(
    address contractAddress,
    string memory functionName,
    uint256 balanceBefore,
    uint256 balanceAfter
) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`contractAddress`|`address`|Address of the contract|
|`functionName`|`string`|Name of the function|
|`balanceBefore`|`uint256`|Balance before operation|
|`balanceAfter`|`uint256`|Balance after operation|


### validateCooldown

Validates that a timestamp-based cooldown has passed

*This function prevents rapid successive calls that could be part of an attack*


```solidity
function validateCooldown(uint256 lastExecutionTime, uint256 cooldownPeriod) internal view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`lastExecutionTime`|`uint256`|Last time the function was executed|
|`cooldownPeriod`|`uint256`|Cooldown period in seconds|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|bool True if cooldown has passed|


### validateRateLimit

Validates that a rate limit hasn't been exceeded

*This function prevents rapid successive operations that could be part of an attack*


```solidity
function validateRateLimit(uint256 currentAmount, uint256 maxAmount) internal pure returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`currentAmount`|`uint256`|Current amount in the period|
|`maxAmount`|`uint256`|Maximum allowed amount in the period|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|bool True if rate limit hasn't been exceeded|


## Events
### FlashLoanProtectionTriggered
Emitted when flash loan protection is triggered


```solidity
event FlashLoanProtectionTriggered(
    address indexed contractAddress,
    string indexed functionName,
    uint256 balanceBefore,
    uint256 balanceAfter,
    uint256 timestamp
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`contractAddress`|`address`|Address of the contract where protection was triggered|
|`functionName`|`string`|Name of the function that triggered protection|
|`balanceBefore`|`uint256`|Balance before function execution|
|`balanceAfter`|`uint256`|Balance after function execution|
|`timestamp`|`uint256`|Timestamp when protection was triggered|

