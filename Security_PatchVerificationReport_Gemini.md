# Smart-Contract Security Audit Report: Quantillon Protocol

**Date:** March 9, 2026
**Auditor:** Gemini Smart Contract Audit Division

## 1. Executive Summary

This report provides a verification of the fixes implemented for the security findings detailed in the `Security_MetaAnalysisFinalReport_Claude.md` document. The audit focused on sequentially reviewing each finding from Critical to Low severity and assessing the correctness and completeness of the applied patches.

**Overall Finding:** The majority of the critical and high-severity vulnerabilities have been **correctly and robustly fixed**. The development team has shown a strong understanding of the issues and has implemented the recommended changes effectively.

However, one issue, **HIGH-2**, has been only **partially fixed**. While the immediate risk of underflow has been eliminated, the secondary issue of the interest accounting gap has not been addressed, which can lead to trapped yield.

All other reviewed findings (**CRIT-1, HIGH-1, HIGH-3, MED-1, MED-2, MED-3, MED-4, MED-5, MED-6, MED-7, LOW-1**) have been **successfully patched**.

No new security issues were identified during this audit.

## 2. Detailed Findings Verification

### 2.1. Critical Severity

| ID | Finding | Status | Auditor's Notes |
|---|---|---|---|
| **CRIT-1** | Unauthorized `claimHedgingRewards()` | ✅ **Fixed** | The function now correctly implements an authorization check, restricting its execution to the `singleHedger` address only. The vulnerability is fully remediated. |

### 2.2. High Severity

| ID | Finding | Status | Auditor's Notes |
|---|---|---|---|
| **HIGH-1** | Upgrade Mechanism Non-Functional | ✅ **Fixed** | The `executeUpgrade` function in `TimelockUpgradeable.sol` now correctly calls the proxy's upgrade function (`ISecureUpgradeable(proxy).executeUpgrade(implementation)`), ensuring that upgrades are properly executed. The vulnerability is resolved. |
| **HIGH-2** | `_withdrawUsdcFromAave` `unchecked` Block | ⚠️ **Partially Fixed** | The `unchecked` block was removed, mitigating the critical underflow risk. However, the interest accounting gap remains. The current implementation will revert if interest has accrued, preventing the withdrawal of that interest. The funds are safe but inaccessible without a further contract upgrade. |
| **HIGH-3** | `distributeYield()` Decimal Scale Mismatch | ✅ **Fixed** | The `distributeYield` function in `stQEUROToken.sol` now correctly converts the 6-decimal USDC yield amount to an 18-decimal QEURO-denominated value using an oracle price before updating the exchange rate. This resolves the decimal mismatch and ensures yield is distributed correctly. |

### 2.3. Medium Severity

| ID | Finding | Status | Auditor's Notes |
|---|---|---|---|
| **MED-1** | `devModeEnabled` Bypasses Protection | ✅ **Fixed** | The ability to instantly enable `devModeEnabled` has been removed. All three affected contracts (`QuantillonVault`, `StorkOracle`, `ChainlinkOracle`) now implement a two-step, timelocked process (`proposeDevMode` and `applyDevMode`) for changing this state variable, which is the correct remediation. |
| **MED-2** | HedgerPool Reward No Funding Mechanism | ✅ **Fixed** | A new public function, `fundRewardReserve(uint256 amount)`, has been added to `HedgerPool.sol`. This function provides the necessary mechanism for the protocol to fund the hedging rewards, resolving the economic flaw. |
| **MED-3** | `TREASURY_ROLE` Dual Capability | ✅ **Fixed** | The roles have been successfully segregated. A new `FEE_SOURCE_ROLE` has been created for authorizing fee deposits, while the `TREASURY_ROLE` is now solely used for fee distribution. This correctly implements separation of duties. |
| **MED-4** | `FeeCollector` Rejects Smart Contracts | ✅ **Fixed** | The `validateNotContract` checks have been removed from the `initialize` and `updateFundAddresses` functions in `FeeCollector.sol`. This allows the protocol to use smart contract-based treasuries, such as Gnosis Safes, aligning with DeFi best practices. |
| **MED-5** | `redeemQEUROLiquidation()` Accessible at CR=0 | ✅ **Fixed** | A check has been added to the `redeemQEUROLiquidation` function in `QuantillonVault.sol` to ensure that the `hedgerPool` and `userPool` contract addresses are initialized. This prevents the function from being called in an uninitialized state where the collateralization ratio would be incorrectly calculated as zero. |
| **MED-6** | `addMargin()` Fee Stranded in Vault | ✅ **Fixed** | The `addMargin` function in `HedgerPool.sol` has been refactored to correctly separate the margin fee from the net margin amount. The fee is now properly routed to the `FeeCollector`, and only the net amount is sent to the vault, preventing collateral ratio inflation. |
| **MED-7** | `_executeAaveDeployment()` Exposed as `external` | ✅ **Fixed** | The function now includes a manual reentrancy guard using the `_aaveDeploymentInProgress` boolean flag. This provides a dedicated lock for the function, preventing reentrancy attacks through the `try/catch` pattern used to call it. |

### 2.4. Low Severity

| ID | Finding | Status | Auditor's Notes |
|---|---|---|---|
| **LOW-1** | Raw `approve()` in `_transferLiquidationFees` | ✅ **Fixed** | The raw `approve()` call in the `_transferLiquidationFees` function has been replaced with the safer and more consistent `safeIncreaseAllowance`, as recommended. |

## 3. Conclusion

The Quantillon Protocol development team has diligently addressed the security findings. With the exception of the partial fix for **HIGH-2**, all reviewed critical, high, and medium severity vulnerabilities have been fully remediated. We recommend the team implement a solution for the interest-harvesting gap in **HIGH-2** to ensure all protocol-generated yield is accessible.
