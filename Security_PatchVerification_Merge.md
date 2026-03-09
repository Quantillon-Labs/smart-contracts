# Quantillon Protocol — Merged Security Patch Verification Report

**Date:** March 9, 2026  
**Protocol:** Quantillon Protocol (QEURO · stQEURO · QTI · QuantillonVault · HedgerPool)  
**Report Type:** Consolidated Patch Verification (Multi-Auditor Synthesis)  

**Source reports merged:**
- `Security_PatchVerificationReport_Claude.md` (Claude Sonnet 4.6)  
- `Security_PatchVerificationReport_Codex.md` (Codex)  
- `Security_PatchVerificationReport_Gemini.md` (Gemini Smart Contract Audit Division)  

**Reference baseline:**
- `Security_MetaAnalysisFinalReport_Claude.md` (25 original findings)  

---

## 1. Scope and Methodology

- This document **does not introduce a new independent audit**.  
  It is a **textual synthesis** of the three existing patch-verification reports listed above.  

- For each of the **25 original findings** (CRIT / HIGH / MED / LOW / INFO), we:
  - Aligned the identifiers and descriptions across reports.  
  - Compared the per-auditor verdicts and rationales.  
  - Assigned a **merged verdict** using a **conservative rule**:
    - If all auditors that commented on a finding say **“fixed”**, merged verdict is **✅ Fixed**.  
    - If any auditor says **“partially fixed/verified”** or expresses unresolved concerns, merged verdict is **⚠️ Partially fixed**.  
    - If any auditor says **“not fixed”**, merged verdict is at most **⚠️ Partially fixed** (never upgraded to “fixed”).  

- We also merged the **“new issues”** discovered during verification:
  - Claude: `NEW-1` (Aave interest tracking gap, residual from HIGH‑2 Issue B).  
  - Codex: `NEW-1`, `NEW-2`, `NEW-3` (reward double-counting, deployment wiring, stale interface).  
  - Gemini: no new issues reported.  

No code was re-audited for this merge.  
All conclusions are strictly derived from the three source reports.  

---

## 2. High-Level Summary (Merged View)

- **Critical & High severity**
  - **CRIT-1**: All three auditors agree it is **fully fixed**.  
  - **HIGH-1**: All three auditors agree it is **fully fixed**.  
  - **HIGH-2**: All three auditors classify it as **only partially fixed**:
    - The dangerous `unchecked` subtraction is removed.  
    - The **Aave interest accounting gap** (Issue B) remains and is treated as an open Medium‑severity design flaw / economic issue.  
  - **HIGH-3**: All three auditors agree it is **fully fixed**.  

- **Medium severity**
  - **Clearly fully fixed by all auditors:** MED‑1, MED‑3, MED‑4, MED‑5, MED‑6, MED‑7.  
  - **MED‑2 (HedgerPool reward funding)**:
    - Gemini considers it **fixed** (new `fundRewardReserve` funding function).  
    - Claude treats it as **“partially verified”** and explicitly **cannot confirm** that protocol fee/yield flows actually fund HedgerPool.  
    - Codex considers the underlying economic issue **not solved** (no structural funding path).  
    - **Merged verdict:** **⚠️ Partially fixed** — mechanical funding function exists, but system‑level funding flow remains questionable.  

- **Low severity**
  - **Clearly fully fixed by all auditors:** LOW‑1, LOW‑2, LOW‑6, LOW‑7.  
  - **LOW‑3 (HedgerPool accounting skipped when paused):**
    - Codex: **not fixed** — accounting desync still structurally possible; only surfaced.  
    - Claude: functionally improved (events added); counts as fixed but explicitly notes structural desync remains.  
    - **Merged verdict:** **⚠️ Partially fixed** — monitoring added, but design‑level desync risk still exists.  
  - **LOW‑4 (non‑`view` query functions):** both Claude and Codex mark as **partially fixed**.  
  - **LOW‑5 (bootstrap mint CR checks):** Claude marks as **fixed**; Codex as **partially fixed** due to remaining bootstrapping nuances.  
    - **Merged verdict:** **⚠️ Partially fixed**.  

