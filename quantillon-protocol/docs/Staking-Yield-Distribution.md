# Staking Yield Distribution

How yield reaches stQEURO stakers: accrual model, the three-way split, the on-chain functions,
parameters, roles, events, and the operator runbook. Implemented in `QuantillonVault` **v1.1.0**.

> Related: [Multi-Vault Staking Runtime Flow](./Multi-Vault-Staking-Flow.md) ·
> [stQEUROFactory](./stQEUROFactory.md) ·
> [External Vault Onboarding Runbook](./External-Vault-Onboarding-Runbook.md) ·
> decision record / investigation: [stQEURO yield pipeline diagnosis](./stQEURO-yield-pipeline-diagnosis.md).

---

## 1. How stakers accrue yield

`stQEUROToken` is a standard **OpenZeppelin ERC-4626** vault whose underlying asset is **QEURO**,
deployed once per staking vault id by `stQEUROFactory` (e.g. `stQEUROMORPHO1` for `vaultId = 2`).
It does **not** override `totalAssets()`, so:

```
sharePrice = totalAssets() / totalSupply()
           = (QEURO held by the stQEURO contract) / (stQEURO shares outstanding)
```

There is **no rebasing and no claim call**. Stakers earn purely through **share-price appreciation**:
the share price rises whenever QEURO is added to the stQEURO contract **without** minting new shares.
The only function that does this is `QuantillonVault.creditVaultYield`, which mints fresh QEURO
directly to the stQEURO contract. A staker's redeemable QEURO is always `previewRedeem(shares)`.

```
Day 0   stake 1,000 QEURO            -> 1,000 stQEURO   (sharePrice 1.000)
...     yield credited over the year -> sharePrice 1.04
Redeem  1,000 stQEURO                -> 1,040 QEURO
```

> The share price can also **fall** if the protocol ever debits the staked pool to cover hedging
> cost (see §6, case 3). That debit path is **not** in the minimal V1.

---

## 2. The three-way distribution model

All protocol USDC (hedger collateral + the USDC backing user mints) is pooled in a single external
yield vault (currently Morpho on Base). The gross yield `Y` realized from that vault is split, **in
this strict order**:

```
realizedYield Y  (USDC harvested from the adapter, above tracked principal)
│
├─ 1. Hedger funding (FIRST, absolute, time-prorated):
│      hedgerShare = fundingRateAnnualBps * notional * Δt / (10000 * 365 days)
│      notional    = principalUsdcByVaultId[vaultId]   (USDC deployed to this vault)
│      → routed to hedgerYieldRecipient (falls back to treasury)
│
└─ 2. residual = Y − hedgerShare, split by the staking ratio:
       stakedRatio   = stQEURO.totalAssets() / QEURO.totalSupply()
       userShare     = residual * stakedRatio   → creditVaultYield() → stQEURO share price ↑
       treasuryShare = residual − userShare      → treasury (yield on unstaked QEURO)
```

Key properties:

- **Hedger is paid first and is an absolute funding cost**, not a percentage of yield. It reflects
  the perp funding rate (+ optional premium), set manually by governance. This is **different** from
  YieldShift's dynamic pool-ratio split — the funding formula is the policy here.
- **Only the staked fraction of QEURO earns the residual.** The share attributable to unstaked QEURO
  goes to the treasury. With no stakers, the entire residual goes to the treasury.
- **Conservation:** `hedgerShare + userShare + treasuryShare == realizedYield` (every harvested USDC
  is routed).
- **Viability:** the protocol is only worthwhile when `Y > hedging cost`. At launch the funding rate
  is **0** (Quantillon is the sole hedger and bootstraps at a loss), so the entire residual flows to
  stakers/treasury.

---

## 3. On-chain functions

### `QuantillonVault.harvestAndDistributeVaultYield(uint256 vaultId)`
`YIELD_DISTRIBUTOR_ROLE`, `nonReentrant`, `whenNotPaused`. The single entrypoint that runs the model:

1. `realizedYield = adapter.harvestYieldToVault()` — pulls the adapter's yield (the amount above
   tracked principal) into the vault as USDC. Principal is untouched.
2. Anchors the per-vault funding clock (`lastYieldHarvestByVaultId[vaultId]`). **The first call for a
   vault id only anchors the clock** (no hedger accrual, `Δt` undefined).
3. Computes `hedgerShare` (capped at `realizedYield` in V1), `userShare`, `treasuryShare`.
4. Routes hedger → `hedgerYieldRecipient`, user → `creditVaultYield` (mints QEURO into stQEURO),
   remainder → `treasury`.
5. Emits `VaultYieldDistributed(vaultId, realizedYield, hedgerShare, userShare, treasuryShare)`.

Returns `(realizedYield, hedgerShare, userShare, treasuryShare)`.

### `IExternalStakingVault.harvestYieldToVault() → realizedYield`
`VAULT_MANAGER_ROLE` on the adapter (held by the vault). Like `harvestYield()`, but transfers the
realized USDC **to the caller (the vault)** instead of routing to YieldShift, so the vault can apply
the distribution policy. Implemented by all three adapters (Aave / Morpho / MetaMorpho). Realizes only
the excess over `principalDeposited`; leaves principal in the strategy.

