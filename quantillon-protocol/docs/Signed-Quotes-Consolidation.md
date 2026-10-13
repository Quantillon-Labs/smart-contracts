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
