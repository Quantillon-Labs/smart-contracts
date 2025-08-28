# YieldShift
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/9eefa03bf794fa559e611658208a6e8b169d2d57/src/core/yieldmanagement/YieldShift.sol)

**Inherits:**
Initializable, ReentrancyGuardUpgradeable, AccessControlUpgradeable, PausableUpgradeable, [SecureUpgradeable](/src/core/SecureUpgradeable.sol/abstract.SecureUpgradeable.md)


## State Variables
### GOVERNANCE_ROLE

```solidity
bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
```


### YIELD_MANAGER_ROLE

```solidity
bytes32 public constant YIELD_MANAGER_ROLE = keccak256("YIELD_MANAGER_ROLE");
```


### EMERGENCY_ROLE

```solidity
bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
```


### usdc

```solidity
IERC20 public usdc;
```


### userPool

```solidity
IUserPool public userPool;
```


### hedgerPool

```solidity
IHedgerPool public hedgerPool;
```


### aaveVault

```solidity
IAaveVault public aaveVault;
```


### stQEURO

```solidity
IstQEURO public stQEURO;
```


### baseYieldShift

```solidity
uint256 public baseYieldShift;
```


### maxYieldShift

```solidity
uint256 public maxYieldShift;
```


### adjustmentSpeed

```solidity
uint256 public adjustmentSpeed;
```


### targetPoolRatio

```solidity
uint256 public targetPoolRatio;
```


### MIN_HOLDING_PERIOD

```solidity
uint256 public constant MIN_HOLDING_PERIOD = 7 days;
```


### TWAP_PERIOD

```solidity
uint256 public constant TWAP_PERIOD = 24 hours;
```


### MAX_TIME_ELAPSED

```solidity
uint256 public constant MAX_TIME_ELAPSED = 365 days;
```


### currentYieldShift

```solidity
uint256 public currentYieldShift;
```


### lastUpdateTime

```solidity
uint256 public lastUpdateTime;
```


### totalYieldGenerated

```solidity
uint256 public totalYieldGenerated;
```


### totalYieldDistributed

```solidity
uint256 public totalYieldDistributed;
```


### userYieldPool

```solidity
uint256 public userYieldPool;
```


### hedgerYieldPool

```solidity
uint256 public hedgerYieldPool;
```


### yieldSources

```solidity
mapping(string => uint256) public yieldSources;
```


### yieldSourceNames

```solidity
string[] public yieldSourceNames;
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


### lastDepositTime

```solidity
mapping(address => uint256) public lastDepositTime;
```


### userPoolHistory

```solidity
PoolSnapshot[] public userPoolHistory;
```


### hedgerPoolHistory

```solidity
PoolSnapshot[] public hedgerPoolHistory;
```


### MAX_HISTORY_LENGTH

```solidity
uint256 public constant MAX_HISTORY_LENGTH = 1000;
```


### yieldShiftHistory

```solidity
YieldShiftSnapshot[] public yieldShiftHistory;
```


## Functions
### constructor


```solidity
constructor();
```

### initialize


```solidity
function initialize(
    address admin,
    address _usdc,
    address _userPool,
    address _hedgerPool,
    address _aaveVault,
    address _stQEURO,
    address timelock
) public initializer;
```

### updateYieldDistribution


```solidity
function updateYieldDistribution() external nonReentrant whenNotPaused;
```

### addYield


```solidity
function addYield(uint256 yieldAmount, string calldata source) external nonReentrant;
```

### claimUserYield


```solidity
function claimUserYield(address user) external nonReentrant returns (uint256 yieldAmount);
```

### claimHedgerYield


```solidity
function claimHedgerYield(address hedger) external nonReentrant returns (uint256 yieldAmount);
```

### _calculateOptimalYieldShift


```solidity
function _calculateOptimalYieldShift(uint256 poolRatio) internal view returns (uint256);
```

### _applyGradualAdjustment


```solidity
function _applyGradualAdjustment(uint256 targetShift) internal view returns (uint256);
```

### _getCurrentPoolMetrics


```solidity
function _getCurrentPoolMetrics()
    internal
    view
    returns (uint256 userPoolSize, uint256 hedgerPoolSize, uint256 poolRatio);
```

### _isWithinTolerance


```solidity
function _isWithinTolerance(uint256 value, uint256 target, uint256 toleranceBps) internal pure returns (bool);
```

### updateLastDepositTime


```solidity
function updateLastDepositTime(address user) external;
```

### getCurrentYieldShift


```solidity
function getCurrentYieldShift() external view returns (uint256);
```

### getUserPendingYield


```solidity
function getUserPendingYield(address user) external view returns (uint256);
```

### getHedgerPendingYield


```solidity
function getHedgerPendingYield(address hedger) external view returns (uint256);
```

### getTotalYieldGenerated


```solidity
function getTotalYieldGenerated() external view returns (uint256);
```

### getYieldDistributionBreakdown


```solidity
function getYieldDistributionBreakdown()
    external
    view
    returns (uint256 userYieldPool_, uint256 hedgerYieldPool_, uint256 distributionRatio);
