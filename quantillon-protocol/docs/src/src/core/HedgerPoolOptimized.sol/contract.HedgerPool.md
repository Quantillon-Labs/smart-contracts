# HedgerPool
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/91f7ed3e8a496e9d369dc182e8f549ec75449a6b/src/core/HedgerPoolOptimized.sol)

**Inherits:**
Initializable, ReentrancyGuardUpgradeable, AccessControlUpgradeable, PausableUpgradeable, [SecureUpgradeable](/src/core/SecureUpgradeable.sol/abstract.SecureUpgradeable.md)

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

Optimized EUR/USD hedging pool for managing currency risk and providing yield

*Optimized version with reduced contract size through library extraction and code consolidation*

**Note:**
security-contact: team@quantillon.money


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


### HEDGER_ROLE

```solidity
bytes32 public constant HEDGER_ROLE = keccak256("HEDGER_ROLE");
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


### treasury

```solidity
address public treasury;
```


### TIME_PROVIDER

```solidity
TimeProvider public immutable TIME_PROVIDER;
```


### coreParams

```solidity
CoreParams public coreParams;
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


### isWhitelistedHedger

```solidity
mapping(address => bool) public isWhitelistedHedger;
```


### hedgerWhitelistEnabled

```solidity
bool public hedgerWhitelistEnabled;
```


### positions

```solidity
mapping(uint256 => HedgePosition) public positions;
```


### hedgers

```solidity
mapping(address => HedgerInfo) public hedgers;
```


### activePositionCount

```solidity
mapping(address => uint256) public activePositionCount;
```


### hedgerHasPosition

```solidity
mapping(address => mapping(uint256 => bool)) public hedgerHasPosition;
```


### positionIndex

```solidity
mapping(address => mapping(uint256 => uint256)) public positionIndex;
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


### hedgerLastRewardBlock

```solidity
mapping(address => uint256) public hedgerLastRewardBlock;
```


### MAX_POSITIONS_PER_HEDGER

```solidity
uint256 public constant MAX_POSITIONS_PER_HEDGER = 50;
```


### MAX_UINT96_VALUE

```solidity
uint96 public constant MAX_UINT96_VALUE = type(uint96).max;
```


### MAX_POSITION_SIZE

```solidity
uint256 public constant MAX_POSITION_SIZE = MAX_UINT96_VALUE;
```


### MAX_MARGIN

```solidity
uint256 public constant MAX_MARGIN = MAX_UINT96_VALUE;
```


### MAX_ENTRY_PRICE

```solidity
uint256 public constant MAX_ENTRY_PRICE = MAX_UINT96_VALUE;
```


### MAX_LEVERAGE

```solidity
uint256 public constant MAX_LEVERAGE = type(uint16).max;
```


### MAX_MARGIN_RATIO

```solidity
uint256 public constant MAX_MARGIN_RATIO = 5000;
```


### MAX_UINT128_VALUE

```solidity
uint128 public constant MAX_UINT128_VALUE = type(uint128).max;
```


### MAX_TOTAL_MARGIN

```solidity
uint256 public constant MAX_TOTAL_MARGIN = MAX_UINT128_VALUE;
```


### MAX_TOTAL_EXPOSURE

```solidity
uint256 public constant MAX_TOTAL_EXPOSURE = MAX_UINT128_VALUE;
```


### MAX_PENDING_REWARDS

```solidity
uint256 public constant MAX_PENDING_REWARDS = MAX_UINT128_VALUE;
```


### LIQUIDATION_COOLDOWN

```solidity
uint256 public constant LIQUIDATION_COOLDOWN = 300;
```


### MAX_REWARD_PERIOD

```solidity
uint256 public constant MAX_REWARD_PERIOD = 365 days;
```


## Functions
### flashLoanProtection


```solidity
modifier flashLoanProtection();
```

### secureNonReentrant


```solidity
modifier secureNonReentrant();
```

### constructor


```solidity
constructor(TimeProvider _TIME_PROVIDER);
```

### initialize


```solidity
function initialize(
    address admin,
    address _usdc,
    address _oracle,
    address _yieldShift,
    address _timelock,
    address _treasury
) public initializer;
```

### enterHedgePosition


```solidity
function enterHedgePosition(uint256 usdcAmount, uint256 leverage)
    external
    secureNonReentrant
    returns (uint256 positionId);
