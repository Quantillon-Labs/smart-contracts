# YieldShift
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/84573e20d663003e9e5ffbb3e1ac29ca4b399f78/src/core/yieldmanagement/YieldShift.sol)

**Inherits:**
Initializable, ReentrancyGuardUpgradeable, AccessControlUpgradeable, PausableUpgradeable, [SecureUpgradeable](/src/core/SecureUpgradeable.sol/abstract.SecureUpgradeable.md)

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

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


### TIME_PROVIDER
TimeProvider contract for centralized time management

*Used to replace direct block.timestamp usage for testability and consistency*


```solidity
TimeProvider public immutable TIME_PROVIDER;
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

Constructor for YieldShift implementation

*Sets up the time provider and disables initialization on implementation for security*

**Notes:**
- security: Validates time provider address and disables initialization on implementation

- validation: Validates time provider is not zero address

- state-changes: Sets time provider and disables initializers

- events: No events emitted

- errors: Throws ZeroAddress if time provider is zero

- reentrancy: Not protected - constructor only

- access: Public constructor

- oracle: No oracle dependencies


```solidity
constructor(TimeProvider _TIME_PROVIDER);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_TIME_PROVIDER`|`TimeProvider`|Address of the time provider contract|


### initialize

Initialize the YieldShift contract

*Sets up the contract with all required addresses and roles*

**Notes:**
- security: Validates all addresses are not zero

- validation: Validates all input addresses

- state-changes: Initializes ReentrancyGuard, AccessControl, and Pausable

- events: Emits initialization events

- errors: Throws if any address is zero

- reentrancy: Protected by initializer modifier

- access: Public initializer

- oracle: No oracle dependencies


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
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|Address of the admin role|
|`_usdc`|`address`|Address of the USDC token contract|
|`_userPool`|`address`|Address of the user pool contract|
|`_hedgerPool`|`address`|Address of the hedger pool contract|
|`_aaveVault`|`address`|Address of the Aave vault contract|
|`_stQEURO`|`address`|Address of the stQEURO token contract|
|`_timelock`|`address`|Address of the timelock contract|
|`_treasury`|`address`|Address of the treasury|


### updateYieldDistribution

Updates the yield distribution between users and hedgers

*Recalculates and applies new yield distribution ratios based on current pool states*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function updateYieldDistribution() external nonReentrant whenNotPaused;
```

### addYield

Add yield from authorized sources

*Adds yield from authorized sources and distributes it according to current yield shift*

**Notes:**
- security: Validates caller is authorized for the yield source

- validation: Validates yield amount is positive and matches actual received

- state-changes: Updates yield sources and total yield generated

- events: Emits YieldAdded event

- errors: Throws if caller is unauthorized or yield amount mismatch

- reentrancy: Protected by nonReentrant modifier

- access: Restricted to authorized yield sources

- oracle: No oracle dependencies