- **Informational**
  - **INFO‑1, INFO‑3, INFO‑5, INFO‑6:** all auditors that discuss them agree they are **fully fixed**.  
  - **INFO‑2 (single‑hedger architecture):**
    - Claude: explicitly classifies this as **an intentional architecture choice**, not a bug.  
    - Codex: marks it as **partially fixed** (risk remains).  
    - **Merged view:** underlying vulnerability is mitigated (CRIT‑1 fix), but counterparty concentration is an **accepted / documented design risk**.  
  - **INFO‑4 (emergency disable governance):** both Claude and Codex mark as **partially fixed** (timelock added, but single‑key remains).  
  - **INFO‑7 (fee NatSpec scale mismatch):**
    - Claude: interface and implementation NatSpec now consistently document `1e18 = 100%`.  
    - Codex: notes that some interface documentation still refers to basis points.  
    - **Merged verdict:** **⚠️ Partially fixed** — most docs corrected, but any remaining bps references should be cleaned up.  

- **New / residual issues (union across auditors)**
  - **Aave interest tracking gap** (Claude `NEW‑1`, HIGH‑2 Issue B): **Medium**, **open**.  
  - **HedgerPool `claimHedgingRewards()` double‑counting `yieldShiftRewards`** (Codex `NEW‑1`): **Medium**, **open**.  
  - **Deployment script wiring gaps** (Codex `NEW‑2`): **Medium**, **open** until runbooks/scripts are updated.  
  - **`ISecureUpgradeable` interface drift** (Codex `NEW‑3`): **Informational**, **open**.  

Overall, the merged view agrees with all three auditors that the patch set **removes any obviously exploitable Critical path** and makes substantial progress on High/Medium items, but **several Medium / Low / Informational risks remain** and should be addressed before declaring the system fully “audit‑clean”.  

---

## 3. Per-Finding Merged Verdicts

### Legend

- **Claude / Codex / Gemini**: direct verdicts from each report (when present).  
- **Merged verdict**: conservative synthesis (see methodology).  

### 3.1 Critical and High Severity

| ID | Claude | Codex | Gemini | Merged verdict | Notes |
|---|---|---|---|---|---|
| **CRIT‑1** Unauthorized `claimHedgingRewards()` | ✅ Fixed | ✅ Fixed | ✅ Fixed | ✅ Fixed | Access now restricted to `singleHedger`; Sybil / any‑EOA drain closed. |
| **HIGH‑1** Upgrade mechanism non‑functional | ✅ Fixed | ✅ Fixed | ✅ Fixed | ✅ Fixed | `TimelockUpgradeable.executeUpgrade()` now actually calls `ISecureUpgradeable(proxy).executeUpgrade(implementation)`, with expiry on proposals. |
| **HIGH‑2** `_withdrawUsdcFromAave` underflow + interest gap | ⚠️ Partially fixed | ⚠️ Partially fixed | ⚠️ Partially fixed | ⚠️ Partially fixed | Unchecked underflow removed; **Aave interest tracking / harvesting gap remains** (Claude `NEW‑1`). |
| **HIGH‑3** `distributeYield()` decimal mismatch | ✅ Fixed | ✅ Fixed | ✅ Fixed | ✅ Fixed | USDC (6 dec) → QEURO (18 dec) conversion via oracle implemented; yield no longer dust‑locked. |

### 3.2 Medium Severity

