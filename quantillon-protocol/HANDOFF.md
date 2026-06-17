# Quantillon Remediation — Handoff

> What was implemented this session, **what the team must do manually**, and **what to do
> afterwards**. Companion to `REMEDIATION_PLAN.md` (full plan + status tracker),
> `BATCH0_OPS_RUNBOOK.md` (on-chain ops), and the three `*_AUDIT_REPORT.md` files.
>
> **Verified state of the working tree:** `make build` OK; `make test` all green;
> upgrade-safety gates green (size 0 breaches, storage 15/15, ABI 13/13). Exact counts are in
> `REMEDIATION_PLAN.md` → Status tracker. **Nothing is committed and nothing is deployed.**

---

## 0. Remaining work / next steps (single view)

> Per-item detail is in `REMEDIATION_PLAN.md` (status tracker) and §2–§6 below; this is the ranked summary. The **in-repo audit-fix work is essentially complete** — what's left is mostly the team's on-chain work plus a few decisions.

- **DONE this pass:** F-14 (vault `OracleUpdated` event — fit at 99.5%), F-15 (hedger `packedData` + the missing `MarginUpdated` emits), L-5 (dead `totalQeuroToMint` removed), the bounded F-19 sweep (82 universally-false tags), and **F-12** (deleted 35 redundant pure-skip attack stubs; real coverage preserved). Suite **1415 passed / 0 failed / 11 skipped** (was 46); NatSpec 100%; gates green.
- **F-19 now fully complete:** the per-function/cross-contract NatSpec sweep is finished across all impls, interfaces, and libraries. Reentrancy tags now use a precise 3-way vocabulary — `Protected by reentrancy guard` (only `nonReentrant` fns), `Protected by flashLoanProtection modifier` (only `flashLoanProtection` fns, e.g. QTI `lock`/`batchLock`/`batchVote`, QEURO `batchMint`/`batchBurn`), `Not protected by a reentrancy guard` (neither) — and the surgical fixer preserves bespoke hand-written prose (e.g. "Protected by CEI pattern"), only rewriting the copy-paste boilerplate. Fixed two real pre-existing mistags: HedgerPool `addMargin`/`removeMargin` were labelled flashLoanProtection but are `nonReentrant`; QEURO `batchMint`/`batchBurn` were labelled "not protected" but use `flashLoanProtection`. Oracle boilerplate (`Requires fresh oracle price data`) now sits only on genuine oracle/feed readers — the libraries (`TreasuryRecoveryLibrary`, `TokenLibrary`, `TimeProviderLibrary`) and ChainlinkOracle admin fns were corrected. All comment-only → byte-identical bytecode; NatSpec 100%; storage 15/15, ABI 13/13, size PASS.

**A. Doable now, in-repo (no on-chain action or decision needed)**
- **L-6** — **Slither-gated**: several duplicate zero-address checks exist specifically to silence Slither's missing-zero-check detector; removing them needs a verified Slither run first (the nightly slither job has a `requirements.txt` path bug), else the "0 Slither findings" posture may regress.
- **L-5 remainder** — the bigger `deposit` loop-consolidation (arrays iterated ~6×) is a hot-path refactor left as a follow-up.
- **Stage the commits** — nothing is committed yet (3-way split in §3).

**B. Blocked on the team — on-chain / process**
1. **Batch 0 — #1 priority.** Deploy a Timelock + multisig, move every privileged role off the deployer EOA, set the sequencer feed, verify the feeds (`BATCH0_OPS_RUNBOOK.md`). Single-key takeover risk until done. (§2)
2. **Pre-merge gate** for the contract fixes — run `make slither` + `make mythril` (never run this session; the nightly slither job has a `requirements.txt` path bug) + human security review. (§2)
3. **Deploy the fixes** (F-3/F-4, F-5, F-6, F-8, F-11) via the new `Upgrade<Contract>.s.sol` scripts — dry-run on a fork, then propose→approve→execute through the timelock+multisig (F-5 touches all 8 core proxies). (§4)
4. **F-7** — rename the mislabeled feed keys; blocked on the Batch-0 feed verification + `quantillon-dapp` coordination. (§6)

**C. Decisions the team owes (these gate further code work)** — F-2 (hold oracle/FeeCollector roles in a timelock vs. migrate to SecureUpgradeable), QTI activation timing, **F-8-full / L-8** (remove the rest of the vestigial `userYieldPool` path + `mockAaveVault`, 35 test refs), and the pre-existing **`getUserInfo` return-order** mismatch (impl vs. interface). (§5)

---

## 1. What was implemented (local working tree only)

