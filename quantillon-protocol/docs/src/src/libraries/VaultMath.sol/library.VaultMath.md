# VaultMath
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/a0c4605b79826572de49aa1618715c7e4813adad/src/libraries/VaultMath.sol)

**Author:**
Quantillon Labs

Mathematical operations library for Quantillon Protocol

*Provides safe math operations with high precision for financial calculations*

**Note:**
team@quantillon.money


## State Variables
### BASIS_POINTS
Precision for percentage calculations (10000 = 100%)


```solidity
uint256 public constant BASIS_POINTS = 10000;
```


### PRECISION
High precision scalar (18 decimals)


```solidity
uint256 public constant PRECISION = 1e18;
```


### MAX_PERCENTAGE
Maximum allowed percentage (10000%)


```solidity
uint256 public constant MAX_PERCENTAGE = 1000000;
```


## Functions
### mulDiv

Multiply two numbers and divide by a third with rounding


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


### calculateCollateralRatio

Calculate collateralization ratio


```solidity
function calculateCollateralRatio(uint256 collateralValue, uint256 debtValue) internal pure returns (uint256 ratio);
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


### calculateLiquidationPenalty

Calculate liquidation penalty amount


```solidity
function calculateLiquidationPenalty(uint256 collateralAmount, uint256 penaltyRate)
    internal
    pure
    returns (uint256 penalty);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`collateralAmount`|`uint256`|Amount of collateral being liquidated|
|`penaltyRate`|`uint256`|Penalty rate in basis points|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`penalty`|`uint256`|Penalty amount in collateral tokens|


### eurToUsd

Convert EUR amount to USD using exchange rate


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


### usdToEurWithUsdcPrecision

Convert USD amount to EUR using exchange rate with USDC precision handling


```solidity
function usdToEurWithUsdcPrecision(uint256 usdAmount, uint256 eurUsdRate) internal pure returns (uint256 eurAmount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdAmount`|`uint256`|Amount in USD (6 decimals for USDC)|
|`eurUsdRate`|`uint256`|EUR/USD exchange rate (18 decimals)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`eurAmount`|`uint256`|Amount in EUR (18 decimals)|


### eurToUsdWithUsdcPrecision

Convert EUR amount to USD using exchange rate with USDC precision handling


```solidity
function eurToUsdWithUsdcPrecision(uint256 eurAmount, uint256 eurUsdRate) internal pure returns (uint256 usdAmount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`eurAmount`|`uint256`|Amount in EUR (18 decimals)|
|`eurUsdRate`|`uint256`|EUR/USD exchange rate (18 decimals)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`usdAmount`|`uint256`|Amount in USD (6 decimals for USDC)|


### calculateRequiredUsdcCollateral

Calculate required USDC collateral for given QEURO debt amount


```solidity
function calculateRequiredUsdcCollateral(uint256 debtAmount, uint256 eurUsdRate, uint256 collateralRatio)
    internal
    pure
    returns (uint256 requiredCollateral);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`debtAmount`|`uint256`|Debt amount in QEURO (18 decimals)|
|`eurUsdRate`|`uint256`|EUR/USD exchange rate (18 decimals)|
|`collateralRatio`|`uint256`|Required collateral ratio (e.g., 1.01e18 for 101%)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`requiredCollateral`|`uint256`|Required USDC collateral amount (6 decimals)|


### calculateMaxQeuroDebt

Calculate maximum QEURO debt for given USDC collateral


```solidity
function calculateMaxQeuroDebt(uint256 collateralAmount, uint256 eurUsdRate, uint256 collateralRatio)
    internal
    pure
    returns (uint256 maxDebt);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`collateralAmount`|`uint256`|USDC collateral amount (6 decimals)|
|`eurUsdRate`|`uint256`|EUR/USD exchange rate (18 decimals)|
|`collateralRatio`|`uint256`|Required collateral ratio|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`maxDebt`|`uint256`|Maximum QEURO that can be minted (18 decimals)|


### isCollateralSufficient

Check if collateral amount satisfies minimum ratio


```solidity
function isCollateralSufficient(uint256 collateralAmount, uint256 debtAmount, uint256 eurUsdRate, uint256 minRatio)
    internal
    pure
    returns (bool isValid);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`collateralAmount`|`uint256`|USDC collateral amount|
|`debtAmount`|`uint256`|QEURO debt amount|
|`eurUsdRate`|`uint256`|EUR/USD exchange rate|
|`minRatio`|`uint256`|Minimum required ratio|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`isValid`|`bool`|Whether collateral is sufficient|


### calculateYieldDistribution

Calculate yield distribution between users and hedgers


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


### calculateCompoundInterest

Calculate compound interest


```solidity
function calculateCompoundInterest(uint256 principal, uint256 rate, uint256 timeElapsed)
    internal
    pure
    returns (uint256 newPrincipal);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`principal`|`uint256`|Initial principal amount|
|`rate`|`uint256`|Annual interest rate in basis points|
|`timeElapsed`|`uint256`|Time elapsed in seconds|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`newPrincipal`|`uint256`|Principal after compound interest|


### scaleDecimals

Scale a value between different decimal precisions with proper rounding


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


### isWithinTolerance

Check if a value is within a certain percentage of another value


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


