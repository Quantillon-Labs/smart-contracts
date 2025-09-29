# CommonValidationLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/71cd41fc9aa7c18638af4654e656fb0dc6b6d493/src/libraries/CommonValidationLibrary.sol)

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

Common validation functions used across multiple contracts

*Main characteristics:
- Consolidates common validation patterns
- Reduces code duplication across contracts
- Uses custom errors for gas efficiency
- Maintains same validation logic*

**Note:**
team@quantillon.money


## Functions
### validateNonZeroAddress

Validates that an address is not zero

*Checks if the provided address is the zero address and reverts with appropriate error*

**Notes:**
- Prevents zero address vulnerabilities in critical operations

- Ensures all addresses are properly initialized

- No state changes - pure function

- No events emitted

- Throws specific custom errors based on errorType

- Not applicable - pure function

- Internal library function

- No oracle dependencies


```solidity
function validateNonZeroAddress(address addr, string memory errorType) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`addr`|`address`|The address to validate|
|`errorType`|`string`|The type of address being validated (admin, treasury, token, oracle, vault)|


### validatePositiveAmount

Validates that an amount is positive

*Ensures the amount is greater than zero to prevent zero-value operations*

**Notes:**
- Prevents zero-amount vulnerabilities and invalid operations

- Ensures amounts are meaningful for business logic

- No state changes - pure function

- No events emitted

- Throws InvalidAmount if amount is zero

- Not applicable - pure function

- Internal library function

- No oracle dependencies


```solidity
function validatePositiveAmount(uint256 amount) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount to validate|


### validateMinAmount

Validates that an amount is above minimum threshold

*Ensures the amount meets the minimum requirement for the operation*

**Notes:**
- Prevents operations with insufficient amounts

- Ensures amounts meet business requirements

- No state changes - pure function

- No events emitted

- Throws InsufficientBalance if amount is below minimum

- Not applicable - pure function

- Internal library function

- No oracle dependencies


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

*Ensures the amount does not exceed the maximum allowed limit*

**Notes:**
- Prevents operations that exceed system limits

- Ensures amounts stay within acceptable bounds

- No state changes - pure function

- No events emitted

- Throws AboveLimit if amount exceeds maximum

- Not applicable - pure function

- Internal library function

- No oracle dependencies


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

*Ensures percentage values are within acceptable bounds for fees and rates*

**Notes:**
- Prevents invalid percentage values that could break system logic

- Ensures percentages are within business rules

- No state changes - pure function

- No events emitted

- Throws AboveLimit if percentage exceeds maximum

- Not applicable - pure function

- Internal library function

- No oracle dependencies


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

*Ensures time-based parameters are within acceptable bounds*

**Notes:**
- Prevents invalid time parameters that could affect system stability

- Ensures durations meet business requirements

- No state changes - pure function

- No events emitted

- Throws HoldingPeriodNotMet or AboveLimit based on validation failure

- Not applicable - pure function

- Internal library function

- No oracle dependencies


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

*Ensures price values are meaningful and not zero*

**Notes:**
- Prevents zero-price vulnerabilities in financial operations

- Ensures prices are valid for calculations

- No state changes - pure function

- No events emitted

- Throws InvalidPrice if price is zero

- Not applicable - pure function

- Internal library function

- No oracle dependencies


```solidity
function validatePrice(uint256 price) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`price`|`uint256`|The price to validate|


### validateCondition

Validates that a boolean condition is true

*Generic condition validator that throws specific errors based on error type*

**Notes:**
- Prevents invalid conditions from proceeding in critical operations

- Ensures business logic conditions are met

- No state changes - pure function

- No events emitted

- Throws specific custom errors based on errorType

- Not applicable - pure function

- Internal library function

- No oracle dependencies


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

*Ensures count-based operations don't exceed system limits*

**Notes:**
- Prevents operations that exceed system capacity limits

- Ensures counts stay within acceptable bounds

- No state changes - pure function

- No events emitted

- Throws TooManyPositions if count exceeds maximum

- Not applicable - pure function

- Internal library function

- No oracle dependencies


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

*Ensures there's enough balance to perform the required operation*

**Notes:**
- Prevents operations with insufficient funds

- Ensures sufficient balance for operations

- No state changes - pure function

- No events emitted

- Throws InsufficientBalance if balance is below required amount

- Not applicable - pure function

- Internal library function

- No oracle dependencies


```solidity
function validateSufficientBalance(uint256 balance, uint256 requiredAmount) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`balance`|`uint256`|The current balance|
|`requiredAmount`|`uint256`|The required amount|


