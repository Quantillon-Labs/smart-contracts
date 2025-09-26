# CommonValidationLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/dd3e083d5d3a3d1f4c483da8f76db5c62d86f916/src/libraries/CommonValidationLibrary.sol)

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

Common validation functions used across multiple contracts

*Main characteristics:
- Consolidates common validation patterns
- Reduces code duplication across contracts
- Uses custom errors for gas efficiency
- Maintains same validation logic*

**Note:**
security-contact: team@quantillon.money


## Functions
### validateNonZeroAddress

Validates that an address is not zero


```solidity
function validateNonZeroAddress(address addr, string memory errorType) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`addr`|`address`|The address to validate|
|`errorType`|`string`|The type of address being validated|


### validatePositiveAmount

Validates that an amount is positive


```solidity
function validatePositiveAmount(uint256 amount) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount to validate|


### validateMinAmount

Validates that an amount is above minimum threshold


```solidity
function validateMinAmount(uint256 amount, uint256 minAmount) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount to validate|
|`minAmount`|`uint256`|The minimum required amount|


### validateMaxAmount

Validates that an amount is below maximum threshold


```solidity
function validateMaxAmount(uint256 amount, uint256 maxAmount) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount to validate|
|`maxAmount`|`uint256`|The maximum allowed amount|


### validatePercentage

Validates that a percentage is within valid range (0-100%)


```solidity
function validatePercentage(uint256 percentage, uint256 maxPercentage) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`percentage`|`uint256`|The percentage to validate (in basis points)|
|`maxPercentage`|`uint256`|The maximum allowed percentage (in basis points)|


### validateDuration

Validates that a duration is within valid range


```solidity
function validateDuration(uint256 duration, uint256 minDuration, uint256 maxDuration) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`duration`|`uint256`|The duration to validate|
|`minDuration`|`uint256`|The minimum allowed duration|
|`maxDuration`|`uint256`|The maximum allowed duration|


### validatePrice

Validates that a price is valid (greater than zero)


```solidity
function validatePrice(uint256 price) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`price`|`uint256`|The price to validate|


### validateCondition

Validates that a boolean condition is true


```solidity
function validateCondition(bool condition, string memory errorType) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`condition`|`bool`|The condition to validate|
|`errorType`|`string`|The type of error to throw if condition is false|


### validateCountLimit

Validates that a count is within limits


```solidity
function validateCountLimit(uint256 count, uint256 maxCount) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`count`|`uint256`|The current count|
|`maxCount`|`uint256`|The maximum allowed count|


### validateSufficientBalance

Validates that a balance is sufficient


```solidity
function validateSufficientBalance(uint256 balance, uint256 requiredAmount) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`balance`|`uint256`|The current balance|
|`requiredAmount`|`uint256`|The required amount|


