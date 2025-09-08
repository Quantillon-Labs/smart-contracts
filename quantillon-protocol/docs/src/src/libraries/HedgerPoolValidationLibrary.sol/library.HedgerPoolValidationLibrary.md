# HedgerPoolValidationLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/2f5647e68ddbc27f036af14281f026d5d4a6db27/src/libraries/HedgerPoolValidationLibrary.sol)

Validation functions for HedgerPool to reduce contract size


## Functions
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