| ID | Claude | Codex | Gemini | Merged verdict | Notes |
|---|---|---|---|---|---|
| **MED‑1** `devModeEnabled` without timelock | ✅ Fixed | ✅ Fixed | ✅ Fixed | ✅ Fixed | Oracles now have 48h timelock; vault dev‑mode removed entirely. |
| **MED‑2** HedgerPool reward has no funding mechanism | ⚠️ Partially verified | ❌ Not fixed | ✅ Fixed | ⚠️ Partially fixed | `fundRewardReserve()` exists, but **no unanimously‑confirmed fee / yield routing into HedgerPool**; economic funding path remains unclear. |
| **MED‑3** `TREASURY_ROLE` dual capability | ✅ Fixed | ✅ Fixed | ✅ Fixed | ✅ Fixed | `FEE_SOURCE_ROLE` split from `TREASURY_ROLE`; depositors no longer have withdrawal rights. |
| **MED‑4** `FeeCollector` rejects contract treasuries | ✅ Fixed | ✅ Fixed | ✅ Fixed | ✅ Fixed | `validateNotContract` removed; Safe/DAO treasuries allowed. |
| **MED‑5** `redeemQEUROLiquidation()` at CR=0 | ✅ Fixed | ✅ Fixed | ✅ Fixed | ✅ Fixed | Reversion when `hedgerPool`/`userPool` are uninitialized; false liquidation mode blocked. |
| **MED‑6** `addMargin()` fee stranded in vault | ✅ Fixed | ✅ Fixed | ✅ Fixed | ✅ Fixed | Net margin sent to vault; fee routed to `FeeCollector`; CR no longer inflated. |
| **MED‑7** `_executeAaveDeployment()` external w/o guard | ✅ Fixed | ✅ Fixed | ✅ Fixed | ✅ Fixed | Self‑call + dedicated boolean reentrancy lock; equivalent to `nonReentrant` under `try this` pattern. |

### 3.3 Low Severity

| ID | Claude | Codex | Gemini | Merged verdict | Notes |
|---|---|---|---|---|---|
| **LOW‑1** Raw `approve()` in liquidation fees | ✅ Fixed | ✅ Fixed | ✅ Fixed | ✅ Fixed | Replaced with `safeIncreaseAllowance`. |
| **LOW‑2** 2‑block dead zone in deviation check | ✅ Fixed | ✅ Fixed | – | ✅ Fixed | `>` → `>=`; no more 2‑block window. |
| **LOW‑3** HedgerPool accounting silently skipped when paused | ✅ Fixed (with caveats) | ❌ Not fixed | – | ⚠️ Partially fixed | Event now emitted on failure, but **liquidation still proceeds while HedgerPool accounting is skipped**, so desync remains possible. |
| **LOW‑4** Non‑`view` query functions (`canMint`, `getProtocolCollateralizationRatio`) | ⚠️ Partially fixed | ⚠️ Partially fixed | – | ⚠️ Partially fixed | View helpers added, but original state‑mutating variants still present; recommended `updatePriceCache()` separation not fully implemented. |
| **LOW‑5** Bootstrap mint bypasses projected CR check | ✅ Fixed | ⚠️ Partially fixed | – | ⚠️ Partially fixed | `initializePriceCache()` enforces explicit seeding, but Codex still flags bootstrap minting behavior as not fully aligned with “normal” collateral checks. |
| **LOW‑6** No expiry on pending upgrades | ✅ Fixed | ✅ Fixed | – | ✅ Fixed | `expiryAt` added; proposals expire after `MAX_PROPOSAL_AGE`. |
| **LOW‑7** Slippage check uses pre‑fee amount | ✅ Fixed | ✅ Fixed | – | ✅ Fixed | `minUsdcOut` now checked against post‑fee (`netUsdcPayout`). |

### 3.4 Informational