### validateNotContract

Validates that an address is not a contract (for security)

*Prevents sending funds to potentially malicious contracts*

**Notes:**
- Prevents arbitrary-send vulnerabilities

- Ensures address is not a contract

- No state changes - pure function

- No events emitted

- Throws InvalidAddress if address is a contract

- Not applicable - pure function

- Internal library function

- No oracle dependencies


```solidity
function validateNotContract(address addr, string memory errorType) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`addr`|`address`|The address to validate|
|`errorType`|`string`|The type of error to throw if validation fails|


### validateTreasuryAddress

Validates treasury address is not zero address

*Prevents setting treasury to zero address which could cause loss of funds*

**Notes:**
- Prevents loss of funds by ensuring treasury is properly set

- Ensures treasury address is valid for fund operations

- No state changes - pure function

- No events emitted

- Throws ZeroAddress if treasury is zero address

- Not applicable - pure function

- Internal library function

- No oracle dependencies


```solidity
function validateTreasuryAddress(address treasury) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`treasury`|`address`|The treasury address to validate|


### validateSlippage

Validates slippage protection for token swaps/trades

*Ensures received amount is within acceptable tolerance of expected*

**Notes:**
- Prevents excessive slippage attacks in token operations

- Ensures received amount meets minimum expectations

- No state changes - pure function

- No events emitted

- Throws InvalidParameter if slippage exceeds tolerance

- Not applicable - pure function

- Internal library function

- No oracle dependencies


```solidity
function validateSlippage(uint256 received, uint256 expected, uint256 tolerance) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`received`|`uint256`|The actual amount received|
|`expected`|`uint256`|The expected amount|
|`tolerance`|`uint256`|The slippage tolerance in basis points|


### validateThresholdValue

Validates that a value meets minimum threshold requirements

*Used for minimum deposits, stakes, withdrawals, etc.*

**Notes:**
- Prevents operations below minimum thresholds

- Ensures values meet business requirements

- No state changes - pure function

- No events emitted

- Throws BelowThreshold if value is below minimum

- Not applicable - pure function

- Internal library function

- No oracle dependencies


```solidity
function validateThresholdValue(uint256 value, uint256 threshold) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`value`|`uint256`|The value to validate|
|`threshold`|`uint256`|The minimum required threshold|


### validateFee

Validates fee amount against maximum allowed fee

*Ensures fees don't exceed protocol limits (typically in basis points)*

**Notes:**
- Prevents excessive fees that could harm users

- Ensures fees stay within protocol limits

- No state changes - pure function

- No events emitted

- Throws InvalidParameter if fee exceeds maximum

- Not applicable - pure function

- Internal library function

- No oracle dependencies


```solidity
function validateFee(uint256 fee, uint256 maxFee) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`fee`|`uint256`|The fee amount to validate|
|`maxFee`|`uint256`|The maximum allowed fee|


### validateThreshold

Validates threshold value against maximum limit

*Used for liquidation thresholds, margin ratios, etc.*

**Notes:**
- Prevents thresholds that could destabilize the system

- Ensures thresholds stay within acceptable bounds

- No state changes - pure function

- No events emitted

- Throws InvalidParameter if threshold exceeds maximum

- Not applicable - pure function

- Internal library function

- No oracle dependencies


```solidity
function validateThreshold(uint256 threshold, uint256 maxThreshold) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`threshold`|`uint256`|The threshold value to validate|
|`maxThreshold`|`uint256`|The maximum allowed threshold|


