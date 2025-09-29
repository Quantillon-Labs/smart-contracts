# YieldShiftOptimizationLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/71cd41fc9aa7c18638af4654e656fb0dc6b6d493/src/libraries/YieldShiftOptimizationLibrary.sol)

**Author:**
Quantillon Labs

Library for YieldShift pool metrics, historical data, and utility functions

*Extracts utility functions from YieldShift to reduce contract size*


## State Variables
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


### MAX_HISTORY_LENGTH

```solidity
uint256 public constant MAX_HISTORY_LENGTH = 100;
```


## Functions
### getCurrentPoolMetrics

Get current pool metrics

*Returns current pool sizes and ratio for yield shift calculations*

**Notes:**
- No security implications - view function

- Input validation handled by calling contract

- No state changes - view function

- No events emitted

- No errors thrown - view function

- Not applicable - view function

- Public function

- No oracle dependencies


```solidity
function getCurrentPoolMetrics(address userPoolAddress, address hedgerPoolAddress)
    external
    view
    returns (uint256 userPoolSize, uint256 hedgerPoolSize, uint256 poolRatio);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`userPoolAddress`|`address`|Address of the user pool contract|
|`hedgerPoolAddress`|`address`|Address of the hedger pool contract|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`userPoolSize`|`uint256`|Current user pool size|
|`hedgerPoolSize`|`uint256`|Current hedger pool size|
|`poolRatio`|`uint256`|Ratio of user to hedger pool sizes|


### getEligiblePoolMetrics

Get eligible pool metrics that only count deposits meeting holding period requirements

*SECURITY: Prevents flash deposit attacks by excluding recent deposits from yield calculations*

**Notes:**
- Prevents flash deposit attacks by excluding recent deposits

- Input validation handled by calling contract

- No state changes - view function

- No events emitted

- No errors thrown - view function

- Not applicable - view function

- Public function

- No oracle dependencies


```solidity
function getEligiblePoolMetrics(
    address userPoolAddress,
    address hedgerPoolAddress,
    uint256 currentTime,
    uint256 lastUpdateTime
) external view returns (uint256 userPoolSize, uint256 hedgerPoolSize, uint256 poolRatio);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`userPoolAddress`|`address`|Address of the user pool contract|
|`hedgerPoolAddress`|`address`|Address of the hedger pool contract|
|`currentTime`|`uint256`|Current timestamp|
|`lastUpdateTime`|`uint256`|Last update timestamp|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`userPoolSize`|`uint256`|Eligible user pool size (deposits older than MIN_HOLDING_PERIOD)|
|`hedgerPoolSize`|`uint256`|Eligible hedger pool size (deposits older than MIN_HOLDING_PERIOD)|
|`poolRatio`|`uint256`|Ratio of eligible pool sizes|


### calculateEligibleUserPoolSize

Calculate eligible user pool size excluding recent deposits

*Only counts deposits older than MIN_HOLDING_PERIOD*

**Notes:**
- Prevents flash deposit attacks by excluding recent deposits

- Input validation handled by calling contract

- No state changes - pure function

- No events emitted

- No errors thrown - pure function

- Not applicable - pure function

- Public function

- No oracle dependencies


```solidity
function calculateEligibleUserPoolSize(uint256 totalUserPoolSize, uint256 currentTime, uint256 lastUpdateTime)
    external
    pure
    returns (uint256 eligibleSize);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`totalUserPoolSize`|`uint256`|Current total user pool size|
|`currentTime`|`uint256`|Current timestamp|
|`lastUpdateTime`|`uint256`|Last update timestamp|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`eligibleSize`|`uint256`|Eligible pool size for yield calculations|


### _calculateEligibleUserPoolSize

Internal function to calculate eligible user pool size

*Only counts deposits older than MIN_HOLDING_PERIOD*

**Notes:**
- Prevents flash deposit attacks by excluding recent deposits

- Input validation handled by calling function

- No state changes - pure function

- No events emitted

- No errors thrown - pure function

- Not applicable - pure function

- Internal function

- No oracle dependencies


```solidity
function _calculateEligibleUserPoolSize(uint256 totalUserPoolSize, uint256 currentTime, uint256 lastUpdateTime)
    internal
    pure
    returns (uint256 eligibleSize);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`totalUserPoolSize`|`uint256`|Current total user pool size|
