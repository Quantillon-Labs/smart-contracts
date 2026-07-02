# stQEURO Staking Yield Pipeline — Diagnosis & Required Fix

**Status:** Resolved in QuantillonVault v1.1.0 (2026-06-29) — `harvestAndDistributeVaultYield` +
`StakingYieldLibrary` implement the pipeline below; a daily yield-keeper operates it. Kept as the
historical diagnosis that motivated the fix.
**Severity (at diagnosis):** High (core staking value proposition was non-functional).
**Scope:** `QuantillonVault`, `MorphoStakingVaultAdapter`, `YieldShift`, role/ops config.
**Verified against:** Base mainnet (chainId 8453), 2026‑06‑29, block ~47,968,200.
**Author:** investigation via dApp + `../smart-contracts` + on-chain reads.

---

## 1. TL;DR

stQEURO is documented and built as a **yield‑bearing ERC‑4626 whose exchange rate rises** (no claim call). On-chain, that exchange rate is **stuck at exactly 1.000000** for the only live vault (MORPHO1, vaultId 2), so the single existing staker has accrued **0 rewards** despite the underlying Morpho position having earned yield.

Two independent breaks, **both** on the path to the share price:

1. **`harvestVaultYield` has never been run** (0 `ExternalVaultYieldHarvested` events ever), and even when run it routes 100% of yield into **YieldShift**, where the user portion is **unspendable** (the user-claim path was removed post‑audit; `userYieldPool` is documented as "never funded").
2. **`creditVaultYield`** — the *only* function that lifts the stQEURO share price — is **called nowhere** (no UI, no service, no keeper), **`YIELD_DISTRIBUTOR_ROLE` is unassigned** in production, and it pulls USDC **from its caller**, with no link to the harvested USDC sitting in YieldShift.

Net effect: harvested yield can only land somewhere unspendable, and the lever that would reward stakers is unfunded, unroled, and uncalled. **`previewRedeem` stays 1:1 forever** under the current wiring.

> **Update — minimal V1 implemented (QuantillonVault v1.1.0, working tree, not yet deployed):**
> `harvestAndDistributeVaultYield(vaultId)` now realizes adapter yield into the vault (new
> `IExternalStakingVault.harvestYieldToVault()` on all three adapters), carves out the hedger
> funding share first (`fundingRateAnnualBps`, governance-set, time-prorated), credits the
> staked-user share into stQEURO via `creditVaultYield` (rising share price), and sends the
> remainder to `hedgerYieldRecipient` (hedger) and `treasury`. Tested in
> `test/StQEUROYieldDistribution.t.sol` at 0.5% funding; full suite green (1550 passing).
> Still required before it earns: grant `YIELD_DISTRIBUTOR_ROLE` to the operator, set
> `fundingRateAnnualBps` (0 commercial / 50 for staging), and run it on a schedule.
> Out of scope (V2): the negative-residual user ponction (case 3) and multi-vault senior/junior.

---

## 2. Intended design (confirmed)

The design target is **automatic share-price appreciation**, not a claim. Evidence from this repo:

- `docs/src/README.md`: *"stQEUROToken — Yield‑bearing wrapper — Automatic yield accrual via exchange rate, no lock‑up"*; *"UserPool … user yield accrues via stQEURO (no staking‑reward claim)."*
- `docs/API-Reference.md:174`: *"unharvested adapter yield … accrues to stQEURO holders via `harvestVaultYield`/`creditVaultYield`."*
- `docs/API-Reference.md:407`: old user claim *"Removed in the post‑audit cleanup … User yield now accrues automatically through the stQEURO wrapper (rising exchange rate); there is no staking‑reward claim call."*
- `docs/API-Reference.md:749`: *"the user share routes via `creditVaultYield` → stQEURO."*
- `test/StQEUROYieldAndExternalCollateral.t.sol`: grants `YIELD_DISTRIBUTOR_ROLE`, calls `creditVaultYield(VAULT_ID, YIELD_USDC)`, asserts the staker redeems more — i.e. `creditVaultYield` is the canonical share-price lever.

**Conclusion:** keep the share-price model and the existing staking UI. The fix is to make harvested yield actually reach `creditVaultYield` → stQEURO. The exact split is defined in §2a.

---

## 2a. Confirmed distribution model (CEO/CTO standup, 2026‑06‑29)

Single yield instrument for now: **all protocol USDC is pooled in one Morpho vault** (hedger collateral + user-mint collateral). Gross yield `Y` is generated on the whole pool and split **in this strict order**:

**1. Hedgers first — paid unconditionally, no cap.**
- `hedgerAccrual = fundingRateAnnual × hedgedNotional × (Δt / 1yr)` — an **absolute** amount (funding rate as a % of the hedged notional, time-prorated), **not** a % of yield.
- `fundingRateAnnual` is a **governance-set parameter**. **Commercial launch value = 0** (Quantillon is the sole hedger and bootstraps at a loss). **Use 0.5% for tests** — at 0 the mechanism is invisible. *(Action item assigned to CTO: code/test with 0.5%.)*
- The hedger receives this **whatever happens** — no cap, no floor at yield.

**2. If `Y ≥ hedgerAccrual` → `residual = Y − hedgerAccrual`**, split by staking ratio:
- `stakedRatio = stakedQEURO / circulatingQEURO`
- `userShare = residual × stakedRatio` → credited to stQEURO holders via **rising share price** (`creditVaultYield`)
- `treasuryShare = residual − userShare` → **protocol treasury** (yield attributable to unstaked QEURO + hedger collateral)

**3. If `Y < hedgerAccrual` → the shortfall `(hedgerAccrual − Y)` is taken FROM the user pool.**
- The hedger is still paid in full; the **user-pool value drops** → stakers who redeem in that window take a **haircut** (stQEURO share price can fall **below 1.0**).
- The protocol stays **over-collateralized**: the user pool is always covered by the hedger pool. By design it tends toward zero (incentivizing redemption), never negative.
- **Viability condition:** the protocol only makes sense when `Y > hedging cost`; otherwise holding QEURO has negative carry.

**Out of scope (V2):** multi-vault senior/junior tranching (deduct proportionally more from higher-yielding pools). Build **minimal, flat, single-vault** only — per CEO: *"fais le code minimal pour que ça tourne… ça se trouve on va tout changer, n'anticipe pas trop."*

**Implications for the contracts:**
- This split **replaces** YieldShift's dynamic %-split (`currentYieldShift`/`calculateOptimalYieldShift`) for this flow. The policy is the **funding formula** (computed by the keeper/vault), not the pool-ratio algorithm. YieldShift can still serve as the hedger-yield ledger/claim (`claimHedgerYield`), but its auto-split is not the policy.
- `creditVaultYield` can only **add** QEURO (share price up). Case 3 (ponction user) needs the **inverse** — a debit path moving backing from stakers to the hedger pool — which **does not exist today**. At test params (0.5% funding vs ~4% Morpho) it won't trigger, so it can be deferred for the minimal V1, but it is required before any real hedging cost approaches the yield.

---

## 3. Verified on-chain state (Base mainnet)

### Addresses
| Component | Address |
|---|---|
| QuantillonVault | `0x833E5Ba510a241b21F1C60c987D1c49eB52E4a07` |
| stQEUROFactory | `0x0382B0b9FB6Ff737209C3B31D727BB9d2E2bcb53` |
| stQEURO MORPHO1 (vaultId 2) | `0x17CD8ed967d17072297CcAe3D379C9e86aeBEb1d` |
| Morpho adapter (vaultId 2) | `0x103aEBD0059AAA3DcCaa9ab0cCb901382Bd48978` |
| YieldShift | `0xdcd66568F8623bDa3387287c31F14b43e49665b1` |
| QEURO | `0x69aD4e6c49d6275D0e11b5515D98a89f029869AA` |
| Safe / Multisig | `0x1d7fF432a93d0085Fb69474c7E567f859829e6cd` |
| Timelock | `0x7Ade8f3Bf1FdaF0785efE9Ea5C6339D1aD6B8342` |

### The vault & its only staker
- stQEURO MORPHO1: `totalSupply = 15e18`, `totalAssets = 15e18`, `QEURO.balanceOf(stQEURO) = 15e18`, **share price = 1.000000**, `yieldFee = 0`, not paused.
- Only registered vault is id 2 (`getVaultIdsByVault(QuantillonVault) = [2]`; ids 0,1,3–6 → `0x0`). UI lists AAVE (id1) and MORPHO2 (id3) as "active" but they are **not deployed**.
- Sole staker `0x8DAD1B6c1A40e2649d50952977b5af1992f098d1` (an EIP‑7702 smart‑account EOA — code `0xef0100…`):
  - **3 QEURO** on 2026‑05‑19 11:38:59 UTC — block 46,200,696 — tx `0x48062637d3446e9f57e2b194dd2c7d592f56cfb0506e85ed59c506fc9c41f5fa`
  - **12 QEURO** on 2026‑05‑28 08:00:19 UTC — block 46,582,936 — tx `0xd7b2bcd6bde8a362cd7f1a1579043b8817d6e44a5563e3a7ac9e20b758b95902`
  - Holds 15 stQEUROMORPHO1 (= 100% of supply). No withdrawals.
  - `previewRedeem(15e18) = 15e18` → **rewards if redeemed now = 0**.

