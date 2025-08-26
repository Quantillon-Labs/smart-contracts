# YieldShift
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/c5a08452eb568457f0f8b1c726e5ba978b846461/src/core/yieldmanagement/YieldShift.sol)

**Inherits:**
Initializable, ReentrancyGuardUpgradeable, AccessControlUpgradeable, PausableUpgradeable, UUPSUpgradeable

**Author:**
Quantillon Labs

Dynamic yield redistribution mechanism between Users and Hedgers

*Core innovation of Quantillon Protocol - balances pools via yield incentives*

**Note:**
security-contact: team@quantillon.money


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


### UPGRADER_ROLE

```solidity
bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
```


### usdc
USDC token contract


```solidity
IERC20 public usdc;
```


### userPool
User pool contract


```solidity
IUserPool public userPool;
```


### hedgerPool
Hedger pool contract


```solidity
IHedgerPool public hedgerPool;
```


### aaveVault
Aave vault contract


```solidity
IAaveVault public aaveVault;
```


### stQEURO
stQEURO token contract (primary yield-bearing token)


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
    address _stQEURO
) public initializer;
```

### updateYieldDistribution

Update yield distribution based on time-weighted average pool balances

*Uses TWAP to prevent gaming by large actors*


```solidity
function updateYieldDistribution() external nonReentrant whenNotPaused;
```

### addYield

Add new yield from protocol operations


```solidity
function addYield(uint256 yieldAmount, string calldata source) external onlyRole(YIELD_MANAGER_ROLE) nonReentrant;
```

### claimUserYield

Claim pending yield for a user


```solidity
function claimUserYield(address user) external nonReentrant checkHoldingPeriod returns (uint256 yieldAmount);
```

### claimHedgerYield

Claim pending yield for a hedger


```solidity
function claimHedgerYield(address hedger) external nonReentrant checkHoldingPeriod returns (uint256 yieldAmount);
```

### _calculateOptimalYieldShift

Calculate optimal yield shift based on pool ratio


```solidity
function _calculateOptimalYieldShift(uint256 poolRatio) internal view returns (uint256);
```

### _applyGradualAdjustment

Apply gradual adjustment to avoid sudden shifts


```solidity
function _applyGradualAdjustment(uint256 targetShift) internal view returns (uint256);
```

### _getCurrentPoolMetrics

Get current pool metrics for yield shift calculation


```solidity
function _getCurrentPoolMetrics()
    internal
    view
    returns (uint256 userPoolSize, uint256 hedgerPoolSize, uint256 poolRatio);
```

### _isWithinTolerance

Check if value is within tolerance of target


```solidity
function _isWithinTolerance(uint256 value, uint256 target, uint256 toleranceBps) internal pure returns (bool);
```

### updateLastDepositTime

Update last deposit time for a user


```solidity
function updateLastDepositTime(address user) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|User address|


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
function setYieldShiftParameters(uint256 _baseYieldShift, uint256 _maxYieldShift, uint256 _adjustmentSpeed)
    external
    onlyRole(GOVERNANCE_ROLE);
```

### setTargetPoolRatio


```solidity
function setTargetPoolRatio(uint256 _targetPoolRatio) external onlyRole(GOVERNANCE_ROLE);
```

### updateYieldAllocation


```solidity
function updateYieldAllocation(address user, uint256 amount, bool isUser) external onlyRole(YIELD_MANAGER_ROLE);
```

### emergencyYieldDistribution


```solidity
function emergencyYieldDistribution(uint256 userAmount, uint256 hedgerAmount) external onlyRole(EMERGENCY_ROLE);
```

### pauseYieldDistribution


```solidity
function pauseYieldDistribution() external onlyRole(EMERGENCY_ROLE);
```

### resumeYieldDistribution


```solidity
function resumeYieldDistribution() external onlyRole(EMERGENCY_ROLE);
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

Harvest yield from Aave and distribute automatically


```solidity
function harvestAndDistributeAaveYield() external nonReentrant;
```

### checkAndUpdateYieldDistribution

Update yield distribution if conditions are met

*Uses TWAP and includes holding period checks with bounds checking*


```solidity
function checkAndUpdateYieldDistribution() external;
```

### forceUpdateYieldDistribution

Force update yield distribution (governance only)

*Emergency function to update yield distribution when normal conditions aren't met*


```solidity
function forceUpdateYieldDistribution() external onlyRole(GOVERNANCE_ROLE);
```

### _authorizeUpgrade


```solidity
function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE);
```

### checkHoldingPeriod

Modifier to check minimum holding period with bounds checking


```solidity
modifier checkHoldingPeriod();
```

### getTimeWeightedAverage

Calculate time-weighted average pool size over a specified period


```solidity
function getTimeWeightedAverage(PoolSnapshot[] storage poolHistory, uint256 period, bool isUserPool)
    internal
    view
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`poolHistory`|`PoolSnapshot[]`|Array of pool snapshots|
|`period`|`uint256`|Time period to calculate average over|
|`isUserPool`|`bool`|Whether this is for user pool (true) or hedger pool (false)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Time-weighted average pool size|


### _recordPoolSnapshot

Record current pool sizes in history for TWAP calculations


```solidity
function _recordPoolSnapshot() internal;
```

### _addToPoolHistory

Add snapshot to pool history array


```solidity
function _addToPoolHistory(PoolSnapshot[] storage poolHistory, uint256 poolSize, bool isUserPool) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`poolHistory`|`PoolSnapshot[]`|Array to add snapshot to|
|`poolSize`|`uint256`|Current pool size|
|`isUserPool`|`bool`|Whether this is for user pool (true) or hedger pool (false)|


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