|`currentTime`|`uint256`|Current timestamp|
|`lastUpdateTime`|`uint256`|Last update timestamp|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`eligibleSize`|`uint256`|Eligible pool size for yield calculations|


### calculateEligibleHedgerPoolSize

Calculate eligible hedger pool size excluding recent deposits

*Only counts deposits older than MIN_HOLDING_PERIOD*

**Notes:**
- Prevents flash deposit attacks by excluding recent deposits

- Input validation handled by calling contract

- No state changes - pure function

- No events emitted

- No errors thrown - pure function

- Not applicable - pure function

- Public function

- No oracle dependencies


```solidity
function calculateEligibleHedgerPoolSize(uint256 totalHedgerPoolSize, uint256 currentTime, uint256 lastUpdateTime)
    external
    pure
    returns (uint256 eligibleSize);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`totalHedgerPoolSize`|`uint256`|Current total hedger pool size|
|`currentTime`|`uint256`|Current timestamp|
|`lastUpdateTime`|`uint256`|Last update timestamp|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`eligibleSize`|`uint256`|Eligible pool size for yield calculations|


### _calculateEligibleHedgerPoolSize

Internal function to calculate eligible hedger pool size

*Only counts deposits older than MIN_HOLDING_PERIOD*

**Notes:**
- Prevents flash deposit attacks by excluding recent deposits

- Input validation handled by calling function

- No state changes - pure function

- No events emitted

- No errors thrown - pure function

- Not applicable - pure function

- Internal function

- No oracle dependencies


```solidity
function _calculateEligibleHedgerPoolSize(uint256 totalHedgerPoolSize, uint256 currentTime, uint256 lastUpdateTime)
    internal
    pure
    returns (uint256 eligibleSize);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`totalHedgerPoolSize`|`uint256`|Current total hedger pool size|
|`currentTime`|`uint256`|Current timestamp|
|`lastUpdateTime`|`uint256`|Last update timestamp|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`eligibleSize`|`uint256`|Eligible pool size for yield calculations|


### calculateHoldingPeriodDiscount

Calculate holding period discount based on recent deposit activity

*Returns a percentage (in basis points) representing eligible deposits*

**Notes:**
- No security implications - pure calculation function

- Input validation handled by calling contract

- No state changes - pure function

- No events emitted

- No errors thrown - pure function

- Not applicable - pure function

- Public function

- No oracle dependencies


```solidity
function calculateHoldingPeriodDiscount(uint256 currentTime, uint256 lastUpdateTime)
    external
    pure
    returns (uint256 discountBps);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`currentTime`|`uint256`|Current timestamp|
|`lastUpdateTime`|`uint256`|Last update timestamp|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`discountBps`|`uint256`|Discount in basis points (10000 = 100%)|


### _calculateHoldingPeriodDiscount

Internal function to calculate holding period discount

*Returns a percentage (in basis points) representing eligible deposits*

**Notes:**
- No security implications - pure calculation function

- Input validation handled by calling function

- No state changes - pure function

- No events emitted

- No errors thrown - pure function

- Not applicable - pure function

- Internal function

- No oracle dependencies


```solidity
function _calculateHoldingPeriodDiscount(uint256 currentTime, uint256 lastUpdateTime)
    internal
    pure
    returns (uint256 discountBps);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`currentTime`|`uint256`|Current timestamp|
|`lastUpdateTime`|`uint256`|Last update timestamp|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`discountBps`|`uint256`|Discount in basis points (10000 = 100%)|


### getTimeWeightedAverage

Get time weighted average of pool history

*Calculates time weighted average of pool history over a specified period*

**Notes:**
- No security implications - pure calculation function

- Input validation handled by calling contract

- No state changes - pure function

- No events emitted

- No errors thrown - pure function

- Not applicable - pure function

- Public function

- No oracle dependencies


