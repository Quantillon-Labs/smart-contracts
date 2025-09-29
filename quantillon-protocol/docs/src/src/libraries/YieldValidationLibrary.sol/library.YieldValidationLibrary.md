# YieldValidationLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/71cd41fc9aa7c18638af4654e656fb0dc6b6d493/src/libraries/YieldValidationLibrary.sol)

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

Yield-specific validation functions for Quantillon Protocol

*Main characteristics:
- Validation functions specific to yield operations
- Yield shift mechanism validations
- Slippage protection validations
- Yield distribution validations*

**Note:**
team@quantillon.money


## Functions
### validateYieldShift

Validates yield shift percentage (0-100%)

*Ensures yield shift is within valid range of 0-10000 basis points*

**Notes:**
- Prevents invalid yield shifts that could destabilize yield distribution

- Ensures yield shift is within valid percentage range

- No state changes - pure function

- No events emitted

- Throws InvalidParameter if shift exceeds 100%

- Not applicable - pure function

- Internal library function

- No oracle dependencies


```solidity
function validateYieldShift(uint256 shift) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`shift`|`uint256`|The yield shift percentage to validate (in basis points)|


### validateAdjustmentSpeed

Validates adjustment speed for yield shift mechanisms

*Prevents excessively fast adjustments that could destabilize the system*

**Notes:**
- Prevents rapid adjustments that could destabilize yield mechanisms

- Ensures adjustment speed stays within safe bounds

- No state changes - pure function

- No events emitted

- Throws InvalidParameter if speed exceeds maximum

- Not applicable - pure function

- Internal library function

- No oracle dependencies


```solidity
function validateAdjustmentSpeed(uint256 speed, uint256 maxSpeed) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`speed`|`uint256`|The adjustment speed to validate|
|`maxSpeed`|`uint256`|The maximum allowed adjustment speed|


### validateTargetRatio

Validates target ratio for yield distribution mechanisms

*Ensures ratio is positive and within acceptable bounds*

**Notes:**
- Prevents invalid ratios that could break yield distribution

- Ensures ratio is positive and within acceptable bounds

- No state changes - pure function

- No events emitted

- Throws InvalidParameter or AboveLimit based on validation

- Not applicable - pure function

- Internal library function

- No oracle dependencies


```solidity
function validateTargetRatio(uint256 ratio, uint256 maxRatio) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`ratio`|`uint256`|The target ratio to validate|
|`maxRatio`|`uint256`|The maximum allowed ratio|


### validateSlippage

Validates slippage protection for token swaps/trades

*Ensures received amount is within acceptable tolerance of expected*

**Notes:**
- Prevents excessive slippage attacks in yield operations

- Ensures received amount meets minimum expectations

- No state changes - pure function

- No events emitted

- Throws ExcessiveSlippage if slippage exceeds tolerance

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


### validatePositiveAmount

Validates that an amount is positive (greater than zero)

*Essential for token amounts, deposits, withdrawals, etc.*

**Notes:**
- Prevents zero-amount operations that could cause issues

- Ensures amount is positive for meaningful operations

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