| ID | Claude | Codex | Gemini | Merged verdict | Notes |
|---|---|---|---|---|---|
| **INFO‑1** `batchMint()` dead fee code | ✅ Fixed | ✅ Fixed | – | ✅ Fixed | Unused `totalFeeAmount` removed; fees handled upstream. |
| **INFO‑2** Single‑hedger architecture / `positionId = 1` | ℹ️ Architecture decision | ⚠️ Partially fixed | – | ℹ️ Accepted design risk | CRIT‑1 exploit is fixed; remaining issue is **concentrated counterparty risk**, now explicitly documented. |
| **INFO‑3** `TAKES_FEES_DURING_LIQUIDATION` constant | ✅ Fixed | ✅ Fixed | – | ✅ Fixed | Constant removed; inline `true` used to avoid misinterpretation as governance‑tunable. |
| **INFO‑4** `emergencyDisableSecureUpgrades()` single‑key path | ⚠️ Partially fixed | ⚠️ Partially fixed | – | ⚠️ Partially fixed | 24h timelock added; recommended multi‑sig threshold not implemented — single admin key can still disable upgrades after delay. |
| **INFO‑5** `calculateLiquidationPayout()` formula mismatch | ✅ Fixed | ✅ Fixed | – | ✅ Fixed | Preview formula now aligned with actual liquidation behavior. |
| **INFO‑6** `VaultMath.mulDiv` unreachable overflow check | ✅ Fixed | ✅ Fixed | – | ✅ Fixed | Dead manual overflow logic removed; relies on Solidity 0.8.x checks. |
| **INFO‑7** Fee parameter scale documentation | ✅ Fixed | ⚠️ Partially fixed | – | ⚠️ Partially fixed | Most NatSpec updated to `1e18 = 100%`; any residual basis‑points wording (especially in interfaces) should be corrected. |

---

## 4. Consolidated View of New / Residual Issues

This section merges **all newly identified or explicitly open issues** across the three reports.  
IDs are kept as in the original reports where possible; when the same conceptual issue appears under different labels, we describe the link explicitly.  

### 4.1 Aave Interest Tracking Gap (Claude `NEW‑1`, HIGH‑2 Issue B)

- **Severity:** Medium  
- **Source:** `Security_PatchVerificationReport_Claude.md` (`NEW‑1`) and HIGH‑2 writeup.  
- **Description:**  
  - `totalUsdcInAave` tracks only **principal**, not the full aToken balance including interest.  
  - Aave interest accrues invisibly; the protocol’s notion of collateral and yield **lags reality**.  
- **Impact (from Claude):**
  - Collateralization ratio is **systematically understated** versus actual assets.  
  - Aave interest is **not fed into yield distribution** (stQEURO holders do not receive it).  
  - Interest can only be extracted via admin `recoverToken()` calls, effectively **stranding** protocol yield.  
- **Status (merged):** **Open**.  

### 4.2 HedgerPool `claimHedgingRewards()` Double-Counts `yieldShiftRewards` (Codex `NEW‑1`)

- **Severity:** Medium  
- **Source:** `Security_PatchVerificationReport_Codex.md` (`NEW‑1`).  
- **Description:**  
  - `claimHedgingRewards()` sums `yieldShiftRewards` into a local `totalRewards` value and then calls `yieldShift.claimHedgerYield(hedger)`, which **already transfers USDC to the hedger**.  
  - After that, HedgerPool still attempts to pay or escrow the full `totalRewards`, which includes the already‑paid `yieldShiftRewards`.  
- **Impact:**  
  - Direct path: hedger receives `yieldShiftRewards` **twice**.  
  - Deferred path: `pendingRewardWithdrawals[hedger]` is **overstated**, leading to inflated future payouts.  
- **Status (merged):** **Open**; requires payout‑flow rework so that **only one component** (YieldShift or HedgerPool) acts as the final settlement source.  

### 4.3 Deployment Script Wiring Gaps (Codex `NEW‑2`)

- **Severity:** Medium (operational / availability).  
- **Source:** `Security_PatchVerificationReport_Codex.md` (`NEW‑2`).  
- **Description:**  
  - The deployment script has been partially updated for the new patches but **omits several required initialization calls**, including (per Codex):  
    - `quantillonVault.initializePriceCache()`  
    - `stQeuroToken.setOracle(address(oracleRouter))`  
    - `hedgerPool.setFeeCollector(address(feeCollector))`  
    - `feeCollector.authorizeFeeSource(address(hedgerPool))`  