```

### getPoolMetrics


```solidity
function getPoolMetrics()
    external
    view
    returns (uint256 userPoolSize, uint256 hedgerPoolSize, uint256 poolRatio, uint256 targetRatio);
```

### calculateOptimalYieldShift


```solidity
function calculateOptimalYieldShift() external view returns (uint256 optimalShift, uint256 currentDeviation);
```

### getYieldSources


```solidity
function getYieldSources()
    external
    view
    returns (uint256 aaveYield, uint256 protocolFees, uint256 interestDifferential, uint256 otherSources);
```

### getHistoricalYieldShift


```solidity
function getHistoricalYieldShift(uint256 period)
    external
    view
    returns (uint256 averageShift, uint256 maxShift, uint256 minShift, uint256 volatility);
```

### getYieldPerformanceMetrics


```solidity
function getYieldPerformanceMetrics()
    external
    view
    returns (
        uint256 totalYieldDistributed_,
        uint256 averageUserYield,
        uint256 averageHedgerYield,
        uint256 yieldEfficiency
    );
```

### _calculateUserAllocation


```solidity
function _calculateUserAllocation() internal view returns (uint256);
```

### _calculateHedgerAllocation


```solidity
function _calculateHedgerAllocation() internal view returns (uint256);
```

### setYieldShiftParameters


```solidity
function setYieldShiftParameters(uint256 _baseYieldShift, uint256 _maxYieldShift, uint256 _adjustmentSpeed) external;
```

### setTargetPoolRatio


```solidity
function setTargetPoolRatio(uint256 _targetPoolRatio) external;
```

### updateYieldAllocation


```solidity
function updateYieldAllocation(address user, uint256 amount, bool isUser) external;
```

### emergencyYieldDistribution


```solidity
function emergencyYieldDistribution(uint256 userAmount, uint256 hedgerAmount) external;
```

### pauseYieldDistribution


```solidity
function pauseYieldDistribution() external;
```

### resumeYieldDistribution


```solidity
function resumeYieldDistribution() external;
```

### getYieldShiftConfig


```solidity
function getYieldShiftConfig()
    external
    view
    returns (uint256 baseShift, uint256 maxShift, uint256 adjustmentSpeed_, uint256 lastUpdate);
```

### isYieldDistributionActive


```solidity
function isYieldDistributionActive() external view returns (bool);
```

### harvestAndDistributeAaveYield


```solidity
function harvestAndDistributeAaveYield() external nonReentrant;
```

### checkAndUpdateYieldDistribution


```solidity
function checkAndUpdateYieldDistribution() external;
```

### forceUpdateYieldDistribution


```solidity
function forceUpdateYieldDistribution() external;
```

### getTimeWeightedAverage


```solidity
function getTimeWeightedAverage(PoolSnapshot[] storage poolHistory, uint256 period, bool isUserPool)
    internal
    view
    returns (uint256);
```

### _recordPoolSnapshot


```solidity
function _recordPoolSnapshot() internal;
```

### _addToPoolHistory


```solidity
function _addToPoolHistory(PoolSnapshot[] storage poolHistory, uint256 poolSize, bool isUserPool) internal;
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
### YieldDistributionUpdated

```solidity
event YieldDistributionUpdated(
    uint256 newYieldShift, uint256 userYieldAllocation, uint256 hedgerYieldAllocation, uint256 timestamp
);
```

### UserYieldClaimed

```solidity
event UserYieldClaimed(address indexed user, uint256 yieldAmount, uint256 timestamp);
```

### HedgerYieldClaimed

```solidity
event HedgerYieldClaimed(address indexed hedger, uint256 yieldAmount, uint256 timestamp);
```

### YieldAdded

```solidity
event YieldAdded(uint256 yieldAmount, string source, uint256 timestamp);
```

### YieldShiftParametersUpdated

```solidity
event YieldShiftParametersUpdated(uint256 baseYieldShift, uint256 maxYieldShift, uint256 adjustmentSpeed);
```

## Structs
### PoolSnapshot

```solidity
struct PoolSnapshot {
    uint256 timestamp;
    uint256 userPoolSize;
    uint256 hedgerPoolSize;
}
```

### YieldShiftSnapshot

```solidity
struct YieldShiftSnapshot {
    uint256 timestamp;
    uint256 yieldShift;
}
```

