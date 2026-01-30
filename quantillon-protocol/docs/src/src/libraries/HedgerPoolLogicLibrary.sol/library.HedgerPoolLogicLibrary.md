# HedgerPoolLogicLibrary
**Title:**
HedgerPoolLogicLibrary

**Author:**
Quantillon Labs

Logic functions for HedgerPool to reduce contract size

Core P&L Calculation Formulas:
1. TOTAL UNREALIZED P&L (mark-to-market of current position):
totalUnrealizedPnL = FilledVolume - (QEUROBacked × OraclePrice / 1e30)
- Positive when price drops (hedger profits from short EUR position)
- Negative when price rises (hedger loses from short EUR position)
2. NET UNREALIZED P&L (after accounting for realized portions):
netUnrealizedPnL = totalUnrealizedPnL - realizedPnL
- Used when margin has been adjusted by realized P&L during redemptions
- Prevents double-counting since margin already reflects realized P&L
3. EFFECTIVE MARGIN (true economic value of position):
effectiveMargin = margin + netUnrealizedPnL
- Represents what the hedger would have if position closed now
- Used for collateralization checks and available collateral calculations
4. LIQUIDATION MODE (CR ≤ 101%):
In liquidation mode, the entire hedger margin is considered at risk.
unrealizedPnL = -margin, meaning effectiveMargin = 0


## Functions
### validateAndCalculatePositionParams

Validates position parameters and calculates derived values

Validates all position constraints and calculates fee, margin, and position size

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

Calculates TOTAL unrealized P&L for a hedge position (mark-to-market)

Formula: TotalUnrealizedP&L = FilledVolume - (QEUROBacked × OraclePrice / 1e30)
Hedgers are SHORT EUR (they owe QEURO to users). When price rises, they lose.
- Price UP → qeuroValueInUSDC increases → P&L becomes more negative → hedger loses
- Price DOWN → qeuroValueInUSDC decreases → P&L becomes more positive → hedger profits
This returns the TOTAL unrealized P&L for the current position state.
To get NET unrealized P&L (after partial redemptions), subtract realizedPnL from this value.

**Notes:**
- security: No security validations required for pure function

- validation: Validates filledVolume and currentPrice are non-zero

- state-changes: None (pure function)

- events: None (pure function)

- errors: None (returns 0 for edge cases)

- reentrancy: Not applicable (pure function)

- access: Internal library function

- oracle: Uses provided currentPrice parameter (must be fresh oracle data)


```solidity
function calculatePnL(uint256 filledVolume, uint256 qeuroBacked, uint256 currentPrice)
    internal
    pure
    returns (int256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`filledVolume`|`uint256`|Size of the filled position in USDC (6 decimals)|
|`qeuroBacked`|`uint256`|Exact QEURO amount backed by this position (18 decimals)|
|`currentPrice`|`uint256`|Current EUR/USD oracle price (18 decimals)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`int256`|Profit (positive) or loss (negative) amount in USDC (6 decimals)|


### calculateCollateralCapacity

Calculates collateral-based capacity for a position

Returns how much additional USDC exposure a position can absorb
Formula breakdown:
1. totalUnrealizedPnL = calculatePnL(filledVolume, qeuroBacked, currentPrice)
2. netUnrealizedPnL = totalUnrealizedPnL - realizedPnL
(margin already reflects realized P&L, so we use net unrealized to avoid double-counting)
3. effectiveMargin = margin + netUnrealizedPnL
4. requiredMargin = (qeuroBacked × currentPrice / 1e30) × minMarginRatio / 10000
5. availableCollateral = effectiveMargin - requiredMargin
6. capacity = availableCollateral × 10000 / minMarginRatio

**Notes:**
- security: No security validations required for pure function

- validation: Validates currentPrice > 0 and minMarginRatio > 0

- state-changes: None (pure function)

- events: None (pure function)

- errors: None (returns 0 for invalid inputs)

- reentrancy: Not applicable (pure function)

- access: Internal library function

- oracle: Uses provided currentPrice parameter (must be fresh oracle data)


```solidity
function calculateCollateralCapacity(
    uint256 margin,
    uint256 filledVolume,
    uint256,
    /* entryPrice */
    uint256 currentPrice,
    uint256 minMarginRatio,
    int128 realizedPnL,
    uint128 qeuroBacked
) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`margin`|`uint256`|Position margin in USDC (6 decimals)|
|`filledVolume`|`uint256`|Current filled volume in USDC (6 decimals)|
|`<none>`|`uint256`||
|`currentPrice`|`uint256`|Current EUR/USD oracle price (18 decimals)|
|`minMarginRatio`|`uint256`|Minimum margin ratio in basis points (e.g., 500 = 5%)|
|`realizedPnL`|`int128`|Cumulative realized P&L from partial redemptions (6 decimals, signed)|
|`qeuroBacked`|`uint128`|Exact QEURO amount backed by this position (18 decimals)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|capacity Additional USDC exposure the position can absorb (6 decimals)|


### isPositionLiquidatable

Determines if a position is eligible for liquidation

Checks if position margin ratio falls below the liquidation threshold
Formula breakdown:
1. totalUnrealizedPnL = calculatePnL(filledVolume, qeuroBacked, currentPrice)
2. netUnrealizedPnL = totalUnrealizedPnL - realizedPnL
(margin already reflects realized P&L, so we use net unrealized to avoid double-counting)
3. effectiveMargin = margin + netUnrealizedPnL
4. qeuroValueInUSDC = qeuroBacked × currentPrice / 1e30
5. marginRatio = effectiveMargin × 10000 / qeuroValueInUSDC
6. liquidatable = marginRatio < liquidationThreshold

**Notes:**
- security: No security validations required for pure function

- validation: Validates currentPrice > 0 and liquidationThreshold > 0

- state-changes: None (pure function)

- events: None (pure function)

- errors: None (returns false for invalid inputs)

- reentrancy: Not applicable (pure function)

- access: Internal library function

- oracle: Uses provided currentPrice parameter (must be fresh oracle data)


```solidity
function isPositionLiquidatable(
    uint256 margin,
    uint256 filledVolume,
    uint256,
    /* entryPrice */
    uint256 currentPrice,
    uint256 liquidationThreshold,
    uint128 qeuroBacked,
    int128 realizedPnL
) external pure returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`margin`|`uint256`|Current margin amount for the position (6 decimals USDC)|
|`filledVolume`|`uint256`|Filled size of the position in USDC (6 decimals)|
|`<none>`|`uint256`||
|`currentPrice`|`uint256`|Current EUR/USD oracle price (18 decimals)|
|`liquidationThreshold`|`uint256`|Minimum margin ratio in basis points (e.g., 500 = 5%)|
|`qeuroBacked`|`uint128`|Exact QEURO amount backed by this position (18 decimals)|
|`realizedPnL`|`int128`|Cumulative realized P&L from partial redemptions (6 decimals, signed)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if position margin ratio is below threshold, false otherwise|


### calculateRewardUpdate

Calculates reward updates for hedgers based on interest rate differentials

Computes new pending rewards based on time elapsed and interest rates

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
|`totalExposure`|`uint256`|Total exposure for the hedger position|
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

Validates margin addition/removal and calculates resulting margin ratio

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


