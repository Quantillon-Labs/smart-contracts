# Quantillon Protocol Patch Verification Report

**Date:** March 9, 2026  
**Scope:** verification of the patches applied for the 25 findings listed in `Security_MetaAnalysisFinalReport_Claude.md` against the current `quantillon-protocol` codebase

## Summary

- **Fixed:** 17 / 25
- **Partially fixed:** 6 / 25
- **Not fixed:** 2 / 25
- **Additional issues found during review:** 3

## Method

- Reviewed the patched contracts and related tests in `quantillon-protocol/src/` and `quantillon-protocol/test/`.
- Reviewed deployment wiring in `quantillon-protocol/scripts/deployment/DeployQuantillon.s.sol`.
- Ran the full Foundry suite: `forge test` -> **1455 tests passed, 0 failed, 57 skipped**.

## Per-Finding Verdict

| ID | Status | Verdict | Key Evidence |
|---|---|---|---|
| CRIT-1 | Fixed | `claimHedgingRewards()` is now restricted to `singleHedger`, which closes the original any-EOA drain vector. | `src/core/HedgerPool.sol:829-835` |
| HIGH-1 | Fixed | Timelock execution now records the proposing proxy and actually calls `ISecureUpgradeable(proxy).executeUpgrade(implementation)`. | `src/core/TimelockUpgradeable.sol:216-225`, `src/core/TimelockUpgradeable.sol:290-315` |
| HIGH-2 | Partially fixed | The dangerous `unchecked` subtraction is gone, but the interest-accounting half of the finding remains: vault collateral still uses principal-only `totalUsdcInAave`, while accrued Aave yield lives separately in `AaveVault`. | `src/core/QuantillonVault.sol:1429-1446`, `src/core/vaults/AaveVault.sol:631-706` |
| HIGH-3 | Fixed | `distributeYield()` now converts 6-decimal USDC yield into 18-decimal QEURO before updating `exchangeRate`. | `src/core/stQEUROToken.sol:656-666` |
| MED-1 | Fixed | Dev mode is no longer a one-transaction bypass; vault and both oracle implementations now require a proposal plus 48-hour delay. | `src/core/QuantillonVault.sol:2082-2094`, `src/oracle/ChainlinkOracle.sol:1126-1140`, `src/oracle/StorkOracle.sol:1152-1166` |
| MED-2 | Not fixed | `fundRewardReserve()` is only a manual transfer wrapper. There is still no protocol-level routing from fees or yield into HedgerPool, so rewards remain structurally unfunded. | `src/core/HedgerPool.sol:870-873`, `src/core/HedgerPool.sol:1278-1282` |
| MED-3 | Fixed | Fee-source authorization is now split from treasury distribution authority via `FEE_SOURCE_ROLE`. | `src/core/FeeCollector.sol:54-56`, `src/core/FeeCollector.sol:149-156`, `src/core/FeeCollector.sol:576-579`, `src/core/FeeCollector.sol:596-599`, `src/core/FeeCollector.sol:756-758` |
| MED-4 | Fixed | Contract treasuries are now allowed; `validateNotContract` was removed from initialization and fund-address updates. | `src/core/FeeCollector.sol:192`, `src/core/FeeCollector.sol:540` |
| MED-5 | Fixed | `redeemQEUROLiquidation()` now rejects calls before `hedgerPool` and `userPool` are initialized. | `src/core/QuantillonVault.sol:1056-1061` |
| MED-6 | Fixed | Margin fees no longer inflate vault collateral: only `netAmount` is sent to the vault, and the fee is separated. | `src/core/HedgerPool.sol:573-585` |
| MED-7 | Fixed | `_executeAaveDeployment()` now has a dedicated self-call reentrancy lock, which is the right shape for this `try this...` pattern. | `src/core/QuantillonVault.sol:694-714` |
| LOW-1 | Fixed | Liquidation fee transfer now uses `safeIncreaseAllowance` instead of raw `approve()`. | `src/core/QuantillonVault.sol:1018-1022` |
| LOW-2 | Fixed | The deviation gate now activates at the boundary block via `>=`. | `src/libraries/PriceValidationLibrary.sol:43-49` |
| LOW-3 | Not fixed | The failure is no longer silent, but liquidation still proceeds while HedgerPool accounting is skipped. This preserves the desync risk. | `src/core/QuantillonVault.sol:995-1002` |
| LOW-4 | Partially fixed | New cached view helpers were added, but the original query functions remain non-`view`, and `getVaultMetrics()` is still stateful. | `src/core/QuantillonVault.sol:1098-1122`, `src/core/QuantillonVault.sol:1659-1735` |
| LOW-5 | Partially fixed | First-price poisoning is mitigated by requiring a seeded cache, but bootstrap minting still bypasses the normal collateral/hedger checks once the cache is initialized. | `src/core/QuantillonVault.sol:601-604`, `src/core/QuantillonVault.sol:616`, `src/core/QuantillonVault.sol:1741-1747` |
| LOW-6 | Fixed | Pending upgrades now expire after `MAX_PROPOSAL_AGE`. | `src/core/TimelockUpgradeable.sol:35-36`, `src/core/TimelockUpgradeable.sol:89`, `src/core/TimelockUpgradeable.sol:295-296` |
| LOW-7 | Fixed | Liquidation slippage is now checked against the post-fee payout. | `src/core/QuantillonVault.sol:903-907` |
| INFO-1 | Fixed | The dead `totalFeeAmount` calculation was removed from `batchMint()`. | `src/core/QEUROToken.sol:521-523` |
| INFO-2 | Partially fixed | The single-hedger constraint is now documented in source comments, but the concentration risk remains by design. | `src/core/HedgerPool.sol:97-102` |
| INFO-3 | Fixed | The misleading `TAKES_FEES_DURING_LIQUIDATION` source constant was removed from logic and replaced with direct behavior. | `src/core/QuantillonVault.sol:210`, `src/core/QuantillonVault.sol:975-978` |
| INFO-4 | Partially fixed | Emergency disable is no longer instant, but it is still a single-admin path rather than a multisig threshold. | `src/core/SecureUpgradeable.sol:341-352` |
| INFO-5 | Fixed | `calculateLiquidationPayout()` now uses the same actual-USDC formula as liquidation execution. | `src/core/QuantillonVault.sol:1849-1855` |
| INFO-6 | Fixed | The unreachable manual overflow check in `VaultMath.mulDiv()` was removed. | `src/libraries/VaultMath.sol:44-47` |
| INFO-7 | Partially fixed | Source comments were corrected, but the public interface still documents mint/redemption fees and collateral ratios as basis points. | `src/core/QuantillonVault.sol:201-217`, `src/interfaces/IQuantillonVault.sol:460-461`, `src/interfaces/IQuantillonVault.sol:475-476`, `src/interfaces/IQuantillonVault.sol:536-537`, `src/interfaces/IQuantillonVault.sol:688-689` |

