# YieldShift
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/d7c48fdd1629827b7afa681d6fa8df870ef46184/src/core/yieldmanagement/YieldShift.sol)

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
- Gradual adjustments prevent dramatic shifts
- Flash deposit protection through eligible pool size calculations
- Only deposits meeting holding period requirements count toward yield distribution*

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
- Tracked per user with deposit timestamps
- Enhanced protection against flash deposit manipulation
- Eligible pool sizes exclude recent deposits from yield calculations
- Dynamic discount system based on deposit timing and activity*

*Security features:
- Role-based access control for all critical operations
- Reentrancy protection for all external calls
- Emergency pause mechanism for crisis situations
- Upgradeable architecture for future improvements
- Authorized yield source validation
- Secure yield distribution mechanisms
- Flash deposit attack prevention through holding period requirements
- Eligible pool size calculations for yield distribution
- Time-weighted protection against yield manipulation*

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


### timeProvider
TimeProvider contract for centralized time management

*Used to replace direct block.timestamp usage for testability and consistency*


```solidity
TimeProvider public immutable timeProvider;
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


### treasury

```solidity
address public treasury;
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
constructor(TimeProvider _timeProvider);
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
    address _timelock,
    address _treasury
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

### _getEligiblePoolMetrics

Get eligible pool metrics that only count deposits meeting holding period requirements

*SECURITY: Prevents flash deposit attacks by excluding recent deposits from yield calculations*


```solidity
function _getEligiblePoolMetrics()
    internal
    view
    returns (uint256 userPoolSize, uint256 hedgerPoolSize, uint256 poolRatio);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`userPoolSize`|`uint256`|Eligible user pool size (deposits older than MIN_HOLDING_PERIOD)|
|`hedgerPoolSize`|`uint256`|Eligible hedger pool size (deposits older than MIN_HOLDING_PERIOD)|
|`poolRatio`|`uint256`|Ratio of eligible pool sizes|


### _calculateEligibleUserPoolSize

Calculate eligible user pool size excluding recent deposits

*Only counts deposits older than MIN_HOLDING_PERIOD*


```solidity
function _calculateEligibleUserPoolSize(uint256 totalUserPoolSize) internal view returns (uint256 eligibleSize);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`totalUserPoolSize`|`uint256`|Current total user pool size|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`eligibleSize`|`uint256`|Eligible pool size for yield calculations|


### _calculateEligibleHedgerPoolSize

Calculate eligible hedger pool size excluding recent deposits

*Only counts deposits older than MIN_HOLDING_PERIOD*


```solidity
function _calculateEligibleHedgerPoolSize(uint256 totalHedgerPoolSize) internal view returns (uint256 eligibleSize);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`totalHedgerPoolSize`|`uint256`|Current total hedger pool size|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`eligibleSize`|`uint256`|Eligible pool size for yield calculations|


### _calculateHoldingPeriodDiscount

Calculate holding period discount based on recent deposit activity

*Returns a percentage (in basis points) representing eligible deposits*


```solidity
function _calculateHoldingPeriodDiscount() internal view returns (uint256 discountBps);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`discountBps`|`uint256`|Discount in basis points (10000 = 100%)|


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

### getHoldingPeriodProtectionStatus

Returns the current holding period protection status

*Useful for monitoring and debugging holding period protection*


```solidity
function getHoldingPeriodProtectionStatus()
    external
    view
    returns (uint256 minHoldingPeriod, uint256 baseDiscount, uint256 currentDiscount, uint256 timeSinceLastUpdate);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`minHoldingPeriod`|`uint256`|Current minimum holding period|
|`baseDiscount`|`uint256`|Current base discount percentage|
|`currentDiscount`|`uint256`|Current calculated discount percentage|
|`timeSinceLastUpdate`|`uint256`|Time since last yield distribution update|


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

Check if a yield source is authorized


```solidity
function isYieldSourceAuthorized(address source, bytes32 yieldType) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`source`|`address`|Source address|
|`yieldType`|`bytes32`|Yield type identifier|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if authorized|


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

### _recordPoolSnapshotWithEligibleSizes

Record pool snapshot using eligible pool sizes to prevent manipulation

*SECURITY: Uses eligible pool sizes that respect holding period requirements*


```solidity
function _recordPoolSnapshotWithEligibleSizes(uint256 eligibleUserPoolSize, uint256 eligibleHedgerPoolSize) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`eligibleUserPoolSize`|`uint256`|Eligible user pool size for yield calculations|
|`eligibleHedgerPoolSize`|`uint256`|Eligible hedger pool size for yield calculations|


### _addToPoolHistory


```solidity
function _addToPoolHistory(PoolSnapshot[] storage poolHistory, uint256 poolSize, bool isUserPool) internal;
```

### recoverToken


```solidity
function recoverToken(address token, uint256 amount) external;
```

### recoverETH


```solidity
function recoverETH() external;
```

### updateHoldingPeriodProtection

Update holding period protection parameters

*SECURITY: Only governance can update these critical security parameters*


```solidity
function updateHoldingPeriodProtection(uint256 _minHoldingPeriod, uint256 _baseDiscount, uint256 _maxTimeFactor)
    external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_minHoldingPeriod`|`uint256`|New minimum holding period in seconds|
|`_baseDiscount`|`uint256`|New base discount percentage in basis points|
|`_maxTimeFactor`|`uint256`|New maximum time factor discount in basis points|


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

### HoldingPeriodProtectionUpdated

```solidity
event HoldingPeriodProtectionUpdated(uint256 minHoldingPeriod, uint256 baseDiscount, uint256 maxTimeFactor);
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

