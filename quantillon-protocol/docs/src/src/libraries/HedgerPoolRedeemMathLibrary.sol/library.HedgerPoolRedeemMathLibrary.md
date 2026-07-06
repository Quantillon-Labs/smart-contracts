# HedgerPoolRedeemMathLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/blob/9c66decc017650bbed0d0184c123aef0af402eaf/src/libraries/HedgerPoolRedeemMathLibrary.sol)

**Title:**
HedgerPoolRedeemMathLibrary

Externalized math helpers for redemption and realized PnL transitions


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


### calculateRedeemPnL

Computes realized PnL delta for a redemption share.

Derives the realized PnL portion corresponding to `qeuroAmount` being redeemed
from a position with `currentQeuroBacked`, using filled volume and mark price.
Works by:
1. Converting `currentQeuroBacked` to USDC notionals using `price`.
2. Computing total unrealized PnL relative to `filledBefore`.
3. Subtracting `previousRealizedPnL` to get net unrealized.
4. Allocating a proportional share of that PnL to `qeuroAmount`.

**Notes:**
- security: Pure math helper; no direct security impact.

- validation: Assumes `currentQeuroBacked > 0` and `qeuroAmount <= currentQeuroBacked`
are enforced by the caller.

- state-changes: None – pure function.

- events: None.

- errors: None – callers must validate inputs.

- reentrancy: Not applicable – pure function.

- access: Library function; callable from HedgerPool only.

- oracle: Expects `price` to be validated by caller using protocol oracle guards.


```solidity
function calculateRedeemPnL(
    uint256 currentQeuroBacked,
    uint256 filledBefore,
    uint256 price,
    uint256 qeuroAmount,
    int128 previousRealizedPnL
) external pure returns (int256 realizedDelta);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`currentQeuroBacked`|`uint256`|Total QEURO amount currently backed by the position.|
|`filledBefore`|`uint256`|Total filled USDC notionals before redemption.|
|`price`|`uint256`|Current EUR/USD price scaled as in `VaultMath.mulDiv` context (1e30 factor).|
|`qeuroAmount`|`uint256`|QEURO amount being redeemed (share of the position).|
|`previousRealizedPnL`|`int128`|Previously realized PnL stored on the position (signed, 128-bit).|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`realizedDelta`|`int256`|Signed realized PnL delta attributable to this redemption.|


### computeMarginTransition

Computes margin/position totals after applying realized PnL.

Updates per-position and global margin figures after realizing `realizedDelta`.
Handles both profit and loss cases, including full margin wipe-out.
Caps `nextMargin` and `nextPositionSize` to `uint96` max to stay within packing limits.

**Notes:**
- security: Pure math helper; callers must ensure values fit within business invariants.

- validation: Assumes `currentMargin` and `totalMarginBefore` are consistent and that
leverage is a sane protocol value; overflow is bounded by explicit caps.

- state-changes: None – pure function, returns `MarginTransition` for caller to persist.

- events: None.

- errors: None – callers must handle invalid inputs.

- reentrancy: Not applicable – pure function.

- access: Library function; intended for HedgerPool internal use.

- oracle: No direct oracle dependency – uses already-priced PnL delta.


```solidity
function computeMarginTransition(
    uint256 totalMarginBefore,
    uint256 currentMargin,
    uint256 leverage,
    int256 realizedDelta
) external pure returns (MarginTransition memory t);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`totalMarginBefore`|`uint256`|Global total margin across all positions before realization.|
|`currentMargin`|`uint256`|Margin currently allocated to the position being updated.|
|`leverage`|`uint256`|Position leverage used to recompute notional size from margin.|
|`realizedDelta`|`int256`|Signed realized PnL amount to apply to this position.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`t`|`MarginTransition`|Struct encoding new margin, position size, ratio and flags describing outcome.|


## Structs
### MarginTransition

```solidity
struct MarginTransition {
    uint256 totalMarginAfter;
    uint256 nextMargin;
    uint256 nextPositionSize;
    uint256 deltaAmount;
    uint256 newMarginRatio;
    bool isProfit;
    bool marginWiped;
}
```