```solidity
function getTimeWeightedAverage(PoolSnapshot[] memory poolHistory, uint256 period, bool isUserPool, uint256 currentTime)
    external
    pure
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`poolHistory`|`PoolSnapshot[]`|Array of pool snapshots|
|`period`|`uint256`|Time period for calculation|
|`isUserPool`|`bool`|Whether this is for user pool or hedger pool|
|`currentTime`|`uint256`|Current timestamp|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Time weighted average value|


### addToPoolHistory

Add pool snapshot to history

*Adds a pool snapshot to the history array with size management*

**Notes:**
- No security implications - pure function

- Input validation handled by calling contract

- No state changes - pure function

- No events emitted

- No errors thrown - pure function

- Not applicable - pure function

- Public function

- No oracle dependencies


```solidity
function addToPoolHistory(PoolSnapshot[] memory poolHistory, uint256 poolSize, bool isUserPool, uint256 currentTime)
    external
    pure
    returns (PoolSnapshot[] memory newHistory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`poolHistory`|`PoolSnapshot[]`|Array of pool snapshots to add to|
|`poolSize`|`uint256`|Size of the pool to record|
|`isUserPool`|`bool`|Whether this is for user pool or hedger pool|
|`currentTime`|`uint256`|Current timestamp|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`newHistory`|`PoolSnapshot[]`|Updated pool history array|


### calculateUserAllocation

Calculate user allocation from current yield shift

*Calculates user allocation based on current yield shift percentage*

**Notes:**
- No security implications - pure calculation function

- Input validation handled by calling contract

- No state changes - pure function

- No events emitted

- No errors thrown - pure function

- Not applicable - pure function

- Public function

- No oracle dependencies


```solidity
function calculateUserAllocation(uint256 userYieldPool, uint256 hedgerYieldPool, uint256 currentYieldShift)
    external
    pure
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`userYieldPool`|`uint256`|Current user yield pool amount|
|`hedgerYieldPool`|`uint256`|Current hedger yield pool amount|
|`currentYieldShift`|`uint256`|Current yield shift percentage|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|User allocation amount based on current yield shift percentage|


### calculateHedgerAllocation

Calculate hedger allocation from current yield shift

*Calculates hedger allocation based on current yield shift percentage*

**Notes:**
- No security implications - pure calculation function

- Input validation handled by calling contract

- No state changes - pure function

- No events emitted

- No errors thrown - pure function

- Not applicable - pure function

- Public function

- No oracle dependencies


```solidity
function calculateHedgerAllocation(uint256 userYieldPool, uint256 hedgerYieldPool, uint256 currentYieldShift)
    external
    pure
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`userYieldPool`|`uint256`|Current user yield pool amount|
|`hedgerYieldPool`|`uint256`|Current hedger yield pool amount|
|`currentYieldShift`|`uint256`|Current yield shift percentage|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Hedger allocation amount based on current yield shift percentage|


### isWithinTolerance

Check if a value is within tolerance of a target value

*Checks if a value is within the specified tolerance of a target*

**Notes:**
- No security implications - pure calculation function

- Input validation handled by calling contract

- No state changes - pure function

- No events emitted

- No errors thrown - pure function

- Not applicable - pure function

- Public function

- No oracle dependencies


```solidity
function isWithinTolerance(uint256 value, uint256 target, uint256 toleranceBps) external pure returns (bool);
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


### calculateHistoricalYieldShift

Calculate historical yield shift metrics

*Calculates statistical metrics for yield shift history*

**Notes:**
- No security implications - pure calculation function

- Input validation handled by calling contract

- No state changes - pure function

- No events emitted

- No errors thrown - pure function

- Not applicable - pure function

- Public function

- No oracle dependencies


```solidity
function calculateHistoricalYieldShift(
    YieldShiftSnapshot[] memory yieldShiftHistory,
    uint256 period,
    uint256 currentTime
) external pure returns (uint256 averageShift, uint256 maxShift, uint256 minShift, uint256 volatility);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`yieldShiftHistory`|`YieldShiftSnapshot[]`|Array of yield shift snapshots|
|`period`|`uint256`|Time period to analyze|
|`currentTime`|`uint256`|Current timestamp|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`averageShift`|`uint256`|Average yield shift during the period|
|`maxShift`|`uint256`|Maximum yield shift during the period|
|`minShift`|`uint256`|Minimum yield shift during the period|
|`volatility`|`uint256`|Volatility measure of yield shifts|


## Structs
### PoolSnapshot

```solidity
struct PoolSnapshot {
    uint64 timestamp;
    uint128 userPoolSize;
    uint128 hedgerPoolSize;
}
```

### YieldShiftSnapshot

```solidity
struct YieldShiftSnapshot {
    uint128 yieldShift;
    uint64 timestamp;
}
```