- **Impact:**  
  - A deployed system can have **correct code but incomplete wiring**, leading to:  
    - First mint blocked until governance manually seeds the price cache.  
    - `stQEURO.distributeYield()` reverting until its oracle is set.  
    - Margin fees not fully wired into `FeeCollector` for hedger activity.  
- **Status (merged):** **Open** until deployment scripts / runbooks ensure **all** required post‑patch wiring steps are performed.  

### 4.4 `ISecureUpgradeable` Interface Drift (Codex `NEW‑3`)

- **Severity:** Informational / integration risk.  
- **Source:** `Security_PatchVerificationReport_Codex.md` (`NEW‑3`).  
- **Description:**  
  - After the change to a two‑step emergency‑disable flow, the interface still exposes the old one‑step `emergencyDisableSecureUpgrades()` and does **not** expose the new `proposeEmergencyDisableSecureUpgrades()` / `applyEmergencyDisableSecureUpgrades()` functions.  
- **Impact:**  
  - Interface consumers and future upgrades can be **misled** about the real upgrade‑safety surface.  
  - Not directly exploitable on‑chain, but a form of **security‑sensitive drift** between interface and implementation.  
- **Status (merged):** **Open**; should be aligned to avoid confusion in security‑critical tooling and scripts.  

---

## 5. Consolidated Pre-Launch Checklist (From All Three Reports)

This checklist is the **union of the most conservative recommendations** from Claude, Codex, and Gemini.  
It is intentionally stricter than any single report on its own.  

Before considering a production mainnet launch, the merged view suggests:

1. **Resolve HIGH‑2 Issue B / Aave interest gap (Claude `NEW‑1`)**
   - Implement and test a **harvest / sync mechanism** that:  
     - Brings `totalUsdcInAave` in line with actual aToken balances.  
     - Routes the harvested delta into a well‑specified yield path (e.g., YieldShift → stQEURO).  

2. **Clarify and implement a robust HedgerPool reward funding path (MED‑2)**
   - Ensure that protocol fee and/or Aave yield flows **actually fund HedgerPool’s reward reserve** in a documented and test‑covered way, not solely via manual `fundRewardReserve()` calls.  

3. **Fix HedgerPool reward double-counting (Codex `NEW‑1`)**
   - Rework `claimHedgingRewards()` / YieldShift interactions so that **each unit of USDC yield is paid exactly once**.  

4. **Address liquidation / HedgerPool accounting desync (LOW‑3)**
   - Either:  
     - Make liquidation **atomically dependent** on successful HedgerPool accounting, or  
     - Implement an explicit and well‑documented reconciliation mechanism that prevents long‑term desync between vault and HedgerPool states.  

5. **Update deployment scripts and interfaces (Codex `NEW‑2`, `NEW‑3`, INFO‑7)**
   - Ensure all new initialization hooks are called in the canonical deployment scripts.  
   - Align `ISecureUpgradeable` (and any other public interfaces) with the current implementation.  
   - Remove any remaining **basis‑points references** in fee documentation where `1e18`‑scale is used.  

6. **Governance hardening for emergency-disable path (INFO‑4)**
   - Consider moving from a single admin key + timelock to a **multi‑sig threshold** for `applyEmergencyDisableSecureUpgrades`, in line with Claude’s recommendation.  

If the project treats some of these as acceptable risk (e.g. single‑hedger model, specific governance trade‑offs), those decisions should be **explicitly documented** alongside the economic and security rationale so that operators, hedgers, and stQEURO holders can evaluate the residual risk.  

---

*This merged report is intended as a convenience layer over the three underlying patch‑verification documents. For any implementation or design decision, the original reports and the on‑chain code remain the ultimate sources of truth.*  

