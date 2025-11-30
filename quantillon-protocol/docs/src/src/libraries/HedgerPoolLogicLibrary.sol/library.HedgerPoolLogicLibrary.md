# HedgerPoolLogicLibrary
Logic functions for HedgerPool to reduce contract size


## Functions
### validateAndCalculatePositionParams

Validates position parameters and calculates derived values

*Validates all position constraints and calculates fee, margin, and position size*

**Notes:**
- Validates all position constraints and limits

- Ensures amounts, leverage, and ratios are within limits

- None (pure function)

- None

- Throws various validation errors if constraints not met

- Not applicable - pure function

- External pure function

- Uses provided eurUsdPrice parameter


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

*Computes PnL using new formula: UnrealizedP&L = FilledVolume - QEUROBacked * OracleCurrentPrice*

**Notes:**
- No security validations required for pure function

- None required for pure function

- None (pure function)

- None

- None

- Not applicable - pure function

- Internal function

- Uses provided currentPrice parameter


```solidity
function calculatePnL(uint256 filledVolume, uint256 qeuroBacked, uint256 currentPrice) internal pure returns (int256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`filledVolume`|`uint256`|Size of the filled position in USDC (6 decimals)|
|`qeuroBacked`|`uint256`|Exact QEURO amount backed by this position (18 decimals)|
|`currentPrice`|`uint256`|Current market price (18 decimals)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`int256`|Profit (positive) or loss (negative) amount in USDC (6 decimals)|


### calculateCollateralCapacity

Calculates collateral-based capacity for a position

*Returns how much additional USDC exposure a position can absorb*

**Notes:**
- No security validations required for pure function

- None required for pure function

- None (pure function)

- None

- None

- Not applicable - pure function

- Internal function

- Uses provided currentPrice parameter


```solidity
function calculateCollateralCapacity(
    uint256 margin,
    uint256 filledVolume,
    uint256,
    uint256 currentPrice,
    uint256 minMarginRatio,
    int128,
    uint128 qeuroBacked
) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`margin`|`uint256`|Position margin in USDC (6 decimals)|
|`filledVolume`|`uint256`|Current filled volume (6 decimals)|
|`<none>`|`uint256`||
|`currentPrice`|`uint256`|Current price (18 decimals)|
|`minMarginRatio`|`uint256`|Minimum margin ratio in basis points|
|`<none>`|`int128`||
|`qeuroBacked`|`uint128`|Exact QEURO amount backed (18 decimals)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|capacity Additional USDC exposure the position can absorb|


### isPositionLiquidatable

Determines if a position is eligible for liquidation

*Checks if position margin ratio is below liquidation threshold*

**Notes:**
- No security validations required for pure function

- None required for pure function

- None (pure function)

- None

- None

- Not applicable - pure function

- External pure function

- Uses provided currentPrice parameter


```solidity
function isPositionLiquidatable(
    uint256 margin,
    uint256 filledVolume,
    uint256,
    uint256 currentPrice,
    uint256 liquidationThreshold,
    uint128 qeuroBacked
) external pure returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`margin`|`uint256`|Current margin amount for the position|
|`filledVolume`|`uint256`|Filled size of the position in USDC|
|`<none>`|`uint256`||
|`currentPrice`|`uint256`|Current market price|
|`liquidationThreshold`|`uint256`|Liquidation threshold in basis points|
|`qeuroBacked`|`uint128`|Exact QEURO amount backed by this position (18 decimals)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if position can be liquidated, false otherwise|


### calculateRewardUpdate

Calculates reward updates for hedgers based on interest rate differentials

*Computes new pending rewards based on time elapsed and interest rates*

**Notes:**
- No security validations required for pure function

- None required for pure function

- None (pure function)

- None

- None

- Not applicable - pure function

- External pure function

- Not applicable


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
- Validates margin constraints and limits

- Ensures margin operations are within limits

- None (pure function)

- None

- Throws InsufficientMargin or validation errors

- Not applicable - pure function

- External pure function

- Not applicable


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
- No security validations required for pure function

- None required for pure function

- None (pure function)

- None

- None

- Not applicable - pure function

- External pure function

- Not applicable


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


