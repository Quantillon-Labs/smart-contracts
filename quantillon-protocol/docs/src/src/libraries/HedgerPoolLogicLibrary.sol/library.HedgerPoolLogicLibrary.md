# HedgerPoolLogicLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/91f7ed3e8a496e9d369dc182e8f549ec75449a6b/src/libraries/HedgerPoolLogicLibrary.sol)

Logic functions for HedgerPool to reduce contract size


## Functions
### validateAndCalculatePositionParams

Validates and calculates position opening parameters


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

### calculatePnL

Calculates profit/loss for a position


```solidity
function calculatePnL(uint256 positionSize, uint256 entryPrice, uint256 currentPrice) internal pure returns (int256);
```

### isPositionLiquidatable

Calculates liquidation eligibility


```solidity
function isPositionLiquidatable(
    uint256 margin,
    uint256 positionSize,
    uint256 entryPrice,
    uint256 currentPrice,
    uint256 liquidationThreshold
) external pure returns (bool);
```

### calculateRewardUpdate

Calculates reward updates for hedgers


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

### validateMarginOperation

Validates margin operations


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

### generateLiquidationCommitment

Generates liquidation commitment hash


```solidity
function generateLiquidationCommitment(address hedger, uint256 positionId, bytes32 salt, address liquidator)
    external
    pure
    returns (bytes32);
```

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