```solidity
function addYield(uint256 yieldAmount, bytes32 source) external nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`yieldAmount`|`uint256`|Amount of yield to add (6 decimals)|
|`source`|`bytes32`|Source identifier for the yield|


### claimUserYield

Claim user yield

*Claims yield for a user after holding period requirements are met*

**Notes:**
- security: Validates caller is authorized and holding period is met

- validation: Validates user has pending yield and meets holding period

- state-changes: Updates user pending yield and transfers USDC

- events: Emits YieldClaimed event

- errors: Throws if caller is unauthorized or holding period not met

- reentrancy: Protected by nonReentrant modifier

- access: Restricted to user or user pool

- oracle: No oracle dependencies


```solidity
function claimUserYield(address user) external nonReentrant returns (uint256 yieldAmount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address of the user to claim yield for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`yieldAmount`|`uint256`|Amount of yield claimed|


### claimHedgerYield

Claim hedger yield

*Claims yield for a hedger*

**Notes:**
- security: Validates caller is authorized

- validation: Validates hedger has pending yield

- state-changes: Updates hedger pending yield and transfers USDC

- events: Emits HedgerYieldClaimed event

- errors: Throws if caller is unauthorized or insufficient yield

- reentrancy: Protected by nonReentrant modifier

- access: Restricted to hedger or hedger pool

- oracle: No oracle dependencies


```solidity
function claimHedgerYield(address hedger) external nonReentrant returns (uint256 yieldAmount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Address of the hedger to claim yield for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`yieldAmount`|`uint256`|Amount of yield claimed|


### _calculateOptimalYieldShift

Calculate optimal yield shift based on current pool ratio

*Calculates optimal yield allocation to incentivize pool balance*

**Notes:**
- security: Uses tolerance checks to prevent excessive adjustments

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe arithmetic used

- reentrancy: Not applicable - view function

- access: Internal function - no access restrictions

- oracle: No oracle dependencies


```solidity
function _calculateOptimalYieldShift(uint256 poolRatio) internal view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`poolRatio`|`uint256`|Current ratio between user and hedger pools (basis points)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Optimal yield shift percentage (basis points)|


### _applyGradualAdjustment

Apply gradual adjustment to yield shift to prevent sudden changes

*Gradually adjusts yield shift based on adjustmentSpeed to prevent volatility*

**Notes:**
- security: Limits adjustment speed to prevent sudden changes

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe arithmetic used

- reentrancy: Not applicable - view function

- access: Internal function - no access restrictions

- oracle: No oracle dependencies


```solidity
function _applyGradualAdjustment(uint256 targetShift) internal view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`targetShift`|`uint256`|Target yield shift percentage (basis points)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Adjusted yield shift percentage (basis points)|


### _getCurrentPoolMetrics

Get current pool metrics

*Returns current pool sizes and ratio for yield shift calculations*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function _getCurrentPoolMetrics()
    internal
    view
    returns (uint256 userPoolSize, uint256 hedgerPoolSize, uint256 poolRatio);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`userPoolSize`|`uint256`|Current user pool size|
|`hedgerPoolSize`|`uint256`|Current hedger pool size|
|`poolRatio`|`uint256`|Ratio of user to hedger pool sizes|


### _getEligiblePoolMetrics

Get eligible pool metrics that only count deposits meeting holding period requirements

*SECURITY: Prevents flash deposit attacks by excluding recent deposits from yield calculations*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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


### _calculateHoldingPeriodDiscount

Calculate holding period discount based on recent deposit activity

*Returns a percentage (in basis points) representing eligible deposits*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function _calculateHoldingPeriodDiscount() internal view returns (uint256 discountBps);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`discountBps`|`uint256`|Discount in basis points (10000 = 100%)|


### _isWithinTolerance

Check if a value is within tolerance of a target value

*Helper function for yield shift calculations*

**Notes:**
- security: Uses safe arithmetic to prevent overflow

- validation: No input validation required - pure function

- state-changes: No state changes - pure function

- events: No events emitted

- errors: No errors thrown - safe arithmetic used

- reentrancy: Not applicable - pure function

- access: Internal function - no access restrictions

- oracle: No oracle dependencies


```solidity
function _isWithinTolerance(uint256 value, uint256 target, uint256 toleranceBps) internal pure returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`value`|`uint256`|The value to check|
|`target`|`uint256`|The target value|
|`toleranceBps`|`uint256`|Tolerance in basis points (e.g., 1000 = 10%)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if value is within tolerance, false otherwise|


### updateLastDepositTime

Updates the last deposit timestamp for a user

*Called by UserPool to track user deposit timing for yield calculations*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function updateLastDepositTime(address user) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The user address to update|


### getCurrentYieldShift

Returns the current yield shift percentage

*Shows how much yield is currently being shifted between pools*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function getCurrentYieldShift() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The current yield shift percentage in basis points|


### getUserPendingYield

Returns the pending yield amount for a specific user

*Calculates unclaimed yield based on user's deposits and current rates*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function getUserPendingYield(address user) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The user address to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The pending yield amount|


### getHedgerPendingYield

Returns the pending yield amount for a specific hedger

*Calculates unclaimed yield based on hedger's positions and current rates*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function getHedgerPendingYield(address hedger) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|The hedger address to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The pending yield amount|


### getTotalYieldGenerated

Returns the total yield generated by the protocol

*Aggregates all yield generated from various sources*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function getTotalYieldGenerated() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The total yield generated|


### getYieldDistributionBreakdown

Returns detailed breakdown of yield distribution

*Shows how yield is allocated between different pools and stakeholders*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function getYieldDistributionBreakdown()
    external
    view
    returns (uint256 userYieldPool_, uint256 hedgerYieldPool_, uint256 distributionRatio);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`userYieldPool_`|`uint256`|Yield allocated to user pool|
|`hedgerYieldPool_`|`uint256`|Yield allocated to hedger pool|
|`distributionRatio`|`uint256`|Current distribution ratio between pools|


### getPoolMetrics

Returns comprehensive metrics for both user and hedger pools

*Provides detailed analytics about pool performance and utilization*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function getPoolMetrics()
    external
    view
    returns (uint256 userPoolSize, uint256 hedgerPoolSize, uint256 poolRatio, uint256 targetRatio);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`userPoolSize`|`uint256`|Total size of user pool|
|`hedgerPoolSize`|`uint256`|Total size of hedger pool|
|`poolRatio`|`uint256`|Current ratio between pools|
|`targetRatio`|`uint256`|Target ratio between pools|


### calculateOptimalYieldShift

Calculates the optimal yield shift based on current market conditions

*Uses algorithms to determine best yield distribution strategy*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function calculateOptimalYieldShift() external view returns (uint256 optimalShift, uint256 currentDeviation);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`optimalShift`|`uint256`|Recommended yield shift percentage|
|`currentDeviation`|`uint256`|Current deviation from optimal shift|


### getYieldSources

Returns information about all yield sources

*Provides details about different yield-generating mechanisms*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function getYieldSources()
    external
    view
    returns (uint256 aaveYield, uint256 protocolFees, uint256 interestDifferential, uint256 otherSources);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`aaveYield`|`uint256`|Yield from Aave protocol|
|`protocolFees`|`uint256`|Protocol fees collected|
|`interestDifferential`|`uint256`|Interest rate differential yield|
|`otherSources`|`uint256`|Other miscellaneous yield sources|


### getHoldingPeriodProtectionStatus

Returns the current holding period protection status

*Useful for monitoring and debugging holding period protection*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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

Returns historical yield shift data for a specified period

*Provides analytics about yield shift patterns over time*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function getHistoricalYieldShift(uint256 period)
    external
    view
    returns (uint256 averageShift, uint256 maxShift, uint256 minShift, uint256 volatility);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`period`|`uint256`|The time period to analyze (in seconds)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`averageShift`|`uint256`|Average yield shift during the period|
|`maxShift`|`uint256`|Maximum yield shift during the period|
|`minShift`|`uint256`|Minimum yield shift during the period|
|`volatility`|`uint256`|Volatility measure of yield shifts|


### getYieldPerformanceMetrics

Returns comprehensive performance metrics for yield operations

*Provides detailed analytics about yield performance and efficiency*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`totalYieldDistributed_`|`uint256`|Total yield distributed to date|
|`averageUserYield`|`uint256`|Average yield for users|
|`averageHedgerYield`|`uint256`|Average yield for hedgers|
|`yieldEfficiency`|`uint256`|Yield efficiency ratio|


### _calculateUserAllocation

Calculate user allocation from current yield shift

*Calculates how much yield should be allocated to users*

**Notes:**
- security: Uses safe arithmetic to prevent overflow

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe arithmetic used

- reentrancy: Not applicable - view function

- access: Internal function - no access restrictions

- oracle: No oracle dependencies


```solidity
function _calculateUserAllocation() internal view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|User allocation amount based on current yield shift percentage|


### _calculateHedgerAllocation

Calculate hedger allocation from current yield shift

*Calculates how much yield should be allocated to hedgers*

**Notes:**
- security: Uses safe arithmetic to prevent overflow

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe arithmetic used

- reentrancy: Not applicable - view function

- access: Internal function - no access restrictions

- oracle: No oracle dependencies


```solidity
function _calculateHedgerAllocation() internal view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Hedger allocation amount based on current yield shift percentage|


### setYieldShiftParameters

Set yield shift parameters

*Sets the base yield shift, maximum yield shift, and adjustment speed*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates yield shift ranges and adjustment speed

- state-changes: Updates yield shift parameters

- events: Emits YieldShiftParametersUpdated event

- errors: Throws if parameters are invalid

- reentrancy: Protected by reentrancy guard

- access: Restricted to governance role

- oracle: No oracle dependencies


```solidity
function setYieldShiftParameters(uint256 _baseYieldShift, uint256 _maxYieldShift, uint256 _adjustmentSpeed) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_baseYieldShift`|`uint256`|Base yield shift percentage in basis points|
|`_maxYieldShift`|`uint256`|Maximum yield shift percentage in basis points|
|`_adjustmentSpeed`|`uint256`|Adjustment speed in basis points|


### setTargetPoolRatio

Sets the target ratio between user and hedger pools

*Governance function to adjust pool balance for optimal yield distribution*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function setTargetPoolRatio(uint256 _targetPoolRatio) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_targetPoolRatio`|`uint256`|The new target pool ratio in basis points|


### authorizeYieldSource

Authorize a yield source for specific yield type

*Authorizes a yield source to add yield of a specific type*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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

*Revokes authorization for a yield source*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function revokeYieldSource(address source) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`source`|`address`|Address of the yield source to revoke|


### updateYieldAllocation

Updates yield allocation for a specific user or hedger

*Called by pools to update individual yield allocations*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function updateYieldAllocation(address user, uint256 amount, bool isUser) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The user or hedger address|
|`amount`|`uint256`|The allocation amount|
|`isUser`|`bool`|True if user, false if hedger|


### emergencyYieldDistribution

Executes emergency yield distribution with specified amounts

*Emergency function to manually distribute yield during critical situations*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function emergencyYieldDistribution(uint256 userAmount, uint256 hedgerAmount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`userAmount`|`uint256`|Amount to distribute to user pool|
|`hedgerAmount`|`uint256`|Amount to distribute to hedger pool|


### pauseYieldDistribution

Pauses all yield distribution operations

*Emergency function to halt yield distribution during critical situations*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function pauseYieldDistribution() external;
```

### resumeYieldDistribution

Resumes yield distribution operations after being paused

*Restarts yield distribution when emergency is resolved*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function resumeYieldDistribution() external;
```

### getYieldShiftConfig

Returns the current yield shift configuration

*Provides access to all yield shift parameters and settings*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function getYieldShiftConfig()
    external
    view
    returns (uint256 baseShift, uint256 maxShift, uint256 adjustmentSpeed_, uint256 lastUpdate);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`baseShift`|`uint256`|Base yield shift percentage|
|`maxShift`|`uint256`|Maximum allowed yield shift|
|`adjustmentSpeed_`|`uint256`|Speed of yield adjustments|
|`lastUpdate`|`uint256`|Timestamp of last configuration update|


### isYieldDistributionActive

Checks if yield distribution is currently active

*Returns false if paused or in emergency mode*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function isYieldDistributionActive() external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if yield distribution is active, false otherwise|


### isYieldSourceAuthorized

Check if a yield source is authorized

Checks if a yield source is authorized for a specific yield type

*Checks if a yield source is authorized for a specific yield type*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data

- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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

Checks current conditions and updates yield distribution if needed

*Automated function to maintain optimal yield distribution*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function checkAndUpdateYieldDistribution() external;
```

### forceUpdateYieldDistribution

Forces an immediate update of yield distribution

*Emergency function to bypass normal update conditions and force distribution*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function forceUpdateYieldDistribution() external;
```

### getTimeWeightedAverage

Get time weighted average of pool history

*Calculates time weighted average of pool history over a specified period*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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
|`period`|`uint256`|Time period for calculation|
|`isUserPool`|`bool`|Whether this is for user pool or hedger pool|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 Time weighted average value|


### _recordPoolSnapshot

Record pool snapshot

*Records current pool metrics as a snapshot for historical tracking*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function _recordPoolSnapshot() internal;
```

### _recordPoolSnapshotWithEligibleSizes

Record pool snapshot using eligible pool sizes to prevent manipulation

*SECURITY: Uses eligible pool sizes that respect holding period requirements*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function _recordPoolSnapshotWithEligibleSizes(uint256 eligibleUserPoolSize, uint256 eligibleHedgerPoolSize) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`eligibleUserPoolSize`|`uint256`|Eligible user pool size for yield calculations|
|`eligibleHedgerPoolSize`|`uint256`|Eligible hedger pool size for yield calculations|


### _addToPoolHistory

Add pool snapshot to history

*Adds a pool snapshot to the history array with size management*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function _addToPoolHistory(PoolSnapshot[] storage poolHistory, uint256 poolSize, bool isUserPool) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`poolHistory`|`PoolSnapshot[]`|Array of pool snapshots to add to|
|`poolSize`|`uint256`|Size of the pool to record|
|`isUserPool`|`bool`|Whether this is for user pool or hedger pool|


### recoverToken

Recovers accidentally sent ERC20 tokens from the contract

*Emergency function to recover tokens that are not part of normal operations*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function recoverToken(address token, uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|The token address to recover|
|`amount`|`uint256`|The amount of tokens to recover|


### recoverETH

Recovers accidentally sent ETH from the contract

*Emergency function to recover ETH that shouldn't be in the contract*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function recoverETH() external;
```

### updateHoldingPeriodProtection

Update holding period protection parameters

*SECURITY: Only governance can update these critical security parameters*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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

