# Oracle Architecture

## Valuation and execution

Since 17 October 2026, signed reference reports supply the EUR/USD valuation path. **SignedReferenceSource 1.0.0** checks the report signature, original observation time, sequence, epoch and independent Chainlink reference. **HyperliquidEurUsdOracle 1.0.7** consumes that source in OracleRouter's active market slot **1**. ChainlinkOracle in slot **0** remains a manual governance fallback and the USDC/USD source.

Reference valuation is separate from an exact execution quote. SignedExecutionPricing 1.1.0 validates transaction-specific execution authorization and signed hedge-capacity reports. A trade's size-dependent price does not change the valuation of all outstanding QEURO.

## Data flow

```text
Hyperliquid observation -> reference signer -> signed reference report
                                                | delivered with a transaction
                                                v
Chainlink independent reference ----------> SignedReferenceSource
                                                |
                                                v
                                      HyperliquidEurUsdOracle
                                                |
                                                v
                                           OracleRouter
                                                |
                                    Vault / HedgerPool accounting

Exact execution quote + capacity report -> SignedExecutionPricing -> settlement
```

SlippageStorage and the publication batchers are historical deployments; they no longer feed the active signed reference path. The adapter's `slippageStorage()` getter retains its legacy name but now returns SignedReferenceSource. The periodic publisher is retired.

## Freshness and validity

Normal reference and capacity reports have a **60-second** maximum age in the verified configuration. Execution quotes have a separate **45-second** maximum measured from the original market observation. The adapter's 900-second market snapshot limit is an additional check, not permission to use an expired signed report or quote.

Report delivery preserves the original observation timestamp. Replaying an identical report cannot refresh it; an older report cannot overwrite a newer cached reference. Price bounds, independent-reference comparison, USDC validation and circuit breakers remain applicable. A rejected price is not made usable by returning a cached value with `isValid = false`.

The adapter supports the signed source's explicit emergency reference policy, with a configured age ceiling of 8100 seconds and the independent oracle's own validity checks. **Emergency redemption has zero budget and is disabled in the current production configuration.** Ordinary signed quotes cannot use this emergency age window.

## Readiness during inactivity

A stored observation may age while no transaction needs it. Dashboards, keepers and the watchdog can obtain fresh signed reports and simulate their delivery with the relevant read or operation. Those simulations do not persist state and do not spend publication gas. An idle cache alone does not establish that signed delivery is unavailable.

The watchdog monitors fresh delivery and hedge health. Slow but successful probes are distinct from failed readiness checks. A valid signature establishes authorization, not economic accuracy or a completed Hyperliquid fill. Current state can still change between simulation and settlement.

## Fallback and governance

OracleRouter selects one source; it does not automatically fail over. Switching to Chainlink is a governance action and does not, by itself, restore execution quotes, hedge capacity or a paused vault. Normal signed settlement fails closed when required data or authorization is unavailable.

Oracle proxies retain their peripheral administration and upgrade paths. The core controller and Safe have different responsibilities; a signed report grants no administrative role. Confirm live roles before constructing governance calls.

See [Signed Quotes](Signed-Quote-Migration.md), [Execution Pricing](API-Reference.md) and [Deployment Status](Production-Protocol-Reference.md) for the verified release and user-facing behavior.
