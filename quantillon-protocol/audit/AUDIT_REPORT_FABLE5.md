# Quantillon Protocol — Security Audit Report

**Auditor:** Claude Fable 5 (three parallel domain passes + source verification)
**Date:** 2026-06-09
**Commit/branch:** `claude/smart-contract-security-audit-8i2fh1`
**Scope:** `quantillon-protocol/src/` — core contracts, oracle layer, libraries, vault adapters.
**Method:** Adversarial review per `audit/FABLE5_SECURITY_AUDIT_PROMPT.md`, split into three
domains (money-center+tokens, hedging+yield, oracles+wrapper+upgradeability). Findings below
were re-verified by the lead against source; the two highest-severity items are corroborated by
the protocol's *own* code/comments contradicting the buggy path. Foundry was bootstrapped in this
environment (solc 0.8.24 fetched from GitHub) to run PoCs where practical.

> Severity = impact × likelihood. Every High has either a runnable PoC or an airtight
> source-level contradiction. Items below 80% confidence are marked **needs verification**.

---

## Summary

| ID | Title | Severity | Status |
|----|-------|----------|--------|
| **H-1** | `exitHedgePosition` double-counts realized P&L → vault overpayment / hedger shortchange | **High** | Confirmed (source contradicts own formula) |
| **H-2** | USDC deployed to a non-default/non-priority external vault is excluded from collateral accounting and unreachable for redemptions | **High** | Confirmed (source trace) |
| **M-1** | Adding to an existing QTI lock overwrites voting power with only the new deposit | **Medium** | Confirmed + PoC |
| **M-2** | EUR/USD deviation guard has no fast recovery path; a single >5% jump freezes the oracle (blocks mint/redeem/liquidation) until 48h dev-mode | **Medium** (liveness) | Confirmed; partly by-design |
| **M-3** | `claimUserYield` is permanently broken — `userYieldPool` is never funded | **Medium** | Confirmed (source) |
| **M-4** | Switching OracleRouter to Stork silently drops the L2 sequencer-uptime check | **Medium** | Confirmed |
| **M-5** | `EMERGENCY_DISABLE_DELAY_BLOCKS` hard-codes 12s blocks → ~4h instead of 24h on Base | **Medium** | Confirmed |
| **M-6** | YieldShift "TWAP" weights by recency, not interval; recording is permissionless | **Medium** | Confirmed (limited blast radius) |
| **L-1** | `resetCircuitBreaker` emits success even when it re-trips | Low | Confirmed |
| **L-2** | Sequencer grace-period check can revert via `currentTime − seqStartedAt` underflow | Low | Confirmed |
| **L-3** | `_addToPoolHistory` O(n) storage shift makes `updateYieldDistribution` ~10M gas at full history | Low | Confirmed |
| **L-4** | Redemption can revert when needed liquidity is in external-vault accrued yield, not tracked principal | Low | Needs verification |
| **L-5** | stQEURO vaults rely solely on OZ virtual shares (offset 0); no seed/decimals offset | Low | Needs verification |
| **L-6** | Holding-period "eligible pool size" is a flat 50–80% discount, not real per-deposit aging | Low | Confirmed |
| **I-1..** | Informational (no liquidation entrypoint, dead reward code, adapter trust asymmetry, dead rate-limit cap) | Info | Confirmed |

---

## H-1 — `exitHedgePosition` double-counts realized P&L

**Severity:** High. **Confidence:** High — the bug contradicts the contract's own formula.

**Location:** `src/core/HedgerPool.sol:547-578` (`_exitHedgePositionCommit`), esp. lines 562 & 570.

**Root cause.** During partial redemptions, `_processRedeem` → `_applyRealizedPnLToMargin`
(`HedgerPool.sol:1725-1777`) folds realized P&L directly into `position.margin` and also
accumulates it in `position.realizedPnL`. Every value-measuring path therefore subtracts
`realizedPnL` to avoid counting it twice. The contract states this explicitly:

```solidity
// getTotalEffectiveHedgerCollateral — HedgerPool.sol:1098-1105
// Calculate NET unrealized P&L = totalUnrealizedPnL - realizedPnL
// ... so we subtract realizedPnL to avoid double-counting.
int256 netUnrealizedPnL = totalUnrealizedPnL - int256(position.realizedPnL);
int256 e = int256(uint256(position.margin)) + netUnrealizedPnL;
```

`isPositionLiquidatable` and `calculateCollateralCapacity` (HedgerPoolLogicLibrary) do the same.
But the exit path does **not**:

```solidity
// _exitHedgePositionCommit — HedgerPool.sol:562-570
pnl = HedgerPoolLogicLibrary.calculatePnL(cachedFilledVolume, cachedQeuroBacked, currentPrice); // = totalUnrealizedPnL
...
int256 rawPayout = int256(cachedMargin) + pnl;   // margin (already includes realizedPnL) + totalUnrealizedPnL
```

Since `cachedMargin` already includes realized P&L, `rawPayout = margin + totalUnrealizedPnL`
double-counts the realized portion. The payout error equals exactly `position.realizedPnL`.

**Exploit (exact integer trace, fees = 0).** Entry 1.10, margin 10,000 USDC, leverage 5,
fill 50,000 → `qeuroBacked = 45,454.5454e18`, `filledVolume = 50,000e6`.
1. Price → 1.05 (hedger is short EUR → profit).
2. User redeems 10,000 QEURO: `realizedDelta = +500 USDC`; margin → 10,500, `realizedPnL = +500`,
   `qeuroBacked → 35,454.5454e18`, `filledVolume → 39,500e6`.
3. Hedger exits at 1.05:
   - `calculatePnL(39,500e6, 35,454.5454e18, 1.05e18) = +2,272.727273 USDC`.
   - Exit payout = `10,500 + 2,272.727273 = 12,772.727273 USDC`.
   - Correct effective collateral (`getTotalEffectiveHedgerCollateral`) = `10,500 + (2,272.727273 − 500) = 12,272.727273 USDC`.
   - **Overpayment = 500.00 USDC**, exactly the banked realized profit, withdrawn a second time from `vault.withdrawHedgerDeposit`.

Symmetric: with a prior realized *loss*, exit underpays the hedger by `|realizedPnL|`. The
overpayment direction is attacker-reachable at will (open → users mint into the fill → trigger
favorable partial redeems to bank `realizedPnL` → exit to collect it twice), scaling linearly.

**Impact.** USDC is withdrawn from `totalUsdcHeld`, the collateral backing QEURO. Overpayment
directly lowers the protocol CR and is extractable profit; the loss direction silently confiscates
hedger margin. Violates the core invariant `payout == margin + netUnrealizedPnL`.

**Recommendation.** Cache `position.realizedPnL` before `_finalizePosition`, then:
```solidity
int256 totalUnreal = HedgerPoolLogicLibrary.calculatePnL(cachedFilledVolume, cachedQeuroBacked, currentPrice);
pnl = totalUnreal - int256(cachedRealizedPnL);
int256 rawPayout = int256(cachedMargin) + pnl;
```
Add a regression test: open → fill → partial-redeem at a moved price → exit, asserting net USDC out
equals `getTotalEffectiveHedgerCollateral` measured immediately before exit. Consider extracting a
shared `_netUnrealizedPnL(position, price)` helper used by all four paths to prevent divergence.

---

## H-2 — USDC in a non-default/non-priority external vault is uncounted and unreachable

**Severity:** High. **Confidence:** High (source trace). **Precondition:** governance/operator
deploys principal to an active vault id that is neither `defaultStakingVaultId` nor in
`redemptionPriorityVaultIds` — a configuration the public mint API actively permits.

**Location:** `src/core/QuantillonVault.sol` — `_getExternalVaultCollateralBalance()` (2163-2186),
`_resolveWithdrawalPriority()` (1915-1924), deploy targets `mintQEUROToVault`/`mintAndStakeQEURO`/
`deployUsdcToVault` gated only by `_validateMintRouting` (796-800), which checks *active + adapter set*
— **not** membership in the priority list or being the default.

**Root cause.** Both the collateral read and the withdrawal router only ever look at the priority
list, falling back to *only* `defaultStakingVaultId` when it is empty. The global tracker
`totalUsdcInExternalVaults` still includes every vault. So principal deployed to an "orphan" vault
is invisible to CR math yet counted in the global total — the two disagree.

**Consequences.**
1. **CR understated:** `getProtocolCollateralizationRatio` and the live mint gate undercount
   collateral by the orphan balance. The protocol can read CR ≤ 101% (liquidation threshold) while
   genuinely over-collateralized, routing redeemers into `_redeemLiquidationMode`, where
   `usdcPayout = qeuroAmount × _getTotalCollateralWithAccruedYield() / totalSupply` (1251-1252) pays
   a pro-rata share of the *understated* collateral — an unwarranted haircut.
2. **Bricked redemptions:** `_planExternalVaultWithdrawal` validates the deficit against the global
   `totalUsdcInExternalVaults` (includes orphan) and may return a positive amount, but
   `_withdrawUsdcFromExternalVaults` iterates only the priority/default set → reverts
   `InsufficientBalance` (1899) even though the funds exist.

