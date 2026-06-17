# Quantillon Protocol — Consolidated Audit Report (Fix-Planning Input)

> **Purpose of this document.** This merges the two read-only audits —
> `SMART_CONTRACT_AUDIT_REPORT.md` (security / upgradeability, IDs `F-n`) and
> `LOGIC_EFFICIENCY_AUDIT_REPORT.md` (logic / efficiency / docs-conformance, IDs `L-n`) —
> into a single work-queue for the **next phase: bug fixing and code improvements.**
> Original IDs are preserved so prior discussion still maps. Each item carries the
> constraints a fix must satisfy (upgrade impact, storage/ABI/bytecode/size sensitivity),
> a recommendation, and suggested tests.
>
> **Nothing here has been changed in code.** This is still audit output. Treat every
> `src/` item as requiring the change-control gate in §3 before a line is edited.

- **Date:** 2026-06-13 · **Model:** Claude Fable 5
- **Repo:** `quantillon-protocol/` · **Live chain:** Base mainnet (8453), authoritative = `deployments/8453/`
- **Source reports:** `SMART_CONTRACT_AUDIT_REPORT.md`, `LOGIC_EFFICIENCY_AUDIT_REPORT.md` (retained; this report supersedes them as the planning input)

Status labels: **proven** (code/artifact shows it) · **needs human review** (depends on live on-chain state that cannot be read offline) · **docs/test/CI** (no deployed-bytecode impact).

---

## 1. TL;DR — what to fix, in order

1. **Verify the live trust model before anything else** (operational, no code): is a real Timelock + multisig actually holding admin/upgrader/oracle-manager roles, or is it still the deployer EOA? Is the oracle stack EOA-upgradeable? Is the Chainlink sequencer feed set? → **F-1, F-2, F-5, F-9**. These dominate real risk and several gate the code fixes below.
2. **Confirm the two "is it dead or just unwired?" questions** that decide whether code changes are even needed: does QTI have any supply / mint path (**L-1**), and does UserPool hold `MINTER_ROLE` (**F-6 / L-2**)? Both currently look non-functional in code.
3. **Correctness code fixes (need an upgrade window):** QTI supply/governance (L-1), UserPool reward subsystem (F-6/L-2/L-3), YieldShift dual yield path (F-8), `_disableInitializers` on OracleRouter/FeeCollector (F-3/F-4).
4. **Cheap durable protections (CI only, safe now with approval):** storage-layout snapshot, size-regression gate on PRs, ABI/selector diff (**B-9/B-10/B-11**).
5. **Artifact/script/doc hygiene (no bytecode):** mislabeled feed keys (F-7), deploy-script test/mock coupling (F-16), help-text/CLI-key (F-17/F-18), doc conformance (L-4, F-19 docs side).
6. **Polish (upgrade-bundled):** events on setters (F-14/F-15), `require`→custom errors (F-11), NatSpec (F-19), dead-state removal (L-8), test cleanup (F-12/F-13).

**Do not "fix" the things that already work** — see §8 (verified-correct economic logic). Editing them risks regressing the ~150-byte EIP-170 headroom for no benefit.

---

## 2. Baseline (the numbers a fix must not regress)

| Metric | Value | Constraint for fixers |
|---|---|---|
| `make build` | ✅ `Compiler run successful` (102 files, solc 0.8.24) | keep green |
| `make test` | **1420 passed / 0 failed / 46 skipped** (61 suites) | no failures; don't weaken/skip to go green |
| Build warnings | 119 × `unknown lint id: 'unsafe-typecast'` (benign) | don't add new warning classes |
| NatSpec | 99.35% (8 oracle internal helpers missing) | `make validate-natspec` must stay ≥ current |
| Contract sizes | all within EIP-170; **QuantillonVault 99.4% (~150 B), UserPool 99.3% (~170 B)**, HedgerPool 96.0%, YieldShift 93.2%, QTIToken 92.8% | **any edit to vault/UserPool must be size-checked**; prefer net-neutral or shrinking |
| Slither / Mythril | **Available, NOT RUN for this report** (`slither 0.11.5`, `myth v0.24.8`) | run `make slither` / `make mythril` before/after any code change |
| Coverage / gas | not generated this pass | generate if touching gas-sensitive paths |

**Environment:** OZ 5.4.0 (ERC-7201 namespaced storage), `via_ir=true`, `optimizer_runs=0`, `bytecode_hash="none"`, EVM shanghai. Tests run fully offline (no fork/live-RPC) — keep it that way.

