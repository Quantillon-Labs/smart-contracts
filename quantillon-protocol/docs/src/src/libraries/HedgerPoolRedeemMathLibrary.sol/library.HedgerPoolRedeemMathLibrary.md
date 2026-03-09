# HedgerPoolRedeemMathLibrary
**Title:**
HedgerPoolRedeemMathLibrary

Externalized math helpers for redemption and realized PnL transitions


## Functions
### calculateRedeemPnL

Computes realized PnL delta for a redemption share.


```solidity
function calculateRedeemPnL(
    uint256 currentQeuroBacked,
    uint256 filledBefore,
    uint256 price,
    uint256 qeuroAmount,
    int128 previousRealizedPnL
) external pure returns (int256 realizedDelta);
```

### computeMarginTransition

Computes margin/position totals after applying realized PnL.


```solidity
function computeMarginTransition(
    uint256 totalMarginBefore,
    uint256 currentMargin,
    uint256 leverage,
    int256 realizedDelta
) external pure returns (MarginTransition memory t);
```

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

