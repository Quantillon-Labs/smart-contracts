# IViewOracle

## Functions
### getEurUsdPrice

Returns EUR/USD oracle price and validity flag

Minimal read-only oracle view interface used by optimization helpers.

**Notes:**
- security: Read-only oracle accessor

- validation: Implementer should guarantee returned values follow protocol expectations

- state-changes: None

- events: None

- errors: Implementation-defined

- reentrancy: Not applicable - view function

- access: External view interface method

- oracle: Primary oracle read dependency


```solidity
function getEurUsdPrice() external view returns (uint256 price, bool isValid);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`price`|`uint256`|EUR/USD price in 18 decimals|
|`isValid`|`bool`|Whether the reported price is valid|


