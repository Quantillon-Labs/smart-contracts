# Quantillon Protocol — Remediation Plan

> **What this is.** The actionable fix program derived from the three read-only audits
> (`SMART_CONTRACT_AUDIT_REPORT.md`, `LOGIC_EFFICIENCY_AUDIT_REPORT.md`, and the
> `CONSOLIDATED_AUDIT_REPORT.md` that merged them). Findings here were **re-verified against
> current source** (not just the audit text) and the intent/state questions were resolved with
> the team. Use this as the living checklist for remediation.
>
> - **Date:** 2026-06-13 · **Repo:** `quantillon-protocol/` · **Live chain:** Base mainnet (8453)
> - **Finding IDs:** `F-n` (security report), `L-n` (logic/efficiency report) — preserved so prior discussion still maps.
> - **Status:** planning. No code/artifact has been changed by this document.

---

## Context

The audits catalogued the protocol's bugs and points of failure but were **audit-only** — nothing was changed, and several findings were "needs human review" because they depend on live Base-mainnet state that can't be read offline. This plan converts that into a sequenced remediation program that does not regress the two hard constraints that dominate this codebase:

1. **Live & UUPS-upgradeable** → storage layouts are frozen (append-only; no reorder/insert/retype/removal of storage slots in a deployed proxy).
2. **EIP-170 headroom is tiny** → `QuantillonVault` (99.4%, ~150 B) and `UserPool` (99.3%, ~170 B) are a few bytes from the 24,576-byte limit; any byte added to them can brick a redeploy/upgrade.

### Decisions taken (team)
| Question | Decision | Consequence |
|---|---|---|
| Scope of this pass | **Full program, batched** | Plan all batches, sequenced below. |
| Live trust model | **Still the deployer EOA** (no real Timelock/multisig) | Batch 0 (operational) is the single highest priority. |
| QTI governance (L-1/F-20) | **Keep dormant, fix docs** | No QTI code upgrade now; correct the docs. |
| Dead user-reward paths (F-6/L-2/L-3/F-8) | **Remove them** | Strip dead functions/logic in an upgrade; stQEURO is the canonical yield route. |

### What re-verification corrected vs. the audit
- **F-3/F-4 is only 2 contracts, not 6.** Exactly `OracleRouter` and `FeeCollector` lack `_disableInitializers()`; all 14 other core/oracle contracts call it directly in their constructors (`HedgerPool.sol:262`, `UserPool.sol:478`, `YieldShift.sol:225`, `stQEUROToken.sol:67`, `ChainlinkOracle.sol:235`, `StorkOracle.sol:303`, `SlippageStorage.sol:118`, …). The audit's original table was right; a sub-agent's broader claim was wrong.
- **CI is thinner than the audit assumed.** Only one workflow exists (`.github/workflows/tests.yml`) running `make build && make test` on push/PR. The `quantillon-protocol-tests.yml` nightly the audit referenced (slither/natspec/sizes) **does not exist** — nothing beyond build+test runs anywhere. The CI-gate batch is therefore *more* valuable, and "nightly slither will catch it" is not a safety net that exists today.
- **Minor refinements:** only `QuantillonVault.updateOracle` lacks an event (the other 3 setters intentionally document none); `HedgerPool.MarginUpdated` is declared but **never emitted**; `EconomicAttackVectors.t.sol` has **10** skips (not 20). F-17 (deploy.sh "1M optimizer runs" vs `optimizer_runs=0`) still holds.

All other findings (F-5, L-1, F-6, F-8, F-2, F-11, F-14, F-15, F-7, F-16, F-18, F-12, F-13, L-4/L-7) were confirmed still accurate.

---

## Change-control gate — REQUIRED before editing any `src/` file

No storage-layout/ABI/bytecode baseline exists in CI yet. For every `src/` change produce and review:
- runtime + creation **bytecode size** before/after (must not push `QuantillonVault`/`UserPool` over EIP-170)
- runtime + creation **bytecode hash** before/after; **storage-layout diff** (`forge inspect <C> storage-layout`) — append-only only
- **ABI / function-selector / event-signature / custom-error-selector** diff
- `make slither` (0.11.5 installed) + `make mythril` (0.24.8) before/after; gas snapshot if gas-sensitive
- `requires-upgrade` yes/no, migration impact, human security-review sign-off

