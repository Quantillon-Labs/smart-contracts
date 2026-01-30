# VaultMath
**Title:**
VaultMath

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

Mathematical operations library for Quantillon Protocol

This library provides essential mathematical utilities:
- Percentage calculations for fees and yield distributions
- Min/max value selection for safe boundaries
- Decimal scaling utilities for different token precisions

**Note:**
security-contact: team@quantillon.money


## State Variables
### BASIS_POINTS
Precision for percentage calculations (10000 = 100%)


```solidity
uint256 public constant BASIS_POINTS = 10000
```


### PRECISION
High precision scalar (18 decimals)


```solidity
uint256 public constant PRECISION = 1e18
```


### MAX_PERCENTAGE
Maximum allowed percentage (10000%)


```solidity
uint256 public constant MAX_PERCENTAGE = 1000000
```


## Functions
### mulDiv

Multiply two numbers and divide by a third with rounding

Used by percentageOf for fee calculations

**Notes:**
- security: Prevents division by zero and multiplication overflow

- validation: Validates c != 0, checks for multiplication overflow

- state-changes: No state changes - pure function

- events: No events emitted

- errors: Throws "Division by zero" if c is 0, "Multiplication overflow" if overflow

- reentrancy: Not applicable - pure function

- access: Internal function - no access restrictions

- oracle: No oracle dependencies


```solidity
function mulDiv(uint256 a, uint256 b, uint256 c) internal pure returns (uint256 result);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`a`|`uint256`|First number|
|`b`|`uint256`|Second number|
|`c`|`uint256`|Divisor|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`result`|`uint256`|a * b / c with proper rounding|


### percentageOf

Calculate percentage of a value

Used for fee calculations across all contracts

**Notes:**
- security: Prevents percentage overflow and division by zero

- validation: Validates percentage <= MAX_PERCENTAGE

- state-changes: No state changes - pure function

- events: No events emitted

- errors: Throws "Percentage too high" if percentage > MAX_PERCENTAGE

- reentrancy: Not applicable - pure function

- access: Internal function - no access restrictions

- oracle: No oracle dependencies


```solidity
function percentageOf(uint256 value, uint256 percentage) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`value`|`uint256`|Base value|
|`percentage`|`uint256`|Percentage in basis points (e.g., 500 = 5%)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Calculated percentage value|


### scaleDecimals

Scale a value between different decimal precisions with proper rounding

Used for converting between token precisions (e.g., USDC 6 decimals to 18 decimals)

**Notes:**
- security: Pure; no overflow for typical decimals

- validation: fromDecimals/toDecimals are uint8

- state-changes: None

- events: None

- errors: None

- reentrancy: No external calls

- access: Internal library

- oracle: None


```solidity
function scaleDecimals(uint256 value, uint8 fromDecimals, uint8 toDecimals)
    internal
    pure
    returns (uint256 scaledValue);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`value`|`uint256`|Original value|
|`fromDecimals`|`uint8`|Original decimal places|
|`toDecimals`|`uint8`|Target decimal places|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`scaledValue`|`uint256`|Scaled value with proper rounding|


### min

Calculate minimum value between two numbers

Returns the smaller of a and b

**Notes:**
- security: Pure; no overflow

- validation: None

- state-changes: None

- events: None

- errors: None

- reentrancy: No external calls

- access: Internal library

- oracle: None


```solidity
function min(uint256 a, uint256 b) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`a`|`uint256`|First number|
|`b`|`uint256`|Second number|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Minimum value|


### max

Calculate maximum value between two numbers

Returns the larger of a and b

**Notes:**
- security: Pure; no overflow

- validation: None

- state-changes: None

- events: None

- errors: None

- reentrancy: No external calls

- access: Internal library

- oracle: None