### `QuantillonVault.creditVaultYield(uint256 vaultId, uint256 usdcAmount)`
`YIELD_DISTRIBUTOR_ROLE`. Pulls `usdcAmount` USDC from the caller and mints the equivalent QEURO
(at the EUR/USD oracle price, minus the stQEURO `yieldFee`) directly into the stQEURO contract,
raising the share price. Reverts (`NotInitialized`) if the vault has no shares yet. Internally this
shares its core with `harvestAndDistributeVaultYield` (which supplies already-held USDC).

### Legacy `QuantillonVault.harvestVaultYield(uint256 vaultId)`
`GOVERNANCE_ROLE`. The original harvest that routes yield to **YieldShift** (`addYield`). Retained for
the hedger-pool / YieldShift accounting path (`claimHedgerYield`). It does **not** move the stQEURO
share price — prefer `harvestAndDistributeVaultYield` for staker rewards.

---

## 4. Parameters

| Parameter | Type | Setter (role) | Notes |
|---|---|---|---|
| `fundingRateAnnualBps` | `uint256` | `setFundingRateAnnualBps` (`GOVERNANCE_ROLE`) | Annualized hedger funding, bps of notional. **0 at commercial launch**, `50` (0.5%) for staging/tests. Hard cap `MAX_FUNDING_RATE_ANNUAL_BPS = 5000` (50%). |
| `hedgerYieldRecipient` | `address` | `setHedgerYieldRecipient` (`GOVERNANCE_ROLE`) | Recipient of the hedger funding share. Falls back to `treasury` when unset (`address(0)`). |
| `lastYieldHarvestByVaultId[vaultId]` | `mapping` | (internal) | Funding accrual clock; anchored on first distribute call per vault. |

---

## 5. Roles, events, errors

**Roles**
- `YIELD_DISTRIBUTOR_ROLE` — `harvestAndDistributeVaultYield`, `creditVaultYield`. Grant to the
  keeper/operator (or the Safe).
- `GOVERNANCE_ROLE` — parameter setters, `harvestVaultYield`, vault config.
- `VAULT_OPERATOR_ROLE` — `deployUsdcToVault` (move idle held USDC into a strategy).
- `VAULT_MANAGER_ROLE` (on each adapter) — must be held by `QuantillonVault` so it can
  deposit/withdraw/harvest.

**Events**
- `VaultYieldDistributed(vaultId, realizedYield, hedgerShare, userShare, treasuryShare)`
- `FundingRateUpdated(oldRateBps, newRateBps)`
- `HedgerYieldRecipientUpdated(oldRecipient, newRecipient)`
- `ExternalVaultYieldHarvested(vaultId, harvestedYield)` (legacy `harvestVaultYield`)

**Common reverts:** `InvalidVault` (zero/inactive id), `ZeroAddress` (unset adapter/recipient),
`NotInitialized` (crediting a vault with zero stQEURO supply), `AboveLimit` (funding rate > cap).

---

## 6. Scope (V1) and deferred behavior

Implemented (minimal V1):
- Single integrated harvest→distribute call; hedger-first; residual to stakers (share price) +
  treasury; governance funding rate; configurable hedger recipient.

Deferred (documented, **not** built):
- **Case 3 — negative residual / user ponction.** When `Y < hedgerAccrual`, the model says the
  shortfall is taken from the user pool (share price falls below 1.0, hedger always paid, protocol
  stays over-collateralized). V1 instead **caps the hedger share at the realized yield**; the debit
  path does not exist yet. It does not trigger while funding stays below the vault yield (e.g. 0.5%
  funding vs ~4% Morpho).
- **Multi-vault senior/junior tranching** — deducting proportionally more from higher-yielding
  vaults. Out of scope until multiple yield instruments exist.

---

## 7. Operator runbook

One-time, per environment:
1. Deploy the v1.1.0 implementation (upgrade via Safe/Timelock).
2. `setFundingRateAnnualBps(0)` for commercial launch, or `50` for staging.
3. `setHedgerYieldRecipient(<hedger pool / treasury>)` (optional; defaults to treasury).
4. Grant `YIELD_DISTRIBUTOR_ROLE` to the operator (Safe or keeper EOA).
5. Ensure `QuantillonVault` holds `VAULT_MANAGER_ROLE` on the adapter and principal is deployed
   (`deployUsdcToVault`).

Recurring:
- Call `harvestAndDistributeVaultYield(vaultId)` on a schedule (keeper or admin action). The first
  call anchors the funding clock; subsequent calls accrue funding over the elapsed interval.

Verify after a run:
- `VaultYieldDistributed` event values sum to `realizedYield`.
- `stQEURO.convertToAssets(1e18)` increased (share price up).
- `hedgerYieldRecipient` and `treasury` USDC balances increased by their shares.
- `adapter.totalUnderlying() ≈ principalUsdcByVaultId[vaultId]` (yield realized out of the strategy).

---

## Source & tests

- `src/core/QuantillonVault.sol` — `harvestAndDistributeVaultYield`, `creditVaultYield`,
  `_creditVaultYield`, `setFundingRateAnnualBps`, `setHedgerYieldRecipient`.
- `src/interfaces/IExternalStakingVault.sol` + `src/core/vaults/{Aave,Morpho,MetaMorpho}StakingVaultAdapter.sol` — `harvestYieldToVault`.
- `test/StQEUROYieldDistribution.t.sol` — distribution at 0.5% funding (hedger-first, share-price rise, treasury split, conservation, access control).