**Storage-safety rule (load-bearing for the "remove dead paths" work):** delete **functions** (removes selectors, shrinks bytecode — safe and desired) and dead **logic**, but **never delete or reorder a storage variable** in a deployed proxy. Unused storage vars stay in place — at most rename to `__deprecated_*` with a NatSpec note, preserving slot order/offset/type.

**Pin the Foundry version** for size measurements (CI uses `v1.7.1`; audit machine had `1.3.5`) — size output can differ across forge versions and we operate within ~150 bytes.

---

## Batches (sequenced)

### Batch 0 — Trust model & operational config (NO code; HIGHEST priority)
The protocol is currently a single-EOA-takeover risk. None of this touches bytecode.

> **Approach finalized (2026-06-15) — `BATCH0_OPS_RUNBOOK.md` is the authoritative role matrix + command sequence.** Verified on-chain: no Timelock was ever deployed (every SecureUpgradeable proxy's `timelock` = deployer EOA `0x8DAD…098d1`); the deployer is an **EIP-7702 smart account** (delegate `0x63c0…32b`); **TimeProvider is ownerless/immutable** (initializers permanently disabled — skip it). The upgrade timelock will be an **OpenZeppelin `TimelockController`** (`minDelay=12h`, Safe = sole proposer+executor, `admin=0`) — **not** the native `TimelockUpgradeable`, whose hard-coded `MIN_MULTISIG_APPROVALS=2` (2 distinct signers) is incompatible with a single Gnosis Safe. The deploy script + a passing fork dry-run live in `scripts/deployment/` (`DeployTimelockController.s.sol`, `SimulateBatch0Migration.s.sol`).

| ID | Action |
|---|---|
| **F-1** | Deploy the OZ `TimelockController` (`DeployTimelockController.s.sol`). `setTimelock(controller)` on the **7** SecureUpgradeable proxies. Move the **exact EOA-held role set per contract** (verified on-chain — runbook §2) to the Safe; **leave** QEURO `MINTER`/`BURNER` (Vault) + FeeCollector `FEE_SOURCE` (sources) + Vault `VAULT_OPERATOR`/`YIELD_DISTRIBUTOR`; reassign SlippageStorage `WRITER` to a **backend keeper key, not the Safe**; renounce everything from the EOA (`DEFAULT_ADMIN` last, after exercising the Safe). Record `Timelock` + `Multisig` + `SlippageStorage` (`0x0fde…099b`, missing today) in `deployments/8453/addresses.json`. |
| **F-2** | For the 5 plain-UUPS contracts (`FeeCollector`, `OracleRouter`, `ChainlinkOracle`, `StorkOracle`, `SlippageStorage`) hold `UPGRADER_ROLE`/`GOVERNANCE_ROLE` only in the multisig/timelock. (Code migration to `SecureUpgradeable` deferred — storage-adding, no gaps, risky.) |
| **F-9** | If `ChainlinkOracle.sequencerUptimeFeed == address(0)`, set it to Base's sequencer-uptime feed (setter exists). |
| **F-7 (verify)** | Confirm on-chain that `0xc91D87E8…`/`0x7e860098…` are the canonical Chainlink Base EUR/USD & USDC/USD aggregators (gates the Batch-2 rename). |
| **§5 reads** | ✅ Verified (2026-06-15): `QTIToken.totalSupply()=0`; `UserPool` has no `MINTER_ROLE`; deployer EOA holds all privileged roles on 11 contracts (full per-contract set in runbook §2); proxies' `timelock` = deployer EOA. Note: `getUpgradeSecurityStatus()` does not exist in source — read `timelock()` / `secureUpgradesEnabled()` getters instead. |

**Effect:** moving `DEFAULT_ADMIN_ROLE` to a multisig means the F-5 bypass already requires multisig consensus — de-risking the F-5 *code* fix into a careful, size-checked upgrade.

### Batch 1 — CI safety gates (no bytecode; ship now)
- **B-10 (size gate on PR):** add `make analyze-contract-sizes` to the PR job (`scripts/analyze-contract-sizes.sh` already `exit 1`s on EIP-170 breach).
- **B-9 (storage-layout baseline + diff):** commit `forge inspect <C> storage-layout` for every upgradeable contract into `storage-layout/`; new `scripts/check-storage-layout.sh` + CI step asserting every existing slot is unchanged (slot/offset/type), allowing only appended trailing slots. Generate the baseline from current source **now** so Batch 3 can diff against it.
- **B-11 (ABI/selector diff):** commit ABI + 4-byte selector/event/error baselines for storage-frozen contracts; CI flags removals/changes.
- **Nightly workflow:** run `make ci` (build, slither, validate-natspec, gas-analysis, analyze-warnings, analyze-contract-sizes) + `make mythril`; install Slither in the workflow. Keep the PR job fast (build + test + size + layout/ABI diff). Keep tests offline.

### Batch 2 — Docs / scripts / artifacts (no deployed bytecode)
- **F-7 (rename):** after Batch-0 verification, rename `addresses.json` keys `MockEURUSD`/`MockUSDCUSD` → `EURUSD`/`USDCUSD`; fix `DeployQuantillon.s.sol:486-488` serialization + false comment. **Coordinate with `quantillon-dapp`** `ContractName` union + `update-frontend-addresses.sh`/`copy-abis.sh`.
- **F-16:** decouple `DeployQuantillon.s.sol` from `import "../../test/ChainlinkOracle.t.sol"` and `src/mocks/Mock*Oracle.sol`; move mock-feed deploy to a mocks-only, non-mainnet-guarded path.
- **F-17:** fix `deploy.sh:84` help → `optimizer_runs=0 (size-minimizing for EIP-170)`.
- **F-18:** `setup-external-vaults.sh` reads the key from env/keystore, not `--private-key` on the CLI.
- **F-19 (NatSpec — safe here):** fix copy-paste `@custom:oracle`/`@custom:reentrancy` tags on functions without those properties (throughout `SecureUpgradeable.sol`, etc.); complete the 8 missing helper docs in `ChainlinkOracle.sol`/`StorkOracle.sol`. NatSpec is comments → byte-identical runtime bytecode; verify the hash diff is empty, then no upgrade is needed.
- **Tests (F-12/F-13):** implement or delete the 10 skipped `EconomicAttackVectors.t.sol` + 15 `RaceConditionTests.t.sol` scenarios; remove `test/GasAnalysisTemp.sol`. Keep the suite green; note the test-count change (see Documentation needs).
- **Docs:** see the dedicated **Documentation update needs** section below.

### Batch 3 — Correctness upgrades (full gate + Slither/Mythril + review + upgrade window)
**3a — targeted; each shrinks or is size-neutral**
- **UserPool (F-6/L-2/L-3/L-5):** delete `claimStakingRewards`/`batchRewardClaim` (dead, would mint *unbacked* QEURO if `MINTER_ROLE` were granted); remove dead reward logic (`accumulatedYieldPerShare` term is always 0); make `getUserInfo` stop reporting a phantom `stakingReward`; drop the unused `totalQeuroToMint` and consolidate the repeated `deposit` loops. **Preserve all storage slots.** Net effect should shrink UserPool (verify; buys back EIP-170 headroom).
- **YieldShift (F-8/L-8):** delete `claimUserYield`, the user branch of `emergencyYieldDistribution`, and the user path of `updateYieldAllocation` (all spend the never-funded `userYieldPool`); stop referencing `mockAaveVault`/`IMockAaveVault`. **Preserve slots** `userYieldPool`, `userPendingYield`, `mockAaveVault`. Live path `addYield → creditVaultYield → stQEURO` unchanged.
- **F-3/F-4:** add `constructor() { _disableInitializers(); }` to `OracleRouter` and `FeeCollector` (plain UUPS, independent low-risk upgrades). Test: impl `initialize` reverts `InvalidInitialization`.

**3b — `SecureUpgradeable` F-5 fix (base class → wide blast radius)**
- **F-5:** in `toggleSecureUpgrades(bool enabled)` (`SecureUpgradeable.sol:177`) reject the disable direction — `if (!enabled) revert ...` — forcing disable through the existing `proposeEmergencyDisableSecureUpgrades`/`approve`/`apply` quorum+delay flow (lines 388–453). Same selector. Add a test that `emergencyUpgrade` is unreachable without quorum+delay.
- **Blast radius:** base of all 8 core contracts → each needs a new impl (roll out per-contract, not atomic). **Size-check `QuantillonVault` first** (99.4%, binding constraint); `UserPool` already shrank in 3a. De-risked because Batch 0 put `DEFAULT_ADMIN_ROLE` behind a multisig.

### Batch 4 — Polish (bundle into the next per-contract window; size-check each)
- **F-14:** event in `QuantillonVault.updateOracle` — only if the size diff allows (vault at 99.4%); else defer.
- **F-15:** populate `packedData` in `HedgePositionOpened`/`Closed`; emit `MarginUpdated` where margin changes or remove the never-emitted declaration.
- **F-11:** `require/revert("…")` in `OracleRouter.switchOracle` (L375) and `updatePriceFeeds` (L648) → custom errors.
- **F-20 / L-6:** QTI schedule fields stay (dormant) — document, don't enforce; remove duplicate zero-address checks opportunistically (size-check; pair with Slither triage).

---

## Documentation update needs

Treat documentation as a first-class deliverable of each batch — several docs are currently **wrong or overstated** relative to the live system, and several will go stale the moment code/tests change. Track them here.

### In-repo developer docs
- **`README.md`**
  - QTI: stop describing governance as live with "fixed 100M supply" — state it is **dormant / supply not yet minted** (decision). (L-1)
  - YieldShift: "TWAP-based allocation" → "holding-period-filtered eligible-pool sizes with gradual adjustment". (L-4)
  - Upgrade model: the "timelock + multi-sig, quorum of 2" claim is **contradicted by the live deploy** (EOA admin, no Timelock). After Batch 0 it becomes true; until then, either soften the claim or mark it as the target state. (F-1/F-2, audit §18)
  - Test counts ("57 test files, 1,471+ tests" / pass numbers) — update after Batch 2/3 test changes.
- **`CLAUDE.md`**
  - Same QTI / TWAP / upgrade-model corrections as README.
  - "Testing Standards" counts (test files, total tests, ~46 skips) — update after F-12/F-13 and any new tests.
  - Yield model: state **stQEURO is the canonical user-yield path**; note the removed UserPool/YieldShift reward paths (decision) so future contributors don't resurrect them. (F-6/L-2/F-8)
  - Security Notes: refresh the "0 Critical/0 Medium Slither" line once Slither is actually run in CI (Batch 1) — it is currently unverified in-repo.
- **In-code NatSpec (F-19):** fix misleading `@custom:oracle Requires fresh oracle price data` / `@custom:reentrancy Protected by reentrancy guard` tags on functions without those properties; complete the 8 undocumented internal helpers in `ChainlinkOracle.sol`/`StorkOracle.sol`. Keep `make validate-natspec` ≥ 99.35%.
- **Generated docs:** run `make docs` (forge doc) after NatSpec changes so `docs/` HTML matches.
- **graphify knowledge graph:** after any `src/` change, rebuild per CLAUDE.md — `python3 -c "from graphify.watch import _rebuild_code; from pathlib import Path; _rebuild_code(Path('.'))"` — and re-check `graphify-out/GRAPH_REPORT.md`.

### Deployment & artifact docs
- **`deployments/8453/addresses.json`:** rename feed keys (F-7); **add `Timelock` + multisig entries** once Batch 0 deploys them (currently absent); record each new implementation in the `*-upgrade.json` records per upgrade.
- **`scripts/deployment/DeployQuantillon.s.sol`:** fix the wrong comment at ~L486 ("address(0) on mainnet"); keep `addresses.json` keys in sync with the dApp `ContractName` union (comment near L465).
- **`deploy.sh`:** help-text optimizer-runs fix (F-17).

### dApp coordination (sibling `quantillon-dapp`)
- Mirror the feed-key rename in the dApp `ContractName` union + `src/config/addresses.json`/`addresses.ts`.
- Re-run `copy-abis.sh` and `update-frontend-addresses.sh` after any ABI/address change (e.g. UserPool `getUserInfo` shape, removed reward functions, new impls).

### Process / audit-trail docs
- Keep the three audit reports **and this remediation plan** as the audit trail. Update the **Status tracker** below as items close (or fold status into the consolidated report).
- If any finding is fixed via on-chain upgrade, link the upgrade record (`*-upgrade.json`) next to the item.
- Security disclosure contact: `team@quantillon.money` — coordinate if any finding warrants responsible-disclosure timing.

---

## Critical files
- **Code upgrades:** `src/core/UserPool.sol`, `src/core/yieldmanagement/YieldShift.sol`, `src/core/SecureUpgradeable.sol`, `src/oracle/OracleRouter.sol`, `src/core/FeeCollector.sol`, `src/core/QuantillonVault.sol`, `src/core/HedgerPool.sol`.
- **Scripts/artifacts:** `scripts/deployment/DeployQuantillon.s.sol`, `deploy.sh`, `setup-external-vaults.sh`, `update-frontend-addresses.sh`, `copy-abis.sh`, `deployments/8453/addresses.json`.
- **CI:** `.github/workflows/tests.yml` (extend) + new nightly workflow + new `scripts/check-storage-layout.sh` + `storage-layout/` baselines; reuse existing `Makefile` targets.
- **Docs:** `README.md`, `CLAUDE.md`, `docs/` (generated), `graphify-out/`.
- **Tests:** `test/EconomicAttackVectors.t.sol`, `test/RaceConditionTests.t.sol`, delete `test/GasAnalysisTemp.sol`, add a `SecureUpgradeable` F-5 negative test.

## Do NOT touch (verified correct — editing only risks EIP-170 headroom)
QEURO 1:1 peg math, 105%/101% collateralization gates, 60/25/15 fee split, HedgerPool short-EUR P&L, QTI 4× voting formula, 7-day holding period, stQEURO ERC-4626 accrual, protocol-favouring rounding, 6↔18 decimal handling, flash-loan/CEI/SafeERC20 guards.

---

## Verification
- **Batch 0:** re-read each proxy's roles + `getUpgradeSecurityStatus()` on Base; assert multisig/timelock holds every privileged role and `sequencerUptimeFeed != address(0)`.
- **Batch 1:** a throwaway PR that (a) bloats a contract past EIP-170 and (b) reorders a storage slot must make CI **fail** on both; confirm nightly runs Slither/Mythril/natspec.
- **Batch 2:** `make build` + `make test` green; `make validate-natspec` ≥ 99.35%; F-19 produces byte-identical bytecode (empty hash diff); dApp still resolves `EURUSD`/`USDCUSD` after rename.
- **Batch 3/4 (per contract):** `make build`; `make test` (no new failures/skips); `make analyze-contract-sizes` (vault/UserPool under limit — include before/after size in the PR); storage-layout diff append-only; ABI/selector/event/error diff reviewed; `make slither` + `make mythril` clean; new tests (UserPool reward funcs gone / `getUserInfo` consistent; YieldShift `claimUserYield` gone; OracleRouter/FeeCollector impl `initialize` reverts; F-5 `emergencyUpgrade` unreachable without quorum+delay).
- **Rollout:** each upgrade via the Batch-0 Timelock + multisig; record new impls in `deployments/8453/*-upgrade.json`; re-run `copy-abis.sh` after ABI-affecting changes.

---

## Status tracker

**Legend:** ✅ implemented locally (built + full test suite green + size/storage/ABI gates green; CODE items still need security review + an upgrade window to deploy) · 📋 runbook provided for the team (on-chain ops I can't execute) · ⏳ deferred to a dedicated PR (with reason).

**This session's verified baseline after the changes:** `make build` OK; `make test` **1415 passed / 0 failed / 11 skipped** (was 46; F-12 removed 35 redundant skip-stubs); size gate 0 EIP-170 breaches (**UserPool 99.3% → 94.0%**, **YieldShift 93.2% → 90.9%**; F-14/F-15 events nudged **QuantillonVault 99.4% → 99.5%**, **HedgerPool 96.0% → 97.3%** — both still within limit); storage-layout 15/15 unchanged; ABI 13/13 (UserPool + YieldShift re-baselined for removed dead selectors; QuantillonVault re-baselined for the additive `OracleUpdated` event); **NatSpec 100%** (was 99.35%).

| ID | Title | Sev | Batch | Type | Status |
|---|---|---|---|---|---|
| F-1 | Single-EOA admin; no Timelock | 🔴 | 0 | OPS | 📋 `BATCH0_OPS_RUNBOOK.md` |
| F-2 | Oracle/FeeCollector no upgrade timelock | 🔴 | 0 (ops) / later (code) | OPS/CODE | 📋 runbook (ops); code-migration ⏳ |
| F-9 | Sequencer uptime feed unset | 🟠 | 0 | OPS | 📋 runbook |
| F-7 (verify) | Feed addresses canonical? | 🟠 | 0 | OPS | 📋 runbook |
| B-9 | Storage-layout baseline + CI diff | 🟠 | 1 | CI | ✅ `scripts/check-storage-layout.sh` + `storage-layout/` |
| B-10 | Size-regression gate on PRs | 🟠 | 1 | CI | ✅ added to PR gate |
| B-11 | ABI/selector/event/error diff | 🟡 | 1 | CI | ✅ `scripts/check-abi.sh` + `abi-baseline/` |
| (CI) | Nightly `make ci` + Slither/Mythril | 🟠 | 1 | CI | ✅ ci-base now runs storage+abi; nightly exists. Mythril step ⏳ (not in requirements.txt) |
| F-17 | deploy.sh help optimizer-runs | ⚪ | 2 | SCRIPT/DOCS | ✅ done |
| F-18 | `--private-key` on CLI | 🟡 | 2 | SCRIPT | ✅ env/keystore signer-args |
| F-13 | `GasAnalysisTemp.sol` leftover | ⚪ | 2 | TEST | ✅ removed |
| L-4/L-7/F-10 | Docs: TWAP / cache-write / failover | ⚪ | 2 | DOCS | ✅ README + CLAUDE.md |
| L-1/F-20 | QTI dormant → docs | 🔴→docs | 2 | DOCS | ✅ README + CLAUDE.md (F-20 N/A while dormant) |
| F-3/F-4 | `_disableInitializers` (Router/FeeCollector) | 🟡 | 3a | CODE | ✅ done + impl-lock tests |
| F-6/L-2/L-3 | Remove UserPool dead reward paths | 🟠 | 3a | CODE | ✅ done + tests (L-5 deposit micro-opt ⏳) |
| F-5 | `toggleSecureUpgrades(false)` bypass | 🔴/🟠 | 3b | CODE | ✅ done + negative test |
| F-11 | OracleRouter require-strings | ⚪ | 4 | CODE | ✅ done + test updated |
| F-16 | Deploy script imports test/mocks | 🟡 | 2 | SCRIPT | ✅ done — extracted `MockAggregatorV3` to `src/mocks/`; deploy + 3 scenario scripts no longer import `test/` |
| F-19 | Misleading/missing NatSpec | ⚪ | 2 | DOCS | ✅ **done (full sweep)** — corrected false `@custom:oracle`/`@custom:reentrancy` tags across all impls, interfaces, and libraries via a signature-based fixer (3-way reentrancy vocab: nonReentrant / flashLoanProtection / none; oracle via call-graph reachability + feed detection), preserving bespoke prose. Fixed 2 pre-existing mistags (HedgerPool `addMargin`/`removeMargin`, QEURO `batchMint`/`batchBurn`). Comment-only → byte-identical; **NatSpec 99.35% → 100%** |
| F-7 (rename) | Mislabeled feed keys + comment | 🟠 | 2 | ARTIFACT/DOCS | ⏳ blocked on F-7 verify + dApp `ContractName` coordination |
| F-12 | Skipped attack scenarios | 🟡 | 2 | TEST | ✅ done — deleted 35 redundant pure-skip stubs (real coverage in EconomicAttackVectorsIntegration + integration harness); skips 46→11 |
| F-8 | Remove YieldShift unfunded user path | 🟠 | 3a | CODE | ✅ partial — removed `claimUserYield` (proven dead: nothing funds `userYieldPool`) + interface decl + 6 tests; YieldShift 93.2%→90.9%, slots preserved. Residual (updateYieldAllocation user branch, userYieldPool/userPendingYield storage) documented for follow-up |
| L-8 | YieldShift `mockAaveVault` vestigial state | ⚪ | 3a | CODE | ⏳ dedicated PR — 35 test refs + config/deploy flow |
| F-14 | Vault `updateOracle` event | 🟡 | 4 | CODE | ✅ done — `OracleUpdated` event added (+ false tags fixed); vault 99.4%→**99.5%**, within EIP-170 |
| F-15 | Hedger event `packedData` / unused `MarginUpdated` | ⚪ | 4 | CODE | ✅ done — packedData populated + `MarginUpdated` emitted in add/removeMargin; HedgerPool 96%→97.3% |
| L-5 | UserPool `deposit` redundant loops + unused `totalQeuroToMint` | 🟡 | 4 | CODE | ✅ partial — dead `totalQeuroToMint` removed; full loop-consolidation deferred |
| L-6 | Duplicate zero-address checks | ⚪ | 4 | CODE | ⏳ deferred — **Slither-gated** (kept to silence Slither; needs a verified Slither run first) |

**CODE changes touch deployed/upgradeable contracts** (`OracleRouter`, `FeeCollector`, `SecureUpgradeable` base → all 8 core proxies, `UserPool`, `IUserPool`). They are implemented + verified locally but **must go through the §3 gate + Slither/Mythril + security review + an upgrade window** before deployment. The storage-layout and ABI baselines committed this session are the diff targets for that review.
