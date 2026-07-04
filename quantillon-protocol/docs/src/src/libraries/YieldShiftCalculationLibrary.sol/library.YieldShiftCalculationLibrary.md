# YieldShiftCalculationLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/fdf5f8f6194f4b414785cf5d6e2e583cb790646c/src/libraries/YieldShiftCalculationLibrary.sol)

**Title:**
YieldShiftCalculationLibrary

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

Calculation functions for YieldShift to reduce contract size

Extracted from YieldShift to reduce bytecode size

**Note:**
security-contact: team@quantillon.money


## Functions
### version

Returns the semantic version of this linked library.

On-chain version of the standalone deployed library; bump per semver on any change.
See deployments/{chainId}/versions.json for deployed-address provenance.

**Notes:**
- security: No security implications - returns a compile-time constant.

- validation: No input validation required.

- state-changes: None - pure function.

- events: None.

- errors: None.

- reentrancy: Not applicable - pure function.

- access: Public - anyone can read the version.

- oracle: No oracle dependencies.


```solidity
function version() external pure returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|Semantic version string (e.g. "1.0.0").|


### calculateOptimalYieldShift

Calculates optimal yield shift based on pool ratio

Calculates optimal yield shift to balance user and hedger pools

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

Gradually adjusts yield shift to prevent sudden changes

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


