# ISlippageMidSource
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/fdf5f8f6194f4b414785cf5d6e2e583cb790646c/src/oracle/HyperliquidEurUsdOracle.sol)

Minimal read surface of SlippageStorage used by this adapter

Declared narrowly so the adapter depends only on the per-source mid read, letting both the
real SlippageStorage and lightweight test doubles satisfy it without the full interface.
The selector matches ISlippageStorage.getSlippageBySource(uint8).

**Note:**
security-contact: team@quantillon.money


## Functions
### getSlippageBySource

Returns the latest slippage snapshot for a given source id

Narrow read surface so lightweight test doubles can satisfy the adapter without the full SlippageStorage interface.

**Notes:**
- security: No security implications - view function

- validation: No validation - interface definition

- state-changes: No state changes - view function

- events: No events emitted

- errors: No errors thrown

- reentrancy: Not protected - view function

- access: Public - no access restrictions

- oracle: Interface for SlippageStorage reads


```solidity
function getSlippageBySource(uint8 sourceId)
    external
    view
    returns (ISlippageStorage.SlippageSnapshot memory snapshot);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`sourceId`|`uint8`|Source identifier (SOURCE_HYPERLIQUID = 1)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`snapshot`|`ISlippageStorage.SlippageSnapshot`|Latest snapshot; midPrice (18 decimals) and timestamp are used here|


