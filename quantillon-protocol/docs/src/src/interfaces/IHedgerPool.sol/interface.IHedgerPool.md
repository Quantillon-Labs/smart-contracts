# IHedgerPool
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/14b540a5cb762ce47f29a6390bf8e3153b372aff/src/interfaces/IHedgerPool.sol)


## Functions
### enterHedgePosition


```solidity
function enterHedgePosition(uint256 usdcAmount, uint256 leverage) external returns (uint256 positionId);
```

### exitHedgePosition


```solidity
function exitHedgePosition(uint256 positionId) external returns (int256 pnl);
```

### addMargin


```solidity
function addMargin(uint256 positionId, uint256 amount) external;
```

### removeMargin


```solidity
function removeMargin(uint256 positionId, uint256 amount) external;
```

### commitLiquidation


```solidity
function commitLiquidation(address hedger, uint256 positionId, bytes32 salt) external;
```

### liquidateHedger


```solidity
function liquidateHedger(address hedger, uint256 positionId, bytes32 salt)
    external
    returns (uint256 liquidationReward);
```

### hasPendingLiquidationCommitment


```solidity
function hasPendingLiquidationCommitment(address hedger, uint256 positionId) external view returns (bool);
```

### clearExpiredLiquidationCommitment


```solidity
function clearExpiredLiquidationCommitment(address hedger, uint256 positionId) external;
```

### cancelLiquidationCommitment


```solidity
function cancelLiquidationCommitment(address hedger, uint256 positionId, bytes32 salt) external;
```

### claimHedgingRewards


```solidity
function claimHedgingRewards()
    external
    returns (uint256 interestDifferential, uint256 yieldShiftRewards, uint256 totalRewards);
```

### getHedgerPosition


```solidity
function getHedgerPosition(address hedger, uint256 positionId)
    external
    view
    returns (
        uint256 positionSize,
        uint256 margin,
        uint256 entryPrice,
        uint256 currentPrice,
        uint256 leverage,
        uint256 lastUpdateTime
    );
```

### getHedgerMarginRatio


```solidity
function getHedgerMarginRatio(address hedger, uint256 positionId) external view returns (uint256);
```

### isHedgerLiquidatable


```solidity
function isHedgerLiquidatable(address hedger, uint256 positionId) external view returns (bool);
```

### getTotalHedgeExposure


```solidity
function getTotalHedgeExposure() external view returns (uint256);
```

### getPoolStatistics


```solidity
function getPoolStatistics()
    external
    view
    returns (
        uint256 activeHedgers,
        uint256 totalPositions,
        uint256 averagePosition,
        uint256 totalMargin,
        uint256 poolUtilization
    );
```

### getPendingHedgingRewards


```solidity
function getPendingHedgingRewards(address hedger)
    external
    view
    returns (uint256 interestDifferential, uint256 yieldShiftRewards, uint256 totalPending);
```

### updateHedgingParameters


```solidity
function updateHedgingParameters(
    uint256 newMinMarginRatio,
    uint256 newLiquidationThreshold,
    uint256 newMaxLeverage,
    uint256 newLiquidationPenalty
) external;
```

### updateInterestRates


```solidity
function updateInterestRates(uint256 newEurRate, uint256 newUsdRate) external;
```

### setHedgingFees


```solidity
function setHedgingFees(uint256 _entryFee, uint256 _exitFee, uint256 _marginFee) external;
```

### getHedgingConfig


```solidity
function getHedgingConfig()
    external
    view
    returns (
        uint256 minMarginRatio,
        uint256 liquidationThreshold,
        uint256 maxLeverage,
        uint256 liquidationPenalty,
        uint256 entryFee,
        uint256 exitFee
    );
```

### emergencyClosePosition


```solidity
function emergencyClosePosition(address hedger, uint256 positionId) external;
```

### pause


```solidity
function pause() external;
```

### unpause


```solidity
function unpause() external;
```

### isHedgingActive


```solidity
function isHedgingActive() external view returns (bool);
```

### recoverToken


```solidity
function recoverToken(address token, address to, uint256 amount) external;
```

### recoverETH


```solidity
function recoverETH(address payable to) external;
```

### usdc


```solidity
function usdc() external view returns (IERC20);
```

### oracle


```solidity
function oracle() external view returns (address);
```

### yieldShift


```solidity
function yieldShift() external view returns (address);
```

### minMarginRatio


```solidity
function minMarginRatio() external view returns (uint256);
```

### liquidationThreshold


```solidity
function liquidationThreshold() external view returns (uint256);
```

### maxLeverage