See the status tracker in `REMEDIATION_PLAN.md` for the per-finding table. In short:
- **CI gates (safe-now):** `scripts/check-storage-layout.sh` + `storage-layout/*.layout`, `scripts/check-abi.sh` + `abi-baseline/*.abisig`, wired into the PR gate and nightly `make ci`.
- **Docs/scripts (safe-now):** F-17, F-18, F-13, F-16, and doc corrections (QTI dormant, TWAP, oracle cache/failover) in `README.md` + `CLAUDE.md`. **F-16:** `MockAggregatorV3` was extracted from `test/ChainlinkOracle.t.sol` into `src/mocks/MockAggregatorV3.sol`; the deploy script and 3 scenario scripts now import it from `src/mocks/` and no longer pull in any `test/` file.
- **NatSpec (F-19, comment-only → byte-identical):** documented the 8 internal oracle helpers in ChainlinkOracle/StorkOracle and corrected the false `@custom:oracle`/`@custom:reentrancy` tags across **all** impls, interfaces, and libraries (not just SecureUpgradeable) — coverage 99.35% → 100%. The reentrancy fix is a precise 3-way vocabulary (reentrancy guard / flashLoanProtection / none) applied only to copy-paste boilerplate, preserving bespoke prose; the oracle fix uses call-graph reachability (consumers) and feed-read detection (oracle contracts). Touches deployed-source files but produces identical runtime bytecode (NatSpec is stripped at compile; storage/ABI/size gates stayed green).
- **Contract fixes (need review + upgrade):** F-3/F-4 (`_disableInitializers` on OracleRouter + FeeCollector), F-5 (`toggleSecureUpgrades` enable-only), F-6/L-2/L-3 (UserPool dead reward removal), F-11 (OracleRouter custom errors), F-8 partial (removed `claimUserYield`; documented the residual vestigial user-yield path).

---

## 2. MANUAL / on-chain actions required (cannot be done from the repo)

**Top priority — `BATCH0_OPS_RUNBOOK.md`.** The live deployment still has **every privileged role on the deployer EOA** = single-key full takeover. Deploy a Timelock + multisig, transfer all roles, set the sequencer feed, verify the Chainlink feeds. Do this **before** anything else; it also de-risks F-5.

