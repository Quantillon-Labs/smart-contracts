# HedgerPoolValidationLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/33d218e93a34affdd8776e90bfbc756888be6ca6/src/libraries/HedgerPoolValidationLibrary.sol)

Validation functions for HedgerPool to reduce contract size


## Functions
### validatePositionParams

Validates all position parameters against maximum limits

*Ensures all position parameters are within acceptable bounds*

**Notes:**
- Validates all position parameters against maximum limits

- Validates all position parameters against maximum limits

- No state changes - pure function

- No events emitted

- Throws various errors if parameters exceed limits

- Not applicable - pure function

- Internal function - no access restrictions

- No oracle dependencies


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
- Validates total margin and exposure limits

- Validates total margin and exposure limits

- No state changes - pure function

- No events emitted

- Throws various errors if totals exceed limits

- Not applicable - pure function

- Internal function - no access restrictions

- No oracle dependencies


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
- Validates timestamp fits in uint32 for storage optimization

- Validates timestamp fits in uint32 for storage optimization

- No state changes - pure function

- No events emitted

- Throws TimestampOverflow if timestamp exceeds uint32 max

- Not applicable - pure function

- Internal function - no access restrictions

- No oracle dependencies


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
- Validates new margin amount against maximum limit

- Validates new margin amount against maximum limit

- No state changes - pure function

- No events emitted

- Throws NewMarginExceedsMaximum if margin exceeds limit

- Not applicable - pure function

- Internal function - no access restrictions

- No oracle dependencies


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
- Validates pending rewards against maximum accumulation limit

- Validates pending rewards against maximum accumulation limit

- No state changes - pure function

- No events emitted

- Throws PendingRewardsExceedMaximum if rewards exceed limit

- Not applicable - pure function

- Internal function - no access restrictions

- No oracle dependencies


```solidity
function validatePendingRewards(uint256 newRewards, uint256 maxRewards) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newRewards`|`uint256`|The new total pending rewards amount|
|`maxRewards`|`uint256`|Maximum allowed pending rewards|


