# Integration Examples

Use the **ethers v6** setup and contract objects from [Quick Start](Quick-Start.md). These examples illustrate client integration; simulate and test them on an isolated fork before use. They are not a guarantee of current liquidity or transaction success.

## Normal redemption

Approve the input QEURO to the same UserPool target used in Quick Start:

```javascript
const inputQeuro = parseUnits('10', 18);
await (await qeuro.approve(poolAddress, inputQeuro)).wait();
```

Then request an executable quote with `action: 'REDEEM'`, `amountIn: inputQeuro.toString()`, `chainId: 8453` and `route: 'USER_POOL'`. Display its exact USDC output and expiry. After review, pass the envelope and the reviewed values to `settleReviewedPoolQuote` from Quick Start, record the returned transaction hash and await its receipt. The function validates that the inner call is precisely `withdraw([inputQeuro], [reviewedUsdcOutput])`.

Normal signed redemption does not use the retired module's degraded-reference fallback. The current emergency-redemption budget is **0 QEURO**, so missing quotes do not automatically open an alternative exit. Protocol liquidation mode uses a separate proportional-backing payout rule, still subject to signed settlement and current contract guards. Never set a zero minimum to bypass an unavailable quote.

## Unstake shares into QEURO

```javascript
const sharesToRedeem = parseUnits('1', 18); // share units, not QEURO assets
const receivedQeuro = await series.redeem.staticCall(sharesToRedeem, owner, owner);
if (receivedQeuro === 0n) throw new Error('Redemption produces no QEURO');
await (await series.redeem(sharesToRedeem, owner, owner)).wait();
```

This returns QEURO, not USDC. A later QEURO-to-USDC redemption is a separate operation with its own quote and approval. Standard ERC-4626 redemption has no minimum-assets argument; simulations do not protect against all intervening state changes. Direct stQEURO redemption is separate from UserPool's unstaking cooldown.

## Portfolio reads

Use `qeuro.balanceOf(owner)` for unstaked QEURO, `series.balanceOf(owner)` for shares and `series.convertToAssets(shares)` for currently recognized assets. Raw assets used in the harvest allocation include unvested credit and can differ from vested ERC-4626 assets.

The provider's APY, UserPool's configured accounting APY, a realized share-price return and future yield are different metrics. Do not label one as a guarantee of another.

## Optional and privileged interfaces

* **UserPool:** deposit and withdrawal inner methods accept arrays and must use the signed wrapper for conversion; optional staking methods have their own accounting. Its bookkeeping and unstaking cooldown are not the direct stQEURO flow.
* **HedgerPool:** reference-dependent position operations use `executeWithReference` or scoped `removeMarginWithReference`, retaining their existing ownership and role checks. Client-side visibility does not grant that authority. HedgerPool and Hyperliquid margin are separate balances.
* **Yield keeper:** harvest conversion uses its bounded signed authorization as well as the configured distributor role and valid strategy/liquidity/collateral conditions. Daily scheduling is an operated service, not an autonomous Solidity timer.
* **QTI:** supply is zero and governance is dormant. Examples of lock/propose/vote are API descriptions, not currently usable public governance.
* **Administration:** core default-admin operations require the controller; retained Safe roles and peripheral administration have different paths. Resolve current roles before constructing calls.

## Transaction recovery

Record a submitted transaction hash and check its receipt before retrying. A network timeout does not prove a transaction failed. Reconcile pending/confirmed state and the wallet nonce, then obtain a fresh quote and ask the user to review any changed output. Do not automatically resubmit a deposit or mint after an ambiguous response.

For revert decoding use the ABI matching the active implementation, including relevant library errors. Report stale/invalid pricing, insufficient capacity, pauses, allowances and minimum-output failures separately where the decoded error supports that distinction. Never silently widen a user's tolerance.

See [Production Protocol Reference](Production-Protocol-Reference.md), [API Reference](API-Reference.md) and [Security Guide](Security.md).