---

## 3. Change-control gate — REQUIRED before editing any `src/` file

The protocol is **live and upgradeable**, storage layouts are **frozen**, and there is **no storage-layout / ABI / bytecode baseline in CI**. For every proposed code change, produce and review:

- runtime + creation **bytecode size** before/after (must not push vault/UserPool over EIP-170)
- runtime + creation **bytecode hash** before/after (deployed-source files: any change = re-verification + needs approval)
- **ABI diff**, **function-selector diff**, **event-signature diff**, **custom-error-selector diff**
- **storage-layout diff** (`forge inspect <C> storage-layout`) — append-only, no reorder/insert/retype/gap-misuse
- **gas snapshot** diff if gas-sensitive
- `requires-upgrade` yes/no, deployment/migration impact, and **human security review** sign-off

**Storage-frozen files (no "cleanup" without the full gate + approval):**
```
src/core/QEUROToken.sol            src/core/QuantillonVault.sol
src/core/QTIToken.sol              src/core/UserPool.sol
src/core/HedgerPool.sol            src/core/stQEUROToken.sol
src/core/stQEUROFactory.sol        src/core/FeeCollector.sol
src/core/SecureUpgradeable.sol     src/core/TimelockUpgradeable.sol
src/core/yieldmanagement/YieldShift.sol
src/oracle/ChainlinkOracle.sol     src/oracle/StorkOracle.sol
src/oracle/OracleRouter.sol        src/oracle/SlippageStorage.sol
src/core/vaults/MetaMorphoStakingVaultAdapter.sol   (deployed, non-upgradeable → redeploy + re-wire)
src/libraries/*.sol   src/interfaces/*.sol          (linked into / consumed by deployed bytecode)
```
A **size-neutral change is not automatically safe**; a **bytecode-hash change to deployed source requires explicit approval**.

---

## 4. Unified findings register

Severity: 🔴 High · 🟠 Medium · 🟡 Low · ⚪ Info. Type: **CODE** (deployed src), **OPS** (on-chain/role config), **SCRIPT/ARTIFACT**, **DOCS**, **TEST**, **CI**.