```

### exitHedgePosition


```solidity
function exitHedgePosition(uint256 positionId) external secureNonReentrant returns (int256 pnl);
```

### addMargin


```solidity
function addMargin(uint256 positionId, uint256 amount) external flashLoanProtection;
```

### removeMargin


```solidity
function removeMargin(uint256 positionId, uint256 amount) external flashLoanProtection;
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

### getMaxValues


```solidity
function getMaxValues()
    external
    pure
    returns (
        uint256 maxPositionSize,
        uint256 maxMargin,
        uint256 maxEntryPrice,
        uint256 maxLeverageValue,
        uint256 maxTotalMargin,
        uint256 maxTotalExposure,
        uint256 maxPendingRewards
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

### recoverToken


```solidity
function recoverToken(address token, uint256 amount) external;
```

### recoverETH


```solidity
function recoverETH() external;
```

### updateTreasury


```solidity
function updateTreasury(address _treasury) external;
```

### whitelistHedger


```solidity
function whitelistHedger(address hedger) external;
```

### removeHedger


```solidity
function removeHedger(address hedger) external;
```

### toggleHedgerWhitelistMode


```solidity
function toggleHedgerWhitelistMode(bool enabled) external;
```

### _getValidOraclePrice


```solidity
function _getValidOraclePrice() internal view returns (uint256);
```

### _validateRole


```solidity
function _validateRole(bytes32 role) internal view;
```

### _removePositionFromArrays


```solidity
function _removePositionFromArrays(address hedger, uint256 positionId) internal;
```

### _packPositionOpenData

Internal event data packing functions to reduce contract size


```solidity
function _packPositionOpenData(uint256 positionSize, uint256 margin, uint256 leverage, uint256 entryPrice)
    internal
    pure
    returns (bytes32);
```

### _packPositionCloseData


```solidity
function _packPositionCloseData(uint256 exitPrice, int256 pnl, uint256 timestamp) internal pure returns (bytes32);
```

### _packMarginData


```solidity
function _packMarginData(uint256 marginAmount, uint256 newMarginRatio, bool isAdded) internal pure returns (bytes32);
```

### _packLiquidationData


```solidity
function _packLiquidationData(uint256 liquidationReward, uint256 remainingMargin) internal pure returns (bytes32);
```

### _packRewardData


```solidity
function _packRewardData(uint256 interestDifferential, uint256 yieldShiftRewards, uint256 totalRewards)
    internal
    pure
    returns (bytes32);
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

### HedgerLiquidated

```solidity
event HedgerLiquidated(
    address indexed hedger, uint256 indexed positionId, address indexed liquidator, bytes32 packedData
);
```

### HedgingRewardsClaimed

```solidity
event HedgingRewardsClaimed(address indexed hedger, bytes32 packedData);
```

### HedgerWhitelisted

```solidity
event HedgerWhitelisted(address indexed hedger, address indexed caller);
```

### HedgerRemoved

```solidity
event HedgerRemoved(address indexed hedger, address indexed caller);
```

### HedgerWhitelistModeToggled

```solidity
event HedgerWhitelistModeToggled(bool enabled, address indexed caller);
```

### ETHRecovered

```solidity
event ETHRecovered(address indexed to, uint256 indexed amount);
```

### TreasuryUpdated

```solidity
event TreasuryUpdated(address indexed treasury);
```

## Structs
### CoreParams

```solidity
struct CoreParams {
    uint64 minMarginRatio;
    uint64 liquidationThreshold;
    uint16 maxLeverage;
    uint16 liquidationPenalty;
    uint16 entryFee;
    uint16 exitFee;
    uint16 marginFee;
    uint16 eurInterestRate;
    uint16 usdInterestRate;
    uint8 reserved;
}
```

### HedgePosition

```solidity
struct HedgePosition {
    address hedger;
    uint96 positionSize;
    uint96 margin;
    uint96 entryPrice;
    uint32 entryTime;
    uint32 lastUpdateTime;
    int128 unrealizedPnL;
    uint16 leverage;
    bool isActive;
}
```

### HedgerInfo

```solidity
struct HedgerInfo {
    uint256[] positionIds;
    uint128 totalMargin;
    uint128 totalExposure;
    uint128 pendingRewards;
    uint64 lastRewardClaim;
    bool isActive;
}
```

