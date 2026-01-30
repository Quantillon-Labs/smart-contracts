# CommonValidationLibrary
**Title:**
CommonValidationLibrary

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

Common validation functions used across multiple contracts

Main characteristics:
- Consolidates common validation patterns
- Reduces code duplication across contracts
- Uses custom errors for gas efficiency
- Maintains same validation logic

**Note:**
security-contact: team@quantillon.money


## Functions
### validateNonZeroAddress

Validates that an address is not zero

Checks if the provided address is the zero address and reverts with appropriate error.
Uses string comparison which is gas-intensive but maintains backward compatibility.
For new code, prefer using validateNonZeroAddressWithType() with AddressType enum.

**Notes:**
- security: Pure; no state change

- validation: Reverts if addr is zero

- state-changes: None

- events: None

- errors: InvalidAdmin, InvalidTreasury, InvalidToken, InvalidOracle, InvalidVault, InvalidAddress

- reentrancy: No external calls

- access: Internal library

- oracle: None


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

Reverts with InvalidAmount if amount is zero

**Notes:**
- security: Pure; no state change

- validation: Reverts if amount is zero

- state-changes: None

- events: None

- errors: InvalidAmount

- reentrancy: No external calls

- access: Internal library

- oracle: None


```solidity
function validatePositiveAmount(uint256 amount) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount to validate|


### validateMinAmount

Validates that an amount is above minimum threshold

Reverts with InsufficientBalance if amount is below minimum

**Notes:**
- security: Pure; no state change

- validation: Reverts if amount < minAmount

- state-changes: None

- events: None

- errors: InsufficientBalance

- reentrancy: No external calls

- access: Internal library

- oracle: None


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

Reverts with AboveLimit if amount exceeds maximum

**Notes:**
- security: Pure; no state change

- validation: Reverts if amount > maxAmount

- state-changes: None

- events: None

- errors: AboveLimit

- reentrancy: No external calls

- access: Internal library

- oracle: None


```solidity
function validateMaxAmount(uint256 amount, uint256 maxAmount) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount to validate|
|`maxAmount`|`uint256`|The maximum allowed amount|


### validatePercentage

Validates that a percentage is within valid range

Reverts with AboveLimit if percentage exceeds maximum

**Notes:**
- security: Pure; no state change

- validation: Reverts if percentage > maxPercentage

- state-changes: None

- events: None

- errors: AboveLimit

- reentrancy: No external calls

- access: Internal library

- oracle: None


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

Reverts with HoldingPeriodNotMet if too short, AboveLimit if too long

**Notes:**
- security: Pure; no state change

- validation: Reverts if duration out of [minDuration, maxDuration]

- state-changes: None

- events: None

- errors: HoldingPeriodNotMet, AboveLimit

- reentrancy: No external calls

- access: Internal library

- oracle: None


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

Reverts with InvalidPrice if price is zero

**Notes:**
- security: Pure; no state change

- validation: Reverts if price is zero

- state-changes: None

- events: None

- errors: InvalidPrice

- reentrancy: No external calls

- access: Internal library

- oracle: None


```solidity
function validatePrice(uint256 price) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`price`|`uint256`|The price to validate|


### validateCondition

Validates that a boolean condition is true

Generic condition validator that throws specific errors based on error type

**Notes:**
- security: Pure; no state change

- validation: Reverts if condition is false

- state-changes: None

- events: None

- errors: InvalidOracle, InsufficientCollateralization, NotAuthorized, InvalidCondition

- reentrancy: No external calls

- access: Internal library

- oracle: None


```solidity
function validateCondition(bool condition, string memory errorType) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`condition`|`bool`|The condition to validate|
|`errorType`|`string`|The type of error to throw if condition is false|


### _keccak256Bytes

Internal keccak256 of string using inline assembly (gas-efficient)


```solidity
function _keccak256Bytes(string memory s) private pure returns (bytes32);
```

### validateCountLimit

Validates that a count is within limits

Reverts with TooManyPositions if count exceeds or equals maximum

**Notes:**
- security: Pure; no state change

- validation: Reverts if count >= maxCount

- state-changes: None

- events: None

- errors: TooManyPositions

- reentrancy: No external calls

- access: Internal library

- oracle: None


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

Reverts with InsufficientBalance if balance is below required amount

**Notes:**
- security: Pure; no state change

- validation: Reverts if balance < requiredAmount

- state-changes: None

- events: None

- errors: InsufficientBalance

- reentrancy: No external calls

- access: Internal library

- oracle: None


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

Prevents sending funds to potentially malicious contracts

**Notes:**
- security: View; checks extcodesize

- validation: Reverts if addr has code

- state-changes: None

- events: None

- errors: InvalidTreasury, InvalidAddress

- reentrancy: No external calls

- access: Internal library

- oracle: None


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

Reverts with ZeroAddress if treasury is zero address

**Notes:**
- security: Pure; no state change

- validation: Reverts if treasury is zero

- state-changes: None

- events: None

- errors: ZeroAddress

- reentrancy: No external calls

- access: Internal library

- oracle: None


```solidity
function validateTreasuryAddress(address treasury) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`treasury`|`address`|The treasury address to validate|


### validateSlippage

Validates slippage protection for token swaps/trades

Reverts with InvalidParameter if slippage exceeds tolerance

**Notes:**
- security: Pure; no state change

- validation: Reverts if received below expected minus tolerance

- state-changes: None

- events: None

- errors: InvalidParameter

- reentrancy: No external calls

- access: Internal library

- oracle: None


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

Reverts with BelowThreshold if value is below minimum

**Notes:**
- security: Pure; no state change

- validation: Reverts if value < threshold

- state-changes: None

- events: None

- errors: BelowThreshold

- reentrancy: No external calls

- access: Internal library

- oracle: None


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

Reverts with InvalidParameter if fee exceeds maximum

**Notes:**
- security: Pure; no state change

- validation: Reverts if fee > maxFee

- state-changes: None

- events: None

- errors: InvalidParameter

- reentrancy: No external calls

- access: Internal library

- oracle: None


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

Reverts with InvalidParameter if threshold exceeds maximum

**Notes:**
- security: Pure; no state change

- validation: Reverts if threshold > maxThreshold

- state-changes: None

- events: None

- errors: InvalidParameter

- reentrancy: No external calls

- access: Internal library

- oracle: None


```solidity
function validateThreshold(uint256 threshold, uint256 maxThreshold) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`threshold`|`uint256`|The threshold value to validate|
|`maxThreshold`|`uint256`|The maximum allowed threshold|