| ID(s) | Title | Sev | Type | Requires upgrade | Safe to do now | Status |
|---|---|---|---|---|---|---|
| **F-1** | Upgrade/admin authority = single EOA at genesis; no Timelock in artifacts | 🔴 | OPS | No (operational) | verify on-chain | proven / review |
| **F-2** | Oracle stack + FeeCollector upgradeable with no timelock (role only) | 🔴 | CODE or OPS | Yes (if code) | No | proven |
| **F-5** | `toggleSecureUpgrades(false)` bypasses emergency-disable quorum/timelock | 🔴/🟠 | CODE | Yes | No | proven |
| **L-1** | QTIToken has no mint path → 0 supply → governance inoperable | 🔴 | CODE | Yes | No | proven / intent review |
| **F-6 + L-2** | UserPool reward path: no MINTER_ROLE (reverts) or mints unbacked QEURO; internal yield index never funded | 🟠 | CODE + OPS | Yes | No | proven / review |
| **F-7** | `addresses.json` mislabels real Chainlink feeds as `Mock*`; wrong deploy comment | 🟠 | SCRIPT/ARTIFACT + DOCS | No | No (artifact/script) | proven / verify feeds |
| **F-8** | YieldShift `userYieldPool` never funded by `addYield` (dual user-yield path) | 🟠 | CODE | Yes | No | likely / review |
| **F-9** | Chainlink `sequencerUptimeFeed` defaults to `address(0)` on an L2 | 🟠 | OPS | No (setter exists) | verify on-chain | review |
| **L-3** | `getUserInfo` reward view formula ≠ claim formula | 🟡 | CODE | Yes | No | proven |
| **F-3 + F-4** | Missing `_disableInitializers()` on OracleRouter & FeeCollector | 🟡 | CODE | Yes | No | proven |
| **F-10** | OracleRouter has no auto fallback / disagreement handling | 🟡 | DOCS | No | docs only | proven (by design) |
| **L-4** | "TWAP-based allocation" overstated for binding yield update | ⚪ | DOCS (or CODE) | No (doc) | docs only | proven |
| **L-5** | `UserPool.deposit` redundant loops + unused `totalQeuroToMint` | 🟡 | CODE | Yes | No | proven |
| **L-6** | Redundant double zero-address validation across init/setters | ⚪ | CODE | Yes | No | proven |
| **L-7** | `getEurUsdPrice()` non-`view`, SSTOREs on every read | ⚪ | DOCS (or CODE) | optional | docs only | proven (by design) |
| **F-14** | Vault address setters emit no events | 🟡 | CODE | Yes | No | proven |
| **F-15** | Hedger events emit `bytes32(0)` placeholder `packedData` | ⚪ | CODE | Yes | No | proven |
| **F-11** | `require("string")` in OracleRouter vs custom-error convention | ⚪ | CODE | Yes | No | proven |
| **F-19** | Misleading copy-paste NatSpec (`@custom:oracle`/`reentrancy`) | ⚪ | CODE (NatSpec) | Yes (hash) | No | proven |
| **F-20** | QTI `executeProposal` ignores its own schedule/hash state | 🟡 | CODE | Yes | No | proven / intent review |
| **F-16** | Deploy script imports `test/` + `src/mocks/` | 🟡 | SCRIPT | No | No (Phase-gated) | proven |
| **F-17** | `deploy.sh` help "1M optimizer runs" vs `optimizer_runs=0` | ⚪ | SCRIPT/DOCS | No | No | proven |
| **F-18** | `setup-external-vaults.sh` takes `--private-key` on CLI | 🟡 | SCRIPT | No | No | proven |
| **F-12** | `EconomicAttackVectors.t.sol` skips 20 attack scenarios | 🟡 | TEST | No | **Yes (test)** | proven |
| **F-13** | `test/GasAnalysisTemp.sol` leftover trivial test | ⚪ | TEST | No | **Yes (test, approval)** | proven |
| **L-8 / F-8 / F-20** | Vestigial state: `YieldShift.mockAaveVault`, `userYieldPool`, QTI schedule fields, 119 lint comments | ⚪ | CODE | Yes | No | proven |
| **B-9** | Storage-layout snapshot baseline + CI diff | 🟠 | CI | No | **Yes (CI, approval)** | recommendation |
| **B-10** | Contract-size regression gate on the PR job | 🟠 | CI | No | **Yes (CI)** | recommendation |
| **B-11** | ABI/selector/event/error diff CI vs baseline | 🟡 | CI | No | **Yes (CI)** | recommendation |

---

## 5. Open questions that gate the code fixes (answer these first)

These on-chain/intent answers determine whether an item is a *code bug to fix* or *already handled operationally*. Resolve before opening fix PRs.

