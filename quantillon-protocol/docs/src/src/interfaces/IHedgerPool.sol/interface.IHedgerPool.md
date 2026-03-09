# IHedgerPool

## Functions
### initialize


```solidity
function initialize(
    address admin,
    address _usdc,
    address _oracle,
    address _yieldShift,
    address _timelock,
    address _treasury,
    address _vault
) external;
```

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

### recordUserMint


```solidity
function recordUserMint(uint256 usdcAmount, uint256 fillPrice, uint256 qeuroAmount) external;
```

### recordUserRedeem


```solidity
function recordUserRedeem(uint256 usdcAmount, uint256 redeemPrice, uint256 qeuroAmount) external;
```

### recordLiquidationRedeem


```solidity
function recordLiquidationRedeem(uint256 qeuroAmount, uint256 totalQeuroSupply) external;
```

### claimHedgingRewards


```solidity
function claimHedgingRewards()
    external
    returns (uint256 interestDifferential, uint256 yieldShiftRewards, uint256 totalRewards);
```

### withdrawPendingRewards


```solidity
function withdrawPendingRewards(address recipient) external;
```

### getTotalEffectiveHedgerCollateral


```solidity
function getTotalEffectiveHedgerCollateral(uint256 currentPrice)
    external
    view
    returns (uint256 totalEffectiveCollateral);
```

### hasActiveHedger


```solidity
function hasActiveHedger() external view returns (bool);
```

### configureRiskAndFees


```solidity
function configureRiskAndFees(HedgerRiskConfig calldata cfg) external;
```

### configureDependencies


```solidity
function configureDependencies(HedgerDependencyConfig calldata cfg) external;
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

### recover


```solidity
function recover(address token, uint256 amount) external;
```

### setSingleHedger


```solidity
function setSingleHedger(address hedger) external;
```

### applySingleHedgerRotation


```solidity
function applySingleHedgerRotation() external;
```

### fundRewardReserve


```solidity
function fundRewardReserve(uint256 amount) external;
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

### vault


```solidity
function vault() external view returns (address);
```

### treasury


```solidity
function treasury() external view returns (address);
```

### coreParams


```solidity
function coreParams()
    external
    view
    returns (
        uint64 minMarginRatio,
        uint16 maxLeverage,
        uint16 entryFee,
        uint16 exitFee,
        uint16 marginFee,
        uint16 eurInterestRate,
        uint16 usdInterestRate,
        uint8 reserved
    );
```

### totalMargin


```solidity
function totalMargin() external view returns (uint256);
```

### totalExposure


```solidity
function totalExposure() external view returns (uint256);
```

### totalFilledExposure


```solidity
function totalFilledExposure() external view returns (uint256);
```

### singleHedger


```solidity
function singleHedger() external view returns (address);
```

### minPositionHoldBlocks


```solidity
function minPositionHoldBlocks() external view returns (uint256);
```

### minMarginAmount


```solidity
function minMarginAmount() external view returns (uint256);
```

### pendingRewardWithdrawals


```solidity
function pendingRewardWithdrawals(address hedger) external view returns (uint256);
```

### feeCollector


```solidity
function feeCollector() external view returns (address);
```

### rewardFeeSplit


```solidity
function rewardFeeSplit() external view returns (uint256);
```

### MAX_REWARD_FEE_SPLIT


```solidity
function MAX_REWARD_FEE_SPLIT() external view returns (uint256);
```

### pendingSingleHedger


```solidity
function pendingSingleHedger() external view returns (address);
```

### singleHedgerPendingAt


```solidity
function singleHedgerPendingAt() external view returns (uint256);
```

### hedgerLastRewardBlock


```solidity
function hedgerLastRewardBlock(address hedger) external view returns (uint256);
```

### positions


```solidity
function positions(uint256 positionId)
    external
    view
    returns (
        address hedger,
        uint96 positionSize,
        uint96 filledVolume,
        uint96 margin,
        uint96 entryPrice,
        uint32 entryTime,
        uint32 lastUpdateTime,
        int128 unrealizedPnL,
        int128 realizedPnL,
        uint16 leverage,
        bool isActive,
        uint128 qeuroBacked,
        uint64 openBlock
    );
```

## Events
### HedgePositionOpened

```solidity
event HedgePositionOpened(address indexed hedger, uint256 indexed positionId, bytes32 packedData);
```

### HedgePositionClosed

```solidity
event HedgePositionClosed(address indexed hedger, uint256 indexed positionId, bytes32 packedData);
```

### MarginUpdated

```solidity
event MarginUpdated(address indexed hedger, uint256 indexed positionId, bytes32 packedData);
```

### HedgingRewardsClaimed

```solidity
event HedgingRewardsClaimed(address indexed hedger, bytes32 packedData);
```

### RewardReserveFunded

```solidity
event RewardReserveFunded(address indexed funder, uint256 amount);
```

### SingleHedgerRotationProposed

```solidity
event SingleHedgerRotationProposed(
    address indexed currentHedger, address indexed pendingHedger, uint256 activatesAt
);
```

### SingleHedgerRotationApplied

```solidity
event SingleHedgerRotationApplied(address indexed previousHedger, address indexed newHedger);
```

## Structs
### HedgerRiskConfig

```solidity
struct HedgerRiskConfig {
    uint256 minMarginRatio;
    uint256 maxLeverage;
    uint256 minPositionHoldBlocks;
    uint256 minMarginAmount;
    uint256 eurInterestRate;
    uint256 usdInterestRate;
    uint256 entryFee;
    uint256 exitFee;
    uint256 marginFee;
    uint256 rewardFeeSplit;
}
```

### HedgerDependencyConfig

```solidity
struct HedgerDependencyConfig {
    address treasury;
    address vault;
    address oracle;
    address yieldShift;
    address feeCollector;
}
```

