# HedgerPoolValidationLibrary
**Title:**
HedgerPoolValidationLibrary

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

HedgerPool-specific validation functions for Quantillon Protocol

Main characteristics:
- Validation functions specific to HedgerPool operations
- Trading position management validations
- Liquidation system validations
- Margin and leverage validation functions

**Note:**
security-contact: team@quantillon.money


## Functions
### validateLeverage

Validates leverage parameters for trading positions

Ensures leverage is within acceptable bounds (> 0 and <= max)

**Notes:**
- security: Prevents excessive leverage that could cause system instability

- validation: Ensures leverage is within acceptable risk bounds

- state-changes: No state changes - pure function

- events: No events emitted

- errors: Throws InvalidLeverage or LeverageTooHigh based on validation

- reentrancy: Not applicable - pure function

- access: Internal library function

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

Prevents positions from being under-collateralized

**Notes:**
- security: Prevents under-collateralized positions that could cause liquidations

- validation: Ensures sufficient margin for position safety

- state-changes: No state changes - pure function

- events: No events emitted

- errors: Throws MarginRatioTooLow if ratio is below minimum

- reentrancy: Not applicable - pure function

- access: Internal library function

- oracle: No oracle dependencies


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

Prevents positions from being over-collateralized (leverage too low)

**Notes:**
- security: Prevents over-collateralization that could reduce capital efficiency

- validation: Ensures margin ratio stays within acceptable bounds

- state-changes: No state changes - pure function

- events: No events emitted

- errors: Throws MarginRatioTooHigh if ratio exceeds maximum

- reentrancy: Not applicable - pure function

- access: Internal library function

- oracle: No oracle dependencies


```solidity
function validateMaxMarginRatio(uint256 marginRatio, uint256 maxRatio) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`marginRatio`|`uint256`|The current margin ratio to validate|
|`maxRatio`|`uint256`|The maximum allowed margin ratio|


### validatePositionActive

Validates that a position is active before operations

Prevents operations on closed or invalid positions

**Notes:**
- security: Prevents operations on inactive positions

- validation: Ensures position is active before modifications

- state-changes: No state changes - pure function

- events: No events emitted

- errors: Throws PositionNotActive if position is inactive

- reentrancy: Not applicable - pure function

- access: Internal library function

- oracle: No oracle dependencies


```solidity
function validatePositionActive(bool isActive) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`isActive`|`bool`|The position's active status|


### validatePositionOwner

Validates position ownership before allowing operations

Security check to ensure only position owner can modify it

**Notes:**
- security: Prevents unauthorized position modifications

- validation: Ensures only position owner can modify position

- state-changes: No state changes - pure function

- events: No events emitted

- errors: Throws PositionOwnerMismatch if caller is not owner

- reentrancy: Not applicable - pure function

- access: Internal library function

- oracle: No oracle dependencies


```solidity
function validatePositionOwner(address owner, address caller) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`owner`|`address`|The position owner's address|
|`caller`|`address`|The address attempting the operation|


### validatePositionParams

Validates all position parameters against maximum limits

Ensures all position parameters are within acceptable bounds

**Notes:**
- security: Prevents position parameters that could destabilize system

- validation: Ensures all position parameters are within limits

- state-changes: No state changes - pure function

- events: No events emitted

- errors: Throws specific errors for each parameter that exceeds limits

- reentrancy: Not applicable - pure function

- access: Internal library function

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

Ensures combined totals don't exceed system-wide limits

**Notes:**
- security: Prevents system-wide limits from being exceeded

- validation: Ensures combined totals stay within system limits

- state-changes: No state changes - pure function

- events: No events emitted

- errors: Throws TotalMarginExceedsMaximum or TotalExposureExceedsMaximum

- reentrancy: Not applicable - pure function

- access: Internal library function

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

Prevents timestamp overflow when casting to uint32

**Notes:**
- security: Prevents timestamp overflow that could cause data corruption

- validation: Ensures timestamp fits within uint32 bounds

- state-changes: No state changes - pure function

- events: No events emitted

- errors: Throws TimestampOverflow if timestamp exceeds uint32 max

- reentrancy: Not applicable - pure function

- access: Internal library function

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

Ensures margin additions don't exceed individual position limits

**Notes:**
- security: Prevents margin additions that exceed position limits

- validation: Ensures new margin stays within position limits

- state-changes: No state changes - pure function

- events: No events emitted

- errors: Throws NewMarginExceedsMaximum if new margin exceeds limit

- reentrancy: Not applicable - pure function

- access: Internal library function

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

Prevents excessive reward accumulation that could cause overflow

**Notes:**
- security: Prevents reward overflow that could cause system issues

- validation: Ensures pending rewards stay within accumulation limits

- state-changes: No state changes - pure function

- events: No events emitted

- errors: Throws PendingRewardsExceedMaximum if rewards exceed limit

- reentrancy: Not applicable - pure function

- access: Internal library function

- oracle: No oracle dependencies


```solidity
function validatePendingRewards(uint256 newRewards, uint256 maxRewards) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newRewards`|`uint256`|The new total pending rewards amount|
|`maxRewards`|`uint256`|Maximum allowed pending rewards|


### validateFee

Validates fee amount against maximum allowed fee

Ensures fees don't exceed protocol limits (typically in basis points)

**Notes:**
- security: Prevents excessive fees that could harm users

- validation: Ensures fees stay within protocol limits

- state-changes: No state changes - pure function

- events: No events emitted

- errors: Throws FeeTooHigh if fee exceeds maximum

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


