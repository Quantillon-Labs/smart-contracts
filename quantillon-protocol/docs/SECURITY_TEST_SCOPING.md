# Security Test Scoping

This document explains why some security-focused test scenarios remain as placeholders or are deferred, and where executable coverage lives.

## Rationale for Deferred Tests

- **EconomicAttackVectors.t.sol**: Several scenarios (e.g. oracle manipulation, sandwich, MEV, liquidation races) require full protocol deployment (vault + oracle + pools) and multi-step attack simulation. Highest-risk ones have been converted to executable tests or covered in IntegrationTests (e.g. `test_Integration_OracleExtremePrice_RevertsMint`). Remaining placeholders document the attack class; automation is deferred until shared vault+oracle setup is available in that file or via a shared helper.

- **RaceConditionTests.t.sol**: Deposit/withdrawal and yield-distribution races that require real UserPool/vault flows remain placeholders. Concrete races using `vm.warp`, `vm.roll`, and timelock/hedger flows have been implemented (ProposalExecution, VotingDeadline, DepositWithdrawSimultaneous, ConcurrentDeposits).

- **ReentrancyTests.t.sol**: Liquidation reentrancy is documented in `test_Reentrancy_Liquidation_Protected`. The protocol has no public `liquidate(position)`; liquidation is triggered by redeem when CR ≤ 101%, and `recordLiquidationRedeem` in HedgerPool is `onlyVault` and `nonReentrant`. A full simulation would require putting the protocol in liquidation mode and a malicious vault callback.

- **GovernanceAttackVectors.t.sol**: The single former placeholder (`test_Governance_MEVProtection_Exists`) is now executable (asserts QTIToken proposalExecutionTime/proposalExecutionHash structure).

## Executable Coverage

- **Oracle / price deviation**: `IntegrationTests.test_Integration_OracleExtremePrice_RevertsMint` (extreme price → mint reverts with ExcessiveSlippage).
- **Flash loan balance protection**: `EconomicAttackVectors.test_Economic_FlashLoanCollateralManipulation_Blocked` (FlashLoanProtectionLibrary rejects decrease beyond maxDecrease).
- **Stale price**: `EconomicAttackVectors.test_Economic_StalePriceRejection` (oracle mocked stale → getEurUsdPrice returns invalid).
- **Invariant liquidation thresholds**: `QuantillonInvariants.invariant_liquidationThresholds` and `invariant_liquidationStateConsistency` assert vault critical ratio and bounds.

## References

- TESTING_IMPROVEMENT_PLAN.md
- UNIT_TESTING_OVERVIEW.md