**Pre-merge for any CODE change (the §3 gate in `REMEDIATION_PLAN.md`):**
- Run `make slither` and `make mythril` on the branch — **I did not run them this session** (they're part of the deploy gate). Note: `scripts/run-slither.sh` does `pip install -r requirements.txt`; `requirements.txt` lives at the **repo root**, not in `quantillon-protocol/` — verify the slither job installs deps correctly (the nightly `ci-heavy` job sets up Python but its `if [ -f requirements.txt ]` check is relative to `quantillon-protocol/` and will be false — fix that path).
- Human security review of the diff, focusing on the storage-frozen contracts: **OracleRouter, FeeCollector, SecureUpgradeable (base → all 8 core proxies), UserPool, YieldShift**.

---

## 3. Git / commit guidance

Nothing is staged. The new baseline directories **must be committed** for CI to work:
- `storage-layout/*.layout` (15 files) and `abi-baseline/*.abisig` (13 files). **Note:** the repo `.gitignore` has `*.abi` (Foundry artifact pattern); that's why the ABI baselines use the `.abisig` extension — do not rename them back to `.abi`.
- New scripts `scripts/check-storage-layout.sh`, `scripts/check-abi.sh`; docs `REMEDIATION_PLAN.md`, `BATCH0_OPS_RUNBOOK.md`, `HANDOFF.md`, and the three `*_AUDIT_REPORT.md`.

**Suggested commit split** (so the safe work can merge without waiting on the upgrade review):
1. **`chore(ci): upgrade-safety gates`** — Makefile, workflow, both check scripts, `storage-layout/`, `abi-baseline/`. Safe to merge now.
2. **`docs+scripts: audit hygiene`** — README, CLAUDE.md, deploy.sh, setup-external-vaults.sh, remove GasAnalysisTemp, the planning/handoff docs. Safe to merge now.
3. **`fix(contracts): audit findings F-3/F-4/F-5/F-6/F-8/F-11`** — the `src/` + `test/` changes. **Do not merge until the §2 review gate passes.** This commit also updates `abi-baseline/UserPool.abisig` (2 dead selectors removed) and `abi-baseline/YieldShift.abisig` (claimUserYield removed) — those re-baselines are intentional; the diff documents why.

> `deploy.sh` / `setup-external-vaults.sh` are git-crypt encrypted; commit them from an unlocked checkout so the encrypted blobs update correctly.

---

## 4. What to do AFTER review — deploy choreography

The CODE changes only take effect via UUPS upgrades. Group by contract to minimise windows:
1. **OracleRouter** — new impl (F-3 constructor + F-11 errors). Plain UUPS; upgrade via `UPGRADER_ROLE` (held by the multisig after Batch 0).
2. **FeeCollector** — new impl (F-4 constructor). Plain UUPS; `GOVERNANCE_ROLE`.
3. **UserPool** — new impl (F-6 reward removal). SecureUpgradeable; route through the Timelock. **Include the before/after size diff in the PR** (it drops 99.3% → 94.0%).
4. **YieldShift** — new impl (F-8 `claimUserYield` removal). SecureUpgradeable; Timelock.
5. **F-5 (SecureUpgradeable base)** — affects **all 8 core proxies** (QEUROToken, QuantillonVault, QTIToken, UserPool, HedgerPool, stQEUROToken, stQEUROFactory, YieldShift). Each needs a new impl to inherit the fix; roll out per-contract through the Timelock. **Size-check QuantillonVault (99.4%) on every one** — it's the binding EIP-170 constraint.

Every upgradeable proxy now has a dedicated `scripts/deployment/Upgrade<Contract>.s.sol` (10 added this session, sharing `UpgradeBase.s.sol`; see the deployment README "Upgrade Scripts" section). Default action is `deploy-only` (deploy + review); then `propose`/`approve`/`execute` for SecureUpgradeable contracts or `deploy-upgrade` for plain UUPS. Most need `--libraries` (at least `TreasuryRecoveryLibrary`; each script's header lists its set). `stQEUROToken` is per-vault — pass `STQEURO_TOKEN=<tokenProxy>`. **Dry-run each on a fork before mainnet.**

After each upgrade: record the new impl in `deployments/8453/*-upgrade.json`; after any ABI-affecting change run `scripts/deployment/copy-abis.sh` and re-baseline (`scripts/check-abi.sh --update`, `scripts/check-storage-layout.sh --update`) so CI's diff target matches the new live impls; re-run `make validate-natspec` and `make docs`; rebuild the graphify graph.

---

## 5. Decisions the team still owes (these gate the remaining work)

1. **F-2:** hold oracle/FeeCollector `UPGRADER_ROLE`/`GOVERNANCE_ROLE` in the Timelock+multisig (ops, recommended short-term), or migrate them to `SecureUpgradeable` (code, storage-adding — append-only). 
2. **QTI:** confirm governance stays dormant (current: docs say so). When launching, add a mint/distribution path (upgrade) — there is **no mint path in code today**.
3. **YieldShift residual (F-8 full / L-8):** I removed the user-facing `claimUserYield` and documented the rest. Still vestigial and recommended for a future upgrade: the `isUser=true` branch of `updateYieldAllocation`, and the `userYieldPool`/`userPendingYield` storage (**proven never funded** — no code path increments `userYieldPool`; the tests faked it via `stdstore`). Removing them is a clean follow-up. Separately, **`mockAaveVault`/`IMockAaveVault`** (L-8) is woven through 35 test refs + the config/deploy flow — a dedicated PR. Decide remove vs keep-for-localhost-dev.
4. **Pre-existing bug found in code review — `getUserInfo` return order:** the impl returns positions 6/7 as `(unstakeAmount, unstakeRequestTime)`; `IUserPool` names them `(unstakeRequestTime, unstakeAmount)`. All `uint256`, so it compiles and the selector matches, but a consumer decoding by the interface's names gets them **swapped**. The deployed impl is the live reality. **Confirm which order the dApp expects**, then either fix the interface names to match the impl (zero on-chain change) or, if the impl is wrong, fix it in an upgrade. Not changed this session (ambiguous which side is canonical).

---

## 6. Deferred audit items (not started; reasons in the status tracker)

- **F-7** (feed-key rename) — blocked on Batch-0 feed verification + `quantillon-dapp` `ContractName` coordination.
- **L-6** (duplicate zero-address checks) — **Slither-gated**: kept to silence Slither; removing needs a verified Slither run first.
- **L-5 remainder** — the bigger `deposit` loop-consolidation (the dead `totalQeuroToMint` is already removed).
- **F-19 — COMPLETE.** Both the universally-false tags and the per-function sweep are done across all impls (UserPool, HedgerPool, QuantillonVault, QTIToken, YieldShift, QEUROToken, ChainlinkOracle, StorkOracle), interfaces, and libraries. Method: a robust signature-based fixer that overwrites only the three generic boilerplate strings (preserving bespoke prose like "Protected by CEI pattern") and re-derives each from the function's actual guard (`nonReentrant` → reentrancy guard, `flashLoanProtection` → flashLoanProtection modifier, neither → not protected); oracle tags via call-graph reachability + feed-read detection. Verified: every remaining `Protected by reentrancy guard` sits on a `nonReentrant` fn and every remaining `Requires fresh oracle price data` on a genuine oracle/feed reader. Two real pre-existing mistags fixed in passing (HedgerPool `addMargin`/`removeMargin`; QEURO `batchMint`/`batchBurn`). `IMockAaveVault` (vestigial dev mock, no oracle/guard) was blanket-corrected; nothing is left skipped.
- **UserPool cleanup follow-ups found in review (not bugs):** `_updatePendingRewards` still accrues `pendingRewards` on stake/unstake into a now-unread field (gas waste — safe to stop accruing in a future upgrade, but verify `lastStakeTime`/`userLastRewardBlock` aren't needed by cooldown logic first); orphaned `MAX_REWARD_BATCH_SIZE` constant and `StakingRewardsClaimed` event (left in place — removing the event would be an ABI change).
