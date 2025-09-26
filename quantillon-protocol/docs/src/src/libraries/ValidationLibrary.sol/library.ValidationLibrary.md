# ValidationLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/dd3e083d5d3a3d1f4c483da8f76db5c62d86f916/src/libraries/ValidationLibrary.sol)

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

Validation functions for Quantillon Protocol

*Main characteristics:
- Comprehensive parameter validation for leverage, margin, fees, and rates
- Time-based validation for holding periods and liquidation cooldowns
- Balance and exposure validation functions
- Array and position validation utilities*

**Note:**
security-contact: team@quantillon.money


## Functions
### validateLeverage

Validates leverage parameters for trading positions

*Ensures leverage is within acceptable bounds (> 0 and <= max)*

**Notes:**
- security: Prevents excessive leverage that could cause system instability

- validation: Validates leverage > 0 and leverage <= maxLeverage

- state-changes: No state changes - pure function

- events: No events emitted

- errors: Throws InvalidLeverage if leverage is 0, LeverageTooHigh if exceeds max

- reentrancy: Not applicable - pure function

- access: Internal function - no access restrictions

- oracle: No oracle dependencies


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
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function validateMarginRatio(uint256 marginRatio, uint256 minRatio) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`marginRatio`|`uint256`|The current margin ratio to validate|
|`minRatio`|`uint256`|The minimum required margin ratio|


### validateMaxMarginRatio

Validates margin ratio against maximum limit to prevent excessive collateralization

*Prevents positions from being over-collateralized (leverage too low)*

**Notes:**
- security: Prevents excessive margin ratios that would result in leverage < 2x

- validation: Validates marginRatio <= maxRatio

- state-changes: No state changes - pure function

- events: No events emitted

- errors: Throws MarginRatioTooHigh if margin ratio exceeds maximum

- reentrancy: Not applicable - pure function

- access: Internal function - no access restrictions

- oracle: No oracle dependencies


```solidity
function validateMaxMarginRatio(uint256 marginRatio, uint256 maxRatio) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`marginRatio`|`uint256`|The current margin ratio to validate|
|`maxRatio`|`uint256`|The maximum allowed margin ratio|


### validateFee

Validates fee amount against maximum allowed fee

*Ensures fees don't exceed protocol limits (typically in basis points)*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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
- security: Prevents excessive slippage that could cause user losses

- validation: Validates received >= expected * (10000 - tolerance) / 10000

- state-changes: No state changes - pure function

- events: No events emitted

- errors: Throws ExcessiveSlippage if slippage exceeds tolerance

- reentrancy: Not applicable - pure function

- access: Internal function - no access restrictions

- oracle: No oracle dependencies


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
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function validateTreasuryAddress(address treasury) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`treasury`|`address`|The treasury address to validate|


### validatePositionParams

Validates all position parameters against maximum limits

*Ensures all position parameters are within acceptable bounds*

**Notes:**
- security: Validates all position parameters against maximum limits

- validation: Validates all position parameters against maximum limits

- state-changes: No state changes - pure function

- events: No events emitted

- errors: Throws various errors if parameters exceed limits

- reentrancy: Not applicable - pure function

- access: Internal function - no access restrictions

- oracle: No oracle dependencies


```solidity
function validatePositionParams(
    uint256 netMargin,
    uint256 positionSize,
    uint256 eurUsdPrice,
    uint256 leverage,
    uint256 maxMargin,
    uint256 maxPositionSize,
    uint256 maxEntryPrice,
    uint256 maxLeverage
) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`netMargin`|`uint256`|The net margin amount after fees|
|`positionSize`|`uint256`|The size of the position|
|`eurUsdPrice`|`uint256`|The EUR/USD entry price|
|`leverage`|`uint256`|The leverage multiplier|
|`maxMargin`|`uint256`|Maximum allowed margin|
|`maxPositionSize`|`uint256`|Maximum allowed position size|
|`maxEntryPrice`|`uint256`|Maximum allowed entry price|
|`maxLeverage`|`uint256`|Maximum allowed leverage|


### validateTotals

Validates total margin and exposure limits

*Ensures combined totals don't exceed system-wide limits*

**Notes:**
- security: Validates total margin and exposure limits

- validation: Validates total margin and exposure limits

- state-changes: No state changes - pure function

- events: No events emitted

- errors: Throws various errors if totals exceed limits

- reentrancy: Not applicable - pure function

- access: Internal function - no access restrictions

- oracle: No oracle dependencies


```solidity
function validateTotals(
    uint256 currentMargin,
    uint256 currentExposure,
    uint256 additionalMargin,
    uint256 additionalExposure,
    uint256 maxTotalMargin,
    uint256 maxTotalExposure
) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`currentMargin`|`uint256`|Current total margin|
|`currentExposure`|`uint256`|Current total exposure|
|`additionalMargin`|`uint256`|Additional margin being added|
|`additionalExposure`|`uint256`|Additional exposure being added|
|`maxTotalMargin`|`uint256`|Maximum allowed total margin|
|`maxTotalExposure`|`uint256`|Maximum allowed total exposure|


### validateTimestamp

Validates timestamp fits in uint32 for storage optimization

*Prevents timestamp overflow when casting to uint32*

**Notes:**
- security: Validates timestamp fits in uint32 for storage optimization

- validation: Validates timestamp fits in uint32 for storage optimization

- state-changes: No state changes - pure function

- events: No events emitted

- errors: Throws TimestampOverflow if timestamp exceeds uint32 max

- reentrancy: Not applicable - pure function

- access: Internal function - no access restrictions

- oracle: No oracle dependencies


```solidity
function validateTimestamp(uint256 timestamp) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`timestamp`|`uint256`|The timestamp to validate|


### validateNewMargin

Validates new margin amount against maximum limit

*Ensures margin additions don't exceed individual position limits*

**Notes:**
- security: Validates new margin amount against maximum limit

- validation: Validates new margin amount against maximum limit

- state-changes: No state changes - pure function

- events: No events emitted

- errors: Throws NewMarginExceedsMaximum if margin exceeds limit

- reentrancy: Not applicable - pure function

- access: Internal function - no access restrictions

- oracle: No oracle dependencies


```solidity
function validateNewMargin(uint256 newMargin, uint256 maxMargin) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newMargin`|`uint256`|The new total margin amount|
|`maxMargin`|`uint256`|Maximum allowed margin per position|


### validatePendingRewards

Validates pending rewards against maximum accumulation limit

*Prevents excessive reward accumulation that could cause overflow*

**Notes:**
- security: Validates pending rewards against maximum accumulation limit

- validation: Validates pending rewards against maximum accumulation limit

- state-changes: No state changes - pure function

- events: No events emitted

- errors: Throws PendingRewardsExceedMaximum if rewards exceed limit

- reentrancy: Not applicable - pure function

- access: Internal function - no access restrictions

- oracle: No oracle dependencies


```solidity
function validatePendingRewards(uint256 newRewards, uint256 maxRewards) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newRewards`|`uint256`|The new total pending rewards amount|
|`maxRewards`|`uint256`|Maximum allowed pending rewards|