### External strategy *has* earned yield (just not credited)
- Adapter `principalDeposited = 21,158,260` (21.15826 USDC); `totalUnderlying = 21,243,721` (21.243721 USDC) → **harvestable yield ≈ 0.0855 USDC** (still growing between reads).
- QuantillonVault: `defaultStakingVaultId = 2`; `totalUsdcHeld = 5.0 USDC`; `totalUsdcInExternalVaults = 21.15826 USDC`; `totalMinted = 18.2064 QEURO`.

### Pipeline configuration status
| Leg | Configured | Ever run |
|---|---|---|
| `deployUsdcToVault(2)` | ✅ (21.16 USDC deployed) | ✅ |
| Morpho accrues yield | ✅ | ✅ (+0.0855 USDC) |
| `harvestVaultYield(2)` [GOVERNANCE_ROLE] | ✅ Safe has role; adapter authorized in YieldShift, bound to vaultId 2; QuantillonVault has `VAULT_MANAGER_ROLE` on adapter | ❌ **0 events ever** |
| `adapter.harvestYield()` destination | ✅ → routes USDC to **YieldShift** (`addYield`) | ❌ |
| `creditVaultYield(2, …)` [YIELD_DISTRIBUTOR_ROLE] — **lifts share price** | ❌ unexposed; **role unassigned** | ❌ |

### Role check (QuantillonVault)
| Holder | GOVERNANCE | YIELD_DISTRIBUTOR | VAULT_OPERATOR |
|---|---|---|---|
| Safe `0x1d7f…` | ✅ true | ❌ false | ❌ false |
| Timelock `0x7Ade…` | ❌ false | ❌ false | ❌ false |

> `VAULT_OPERATOR_ROLE` is also not on Safe/Timelock yet 21 USDC was deployed → a separate deployer/keeper EOA holds it. `YIELD_DISTRIBUTOR_ROLE` appears unassigned entirely (held by neither governance address; never used).

Role hashes: `GOVERNANCE_ROLE=0x71840dc4…`, `YIELD_DISTRIBUTOR_ROLE=0x30cc2fca…`, `VAULT_OPERATOR_ROLE=0x696e8788…`, `VAULT_MANAGER_ROLE=0xd1473398…`.

---

## 4. Root cause

The documented "user share routes via `creditVaultYield` → stQEURO" is **not plumbed end-to-end**:

1. `MorphoStakingVaultAdapter.harvestYield()` (`src/core/vaults/MorphoStakingVaultAdapter.sol:185`) withdraws the excess over principal and sends it to **YieldShift** via `addYield(yieldVaultId, harvestedYield, "morpho")`.
2. Inside YieldShift the "user" slice is **dead**: the user-claim function was removed post‑audit and `userYieldPool` is documented as never funded; only `claimHedgerYield` remains. So the user slice is stranded.
3. `QuantillonVault.creditVaultYield()` (`src/core/QuantillonVault.sol:1775`) is what mints QEURO into the stQEURO token (`qeuro.mint(stToken, qeuroMinted)` at line 1816), raising the share price — but it pulls `usdcAmount` via `safeTransferFrom(msg.sender, …)`. **There is no on-chain or off-chain path that moves the harvested user-share USDC from YieldShift into a `creditVaultYield` call.**
4. Operationally: `YIELD_DISTRIBUTOR_ROLE` is unassigned, and `creditVaultYield` is invoked by no UI/service/keeper. `harvestVaultYield` itself has never been called.

**Why a backend-only fix is insufficient:** harvesting pushes USDC into YieldShift (stranded), while `creditVaultYield` needs USDC *in the caller's hands*. Without a contract change, the only way to fund `creditVaultYield` is from treasury USDC — a subsidy that lifts the share price but never realizes the adapter yield (which keeps accumulating in Morpho). That is accounting-incorrect as a steady state.

---

## 5. Recommended fix (contracts)

Add a governance/keeper-callable path that composes harvest + credit so the **user share of realized adapter yield lands in stQEURO as share-price**, and only the **hedger share** goes to YieldShift.

### 5.1 Adapter change
Add a method that realizes yield **to the vault** instead of YieldShift, e.g.:

```solidity
// MorphoStakingVaultAdapter
// Withdraw (currentUnderlying - principalDeposited) and transfer USDC to msg.sender (the vault),
// returning the realized amount. Principal unchanged. Restricted to VAULT_MANAGER_ROLE.
function harvestYieldToVault() external onlyRole(VAULT_MANAGER_ROLE) nonReentrant returns (uint256 realizedYield);
```

(Equivalently, parameterize the existing `harvestYield` with a destination, but a distinct method avoids touching the YieldShift-routing path used elsewhere.)

### 5.2 Vault change

Implement the §2a split (hedger-first, no cap; residual by staking ratio; remainder to treasury):

