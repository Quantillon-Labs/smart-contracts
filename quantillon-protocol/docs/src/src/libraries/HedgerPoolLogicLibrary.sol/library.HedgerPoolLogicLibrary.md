# HedgerPoolLogicLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/03f8f2db069e4fe5f129cc3e28526efe7b1f6f49/src/libraries/HedgerPoolLogicLibrary.sol)

Logic functions for HedgerPool to reduce contract size


## Functions
### validateAndCalculatePositionParams

Validates position parameters and calculates derived values

*Validates all position constraints and calculates fee, margin, and position size*

**Notes:**
- security: Validates all position constraints and limits

- validation: Ensures amounts, leverage, and ratios are within limits

- state-changes: None (pure function)

- events: None

- errors: Throws various validation errors if constraints not met

- reentrancy: Not applicable - pure function

- access: External pure function

- oracle: Uses provided eurUsdPrice parameter


```solidity
function validateAndCalculatePositionParams(
    uint256 usdcAmount,
    uint256 leverage,
    uint256 eurUsdPrice,
    uint256 entryFee,
    uint256 minMarginRatio,
    uint256 maxMarginRatio,
    uint256 maxLeverage,
    uint256 maxPositionsPerHedger,
    uint256 activePositionCount,
    uint256 maxMargin,
    uint256 maxPositionSize,
    uint256 maxEntryPrice,
    uint256 maxLeverageValue,
    uint256 currentTime
) external pure returns (uint256 fee, uint256 netMargin, uint256 positionSize, uint256 marginRatio);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdcAmount`|`uint256`|Amount of USDC to deposit|
|`leverage`|`uint256`|Leverage multiplier for the position|
|`eurUsdPrice`|`uint256`|Current EUR/USD price from oracle|
|`entryFee`|`uint256`|Entry fee rate in basis points|
|`minMarginRatio`|`uint256`|Minimum margin ratio in basis points|
|`maxMarginRatio`|`uint256`|Maximum margin ratio in basis points|
|`maxLeverage`|`uint256`|Maximum allowed leverage|
|`maxPositionsPerHedger`|`uint256`|Maximum positions per hedger|
|`activePositionCount`|`uint256`|Current active position count for hedger|
|`maxMargin`|`uint256`|Maximum margin per position|
|`maxPositionSize`|`uint256`|Maximum position size|
|`maxEntryPrice`|`uint256`|Maximum entry price|
|`maxLeverageValue`|`uint256`|Maximum leverage value|
|`currentTime`|`uint256`|Current timestamp|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`fee`|`uint256`|Calculated entry fee|
|`netMargin`|`uint256`|Net margin after fee deduction|
|`positionSize`|`uint256`|Calculated position size|
|`marginRatio`|`uint256`|Calculated margin ratio|


### calculatePnL

Calculates profit or loss for a hedge position

*Computes PnL based on price movement from entry to current price*

**Notes:**
- security: No security validations required for pure function

- validation: None required for pure function

- state-changes: None (pure function)

- events: None

- errors: None

- reentrancy: Not applicable - pure function

- access: Internal function

- oracle: Uses provided currentPrice parameter


```solidity
function calculatePnL(uint256 positionSize, uint256 entryPrice, uint256 currentPrice) internal pure returns (int256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`positionSize`|`uint256`|Size of the position in USDC|
|`entryPrice`|`uint256`|Price at which the position was opened|
|`currentPrice`|`uint256`|Current market price|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`int256`|Profit (positive) or loss (negative) amount|


### isPositionLiquidatable

Determines if a position is eligible for liquidation

*Checks if position margin ratio is below liquidation threshold*

**Notes:**
- security: No security validations required for pure function

- validation: None required for pure function

- state-changes: None (pure function)

- events: None

- errors: None

- reentrancy: Not applicable - pure function

- access: External pure function

- oracle: Uses provided currentPrice parameter


```solidity
function isPositionLiquidatable(
    uint256 margin,
    uint256 positionSize,
    uint256 entryPrice,
    uint256 currentPrice,
    uint256 liquidationThreshold
) external pure returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`margin`|`uint256`|Current margin amount for the position|
|`positionSize`|`uint256`|Size of the position in USDC|
|`entryPrice`|`uint256`|Price at which the position was opened|
|`currentPrice`|`uint256`|Current market price|
|`liquidationThreshold`|`uint256`|Liquidation threshold in basis points|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if position can be liquidated, false otherwise|