## Additional Issues Found

### NEW-1: `HedgerPool.claimHedgingRewards()` double-counts `yieldShiftRewards`

**Severity:** Medium

`claimHedgingRewards()` reads `yieldShiftRewards`, adds it into `totalRewards`, then calls `yieldShift.claimHedgerYield(hedger)`. That `YieldShift` function already transfers USDC directly to the hedger. After that, `HedgerPool` still tries to pay or escrow the full `totalRewards`, including the already-paid `yieldShiftRewards`.

- Direct payment path: the hedger receives `yieldShiftRewards` twice.
- Deferred path: `pendingRewardWithdrawals[hedger]` is overstated by the already-paid `yieldShiftRewards`.

**Evidence**

- `src/core/HedgerPool.sol:856-873`
- `src/core/yieldmanagement/YieldShift.sol:489-500`

**Recommended fix**

- Either exclude `yieldShiftRewards` from HedgerPool's own payout after `yieldShift.claimHedgerYield()`, or
- change the flow so YieldShift pays HedgerPool, not the hedger, and HedgerPool becomes the single settlement point.

### NEW-2: Deployment script does not wire all newly required post-patch dependencies

**Severity:** Medium (availability / operability)

The deployment script now authorizes `quantillonVault` as a fee source, but it does not perform the other calls required by the patches:

- no `quantillonVault.initializePriceCache()`
- no `stQeuroToken.setOracle(address(oracleRouter))`
- no `hedgerPool.setFeeCollector(address(feeCollector))`
- no `feeCollector.authorizeFeeSource(address(hedgerPool))`

As written, the deployed system can launch with patched code but incomplete wiring:

- first mint stays unusable until governance seeds the price cache
- `stQEURO.distributeYield()` reverts until its oracle is set
- a future non-zero `marginFee` will not be operationally wired for fee collection

**Evidence**

- `scripts/deployment/DeployQuantillon.s.sol:438-463`

### NEW-3: `ISecureUpgradeable` is stale after the two-step emergency-disable change

**Severity:** Informational

The interface still exposes the removed one-step `emergencyDisableSecureUpgrades()` function and does not expose `proposeEmergencyDisableSecureUpgrades()` / `applyEmergencyDisableSecureUpgrades()`.

This is not an on-chain exploit by itself, but it is integration drift in a security-sensitive interface and will mislead external callers or future upgrades.

**Evidence**

- `src/interfaces/ISecureUpgradeable.sol:183-195`
- `src/core/SecureUpgradeable.sol:341-352`

## Bottom Line

The critical outsider exploit and most of the concrete contract bugs are addressed. The current patch set is materially better than the version described in the original meta-report.

The remaining blockers are:

- `MED-2` is still not really solved.
- `LOW-3` is still not really solved.
- `HIGH-2`, `LOW-4`, `LOW-5`, `INFO-4`, and `INFO-7` are only partial remediations.
- `NEW-1` is a real additional accounting bug in the patched reward flow.

I would not treat this patch set as fully launch-ready until `MED-2`, `LOW-3`, and `NEW-1` are resolved and the deployment wiring from `NEW-2` is incorporated into the production runbook/script.
