# TokenValidationLibrary
**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

Token-specific validation functions for Quantillon Protocol

*Main characteristics:
- Validation functions specific to token operations
- Fee and threshold validations
- Oracle price validations
- Treasury address validations*

**Note:**
team@quantillon.money


## Functions
### validateFee

Validates fee amount against maximum allowed fee

*Ensures fees don't exceed protocol limits (typically in basis points)*

**Notes:**
- Prevents excessive fees that could harm users

- Ensures fees stay within protocol limits

- No state changes - pure function

- No events emitted

- Throws AboveLimit if fee exceeds maximum

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

- Throws AboveLimit if threshold exceeds maximum

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


### validateOraclePrice

Validates oracle price data integrity

*Ensures oracle price is valid before using in calculations*

**Notes:**
- Prevents use of invalid oracle data that could cause financial losses

- Ensures oracle price data is valid and recent

- No state changes - pure function

- No events emitted

- Throws InvalidParameter if oracle price is invalid

- Not applicable - pure function

- Internal library function

- Validates oracle price data integrity


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