**Recommendation.** Make accounting authoritative over *all* vaults with non-zero tracked principal:
maintain an enumerable set of active vault ids and iterate it in both
`_getExternalVaultCollateralBalance()` and the withdrawal loop (the priority list should only *order*
withdrawals, not define the universe). Minimal hardening: reject deploy targets not in
`redemptionPriorityVaultIds` (or the default) in `_validateMintRouting`/`deployUsdcToVault`.

---

## M-1 — Adding to an existing QTI lock overwrites voting power with only the new deposit

**Severity:** Medium. **Confidence:** High + PoC.

**Location:** `src/core/QTIToken.sol:463-510` — `lock()`, lines 480, 493, 497, 501.

**Root cause.** On a top-up, `lockInfo.amount` correctly accumulates (`newAmount = amount + amount`),
but voting power is computed from **only the new deposit** and **overwritten**, not accumulated:
```solidity
uint256 newVotingPower = amount * multiplier / 1e18;   // line 480: uses `amount`, not `newAmount`
lockInfo.initialVotingPower = uint96(newVotingPower);  // 493: overwrite
lockInfo.votingPower      = uint96(newVotingPower);    // 497: overwrite
totalVotingPower = totalVotingPower - oldVotingPower + newVotingPower; // 501
```

**Numeric proof.** Lock 100,000 QTI @365d (4×) → `votingPower = 400,000e18`. Then add **1 QTI** @365d:
`newVotingPower = 1×4 = 4e18`, so `votingPower` is overwritten to `4e18` while `amount` is
`100,001e18`. Depositing more tokens cut the user's power from 400,000 to 4 (~99.999% loss) and
dropped `totalVotingPower` (the governance metric denominator) by ~400,000e18. The existing
`test_VoteEscrow_ExtendLock` uses an *equal* amount so the regression is masked; it never asserts
`votingPower` after the second lock.

**PoC — executed & passing** (`test/AuditPoC.t.sol::test_PoC_AddingToLockCollapsesVotingPower`,
`forge test`, solc 0.8.24, test profile):
```
amount after first lock : 100000000000000000000000   (100,000 QTI)
votingPower after first : 400000000000000000000000   (400,000)
amount after top-up      : 100001000000000000000000   (100,001 QTI — increased)
votingPower after top-up : 4000000000000000000        (4 — collapsed)
totalVotingPower after 2 : 4000000000000000000        (4 — collapsed)
[PASS] test_PoC_AddingToLockCollapsesVotingPower
```
Adding 1 QTI cut voting power from 400,000 to 4 and dropped the global `totalVotingPower` identically.

**Recommendation.** Recompute over the full position with the effective (extended) duration:
`newVotingPower = newAmount * _calculateVotingPowerMultiplier(effectiveLockTime) / 1e18`; set
`initialVotingPower`/`votingPower` from that and add the delta to `totalVotingPower`. Add a test
asserting a top-up never decreases voting power.

---

## M-2 — EUR/USD deviation guard has no fast recovery; a single >5% jump freezes the oracle

**Severity:** Medium (liveness; partly by-design). **Confidence:** High on mechanism.

**Location:** `src/oracle/ChainlinkOracle.sol:413-433, 485-491, 930-934, 993-1035`; mirrored in
`StorkOracle.sol`.

**Mechanism.** The deviation check rejects any move >5% vs the stored baseline
`lastValidEurUsdPrice`, and the baseline is updated *only* on an accepted read (`_commitEurUsdPrice`,
line 486). If a fresh in-absolute-bounds price jumps >5% in a single feed update, every subsequent
read compares the live price against the frozen baseline and stays invalid. `resetCircuitBreaker`
re-runs the same check and re-trips. Consumers treat `isValid=false` as a hard revert, so mint,
redeem, hedger open/close **and liquidation** all revert. The only escapes are a 48h dev-mode
proposal or an upgrade.

**Design nuance (important).** The existing tests `test_PriceFetching_DirectLargeMoveDoesNotAdvanceBaseline`
and `..._CumulativeValidMovesAdvanceBaseline` show this is **intended**: gradual moves (<5% steps)
advance the baseline and self-heal; a single large jump is deliberately rejected as stale. A real
Chainlink feed usually reports intermediate values (sub-1% deviation threshold), so the baseline
advances in steps and recovers. The genuine risk is the **fast >5% single-update move** (extreme
volatility / depeg), where there is no intermediate value to step through and no on-chain operator
re-seed — recovery requires the 48h dev-mode timelock, during which liquidations cannot execute and
bad debt can accrue.

