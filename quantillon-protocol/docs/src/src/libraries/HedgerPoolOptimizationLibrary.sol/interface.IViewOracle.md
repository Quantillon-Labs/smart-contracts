# IViewOracle
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/0c6311949cabadbce9e79a7dafc6269035f6039e/src/libraries/HedgerPoolOptimizationLibrary.sol)


## Functions
### getEurUsdPrice

Returns EUR/USD oracle price and validity flag

Minimal oracle interface used by optimization helpers.

**Notes:**
- security: Validated oracle accessor

- validation: Implementer should guarantee returned values follow protocol expectations

- state-changes: Implementation-defined; production oracles may refresh their accepted baseline

- events: Implementation-defined

- errors: Implementation-defined

- reentrancy: External oracle call

- access: External interface method

- oracle: Primary oracle read dependency


```solidity
function getEurUsdPrice() external returns (uint256 price, bool isValid);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`price`|`uint256`|EUR/USD price in 18 decimals|
|`isValid`|`bool`|Whether the reported price is valid|


