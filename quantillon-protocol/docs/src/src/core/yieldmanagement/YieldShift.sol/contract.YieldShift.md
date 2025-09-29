# YieldShift
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/71cd41fc9aa7c18638af4654e656fb0dc6b6d493/src/core/yieldmanagement/YieldShift.sol)

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
team@quantillon.money


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
- Validates time provider address and disables initialization on implementation

- Validates time provider is not zero address

- Sets time provider and disables initializers

- No events emitted

- Throws ZeroAddress if time provider is zero

- Not protected - constructor only

- Public constructor

- No oracle dependencies


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
- Validates all addresses are not zero

- Validates all input addresses

- Initializes ReentrancyGuard, AccessControl, and Pausable

- Emits initialization events

- Throws if any address is zero

- Protected by initializer modifier

- Public initializer

- No oracle dependencies


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
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function updateYieldDistribution() external nonReentrant whenNotPaused;
```

### addYield

Add yield from authorized sources

*Adds yield from authorized sources and distributes it according to current yield shift*

**Notes:**
- Validates caller is authorized for the yield source

- Validates yield amount is positive and matches actual received

- Updates yield sources and total yield generated

- Emits YieldAdded event

- Throws if caller is unauthorized or yield amount mismatch

- Protected by nonReentrant modifier

- Restricted to authorized yield sources

- No oracle dependencies


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
- Validates caller is authorized and holding period is met

- Validates user has pending yield and meets holding period

- Updates user pending yield and transfers USDC

- Emits YieldClaimed event

- Throws if caller is unauthorized or holding period not met

- Protected by nonReentrant modifier

- Restricted to user or user pool

- No oracle dependencies


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
- Validates caller is authorized

- Validates hedger has pending yield

- Updates hedger pending yield and transfers USDC

- Emits HedgerYieldClaimed event

- Throws if caller is unauthorized or insufficient yield

- Protected by nonReentrant modifier

- Restricted to hedger or hedger pool

- No oracle dependencies


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
- Uses tolerance checks to prevent excessive adjustments

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe arithmetic used

- Not applicable - view function

- Internal function - no access restrictions

- No oracle dependencies


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
- Limits adjustment speed to prevent sudden changes

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe arithmetic used

- Not applicable - view function

- Internal function - no access restrictions

- No oracle dependencies


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
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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
- Uses safe arithmetic to prevent overflow

- No input validation required - pure function

- No state changes - pure function

- No events emitted

- No errors thrown - safe arithmetic used

- Not applicable - pure function

- Internal function - no access restrictions

- No oracle dependencies


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
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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
- Uses safe arithmetic to prevent overflow

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe arithmetic used

- Not applicable - view function

- Internal function - no access restrictions

- No oracle dependencies


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
- Uses safe arithmetic to prevent overflow

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe arithmetic used

- Not applicable - view function

- Internal function - no access restrictions

- No oracle dependencies


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
- Validates input parameters and enforces security checks

- Validates yield shift ranges and adjustment speed

- Updates yield shift parameters

- Emits YieldShiftParametersUpdated event

- Throws if parameters are invalid

- Protected by reentrancy guard

- Restricted to governance role

- No oracle dependencies


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
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function pauseYieldDistribution() external;
```

### resumeYieldDistribution

Resumes yield distribution operations after being paused

*Restarts yield distribution when emergency is resolved*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function resumeYieldDistribution() external;
```

### getYieldShiftConfig

Returns the current yield shift configuration

*Provides access to all yield shift parameters and settings*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data

- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function checkAndUpdateYieldDistribution() external;
```

### forceUpdateYieldDistribution

Forces an immediate update of yield distribution

*Emergency function to bypass normal update conditions and force distribution*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function forceUpdateYieldDistribution() external;
```

### getTimeWeightedAverage

Get time weighted average of pool history

*Calculates time weighted average of pool history over a specified period*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function _recordPoolSnapshot() internal;
```

### _recordPoolSnapshotWithEligibleSizes

Record pool snapshot using eligible pool sizes to prevent manipulation

*SECURITY: Uses eligible pool sizes that respect holding period requirements*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function recoverETH() external;
```

### updateHoldingPeriodProtection

Update holding period protection parameters

*SECURITY: Only governance can update these critical security parameters*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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