```solidity
function maxLeverage() external view returns (uint256);
```

### liquidationPenalty


```solidity
function liquidationPenalty() external view returns (uint256);
```

### entryFee


```solidity
function entryFee() external view returns (uint256);
```

### exitFee


```solidity
function exitFee() external view returns (uint256);
```

### marginFee


```solidity
function marginFee() external view returns (uint256);
```

### totalMargin


```solidity
function totalMargin() external view returns (uint256);
```

### totalExposure


```solidity
function totalExposure() external view returns (uint256);
```

### activeHedgers


```solidity
function activeHedgers() external view returns (uint256);
```

### nextPositionId


```solidity
function nextPositionId() external view returns (uint256);
```

### eurInterestRate


```solidity
function eurInterestRate() external view returns (uint256);
```

### usdInterestRate


```solidity
function usdInterestRate() external view returns (uint256);
```

### totalYieldEarned


```solidity
function totalYieldEarned() external view returns (uint256);
```

### interestDifferentialPool


```solidity
function interestDifferentialPool() external view returns (uint256);
```

### activePositionCount


```solidity
function activePositionCount(address) external view returns (uint256);
```

### positions


```solidity
function positions(uint256)
    external
    view
    returns (
        address hedger,
        uint256 positionSize,
        uint256 margin,
        uint256 entryPrice,
        uint256 leverage,
        uint256 entryTime,
        uint256 lastUpdateTime,
        int256 unrealizedPnL,
        bool isActive
    );
```

### hedgers


```solidity
function hedgers(address)
    external
    view
    returns (
        uint256[] memory positionIds,
        uint256 totalMargin,
        uint256 totalExposure,
        uint256 pendingRewards,
        uint256 lastRewardClaim,
        bool isActive
    );
```

### hedgerPositions


```solidity
function hedgerPositions(address) external view returns (uint256[] memory);
```

### userPendingYield


```solidity
function userPendingYield(address) external view returns (uint256);
```

### hedgerPendingYield


```solidity
function hedgerPendingYield(address) external view returns (uint256);
```

### userLastClaim


```solidity
function userLastClaim(address) external view returns (uint256);
```

### hedgerLastClaim


```solidity
function hedgerLastClaim(address) external view returns (uint256);
```

### hedgerLastRewardBlock


```solidity
function hedgerLastRewardBlock(address) external view returns (uint256);
```

### liquidationCommitments


```solidity
function liquidationCommitments(bytes32) external view returns (bool);
```

### liquidationCommitmentTimes


```solidity
function liquidationCommitmentTimes(bytes32) external view returns (uint256);
```

### lastLiquidationAttempt


```solidity
function lastLiquidationAttempt(address) external view returns (uint256);
```

### hasPendingLiquidation


```solidity
function hasPendingLiquidation(address, uint256) external view returns (bool);
```

### MAX_POSITIONS_PER_HEDGER


```solidity
function MAX_POSITIONS_PER_HEDGER() external view returns (uint256);
```

### BLOCKS_PER_DAY


```solidity
function BLOCKS_PER_DAY() external view returns (uint256);
```

### MAX_REWARD_PERIOD


```solidity
function MAX_REWARD_PERIOD() external view returns (uint256);
```

### LIQUIDATION_COOLDOWN


```solidity
function LIQUIDATION_COOLDOWN() external view returns (uint256);
```

## Events
### HedgePositionOpened

```solidity
event HedgePositionOpened(
    address indexed hedger,
    uint256 indexed positionId,
    uint256 positionSize,
    uint256 margin,
    uint256 leverage,
    uint256 entryPrice
);
```

### HedgePositionClosed

```solidity
event HedgePositionClosed(
    address indexed hedger, uint256 indexed positionId, uint256 exitPrice, int256 pnl, uint256 timestamp
);
```

### MarginAdded

```solidity
event MarginAdded(address indexed hedger, uint256 indexed positionId, uint256 marginAdded, uint256 newMarginRatio);
```

### MarginRemoved

```solidity
event MarginRemoved(address indexed hedger, uint256 indexed positionId, uint256 marginRemoved, uint256 newMarginRatio);
```

### HedgerLiquidated

```solidity
event HedgerLiquidated(
    address indexed hedger,
    uint256 indexed positionId,
    address indexed liquidator,
    uint256 liquidationReward,
    uint256 remainingMargin
);
```

### HedgingRewardsClaimed

```solidity
event HedgingRewardsClaimed(
    address indexed hedger, uint256 interestDifferential, uint256 yieldShiftRewards, uint256 totalRewards
);
```

