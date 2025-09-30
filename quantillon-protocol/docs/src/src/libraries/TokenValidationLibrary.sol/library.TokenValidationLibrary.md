# TokenValidationLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/d4ff9dd61a04d59de40a8b136ac832356918d46a/src/libraries/TokenValidationLibrary.sol)

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

Token-specific validation functions for Quantillon Protocol

*Main characteristics:
- Validation functions specific to token operations
- Fee and threshold validations
- Oracle price validations
- Treasury address validations*

**Note:**
security-contact: team@quantillon.money


## Functions
### validateFee

Validates fee amount against maximum allowed fee

*Ensures fees don't exceed protocol limits (typically in basis points)*

**Notes:**
- security: Prevents excessive fees that could harm users

- validation: Ensures fees stay within protocol limits

- state-changes: No state changes - pure function

- events: No events emitted

- errors: Throws AboveLimit if fee exceeds maximum

- reentrancy: Not applicable - pure function

- access: Internal library function

- oracle: No oracle dependencies


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
- security: Prevents thresholds that could destabilize the system

- validation: Ensures thresholds stay within acceptable bounds

- state-changes: No state changes - pure function

- events: No events emitted

- errors: Throws AboveLimit if threshold exceeds maximum

- reentrancy: Not applicable - pure function

- access: Internal library function

- oracle: No oracle dependencies


```solidity
function validateThreshold(uint256 threshold, uint256 maxThreshold) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`threshold`|`uint256`|The threshold value to validate|
|`maxThreshold`|`uint256`|The maximum allowed threshold|


### validateThresholdValue

Validates that a value meets minimum threshold requirements

*Used for minimum deposits, stakes, withdrawals, etc.*

**Notes:**
- security: Prevents operations below minimum thresholds

- validation: Ensures values meet business requirements

- state-changes: No state changes - pure function

- events: No events emitted

- errors: Throws BelowThreshold if value is below minimum

- reentrancy: Not applicable - pure function

- access: Internal library function

- oracle: No oracle dependencies


```solidity
function validateThresholdValue(uint256 value, uint256 threshold) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`value`|`uint256`|The value to validate|
|`threshold`|`uint256`|The minimum required threshold|


### validateOraclePrice

Validates oracle price data integrity

*Ensures oracle price is valid before using in calculations*

**Notes:**
- security: Prevents use of invalid oracle data that could cause financial losses

- validation: Ensures oracle price data is valid and recent

- state-changes: No state changes - pure function

- events: No events emitted

- errors: Throws InvalidParameter if oracle price is invalid

- reentrancy: Not applicable - pure function

- access: Internal library function

- oracle: Validates oracle price data integrity


```solidity
function validateOraclePrice(bool isValid) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`isValid`|`bool`|Whether the oracle price is valid and recent|


### validateTreasuryAddress

Validates treasury address is not zero address

*Prevents setting treasury to zero address which could cause loss of funds*

**Notes:**
- security: Prevents loss of funds by ensuring treasury is properly set

- validation: Ensures treasury address is valid for fund operations

- state-changes: No state changes - pure function

- events: No events emitted

- errors: Throws ZeroAddress if treasury is zero address

- reentrancy: Not applicable - pure function

- access: Internal library function

- oracle: No oracle dependencies


```solidity
function validateTreasuryAddress(address treasury) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`treasury`|`address`|The treasury address to validate|


### validatePositiveAmount

Validates that an amount is positive (greater than zero)

*Essential for token amounts, deposits, withdrawals, etc.*

**Notes:**
- security: Prevents zero-amount operations that could cause issues

- validation: Ensures amount is positive for meaningful operations

- state-changes: No state changes - pure function

- events: No events emitted

- errors: Throws InvalidAmount if amount is zero

- reentrancy: Not applicable - pure function

- access: Internal library function

- oracle: No oracle dependencies


```solidity
function validatePositiveAmount(uint256 amount) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount to validate|


