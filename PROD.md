# Production documentation and operations

Signed quotes are active on Base mainnet since **17 October 2026**. Production uses Vault 1.6.0, UserPool 1.3.0, HedgerPool 1.6.0, HyperliquidEurUsdOracle 1.0.7, SignedExecutionPricing 1.1.0 and SignedReferenceSource 1.0.0. Normal quotes have a maximum lifetime of 45 seconds from the market observation; the emergency-redemption budget is zero.

The [production integration guide](quantillon-protocol/docs/Signed-Quote-Migration.md) records the confirmed activation, addresses, verified bindings and ongoing operational requirements. The [public documentation](https://smartcontracts.quantillon.money/Signed-Quote-Migration.html) is published from `main` by the Forge Docs workflow. The [GitBook](https://docs.quantillon.money/) is maintained in the separate `Quantillon-Labs/gitbook` repository.

Future releases must preserve the division between the Safe's operational roles and the controller's 12-hour upgrade delay. Timelock expiry requires explicit execution. Reconcile outstanding authorizations, Base settlements and real venue fills before replacing active bindings; a software or database rollback does not undo transactions.

Keep credentials, audit records, transaction JSON, Safe import payloads and detailed operator receipts private. Documentation builds must not broadcast transactions or restart production services. Update public deployment records only from confirmed receipts and verified onchain state.
