# IReferencePriceSource
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/blob/083874330beb67c980851f48832ef5faa68973d3/src/oracle/HyperliquidEurUsdOracle.sol)


## Functions
### peekEurUsdPrice

Reads an independent EUR/USD reference without cached-baseline substitution.

Returns validity, freshness timestamp, and scaled price.

**Notes:**
- security: Read-only reference check.

- validation: Implementations fail closed on stale or invalid rounds.

- state-changes: None.

- events: None.

- errors: Implementations may revert on feed failure.

- reentrancy: None.

- access: Public view.

- oracle: Chainlink EUR/USD.


```solidity
function peekEurUsdPrice() external view returns (uint256 price, uint256 updatedAt, bool isValid);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`price`|`uint256`|EUR/USD price in 18 decimals.|
|`updatedAt`|`uint256`|Feed timestamp.|
|`isValid`|`bool`|Whether the independent feed passed its checks.|
