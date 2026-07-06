# YieldValidationLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/blob/9c66decc017650bbed0d0184c123aef0af402eaf/src/libraries/YieldValidationLibrary.sol)

**Title:**
YieldValidationLibrary

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

Yield-specific validation functions for Quantillon Protocol

Main characteristics:
- Validation functions specific to yield operations
- Yield shift mechanism validations
- Slippage protection validations
- Yield distribution validations

**Note:**
security-contact: team@quantillon.money


## Constants
### VERSION
Library version (semver); see deployments/{chainId}/versions.json for provenance.


```solidity
string internal constant VERSION = "1.0.0"
```


## Functions
### validateYieldShift

Validates yield shift percentage (0-100%)

Ensures yield shift is within valid range of 0-10000 basis points

**Notes:**
- security: Prevents invalid yield shifts that could destabilize yield distribution

- validation: Ensures yield shift is within valid percentage range

- state-changes: No state changes - pure function

- events: No events emitted

- errors: Throws InvalidParameter if shift exceeds 100%

- reentrancy: Not applicable - pure function

- access: Internal library function

- oracle: No oracle dependencies


```solidity
function validateYieldShift(uint256 shift) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`shift`|`uint256`|The yield shift percentage to validate (in basis points)|


### validateAdjustmentSpeed

Validates adjustment speed for yield shift mechanisms

Prevents excessively fast adjustments that could destabilize the system

**Notes:**
- security: Prevents rapid adjustments that could destabilize yield mechanisms

- validation: Ensures adjustment speed stays within safe bounds

- state-changes: No state changes - pure function

- events: No events emitted

- errors: Throws InvalidParameter if speed exceeds maximum

- reentrancy: Not applicable - pure function

- access: Internal library function

- oracle: No oracle dependencies


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

Ensures ratio is positive and within acceptable bounds

**Notes:**
- security: Prevents invalid ratios that could break yield distribution

- validation: Ensures ratio is positive and within acceptable bounds

- state-changes: No state changes - pure function

- events: No events emitted

- errors: Throws InvalidParameter or AboveLimit based on validation

- reentrancy: Not applicable - pure function

- access: Internal library function

- oracle: No oracle dependencies


```solidity
function validateTargetRatio(uint256 ratio, uint256 maxRatio) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`ratio`|`uint256`|The target ratio to validate|
|`maxRatio`|`uint256`|The maximum allowed ratio|


### validateTreasuryAddress

Validates treasury address is not zero address

Prevents setting treasury to zero address which could cause loss of funds

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


