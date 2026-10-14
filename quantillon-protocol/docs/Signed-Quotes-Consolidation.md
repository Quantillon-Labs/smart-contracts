# Signed quotes: consolidated candidate for production

> **Historical checkpoint.** This consolidation record predates the 14 October dev/preprod activation and dev delegation follow-up. For current versions, deployed branches and production gates, use [Signed Quote Migration](Signed-Quote-Migration.md).

## Production branch promotion — 13 October 2026

`feat/signed-quotes-migration` now contains the source and test changes validated
on preprod through `08387433`. The promotion preserves the original candidate
history. It does not upgrade Base, change deployment manifests, send governance
transactions or publish the production documentation site. Paired Dapp evidence
is in `docs/migrations/signed-quotes-production-sync-2026-10-13.md` in the frontend repository.

Candidate versions are Vault **1.6.0**, UserPool **1.3.0**, HedgerPool **1.6.0** and
ReferenceSettlementLibrary **1.1.0**. The typed margin withdrawal and normal,
paused, capacity-constrained, emergency and liquidation settlement tests are
included. The six newly declared interface functions now have complete NatSpec.
This documentation completion changes no runtime bytecode: canonical artifacts
were compared before and after, and only matching-version dependency hashes were
refreshed. No interface selector or storage field was changed by that completion.

Fresh validation: 186 tests across seven signed/reference suites; EIP-170,
append-only storage, additive ABI, version tracing, 100% NatSpec and generated
documentation checks. These are candidate checks, not production activation evidence.

Production preparation subsequently added live fill evidence/allocation, typed Roles
permission support and private service/Dapp staging in the paired Dapp branch.
An isolated Base fork at block **52,554,188** repeated deployment, the actual
TimelockController's **43,200-second** delay, refusal before eligibility and
activation of these three proxy versions. The Safe performs operational pause
and configuration; the timelock performs the upgrades. Existing UserPool pending
liability initialization must be preserved rather than run a second time.
No extra Solidity runtime change was needed for this backend preparation.

Before production activation, validate preprod, complete independent review and
initial parameter/signer selection, deploy inactive production modules, stage
artifacts against their actual addresses and submit the reviewed permissions and
upgrade proposals. User decision on 13 October: no mandatory shadow duration or
completed-hedge quota. Cut over services, Dapp and contracts with the explicit
activation after the 12-hour governance delay, keeping admission closed until
bindings and readiness are verified. Timelock expiry alone does not execute the
upgrade. See `docs/migrations/signed-quotes-production-preparation.md` in the Dapp
repository for the executable rehearsal and staged cutover sequence. Fork keys,
mock feeds and fixture transaction artifacts must never be used on Base.

The historical preprod evidence below retains its original scope.

---

# Signed quotes: preprod consolidation (2026-10-13)

Scope: the dedicated `feat/signed-quotes-preprod` branch. This change does not authorize a production or dev deployment.

## Contract changes

`HedgerPool` 1.6.0 adds `removeMarginWithReference(positionId, amount, authorization)`.
It returns the underlying operation's ABI-encoded return data (empty for a successful withdrawal).
The linked `ReferenceSettlementLibrary` 1.1.0 submits the governed signed reference and delegates the existing withdrawal in the same transaction. A failed withdrawal rolls back the reference update. The original caller, ownership, pause, reentrancy, margin and collateral checks remain in force. No storage field or namespace is added.

The typed selector exposes position and amount to Zodiac Roles conditions without granting the generic `executeWithReference(bytes,bytes)` wrapper. Existing generic reference operations remain supported for hedgers signing directly.

`IHedgerPool` and `IQuantillonVault` now declare their existing signed settlement entrypoints, in addition to the new typed withdrawal. The interfaces do not remove legacy selectors or economic guards. Removing the Dapp's legacy deviation input does not remove onchain reference bounds or execution impact limits.

## Permissions and rollout

Preprod uses a local fork (chain 31338), with external capital execution disabled. Its governance impersonation is strictly local. Upgrade only HedgerPool; preserve pricing modules, signers, capacity counters, positions, and pause state. Record the implementation, library addresses, source commit and runtime hash privately. Keep the previous implementation for rollback; storage compatibility is unchanged.

Before enabling a Safe operator on any environment, governance must explicitly scope the typed selector to the correct pool and position, zero ETH value and CALL operation, retaining the reviewed amount policy. The authorization bytes contain only a reference report verified by the governed source. Do not grant arbitrary delegatecall or generic envelope permissions. Full Roles simulation must succeed before signing. The current production policy-history allowlist has not been migrated by this preprod change; it intentionally rejects unreviewed permission transitions.

Tests exercise the actual HedgerPool proxy against the reference source, including caller preservation, rejected callers, economic failure rollback, expired reports, and the preexisting margin-accounting suite. Safe client unit tests are not evidence that a live Safe permission upgrade has executed.

## Verification

- HedgerPool runtime: 24,534 bytes (EIP-170 limit: 24,576). There is little remaining headroom; future additions should use linked libraries.
- Storage layout compared with the previous preprod artifact: identical after ignoring compiler AST identifiers.
- Scoped upgrade rehearsed on an isolated fork of preprod (port 18550), retaining margin, exposure, oracle, pricing module, owner, time provider and pause state.
- A real typed withdrawal of one USDC base unit succeeded on that isolated fork: total margin decreased by one and the owner's USDC balance increased by one. No test withdrawal was sent to the served preprod instance.
- Three source-closure baselines (`QuantillonRebalancerModule`, `YieldShift`, `YieldShiftOptimizationLibrary`) were refreshed only after verifying their deployed bytecode was identical to the previous preprod artifacts. Interface additions changed dependency hashes without changing their runtime. The reference settlement library is now explicitly covered by the version gate.

## Stateful preprod simulation (13 October, subsequent delivery)

The dedicated preprod branch now runs the normal hedging engine against a durable
local venue. Orders, fills, fees, margin nonces and allocation to signed or emergency
settlements survive worker restarts. The fork uses a sealed historical-origin cache;
initialization may read the approved Base proxy, but ordinary sealed execution cannot.
All transactions are on chain 31338. External orders and bridges remain disabled.

The served local Safe has a dedicated Roles module. Browser tests exercised a USDC
collateral addition and the typed reference withdrawal, with exact Safe balance
checks. This supersedes the earlier served-instance testing limitation above; it
is not a production permission migration.

`SignedProtocolSettlement.t.sol` additionally covers pause/resume without nonce
consumption, concurrent quotes against admitted capacity, emergency budget rollback,
and pro-rata liquidation against the real router. Browser tests exercise emergency
redemption with the quote signer stopped, liquidation redemption, stake/unstake and
positive fixture-yield conversion followed by a simulated hedge and reconciliation.
No contract bytecode was changed for these additional simulation tests, so the
previously deployed versions remain Vault 1.6.0, UserPool 1.3.0 and HedgerPool 1.6.0.

Operational scenarios and reset instructions are in the Dapp repository at
`docs/migrations/preprod-isolated-simulation.md`. Synthetic funding/APY data does not
model Hyperliquid funding cashflows or exchange liquidations. Real-fill integration, initial parameter review and governed production
activation remain separate release gates; no timed calibration window is required.

## Shared candidate alignment — 14 October 2026

The preprod and production signed-quotes branches now share the same contract
source, documented interfaces, deployment helper, version assertions and test CI.
The synchronization changes no core implementation, storage layout or contract
version. The eight signed/reference/version suites passed all 198 tests locally.
The deployment entrypoint remains encrypted; the helper is testable in a locked
checkout. This source synchronization does not upgrade either running instance.
