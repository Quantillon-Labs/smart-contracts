# Governance Configuration Preservation

## Current execution-buffer policy

The governance-selected execution-rate buffer is currently zero. It remains a
governance parameter: the Safe may change it with `updateRiskLimits` while the
vault is paused and all admitted exposure is settled. The deployment candidate
and admin UI use zero as the current proposed value, not as an immutable default.

This is different from the hedge executor's off-chain fee/capacity reserve. That
reserve is not added to a user's mint or redemption rate and is not governed by
`ExecutionPricing.bufferBps`.

An intentional Safe parameter change is allowed. A module replacement is not an
intentional parameter change unless the reviewed release manifest explicitly
lists it. The combined-release rehearsal therefore requires a replacement module
to preserve the active buffer and every other configurable pricing value.

## Why settings can reappear

An implementation upgrade of a UUPS proxy preserves the proxy's storage. It does
not restore Solidity initializer defaults. A value can nevertheless change in an
upgrade release when the same Safe batch:

- replaces a dependency with a freshly initialized contract;
- calls an initializer or reinitializer;
- calls a setter containing a full configuration snapshot assembled from stale
  defaults; or
- points a registry, router, vault, or factory at a new instance or template.

`ExecutionPricing` is a non-proxy module. Calling
`QuantillonVault.configureExecutionPricing` replaces the entire stateful module,
which is how a fresh deployment's 10 bps constructor value replaced the earlier
governance-set zero.

## Configuration reset inventory

The following groups require preservation checks. "Snapshot" means one call can
silently overwrite several independently governed values.

| Component | Governance surface | Values that must be diffed or preserved | Reset mechanism |
| --- | --- | --- | --- |
| `ExecutionPricing` | constructor, `updateRiskLimits`, `setDegradedHaircutBps`, vault `configureExecutionPricing` | venue oracle, reserve recipient, max age, max impact, buffer, outstanding cap, degraded haircut, vault binding | Fresh non-proxy module replacement; full four-value snapshot setter |
| `OracleRouter` | `updateOracleAddresses` | Chainlink oracle and market-oracle slot | Two-address snapshot or pointer replacement |
| Hyperliquid/Lighter market oracle | initializer, `updatePriceBounds`, `updateSlippageSource`, `updateUsdcSource`, `setMaxPriceStaleness`, reference/baseline controls | min/max price, USDC tolerance/source, staleness, slippage storage/source ID, treasury, and Hyperliquid reference-check thresholds | Fresh proxy deployment and router repointing; multi-value setters |
| Chainlink/Stork oracle | initializer, `updatePriceBounds`, `updatePriceFeeds`, `setSequencerUptimeFeed`, tolerance/treasury setters | price bounds, feed addresses/IDs, sequencer feed and grace period, USDC tolerance, treasury | Fresh proxy or snapshot setters |
| `SlippageStorage` | guard and source setters | enabled-source mask, update interval, deviation threshold, three mid-price guards, two drift guards, treasury | Fresh deployment or multi-value setters |
| `QuantillonVault` | `updateParameters`, `updateCollateralizationThresholds`, dependency setters, staking-vault setters, execution-pricing setter | mint/redemption fees, collateralization floors, reward split, dependency addresses, staking adapter registry/default/priority, yield recipient/haircut, pricing module | Full two-value snapshots, pointer replacement, or a fresh adapter/module |
| Staking-vault adapters | constructor/initializer and underlying-vault setter | underlying Aave/Morpho/MetaMorpho vault, roles, vault binding | Fresh adapter replacement through `setStakingVault` |
| `HedgerPool` | `configureRiskAndFees`, `configureDependencies`, `initializeCostBasisAccounting` | all leverage, margin, fee, rate, hold-block and reward-split fields; five dependencies; cost-basis migration state | Large snapshot structs or the one-time reinitializer |
| `UserPool` | `updateStakingParameters`, fee and dependency setters | APY, minimum stake, cooldown, performance fee, YieldShift address | Three-value snapshot or setter in a release batch |
| `YieldShift` | `configureYieldModel`, `configureDependencies`, source authorization/binding setters | four yield-model fields, five dependencies, authorized sources, source types, vault bindings and enforcement | Snapshot structs, mappings, or fresh proxy deployment |
| `FeeCollector` | `updateFeeRatios`, `updateFundAddresses` | three fee ratios and three destination addresses | Three-value snapshot setters |
| `QEUROToken` | `updateRateLimits` and individual controls | mint/burn rate limits, max supply, price precision, treasury, fee collector, minting kill switch | Two-value snapshot or setter in a release batch |
| `QTIToken` | `updateGovernanceParameters` and treasury setter | proposal threshold, minimum voting period, quorum, treasury | Three-value snapshot |
| `stQEUROFactory` | implementation and dependency setters | token implementation used by future series, YieldShift, oracle, treasury, token admin | Template pointer replacement; existing token proxies are not reset |
| `stQEUROToken` | yield, vesting, and treasury setters | yield fee, vesting period, treasury | Setter in a release batch or fresh series initialization |
| Rebalancer module | `configure` | operator and all automation limits | Full limits snapshot or fresh module deployment |

The inventory covers protocol-owned production configuration surfaces. Dynamic
accounting, user balances, oracle observations, and mock-only setters are not
governance constants and are intentionally excluded.

## Mandatory release invariant

Every production Safe batch must be generated and reviewed as an explicit state
transition:

1. Read configuration from the live contracts at a pinned block immediately
   before preparing calldata. Do not use UI, script, `.env`, or deployment-file
   defaults as current state.
2. Record an allowlist of intended changes as `contract.field: old -> new`. An
   upgrade with no policy change has an empty allowlist.
3. Rehearse the exact Safe batch on a fork at that block. Read every field in the
   inventory before and after, and fail when an unlisted field changes.
4. For a fresh dependency, compare its complete configuration with the active
   instance before executing the pointer switch. Role membership and immutable
   bindings are part of the comparison.
5. Decode every Safe subcall. Treat full-snapshot setters, initializers,
   reinitializers, router updates, factory-template updates, and dependency
   replacements as configuration changes even when they accompany an upgrade.
6. After execution, perform the same readback against the intended manifest and
   alert on later drift. For `ExecutionPricing`, a buffer change without an
   explicit Safe parameter-change entry is a critical release violation.

Release source must also be traceable to the reviewed main branch. A deployment
must not be built from an implementation commit that is absent from main, because
later releases can otherwise unknowingly omit live fixes while restoring stale
configuration assumptions.

`DryRunCombinedRelease.s.sol` already fails replacement of `ExecutionPricing`
when its binding or configurable values differ from the active module. The next
release-hardening step is to make the inventory above machine-readable and apply
the same before/after comparison to every production Safe batch.