1. **F-1 / F-2 / F-5:** Who currently holds `DEFAULT_ADMIN_ROLE`, `UPGRADER_ROLE`, `ORACLE_MANAGER_ROLE`, `GOVERNANCE_ROLE` on all 13 contracts — a multisig/Timelock or the deployer EOA? Is `SecureUpgradeable.timelock` a real `TimelockUpgradeable` contract or an EOA? (Read each proxy's roles + `getUpgradeSecurityStatus()` on Base.)
2. **L-1:** What is `QTIToken.totalSupply()` on mainnet? Is QTI intended to circulate now, later, or never? (There is **no mint path in code** — any supply needs an upgrade.)
3. **F-6 / L-2:** Does `UserPool` hold `QEUROToken.MINTER_ROLE` on mainnet? Are staking rewards a real product feature or vestigial? If real, what backs the minted QEURO?
4. **F-7:** Are `0xc91D87E8…` (EUR/USD) and `0x7e860098…` (USDC/USD) the canonical Chainlink Base aggregators? (Confirm on-chain.)
5. **F-9:** Is `ChainlinkOracle.sequencerUptimeFeed` set on mainnet?
6. **F-8 / F-20:** Are the `userYieldPool`/`userPendingYield` path and the QTI proposal-schedule fields intended to be live, or are they dead scaffolding to be removed in a future upgrade?

---

## 6. Detailed fix plan (grouped, sequenced)

### P0 — Trust model & upgrade safety (mostly operational; one code item)

**F-1 — Single-EOA authority / no Timelock (OPS).** Evidence: `DeployQuantillon.s.sol` passes `admin = deployerEOA` and `_timelock = deployerEOA` to every `initialize` (lines 210,218,253,264,278,291,301,323,333,343,353); `deployments/8453/addresses.json` has no `Timelock` key. Because `SecureUpgradeable.timelock` is an EOA, `executeUpgrade(onlyTimelock)` and `_authorizeUpgrade` accept that EOA with zero delay.
→ **Action:** confirm/transfer all admin/upgrader/oracle-manager roles to a multisig + real `TimelockUpgradeable`; call `setTimelock()` where missing; record the timelock + multisig in `addresses.json`. No contract code change required.

**F-2 — Oracle/FeeCollector have no timelock on upgrade.** Evidence: `_authorizeUpgrade` gated only by `UPGRADER_ROLE`/`GOVERNANCE_ROLE` (plain UUPS) in `FeeCollector.sol:783`, `OracleRouter.sol:283`, `ChainlinkOracle.sol:851`, `StorkOracle.sol:846`, `SlippageStorage.sol:614`. The price-critical stack is the weakest-gated.
→ **Action (choose):** (a) **OPS** — hold `UPGRADER_ROLE`/`GOVERNANCE_ROLE` only in a Timelock+multisig (no code change); or (b) **CODE** — migrate these to `SecureUpgradeable` (storage-adding, ABI/bytecode change, upgrade + review). Prefer (a) short-term; (b) only with storage-layout planning (adds `timelock`, `secureUpgradesEnabled` — must be appended).

**F-5 — `toggleSecureUpgrades(false)` bypass (CODE).** Evidence: `SecureUpgradeable.toggleSecureUpgrades` (single `DEFAULT_ADMIN_ROLE`) instantly disables secure upgrades, satisfying `emergencyUpgrade`'s `!secureUpgradesEnabled` precondition → immediate timelock-free upgrade, nullifying the 24h/quorum-of-2 flow.
→ **Fix:** gate `toggleSecureUpgrades(false)` behind the same quorum+delay as `proposeEmergencyDisableSecureUpgrades`, or remove the instant disable. Same selector (no ABI change) but **behavior change → upgrade + review**. **Test:** assert `emergencyUpgrade` is unreachable without quorum+delay. Short-term mitigation: hold `DEFAULT_ADMIN_ROLE` in a multisig.

**F-9 — Sequencer feed (OPS).** Set `ChainlinkOracle.sequencerUptimeFeed` to Base's sequencer-uptime feed if unset (setter exists; no code change).

### P1 — Correctness / economic code fixes (need an upgrade window)

**L-1 — QTI has no mint path (CODE, highest correctness impact).** Evidence: no `_mint`/`mint`/`MINTER_ROLE` anywhere in `QTIToken.sol`; `initialize` (402–430) mints nothing; `TOTAL_SUPPLY_CAP=100M` (line 148) unused. `lock()` requires `balanceOf ≥ amount` (457) → always reverts → all governance dead.
→ **Fix (intent-dependent):** if QTI should circulate, add a controlled mint/distribution path (e.g., one-time mint of the fixed cap to treasury in a `reinitializer`, or a guarded distributor) — **behavior + ABI change, upgrade, review**, and update docs. If governance is deliberately dormant, **fix the docs instead** (README/CLAUDE.md say "fixed supply (100M)" as if live). **Test:** supply == cap after activation; lock/vote/propose/execute happy-path + threshold/quorum reverts.

**F-6 + L-2 — UserPool reward subsystem (CODE + OPS).** Evidence: `claimStakingRewards`/`batchRewardClaim` call `qeuro.mint`/`batchMint` but UserPool holds no `MINTER_ROLE` (deploy grants it only to the vault) → revert; `accumulatedYieldPerShare` is only ever set to 0 (UserPool.sol:537) → `yieldReward` always 0; `lastYieldDistribution`/`totalYieldDistributed` set once, never updated. Real user yield flows via YieldShift→`creditVaultYield`→stQEURO.
→ **Fix (intent-dependent):** (a) if rewards are vestigial → remove the dead functions/fields in an upgrade and stop advertising `stakingAPY`/`claimStakingRewards`; (b) if real → wire a funding source and grant `MINTER_ROLE` deliberately **with backing accounted** (minting unbacked QEURO degrades CR — do not just grant the role). **Do not** grant `MINTER_ROLE` to UserPool as a "quick fix" without addressing backing. **Test:** reward claim reverts cleanly if disabled, or succeeds with conserved collateralization if enabled.

**F-8 — YieldShift dual user-yield path (CODE).** Evidence: `addYield` increments only `hedgerYieldPool` (user share routed to `creditVaultYield`), while `claimUserYield`/`emergencyYieldDistribution` spend `userYieldPool`, and `updateYieldAllocation` (YIELD_MANAGER) bumps `userPendingYield` without funding `userYieldPool` → `claimUserYield` reverts `InsufficientYield` unless funded out-of-band.
→ **Fix:** decide canonical model; if vestigial, remove the unfunded path in an upgrade; add invariant `Σ userPendingYield ≤ userYieldPool`. **Test:** invariant + claim happy/again-revert paths.

**L-3 — `getUserInfo` view ≠ claim accrual (CODE).** Evidence: state path uses `UserPoolStakingLibrary.calculateStakingRewards` (timestamp-based + >30d bonus, lib lines 77–83); `getUserInfo` (view) uses block-based `timeElapsed*12 * stakingAPY/10000` with no bonus. → **Fix:** make the view delegate to the same library. Bundle with the F-6/L-2 decision (moot if rewards are removed). **Test:** view == claimable for representative durations.

**F-3 / F-4 — Missing `_disableInitializers()` (CODE).** Add `constructor() { _disableInitializers(); }` to `OracleRouter` and `FeeCollector` (the other 11 contracts already have it). New implementations + upgrade; low risk (OZ 5.4.0 `onlyProxy` already blocks the worst vector) but closes the deviation. **Test:** implementation `initialize` reverts `InvalidInitialization`.

### P1 — CI safety gates (no bytecode; safe to implement now with approval)

- **B-9 — Storage-layout snapshot:** commit `forge inspect <C> storage-layout` for every upgradeable contract; CI fails on diff. Closes the biggest upgrade-safety gap (no gaps, no baseline today).
- **B-10 — Size-regression gate on PRs:** `make analyze-contract-sizes` already exits 1 on EIP-170 breach but runs only nightly; add it to the PR-gating job (vault/UserPool at ~99%).
- **B-11 — ABI/selector/event/error diff** vs committed baseline for storage-frozen contracts.
- Also recommended: Slither in the PR gate (nightly-only today) with a tracked baseline; generated-artifact (dApp ABI/address) drift check.

### P1 — Artifact / script / docs (no deployed bytecode)

- **F-7:** verify feeds on-chain, then rename `addresses.json` keys `MockEURUSD`/`MockUSDCUSD` → `EURUSD`/`USDCUSD` (coordinate with dApp `ContractName` union) and fix the false comment at `DeployQuantillon.s.sol:486`.
- **F-16:** decouple `DeployQuantillon.s.sol` from `test/ChainlinkOracle.t.sol` and `src/mocks/` (move mock-feed deploy into a mocks-only script/path).
- **F-17:** fix `deploy.sh` help text ("1M optimizer runs" → `optimizer_runs=0`).
- **F-18:** change `setup-external-vaults.sh` to read the key from env/keystore, not `--private-key`.
- **L-4 / L-7 / F-10:** align docs — yield allocation is "holding-period-filtered eligible sizes + gradual adjustment" (not pure TWAP); document that `getEurUsdPrice()` mutates the cache; document manual oracle failover.

### P2 / P3 — Polish (bundle into the next upgrade)

- **F-14:** emit events in `QuantillonVault.updateOracle/updateHedgerPool/updateUserPool/updateFeeCollector`.
- **F-15:** populate `packedData` in `HedgePositionOpened/Closed/MarginUpdated` (currently `bytes32(0)`).
- **F-11:** replace `require("…")` in `OracleRouter.switchOracle`/`updatePriceFeeds` with custom errors.
- **F-19:** fix copy-paste NatSpec (`@custom:oracle`/`@custom:reentrancy`) on functions without those properties; complete the 8 missing oracle-helper docs.
- **F-20:** either enforce the `proposalScheduled`/`proposalExecutionTime`/`proposalExecutionHash` schedule in `executeProposal`, or remove the unused fields/getters (intent-dependent).
- **L-5:** consolidate `UserPool.deposit` loops, drop unused `totalQeuroToMint` (size-check; likely shrinks).
- **L-6:** remove duplicate zero-address checks (keep the custom-error library form); pairs with a Slither triage.
- **L-8:** remove vestigial `YieldShift.mockAaveVault`/`IMockAaveVault` references and the 119 no-op `forge-lint` comments (cosmetic; bytecode-hash change).

### Test cleanup (safe now)

- **F-12:** implement the 20 skipped `EconomicAttackVectors` scenarios against the integration harness, or delete the misleading stubs (don't claim attack coverage that's skipped).
- **F-13:** remove `test/GasAnalysisTemp.sol` (trivial `require(true)`, referenced nowhere) — test-only, alters test count, needs a nod.
- Add the missing negative/invariant tests called out: `toggleSecureUpgrades` bypass (F-5), stQEURO donation/first-depositor on a freshly registered per-vault token, YieldShift conservation (F-8).

---

## 7. Suggested PR/upgrade batching

| Batch | Contents | Gate |
|---|---|---|
| **Batch 0 (no code)** | F-1/F-2/F-5/F-9 on-chain verification + role/timelock/sequencer config; answer §5 questions | ops sign-off |
| **Batch 1 (CI)** | B-9 storage-layout baseline+diff, B-10 size gate on PR, B-11 ABI/selector diff, Slither-in-PR | CI review |
| **Batch 2 (docs/scripts/tests)** | F-7, F-16, F-17, F-18, L-4/L-7/F-10 docs, F-12, F-13 | no bytecode change |
| **Batch 3 (upgrade — correctness)** | L-1 (QTI), F-6/L-2/L-3 (UserPool rewards), F-8 (YieldShift), F-3/F-4, F-5 (if coded) | full §3 gate + Slither + security review + upgrade |
| **Batch 4 (upgrade — polish)** | F-14, F-15, F-11, F-19, F-20, L-5, L-6, L-8 | full §3 gate; size-check vault/UserPool |

Batches 3–4 each consume one upgrade window per affected proxy; group by contract to minimize upgrades. **UserPool and QuantillonVault edits must include a before/after size diff** in the PR.

---

## 8. Verified-CORRECT — do NOT "fix" these

These documented behaviors were checked against code and **match**; editing them only risks the EIP-170 headroom.

| Claim | Code | Verdict |
|---|---|---|
| QEURO 1:1 EUR peg via oracle | mint `netAmount.mulDiv(1e30, price)`, redeem `qeuroAmount.mulDiv(price,1e18)/1e12` (symmetric) | ✅ |
| Mint ≥105% / liquidation 101% | `MIN_…=105e18`, `criticalCR=101e18`; gates enforced on live price | ✅ |
| Fee split 60/25/15 | `6000/2500/1500`, sum-enforced, community gets remainder | ✅ |
| HedgerPool P&L `FilledVolume − QEUROBacked×Price/1e30` | `HedgerPoolLogicLibrary.calculatePnL` 151–167; liq-mode `effectiveMargin=0` | ✅ |
| QTI ≤4× linear voting | `1e18 + (lockTime−MIN)*3e18/(MAX−MIN)` capped 4× | ✅ (formula; supply is the issue — L-1) |
| 7-day holding period | `MIN_HOLDING_PERIOD=7 days` enforced in `claimUserYield` | ✅ |
| stQEURO yield-bearing | ERC4626; `creditVaultYield` raises share price | ✅ |
| Rounding favors protocol | `VaultMath.mulDiv` truncates down on mint/redeem/fees | ✅ |
| 6↔18 decimal handling | explicit `/1e12`, `*1e30`; CR uses `1e20=100%` | ✅ |
| USDC blacklist resilience | pull-based escrow w/ recipient override (HedgerPool + UserPool) | ✅ |
| Flash-loan guard, CEI, SafeERC20 | balance-delta guard; commit-after-effects; SafeERC20/forceApprove | ✅ |

---

## 9. Caveats carried from the source audits

- **Slither/Mythril not run for this report** — the tools are now installed globally on this VPS (`slither` and `myth` are callable), but no Slither/Mythril findings are incorporated here. Run them before merging any code change; the README "0 Critical/Medium" claim remains unverified by this consolidated report.
- **No on-chain reads were possible** (offline, no fork tests) — every "needs human review" item in §5 must be answered from Base mainnet state before its fix is scoped.
- **No bytecode-hash baseline** (`bytecode_hash="none"`) — source-vs-deployed can't be byte-compared; rely on the recorded implementation addresses in `deployments/8453/*-upgrade.json`.
- This document changed **no code, artifacts, or config** — only this file was created. The two source reports remain in place; delete them only if you want this consolidated report to be the single source of truth.