**Recommendation.** Decouple "reject a suspicious spike" from "freeze the baseline forever." Add a
gated `ORACLE_MANAGER` re-seed of `lastValidEurUsdPrice` to the current feed value (eventful), or a
heartbeat escape: if the live price stays outside the band longer than `MAX_PRICE_STALENESS`, accept
it as the new baseline (a sustained move is real). Apply to StorkOracle too.

---

## M-3 — `claimUserYield` is permanently broken; `userYieldPool` is never funded

**Severity:** Medium. **Location:** `src/core/yieldmanagement/YieldShift.sol:415-428, 450-478, 692-702`.

`addYield` adds the hedger share to `hedgerYieldPool` but routes the user share to stQEURO via
`creditVaultYield`; `userYieldPool` is never incremented anywhere. `claimUserYield` pays from
`userYieldPool` and reverts `InsufficientYield` whenever `userPendingYield[user] > 0`. Result:
(1) if governance ever sets `userPendingYield` (per `IYieldShift` docs), users can never claim;
(2) `getYieldDistributionBreakdown`/`getYieldPerformanceMetrics` always report `userYieldPool = 0`,
misrepresenting the split. Looks like a half-finished migration from a pull model to stQEURO-credit.
**Fix:** pick one model — delete the dead pull-path state, or have `addYield` fund `userYieldPool`.

---

## M-4 — Switching to Stork silently removes the L2 sequencer-uptime check

**Severity:** Medium. **Location:** `StorkOracle.sol` (no sequencer feed) vs `ChainlinkOracle.sol:999-1015`; switch at `OracleRouter.sol:374-386`.

`ChainlinkOracle` gates on the L2 sequencer-uptime feed; `StorkOracle` has no equivalent. Since
`ORACLE_MANAGER_ROLE` can flip `activeOracle` to Stork at any time, a routine governance switch
degrades a documented L2 protection on Base, allowing stale/front-runnable prices during sequencer
recovery. **Fix:** mirror the sequencer gate in StorkOracle, or have OracleRouter require both
oracles expose it before allowing a switch on L2.

---

## M-5 — Emergency-disable delay assumes 12s blocks → ~4h instead of 24h on Base

**Severity:** Medium. **Location:** `src/core/SecureUpgradeable.sol:32-34, 394, 444`.

`EMERGENCY_DISABLE_DELAY_BLOCKS = 24 hours / 12 = 7200`, compared against `block.number`. On Base
(~2s blocks) 7200 blocks ≈ **4 hours**, a quarter of the intended 24h cool-off before secure-upgrade
protections can be torn down (after which `_authorizeUpgrade` falls back to plain `UPGRADER_ROLE`).
**Fix:** base the delay on `block.timestamp` via the shared TimeProvider, or make blocks-per-period a
chain-configured immutable.

---

## M-6 — YieldShift "TWAP" weights by recency, not interval; recording is permissionless

**Severity:** Medium (limited blast radius). **Location:** `YieldShift.sol:1271-1296`; duplicated in
`YieldShiftOptimizationLibrary.sol:371-397`.

`getTimeWeightedAverage` weights each snapshot by `timestamp − cutoffTime` (distance from the window
start), so the most recent sample dominates — it is not a TWAP. `updateYieldDistribution` (which
records snapshots) is permissionless, so anyone can append a fresh snapshot before the average is
read. Blast radius is limited because the value only feeds the *trigger*; the actual shift is
recomputed from current eligible metrics. Still, the claimed manipulation resistance is largely
absent. **Fix:** weight by the duration each snapshot represents (stepwise/trapezoidal TWAP), drop the
trailing partial interval, and enforce a minimum spacing between recorded snapshots.

---

## Low

- **L-1** `resetCircuitBreaker` (`ChainlinkOracle.sol:930-934`, `StorkOracle.sol:919-923`) emits
  `CircuitBreakerReset` even when `_updatePrices` re-trips the breaker → false "recovered" signal to
  monitoring. Emit only on success, or a distinct failure event.
- **L-2** Sequencer grace-period check `currentTime() − seqStartedAt` (`ChainlinkOracle.sol:1012`)
  underflows and reverts if the feed reports a future `seqStartedAt`, turning graceful degradation
  into a hard revert on the mint/redeem/liquidation path. Guard with `seqStartedAt > currentTime()`.
