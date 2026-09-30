# Integration Examples

Use the **ethers v6** setup and contract objects from [Quick Start](Quick-Start.md). These examples illustrate client integration; simulate and test them on an isolated fork before use. They are not a guarantee of current liquidity or transaction success.

## Normal redemption

```javascript
const assets = parseUnits('10', 18);
await (await qeuro.approve(vaultAddress, assets)).wait();
const [liquidation] = await vault.shouldTriggerLiquidationLive.staticCall();
if (liquidation) throw new Error('Use the liquidation-specific payout flow');
const quote = await pricing.previewRedeem(assets);
const minUsdc = minimum(quote.amountOut, 50n); // user-selected tolerance
await vault.redeemQEURO.staticCall(assets, minUsdc);
await (await vault.redeemQEURO(assets, minUsdc)).wait();
```

The pricing preview includes redemption fees and may return the module's degraded reference-price quote. It does not include the protocol liquidation-mode formula. The current dapp applies additional quote freshness/capacity gating and may not offer every fallback the contract can execute.

Liquidation redemption distributes proportional backing when the computed ratio is positive and at or below the critical threshold. Build that preview from the current backing and supply, account for the redemption fee, and simulate the actual vault call from the user's account. Never substitute a normal execution quote for a liquidation payout or set a zero minimum merely to bypass a failed quote. Pauses, invalid prices and liquidity limitations still apply.

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

* **UserPool:** batch deposit/withdraw/stake methods accept arrays. Its bookkeeping and unstaking cooldown are not the direct stQEURO flow.
* **HedgerPool:** opening and managing positions requires the designated single hedger. Client-side visibility does not grant that authority. HedgerPool and Hyperliquid margin are separate balances.
* **Yield keeper:** harvesting requires the configured distributor role and valid strategy/liquidity/collateral conditions. Daily scheduling is an operated service, not an autonomous Solidity timer.
* **QTI:** supply is zero and governance is dormant. Examples of lock/propose/vote are API descriptions, not currently usable public governance.
* **Administration:** core default-admin operations require the controller; retained Safe roles and peripheral administration have different paths. Resolve current roles before constructing calls.

## Transaction recovery

Record a submitted transaction hash and check its receipt before retrying. A network timeout does not prove a transaction failed. Reconcile pending/confirmed state and the wallet nonce, then obtain a fresh quote and ask the user to review any changed output. Do not automatically resubmit a deposit or mint after an ambiguous response.

For revert decoding use the ABI matching the active implementation, including relevant library errors. Report stale/invalid pricing, insufficient capacity, pauses, allowances and minimum-output failures separately where the decoded error supports that distinction. Never silently widen a user's tolerance.

See [Production Protocol Reference](Production-Protocol-Reference.md), [API Reference](API-Reference.md) and [Security Guide](Security.md).
