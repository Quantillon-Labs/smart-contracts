# YieldShift
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/0e00532d7586178229ff1180b9b225e8c7a432fb/src/core/yieldmanagement/YieldShift.sol)

**Inherits:**
Initializable, ReentrancyGuardUpgradeable, AccessControlUpgradeable, PausableUpgradeable, [SecureUpgradeable](/src/core/SecureUpgradeable.sol/abstract.SecureUpgradeable.md)

**Author:**
Quantillon Labs

Dynamic yield distribution system balancing rewards between users and hedgers

*Main characteristics:
- Dynamic yield allocation based on pool balance ratios
- Time-weighted average price (TWAP) calculations for stability
- Multiple yield sources integration (Aave, fees, interest differentials)
- Automatic yield distribution with holding period requirements
- Emergency pause mechanism for crisis situations
- Upgradeable via UUPS pattern*

*Yield shift mechanics:
- Base yield shift determines default allocation (default 50/50)
- Maximum yield shift caps allocation changes (default 90/10)
- Adjustment speed controls how quickly shifts occur
- Target pool ratio defines optimal balance point
- Real-time calculations based on pool metrics*

*Distribution algorithm:
- Monitors user pool vs hedger pool size ratios
- Adjusts yield allocation to incentivize balance
- Higher user pool → more yield to hedgers (attract hedging)
- Higher hedger pool → more yield to users (attract deposits)
- Gradual adjustments prevent dramatic shifts*

*Yield sources:
- Aave yield from USDC deposits in lending protocols
- Protocol fees from minting, redemption, and trading
- Interest rate differentials from hedging operations
- External yield farming opportunities
- Authorized source validation for security*

*Time-weighted calculations:
- 24-hour TWAP for pool size measurements
- Historical data tracking for trend analysis
- Maximum history length prevents unbounded storage
- Drift tolerance for timestamp validation
- Automatic data cleanup and optimization*

*Holding period requirements:
- Minimum 7-day holding period for yield claims
- Prevents yield farming attacks and speculation
- Encourages long-term protocol participation
- Tracked per user with deposit timestamps*

*Security features:
- Role-based access control for all critical operations
- Reentrancy protection for all external calls
- Emergency pause mechanism for crisis situations
- Upgradeable architecture for future improvements
- Authorized yield source validation
- Secure yield distribution mechanisms*

*Integration points:
- User pool for deposit and staking metrics
- Hedger pool for hedging exposure metrics
- Aave vault for yield generation and harvesting
- stQEURO token for user yield distribution
- USDC for yield payments and transfers*

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
mapping(bytes32 => uint256) public yieldSources;
```


### yieldSourceNames

```solidity
bytes32[] public yieldSourceNames;
```


### authorizedYieldSources

```solidity
mapping(address => bool) public authorizedYieldSources;
```


### sourceToYieldType

```solidity
mapping(address => bytes32) public sourceToYieldType;
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
function addYield(uint256 yieldAmount, bytes32 source) external nonReentrant;
```

### _addYieldInternal

Internal function to add yield (bypasses authorization for internal calls)


```solidity
function _addYieldInternal(uint256 yieldAmount, bytes32 source) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`yieldAmount`|`uint256`|Amount of yield to add|
|`source`|`bytes32`|Source identifier|


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

### authorizeYieldSource

Authorize a yield source for specific yield type


```solidity
function authorizeYieldSource(address source, bytes32 yieldType) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`source`|`address`|Address of the yield source|
|`yieldType`|`bytes32`|Type of yield this source is authorized for|


### revokeYieldSource

Revoke authorization for a yield source


```solidity
function revokeYieldSource(address source) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`source`|`address`|Address of the yield source to revoke|


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

### isYieldSourceAuthorized

Check if an address is authorized for a specific yield type


```solidity
function isYieldSourceAuthorized(address source, bytes32 yieldType) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`source`|`address`|Address to check|
|`yieldType`|`bytes32`|Yield type to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if authorized|


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
*OPTIMIZED: Indexed timestamp for efficient time-based filtering*


```solidity
event YieldDistributionUpdated(
    uint256 newYieldShift, uint256 userYieldAllocation, uint256 hedgerYieldAllocation, uint256 indexed timestamp
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
*OPTIMIZED: Indexed source and timestamp for efficient filtering*


```solidity
event YieldAdded(uint256 yieldAmount, string indexed source, uint256 indexed timestamp);
```

### YieldShiftParametersUpdated
*OPTIMIZED: Indexed parameter type for efficient filtering*


```solidity
event YieldShiftParametersUpdated(
    string indexed parameterType, uint256 baseYieldShift, uint256 maxYieldShift, uint256 adjustmentSpeed
);
```

### YieldSourceAuthorized

```solidity
event YieldSourceAuthorized(address indexed source, bytes32 indexed yieldType);
```

### YieldSourceRevoked

```solidity
event YieldSourceRevoked(address indexed source);
```

## Structs
### PoolSnapshot
*OPTIMIZED: Packed struct for gas efficiency in historical arrays*


```solidity
struct PoolSnapshot {
    uint128 userPoolSize;
    uint128 hedgerPoolSize;
    uint64 timestamp;
}
```

### YieldShiftSnapshot
*OPTIMIZED: Packed struct for gas efficiency in yield shift tracking*


```solidity
struct YieldShiftSnapshot {
    uint128 yieldShift;
    uint64 timestamp;
}
```

