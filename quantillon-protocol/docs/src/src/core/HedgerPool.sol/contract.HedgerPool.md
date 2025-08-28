# HedgerPool
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/996f4133ba7998f0eb28738b06e228de221fcf63/src/core/HedgerPool.sol)

**Inherits:**
Initializable, ReentrancyGuardUpgradeable, AccessControlUpgradeable, PausableUpgradeable, [SecureUpgradeable](/src/core/SecureUpgradeable.sol/abstract.SecureUpgradeable.md)

**Author:**
Quantillon Labs

Manages hedging positions and risk management for the Quantillon protocol

*Main characteristics:
- Leveraged hedging positions against EUR/USD exchange rate movements
- Real-time price oracle integration for position management
- Liquidation mechanisms for risk management
- Yield distribution to hedgers based on interest rate differentials
- Emergency pause mechanism for crisis situations
- Upgradeable via UUPS pattern*

*Hedging mechanics:
- Hedgers can open leveraged positions against EUR/USD movements
- Positions are collateralized with USDC
- Real-time P&L calculation based on oracle prices
- Automatic liquidation when margin ratios fall below threshold
- Liquidation commitment system for MEV protection*

*Risk management:
- Minimum margin ratios and maximum leverage limits
- Liquidation thresholds and penalty mechanisms
- Position size limits per hedger
- Emergency pause capabilities
- Oracle price validation and staleness checks*

*Yield distribution:
- Hedgers earn yield based on interest rate differentials
- Yield shift mechanism for dynamic allocation
- Block-based reward calculations to prevent manipulation
- Claim mechanisms for accumulated rewards*

*Security features:
- Role-based access control for all critical operations
- Reentrancy protection for all external calls
- Emergency pause mechanism for crisis situations
- Upgradeable architecture for future improvements
- Secure liquidation mechanisms
- Oracle price validation*

**Note:**
team@quantillon.money


## State Variables
### GOVERNANCE_ROLE

```solidity
bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
```


### LIQUIDATOR_ROLE

```solidity
bytes32 public constant LIQUIDATOR_ROLE = keccak256("LIQUIDATOR_ROLE");
```


### EMERGENCY_ROLE

```solidity
bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
```


### usdc

```solidity
IERC20 public usdc;
```


### oracle

```solidity
IChainlinkOracle public oracle;
```


### yieldShift

```solidity
IYieldShift public yieldShift;
```


### minMarginRatio

```solidity
uint256 public minMarginRatio;
```


### liquidationThreshold

```solidity
uint256 public liquidationThreshold;
```


### maxLeverage

```solidity
uint256 public maxLeverage;
```


### liquidationPenalty

```solidity
uint256 public liquidationPenalty;
```


### MAX_POSITIONS_PER_HEDGER

```solidity
uint256 public constant MAX_POSITIONS_PER_HEDGER = 50;
```


### activePositionCount

```solidity
mapping(address => uint256) public activePositionCount;
```


### entryFee

```solidity
uint256 public entryFee;
```


### exitFee

```solidity
uint256 public exitFee;
```


### marginFee

```solidity
uint256 public marginFee;
```


### totalMargin

```solidity
uint256 public totalMargin;
```


### totalExposure

```solidity
uint256 public totalExposure;
```


### activeHedgers

```solidity
uint256 public activeHedgers;
```


### nextPositionId

```solidity
uint256 public nextPositionId;
```


### eurInterestRate

```solidity
uint256 public eurInterestRate;
```


### usdInterestRate

```solidity
uint256 public usdInterestRate;
```


### positions

```solidity
mapping(uint256 => HedgePosition) public positions;
```


### hedgers

```solidity
mapping(address => HedgerInfo) public hedgers;
```


### hedgerPositions

```solidity
mapping(address => uint256[]) public hedgerPositions;
```


### totalYieldEarned

```solidity
uint256 public totalYieldEarned;
```


### interestDifferentialPool

```solidity
uint256 public interestDifferentialPool;
```


### userPendingYield

```solidity
mapping(address => uint256) public userPendingYield;
```


### hedgerPendingYield

```solidity
mapping(address => uint256) public hedgerPendingYield;
```


### userLastClaim

```solidity
mapping(address => uint256) public userLastClaim;
```


### hedgerLastClaim

```solidity
mapping(address => uint256) public hedgerLastClaim;
```


### hedgerLastRewardBlock

```solidity
mapping(address => uint256) public hedgerLastRewardBlock;
```


### BLOCKS_PER_DAY

