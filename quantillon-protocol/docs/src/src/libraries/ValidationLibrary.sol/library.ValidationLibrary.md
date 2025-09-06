# ValidationLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/076c7312a6c5bd467439b8303ad03ed05c21f052/src/libraries/ValidationLibrary.sol)

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

Validation functions for Quantillon Protocol

*Main characteristics:
- Comprehensive parameter validation for leverage, margin, fees, and rates
- Time-based validation for holding periods and liquidation cooldowns
- Balance and exposure validation functions
- Array and position validation utilities*

**Note:**
team@quantillon.money


## Functions
### validateLeverage

Validates leverage parameters for trading positions

*Ensures leverage is within acceptable bounds (> 0 and <= max)*

**Notes:**
- Prevents excessive leverage that could cause system instability

- Validates leverage > 0 and leverage <= maxLeverage

- No state changes - pure function

- No events emitted

- Throws InvalidLeverage if leverage is 0, LeverageTooHigh if exceeds max

- Not applicable - pure function

- Internal function - no access restrictions

- No oracle dependencies


```solidity
function validateLeverage(uint256 leverage, uint256 maxLeverage) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`leverage`|`uint256`|The leverage multiplier to validate|
|`maxLeverage`|`uint256`|The maximum allowed leverage|


### validateMarginRatio

Validates margin ratio to ensure sufficient collateralization

*Prevents positions from being under-collateralized*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function validateMarginRatio(uint256 marginRatio, uint256 minRatio) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`marginRatio`|`uint256`|The current margin ratio to validate|
|`minRatio`|`uint256`|The minimum required margin ratio|


### validateFee

Validates fee amount against maximum allowed fee

*Ensures fees don't exceed protocol limits (typically in basis points)*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function validateThreshold(uint256 threshold, uint256 maxThreshold) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`threshold`|`uint256`|The threshold value to validate|
|`maxThreshold`|`uint256`|The maximum allowed threshold|


### validatePositiveAmount

Validates that an amount is positive (greater than zero)

*Essential for token amounts, deposits, withdrawals, etc.*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function validatePositiveAmount(uint256 amount) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount to validate|


### validateYieldShift

Validates yield shift percentage (0-100%)

*Ensures yield shift is within valid range of 0-10000 basis points*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function validateTargetRatio(uint256 ratio, uint256 maxRatio) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`ratio`|`uint256`|The target ratio to validate|
|`maxRatio`|`uint256`|The maximum allowed ratio|


### validateLiquidationCooldown

Validates liquidation cooldown period to prevent manipulation

*Uses block numbers to prevent timestamp manipulation attacks*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function validateLiquidationCooldown(uint256 lastAttempt, uint256 cooldown) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`lastAttempt`|`uint256`|The block number of the last liquidation attempt|
|`cooldown`|`uint256`|The required cooldown period in blocks|


### validateSlippage

Validates slippage protection for token swaps/trades

*Ensures received amount is within acceptable tolerance of expected*

**Notes:**
- Prevents excessive slippage that could cause user losses

- Validates received >= expected * (10000 - tolerance) / 10000

- No state changes - pure function

- No events emitted

- Throws ExcessiveSlippage if slippage exceeds tolerance

- Not applicable - pure function

- Internal function - no access restrictions

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
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function validateThresholdValue(uint256 value, uint256 threshold) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`value`|`uint256`|The value to validate|
|`threshold`|`uint256`|The minimum required threshold|


### validatePositionActive

Validates that a position is active before operations

*Prevents operations on closed or invalid positions*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function validatePositionActive(bool isActive) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`isActive`|`bool`|The position's active status|


### validatePositionOwner

Validates position ownership before allowing operations

*Security check to ensure only position owner can modify it*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function validatePositionOwner(address owner, address caller) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`owner`|`address`|The position owner's address|
|`caller`|`address`|The address attempting the operation|


### validatePositionCount

Validates position count limits to prevent system overload

*Enforces maximum positions per user for gas and complexity management*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function validatePositionCount(uint256 count, uint256 max) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`count`|`uint256`|The current position count|
|`max`|`uint256`|The maximum allowed positions|


### validateCommitmentNotExists

Validates that a commitment doesn't already exist

*Prevents duplicate commitments in liquidation system*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function validateCommitmentNotExists(bool exists) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`exists`|`bool`|Whether the commitment already exists|


### validateCommitment

Validates that a valid commitment exists

*Ensures commitment exists before executing liquidation*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function validateCommitment(bool exists) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`exists`|`bool`|Whether a valid commitment exists|


### validateOraclePrice

Validates oracle price data integrity

*Ensures oracle price is valid before using in calculations*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function validateTreasuryAddress(address treasury) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`treasury`|`address`|The treasury address to validate|


