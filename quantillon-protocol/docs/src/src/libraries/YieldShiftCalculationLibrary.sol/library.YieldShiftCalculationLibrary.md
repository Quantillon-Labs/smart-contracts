# YieldShiftCalculationLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/8526548ebebe4cec60f21492516bc5894f11137e/src/libraries/YieldShiftCalculationLibrary.sol)

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

Calculation functions for YieldShift to reduce contract size

*Extracted from YieldShift to reduce bytecode size*

**Note:**
security-contact: team@quantillon.money


## Functions
### calculateOptimalYieldShift

Calculates optimal yield shift based on pool ratio

*Calculates optimal yield shift to balance user and hedger pools*

**Notes:**
- security: No security implications - pure calculation function

- validation: Input validation handled by calling contract

- state-changes: No state changes - pure function

- events: No events emitted

- errors: No errors thrown - pure function

- reentrancy: Not applicable - pure function

- access: Public function

- oracle: No oracle dependencies


```solidity
function calculateOptimalYieldShift(
    uint256 poolRatio,
    uint256 baseYieldShift,
    uint256 maxYieldShift,
    uint256 targetPoolRatio
) external pure returns (uint256 optimalShift);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`poolRatio`|`uint256`|Current pool ratio (user/hedger)|
|`baseYieldShift`|`uint256`|Base yield shift percentage|
|`maxYieldShift`|`uint256`|Maximum yield shift percentage|
|`targetPoolRatio`|`uint256`|Target pool ratio|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`optimalShift`|`uint256`|Optimal yield shift percentage|


### applyGradualAdjustment

Applies gradual adjustment to yield shift

*Gradually adjusts yield shift to prevent sudden changes*

**Notes:**
- security: No security implications - pure calculation function

- validation: Input validation handled by calling contract

- state-changes: No state changes - pure function

- events: No events emitted

- errors: No errors thrown - pure function

- reentrancy: Not applicable - pure function

- access: Public function

- oracle: No oracle dependencies


```solidity
function applyGradualAdjustment(uint256 currentShift, uint256 targetShift, uint256 adjustmentSpeed)
    external
    pure
    returns (uint256 newShift);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`currentShift`|`uint256`|Current yield shift|
|`targetShift`|`uint256`|Target yield shift|
|`adjustmentSpeed`|`uint256`|Adjustment speed (basis points per update)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`newShift`|`uint256`|New yield shift after adjustment|


### calculateUserAllocation

Calculates user allocation percentage

*Calculates user allocation based on yield shift percentage*

**Notes:**
- security: No security implications - pure calculation function

- validation: Input validation handled by calling contract

- state-changes: No state changes - pure function

- events: No events emitted

- errors: No errors thrown - pure function

- reentrancy: Not applicable - pure function

- access: Public function

- oracle: No oracle dependencies


```solidity
function calculateUserAllocation(uint256 yieldShift) external pure returns (uint256 userAllocation);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`yieldShift`|`uint256`|Current yield shift percentage|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`userAllocation`|`uint256`|User allocation percentage|


### calculateHedgerAllocation

Calculates hedger allocation percentage

*Calculates hedger allocation based on yield shift percentage*

**Notes:**
- security: No security implications - pure calculation function

- validation: Input validation handled by calling contract

- state-changes: No state changes - pure function

- events: No events emitted

- errors: No errors thrown - pure function

- reentrancy: Not applicable - pure function

- access: Public function

- oracle: No oracle dependencies


```solidity
function calculateHedgerAllocation(uint256 yieldShift) external pure returns (uint256 hedgerAllocation);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`yieldShift`|`uint256`|Current yield shift percentage|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`hedgerAllocation`|`uint256`|Hedger allocation percentage|


### calculatePoolTWAP

Calculates TWAP for pool sizes

*Calculates time-weighted average price for pool sizes*

**Notes:**
- security: No security implications - pure calculation function

- validation: Input validation handled by calling contract

- state-changes: No state changes - pure function

- events: No events emitted

- errors: No errors thrown - pure function

- reentrancy: Not applicable - pure function

- access: Public function

- oracle: No oracle dependencies


```solidity
function calculatePoolTWAP(uint256[] memory snapshots)
    external
    pure
    returns (uint256 userPoolTWAP, uint256 hedgerPoolTWAP);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`snapshots`|`uint256[]`|Array of pool snapshots|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`userPoolTWAP`|`uint256`|TWAP for user pool size|
|`hedgerPoolTWAP`|`uint256`|TWAP for hedger pool size|


### calculateYieldDistribution

Calculates yield distribution amounts

*Calculates yield distribution between users and hedgers*

**Notes:**
- security: No security implications - pure calculation function

- validation: Input validation handled by calling contract

- state-changes: No state changes - pure function

- events: No events emitted

- errors: No errors thrown - pure function

- reentrancy: Not applicable - pure function

- access: Public function

- oracle: No oracle dependencies


```solidity
function calculateYieldDistribution(uint256 totalYield, uint256 userAllocation, uint256 hedgerAllocation)
    external
    pure
    returns (uint256 userYield, uint256 hedgerYield);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`totalYield`|`uint256`|Total yield to distribute|
|`userAllocation`|`uint256`|User allocation percentage|
|`hedgerAllocation`|`uint256`|Hedger allocation percentage|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`userYield`|`uint256`|User yield amount|
|`hedgerYield`|`uint256`|Hedger yield amount|


### validateYieldShiftParams

Validates yield shift parameters

*Ensures yield shift parameters are within valid bounds*

**Notes:**
- security: Prevents invalid yield shift parameters

- validation: Validates all parameters are within acceptable bounds

- state-changes: No state changes - pure function

- events: No events emitted

- errors: Throws require statements for invalid parameters

- reentrancy: Not applicable - pure function

- access: Public function

- oracle: No oracle dependencies


```solidity
function validateYieldShiftParams(
    uint256 baseYieldShift,
    uint256 maxYieldShift,
    uint256 adjustmentSpeed,
    uint256 targetPoolRatio
) external pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`baseYieldShift`|`uint256`|Base yield shift|
|`maxYieldShift`|`uint256`|Maximum yield shift|
|`adjustmentSpeed`|`uint256`|Adjustment speed|
|`targetPoolRatio`|`uint256`|Target pool ratio|