### calculateRewardUpdate

Calculates reward updates for hedgers based on interest rate differentials

*Computes new pending rewards based on time elapsed and interest rates*

**Notes:**
- security: No security validations required for pure function

- validation: None required for pure function

- state-changes: None (pure function)

- events: None

- errors: None

- reentrancy: Not applicable - pure function

- access: External pure function

- oracle: Not applicable


```solidity
function calculateRewardUpdate(
    uint256 totalExposure,
    uint256 eurInterestRate,
    uint256 usdInterestRate,
    uint256 lastRewardBlock,
    uint256 currentBlock,
    uint256 maxRewardPeriod,
    uint256 currentPendingRewards
) external pure returns (uint256 newPendingRewards, uint256 newLastRewardBlock);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`totalExposure`|`uint256`|Total exposure across all positions|
|`eurInterestRate`|`uint256`|EUR interest rate in basis points|
|`usdInterestRate`|`uint256`|USD interest rate in basis points|
|`lastRewardBlock`|`uint256`|Block number of last reward calculation|
|`currentBlock`|`uint256`|Current block number|
|`maxRewardPeriod`|`uint256`|Maximum reward period in blocks|
|`currentPendingRewards`|`uint256`|Current pending rewards amount|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`newPendingRewards`|`uint256`|Updated pending rewards amount|
|`newLastRewardBlock`|`uint256`|Updated last reward block|


### validateMarginOperation

Validates margin operations and calculates new margin values

*Validates margin addition/removal and calculates resulting margin ratio*

**Notes:**
- security: Validates margin constraints and limits

- validation: Ensures margin operations are within limits

- state-changes: None (pure function)

- events: None

- errors: Throws InsufficientMargin or validation errors

- reentrancy: Not applicable - pure function

- access: External pure function

- oracle: Not applicable


```solidity
function validateMarginOperation(
    uint256 currentMargin,
    uint256 amount,
    bool isAddition,
    uint256 minMarginRatio,
    uint256 positionSize,
    uint256 maxMargin
) external pure returns (uint256 newMargin, uint256 newMarginRatio);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`currentMargin`|`uint256`|Current margin amount for the position|
|`amount`|`uint256`|Amount of margin to add or remove|
|`isAddition`|`bool`|True if adding margin, false if removing|
|`minMarginRatio`|`uint256`|Minimum margin ratio in basis points|
|`positionSize`|`uint256`|Size of the position in USDC|
|`maxMargin`|`uint256`|Maximum margin per position|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`newMargin`|`uint256`|New margin amount after operation|
|`newMarginRatio`|`uint256`|New margin ratio after operation|


### generateLiquidationCommitment

Generates a unique liquidation commitment hash

*Creates a commitment hash for MEV protection in liquidation process*

**Notes:**
- security: No security validations required for pure function

- validation: None required for pure function

- state-changes: None (pure function)

- events: None

- errors: None

- reentrancy: Not applicable - pure function

- access: External pure function

- oracle: Not applicable


```solidity
function generateLiquidationCommitment(address hedger, uint256 positionId, bytes32 salt, address liquidator)
    external
    pure
    returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Address of the hedger whose position will be liquidated|
|`positionId`|`uint256`|ID of the position to liquidate|
|`salt`|`bytes32`|Random salt for commitment uniqueness|
|`liquidator`|`address`|Address of the liquidator making the commitment|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|Commitment hash for liquidation process|


## Structs
### PositionData

```solidity
struct PositionData {
    uint256 positionSize;
    uint256 margin;
    uint256 entryPrice;
    uint32 entryTime;
    uint32 lastUpdateTime;
    int128 unrealizedPnL;
    uint16 leverage;
    bool isActive;
}
```

### HedgerData

```solidity
struct HedgerData {
    uint256 totalMargin;
    uint256 totalExposure;
    uint128 pendingRewards;
    uint64 lastRewardClaim;
    bool isActive;
}
```