```solidity
function max(uint256 a, uint256 b) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`a`|`uint256`|First number|
|`b`|`uint256`|Second number|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Maximum value|


### eurToUsd

Convert EUR amount to USD using exchange rate

usdAmount = eurAmount * eurUsdRate / PRECISION

**Notes:**
- security: Uses mulDiv; no division by zero if rate > 0

- validation: Caller must ensure eurUsdRate > 0

- state-changes: None

- events: None

- errors: None

- reentrancy: No external calls

- access: Internal library

- oracle: Rate passed in; no live oracle


```solidity
function eurToUsd(uint256 eurAmount, uint256 eurUsdRate) internal pure returns (uint256 usdAmount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`eurAmount`|`uint256`|Amount in EUR (18 decimals)|
|`eurUsdRate`|`uint256`|EUR/USD exchange rate (18 decimals)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`usdAmount`|`uint256`|Amount in USD (18 decimals)|


### usdToEur

Convert USD amount to EUR using exchange rate

eurAmount = usdAmount * PRECISION / eurUsdRate

**Notes:**
- security: Uses mulDiv; reverts if eurUsdRate is zero

- validation: Caller must ensure eurUsdRate > 0

- state-changes: None

- events: None

- errors: DivisionByZero if eurUsdRate is 0

- reentrancy: No external calls

- access: Internal library

- oracle: Rate passed in; no live oracle


```solidity
function usdToEur(uint256 usdAmount, uint256 eurUsdRate) internal pure returns (uint256 eurAmount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdAmount`|`uint256`|Amount in USD (18 decimals)|
|`eurUsdRate`|`uint256`|EUR/USD exchange rate (18 decimals)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`eurAmount`|`uint256`|Amount in EUR (18 decimals)|


### calculateCollateralRatio

Calculate collateralization ratio

Returns type(uint256).max when debtValue is zero (infinite ratio)

**Notes:**
- security: Pure; no overflow for typical values

- validation: debtValue 0 returns max

- state-changes: None

- events: None

- errors: None

- reentrancy: No external calls

- access: Internal library

- oracle: None


```solidity
function calculateCollateralRatio(uint256 collateralValue, uint256 debtValue)
    internal
    pure
    returns (uint256 ratio);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`collateralValue`|`uint256`|Total collateral value in USD|
|`debtValue`|`uint256`|Total debt value in USD|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`ratio`|`uint256`|Collateralization ratio in 18 decimals (e.g., 1.5e18 = 150%)|


### calculateYieldDistribution

Calculate yield distribution between users and hedgers

Reverts with InvalidParameter if yieldShiftBps exceeds BASIS_POINTS

**Notes:**
- security: Pure; hedgerYield + userYield = totalYield

- validation: yieldShiftBps <= BASIS_POINTS

- state-changes: None

- events: None

- errors: InvalidParameter if yieldShiftBps > BASIS_POINTS

- reentrancy: No external calls

- access: Internal library

- oracle: None


```solidity
function calculateYieldDistribution(uint256 totalYield, uint256 yieldShiftBps)
    internal
    pure
    returns (uint256 userYield, uint256 hedgerYield);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`totalYield`|`uint256`|Total yield generated|
|`yieldShiftBps`|`uint256`|Yield shift percentage in basis points (0-10000)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`userYield`|`uint256`|Yield allocated to QEURO users|
|`hedgerYield`|`uint256`|Yield allocated to hedgers|


### isWithinTolerance

Check if a value is within a certain percentage of another value

difference <= percentageOf(larger, toleranceBps)

**Notes:**
- security: Pure; uses percentageOf

- validation: toleranceBps <= MAX_PERCENTAGE implied by percentageOf

- state-changes: None

- events: None

- errors: None

- reentrancy: No external calls

- access: Internal library

- oracle: None


```solidity
function isWithinTolerance(uint256 value1, uint256 value2, uint256 toleranceBps) internal pure returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`value1`|`uint256`|First value|
|`value2`|`uint256`|Second value|
|`toleranceBps`|`uint256`|Tolerance in basis points|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|isWithinTolerance Whether values are within tolerance|