```solidity
// QuantillonVault
// 1. realizedYield  = adapter.harvestYieldToVault()                 // USDC now held by the vault
// 2. hedgerAccrual  = fundingRateAnnual * hedgedNotional * dt / 1yr  // ABSOLUTE, not % of yield; no cap
//    -> route hedgerAccrual to the hedger pool (YieldShift hedger ledger / claimHedgerYield)
// 3. if realizedYield >= hedgerAccrual:
//        residual     = realizedYield - hedgerAccrual
//        userShare    = residual * stakedQEURO / circulatingQEURO
//        treasuryShare = residual - userShare
//        creditVaultYield(vaultId, userShare)  // mint QEURO into stQEURO (share price up)
//        send treasuryShare to treasury
//    else:  // shortfall — V2: debit user pool by (hedgerAccrual - realizedYield); does NOT trigger at test params
//        (out of minimal V1 scope; see §2a case 3)
// fundingRateAnnual is governance-set: 0 commercial, 0.5% for tests.
function harvestAndDistributeVaultYield(uint256 vaultId)
    external
    onlyRole(GOVERNANCE_ROLE) /* or a dedicated YIELD_KEEPER_ROLE */
    nonReentrant
    returns (uint256 userCreditedQeuro, uint256 hedgerPaidUsdc, uint256 treasuryUsdc);
```

> The hedger share is computed by the **funding formula**, not by `YieldShift.addYield`'s internal %-split — do not route it through `currentYieldShift`. `stakedQEURO` = `stQEURO.totalAssets()` (QEURO backing the staked series); `circulatingQEURO` = `QEURO.totalSupply()` (or `totalMinted`). Confirm the exact denominator with the team.

This removes the USDC-sourcing mismatch (no external distributor USDC needed) and removes the YieldShift round-trip for the user portion.

### 5.3 Ops to close regardless of code
- Add a governance-set `fundingRateAnnual` parameter (§2a): **0 for commercial launch, 0.5% for tests**.
- Grant `YIELD_DISTRIBUTOR_ROLE` (and/or a new `YIELD_KEEPER_ROLE`) to the operator (Safe or keeper EOA) via the Safe.
- Stand up a schedule/keeper to call the harvest+distribute (no automation exists today).

### 5.4 Acceptance criteria
- After `harvestAndCreditVaultYield(2)`:
  - `convertToAssets(1e18) > 1e18` and staker `previewRedeem(15e18) > 15e18`.
  - stQEURO `totalAssets` increases by the credited QEURO; `QEURO.balanceOf(stQEURO)` rises in lockstep.
  - `adapter.totalUnderlying() ≈ principalDeposited` (yield realized out of Morpho).
  - YieldShift hedger pool increases by **hedger share only**.
  - Collateralization invariant holds: QEURO minted to stQEURO is matched by USDC added to `totalUsdcHeld` (no unbacked QEURO — same guard that retired the old UserPool claim).
- Add a Foundry test mirroring `StQEUROYieldAndExternalCollateral.t.sol` that drives Morpho yield, calls `harvestAndCreditVaultYield`, and asserts the staker's redeemable QEURO increased by the user share.

---

## 6. Alternatives considered

- **Backend keeper / admin button funding `creditVaultYield` from treasury USDC** — no contract change; rewards the current staker immediately; but it is a treasury subsidy, the adapter yield stays stranded, and it still needs the role grant + USDC approvals. Acceptable as a short-term bridge, not the steady state.
- **Switch UI to a YieldShift "claim" model** — rejected: contradicts the documented design; the user-claim path was deliberately removed post‑audit.

---

## 7. Secondary issues found (lower priority)

- The admin **"Harvest Yield"** button (`src/components/admin/StakingVaultsPanel.tsx`) calls `harvestVaultYield` only — under current contracts this routes to YieldShift and **does not benefit stQEURO stakers**, which can mislead operators into thinking stakers were paid.
- The staking page's **"Yield Accruing"** badge is hardcoded (`src/components/QEUROStaking.tsx`) — it should be gated on `sharePrice > 1`.
- Vaults **AAVE (id1)** and **MORPHO2 (id3)** render as active in the marketplace but are not deployed on-chain (factory returns `0x0`); staking is correctly disabled at runtime, but they should be hidden/labeled.

---

## 8. Reproduction (read-only)

All facts above were obtained with `cast call` / `eth_getLogs` against Base mainnet. Key checks:
- `stQEURO.convertToAssets(1e18)` → `1e18` (share price 1.0).
- `QuantillonVault.getVaultExposure(2)` → `(adapter, true, 21158260, 2124xxxx)`.
- `QuantillonVault.hasRole(YIELD_DISTRIBUTOR_ROLE, Safe)` → `false`.
- `eth_getLogs` for `ExternalVaultYieldHarvested` on QuantillonVault over its lifetime → **0**.
- grep of dApp frontend+backend for `creditVaultYield` → only present in the ABI JSON; never invoked.
