# VaultMath
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/blob/9c66decc017650bbed0d0184c123aef0af402eaf/src/libraries/VaultMath.sol)

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


## Constants
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
### version

Returns the semantic version of this linked library.

On-chain version of the standalone deployed library; bump per semver on any change.
See deployments/{chainId}/versions.json for deployed-address provenance.

**Notes:**
- security: No security implications - returns a compile-time constant.

- validation: No input validation required.

- state-changes: None - pure function.

- events: None.

- errors: None.

- reentrancy: Not applicable - pure function.

- access: Public - anyone can read the version.

- oracle: No oracle dependencies.


```solidity
function version() external pure returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|Semantic version string (e.g. "1.0.0").|


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