```solidity
uint256 public constant BLOCKS_PER_DAY = 7200;
```


### MAX_REWARD_PERIOD

```solidity
uint256 public constant MAX_REWARD_PERIOD = 365 days;
```


### LIQUIDATION_COOLDOWN

```solidity
uint256 public constant LIQUIDATION_COOLDOWN = 1 hours;
```


### liquidationCommitments

```solidity
mapping(bytes32 => bool) public liquidationCommitments;
```


### liquidationCommitmentTimes

```solidity
mapping(bytes32 => uint256) public liquidationCommitmentTimes;
```


### lastLiquidationAttempt

```solidity
mapping(address => uint256) public lastLiquidationAttempt;
```


### hasPendingLiquidation

```solidity
mapping(address => mapping(uint256 => bool)) public hasPendingLiquidation;
```


## Functions
### constructor


```solidity
constructor();
```

### initialize


```solidity
function initialize(address admin, address _usdc, address _oracle, address _yieldShift, address timelock)
    public
    initializer;
```

### enterHedgePosition


```solidity
function enterHedgePosition(uint256 usdcAmount, uint256 leverage)
    external
    nonReentrant
    whenNotPaused
    returns (uint256 positionId);
```

### exitHedgePosition


```solidity
function exitHedgePosition(uint256 positionId) external nonReentrant whenNotPaused returns (int256 pnl);
```

### _removePositionFromArrays


```solidity
function _removePositionFromArrays(address hedger, uint256 positionId) internal;
```

### addMargin


```solidity
function addMargin(uint256 positionId, uint256 amount) external nonReentrant whenNotPaused;
```

### removeMargin


```solidity
function removeMargin(uint256 positionId, uint256 amount) external nonReentrant whenNotPaused;
```

### commitLiquidation


```solidity
function commitLiquidation(address hedger, uint256 positionId, bytes32 salt) external;
```

### liquidateHedger


```solidity
function liquidateHedger(address hedger, uint256 positionId, bytes32 salt)
    external
    nonReentrant
    returns (uint256 liquidationReward);
```

### claimHedgingRewards


```solidity
function claimHedgingRewards()
    external
    nonReentrant
    returns (uint256 interestDifferential, uint256 yieldShiftRewards, uint256 totalRewards);
```

### _updateHedgerRewards


```solidity
function _updateHedgerRewards(address hedger) internal;
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

### _isPositionLiquidatable


```solidity
function _isPositionLiquidatable(uint256 positionId) internal view returns (bool);
```

### _calculatePnL


```solidity
function _calculatePnL(HedgePosition storage position, uint256 currentPrice) internal view returns (int256);
```

### getTotalHedgeExposure


```solidity
function getTotalHedgeExposure() external view returns (uint256);
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

### hasPendingLiquidationCommitment


```solidity
function hasPendingLiquidationCommitment(address hedger, uint256 positionId) external view returns (bool);
```

### getHedgingConfig


```solidity
function getHedgingConfig()
    external
    view
    returns (
        uint256 minMarginRatio_,
        uint256 liquidationThreshold_,
        uint256 maxLeverage_,
        uint256 liquidationPenalty_,
        uint256 entryFee_,
        uint256 exitFee_
    );
```

### isHedgingActive


```solidity
function isHedgingActive() external view returns (bool);
```

### clearExpiredLiquidationCommitment


```solidity
function clearExpiredLiquidationCommitment(address hedger, uint256 positionId) external;
```

### cancelLiquidationCommitment


```solidity
function cancelLiquidationCommitment(address hedger, uint256 positionId, bytes32 salt) external;
```

### _hasPendingLiquidationCommitment


```solidity
function _hasPendingLiquidationCommitment(address hedger, uint256 positionId) internal view returns (bool);
```

### recoverToken


```solidity
function recoverToken(address token, address to, uint256 amount) external;
```

### recoverETH


```solidity
function recoverETH(address payable to) external;
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

## Structs
### HedgePosition

```solidity
struct HedgePosition {
    address hedger;
    uint256 positionSize;
    uint256 margin;
    uint256 entryPrice;
    uint256 leverage;
    uint256 entryTime;
    uint256 lastUpdateTime;
    int256 unrealizedPnL;
    bool isActive;
}
```

### HedgerInfo

```solidity
struct HedgerInfo {
    uint256[] positionIds;
    uint256 totalMargin;
    uint256 totalExposure;
    uint256 pendingRewards;
    uint256 lastRewardClaim;
    bool isActive;
}
```