- **L-3** `_addToPoolHistory` (`YieldShift.sol:1352-1372`, `MAX_HISTORY_LENGTH=1000`) does an O(n)
  storage-to-storage shift for both histories on every update once full (~10M gas), a soft-DoS on the
  permissionless rebalancer. Use a ring buffer. (Library copy uses 100 — inconsistent.)
- **L-4** *(needs verification)* Normal-mode redemption gates on collateral *including* accrued yield
  but the withdrawal path caps at tracked principal (`QuantillonVault.sol:1336-1343, 1941-1959`); a
  redemption fundable only from yield can revert. Confirm with an adapter whose `totalUnderlying()`
  exceeds principal.
- **L-5** *(needs verification)* stQEURO vaults use OZ 5.4 ERC4626 with default `_decimalsOffset()=0`
  and no seed deposit; factory creates empty, permissionlessly-depositable vaults. Virtual shares make
  theft unlikely but leave first-depositor griefing/precision exposure. Override `_decimalsOffset()`
  to 3–6 and/or seed dead shares in the initializer.
- **L-6** `_calculateEligibleUserPoolSize`/`_calculateEligibleHedgerPoolSize`
  (`YieldShiftOptimizationLibrary.sol:193-326`) apply a flat 50–80% discount to the *current total*
  rather than excluding deposits younger than `MIN_HOLDING_PERIOD`; the advertised flash-deposit
  protection is largely cosmetic. Track deposit ages or document the approximation.

## Informational

- **I-1** No permissionless hedger liquidation function and no liquidator incentive; undercollateralized
  hedgers are only realized via user redemption flow (`recordLiquidationRedeem`). Architectural risk in
  the single-hedger model.
- **I-2** Dead reward code in UserPool: `accumulatedYieldPerShare` is never updated (always 0); the
  block-based anti-manipulation values in `_updatePendingRewards` are computed then ignored. Maintenance
  hazard if later wired without a per-user reward debt.
- **I-3** Adapter trust asymmetry: Aave/Morpho adapters trust the mock vault's returned `withdrawn`
  value; only MetaMorpho verifies the balance delta. Acceptable for localhost-only mocks per CLAUDE.md,
  but `setAaveVault`/`setMorphoVault` could repoint them at real vaults — adopt the balance-delta check
  uniformly or document the constraint.
- **I-4** Dead 7200-block cap in QEURO rate-limit reset (`QEUROToken.sol:682-685, 723-726`) — capped
  value is never used in proportional math. Remove to avoid implying a sliding reset.
- **I-5** "Quorum 2" in SecureUpgradeable is two `DEFAULT_ADMIN_ROLE` addresses, with the proposer
  auto-counting as approval #1; ensure `DEFAULT_ADMIN_ROLE` is a true multisig, never a single EOA.

---

## Systemic observations

- **One missing `− realizedPnL` term (H-1) is the standout.** Three of four P&L paths are correct;
  the exit path — the one that moves real USDC — is the outlier. A shared `_netUnrealizedPnL` helper
  would have prevented it.
- **Oracle layer is conservative about *accepting* bad prices (good) but its protection and its
  recovery share the same gate (M-2),** so it cannot self-heal from a fast large move. Decoupling
  rejection from baseline-freeze is the key architectural fix.
- **Several subsystems look mid-migration** (user-yield pull vs stQEURO-credit in M-3; dead reward
  accumulator in I-2). Worth a deliberate cleanup before sign-off.

## Well-defended (positive notes)

- Strong CEI discipline and reentrancy guards across vault mint/redeem and hedger exit/margin paths;
  state cleared before external transfers.
- Protocol-favorable rounding throughout the money math; FeeCollector routes dust to community with no
  leakage; ETH recipients whitelisted and code-size-checked.
- `addYield` validates actual USDC received (balance delta) vs claimed — defeats fee-on-transfer tricks.
- All oracle reads check `roundId == answeredInRound`, `startedAt ≤ updatedAt`, `price > 0`, freshness,
  and future-dating; ChainlinkOracle includes an L2 sequencer gate; dev-mode and emergency-disable are
  timelocked; `_disableInitializers()` present on all in-scope implementations.

## Verification status

- **H-1, H-2, M-3, M-4, M-5, M-6** confirmed by source trace (H-1/H-2 corroborated by the protocol's
  own contradicting code/comments).
- **M-1** confirmed by source **and** an executed, passing Foundry PoC (`test/AuditPoC.t.sol`,
  output reproduced above).
- **M-2** mechanism confirmed and shown to be partly intended by existing tests; framed as a liveness
  risk, not a clean exploit.
- **L-4, L-5** marked needs-verification with the exact test that would confirm them.
