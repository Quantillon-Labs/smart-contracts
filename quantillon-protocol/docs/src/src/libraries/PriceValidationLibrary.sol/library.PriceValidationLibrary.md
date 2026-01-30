# PriceValidationLibrary
**Title:**
PriceValidationLibrary

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

Library for price validation and deviation checks

Main characteristics:
- Price deviation checks to prevent flash loan attacks
- Block-based validation for price freshness
- Reduces code duplication across contracts

**Note:**
security-contact: team@quantillon.money


## Functions
### checkPriceDeviation

Checks if price deviation exceeds maximum allowed

Only checks deviation if enough blocks have passed since last update

**Notes:**
- security: Prevents flash loan attacks by validating price deviations

- validation: Validates price changes are within acceptable bounds

- state-changes: No state changes - view function

- events: No events emitted

- errors: No errors thrown - returns boolean flag

- reentrancy: Not applicable - view function

- access: Internal library function - no access restrictions

- oracle: Uses provided price parameters (no direct oracle calls)


```solidity
function checkPriceDeviation(
    uint256 currentPrice,
    uint256 lastValidPrice,
    uint256 maxDeviation,
    uint256 lastUpdateBlock,
    uint256 minBlocksBetweenUpdates
) internal view returns (bool shouldRevert, uint256 deviationBps);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`currentPrice`|`uint256`|Current price from oracle|
|`lastValidPrice`|`uint256`|Last valid cached price|
|`maxDeviation`|`uint256`|Maximum allowed deviation in basis points|
|`lastUpdateBlock`|`uint256`|Block number of last price update|
|`minBlocksBetweenUpdates`|`uint256`|Minimum blocks required between updates|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`shouldRevert`|`bool`|True if deviation check should cause revert|
|`deviationBps`|`uint256`|Calculated deviation in basis points|


