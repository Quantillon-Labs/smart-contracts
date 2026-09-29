# Staking-ratio yield distribution — 1.5.0 release candidate

This is an implementation and activation runbook, not a statement that 1.5.0 is deployed.
QuantillonVault and its linked StakingYieldLibrary change from capital-weighted allocation to
harvest-time staking-ratio allocation. The Morpho adapter and staking-token implementation do not
change. The existing single-funded-strategy guard remains.

## Economics

Let Y be actual harvested USDC, Q total QEURO supply, S the registered staking token's raw QEURO
balance when it has outstanding shares (including credited, unvested yield), and h the haircut in
basis points. Clamp S to Q. Snapshot S and Q before harvesting or minting.

- Gross staker yield G = floor(Y × S / Q); G = 0 if Q is zero or no staking shares exist.
- Hedger payout H = floor(G × h / 10,000).
- Staker allocation = G − H; treasury allocation = Y − G.
- Hedger collateral, unrealized P&L and reference exchange rates do not weight the allocation.
- Zero haircut means no hedger payment, including the first harvest. Principal is never deducted.
- Staking-ratio rounding remains with treasury; haircut rounding remains with stakers.

The strategy's harvested yield is assigned to QEURO backing under this policy. Before activation,
review the actual funded strategy and the provenance of its principal; separately owned hedger
strategy deposits or multiple funded strategies require explicit accounting outside this release.

This remains snapshot-weighted, not time-weighted: staking duration is not accumulated. The staker
allocation is converted into QEURO and vests using the token's existing schedule, currently 24 hours.
Existing conversion costs, oracle checks, execution admission, collateralization and mint eligibility
remain enforced. The token's legacy yieldFee value is ignored for both harvested and directly
credited yield. Direct creditVaultYield credits an already allocated amount and does not apply the
harvest haircut again. Public mint/redeem fees are unchanged.

## Compatibility

Storage layout and public selectors are unchanged. previewVaultYieldDistribution and
VaultYieldBreakdown retain hedgerBase, now always zero. Preview estimates accrued yield; execution
uses the adapter's actual liquid payout, so a liquidity limit may reduce all allocations. A successful
allocation preview is not a guarantee that conversion admission will succeed. Conversion failure
rolls back the entire harvest, USDC transfers and lastHarvest timestamp.

Deploy the version-aware dapp/backend/keeper release before activating the contract. It recognizes
1.4.x as capital and 1.5.x as staking-ratio, keeps older funding semantics, and disables the legacy
staking-yield-fee control only for the new model (unknown versions cannot enable that control).
The displayed provider APY remains an underlying historical rate, explicitly before deductions and
conversion costs, not a guaranteed QEURO return. No new net-APY estimator is included.

## Required release evidence

1. Preserve unrelated local changes; build from the reviewed release commit and installed pinned
   dependencies. Run contract tests, keeper tests/typecheck, dapp typecheck and targeted UI/backend tests.
2. Run ABI, storage-layout, size and version-bump gates. Bump versions for dependency-closure changes;
   do not overwrite the deployed-version manifest with candidate addresses.
3. Rehearse the upgrade and zero/nonzero-haircut harvests on Base block 51,942,142 (deployed 1.4.0):

   ```bash
   REQUIRE_BASE_FORK=true FOUNDRY_PROFILE=production forge test \
     --match-contract StakingYieldUpgradeForkTest \
     --fork-url https://app.quantillon.money/api/rpc/base \
     --fork-block-number 51942142 -vv
   ```

   The tests upgrade only the local fork and check balances, private token vesting storage,
   configuration, timestamps, conservation, recipient balance deltas and subsequent vesting.
4. Reconcile the live proxy version, EIP-1967 implementation and linked libraries against on-chain
   evidence. Record the current haircut, recipient, strategy binding and funding. The tracked version
   manifest may lag live state; do not infer the predecessor from that manifest alone.
5. Run reproducible-bytecode checks for the library and vault. If the ordinary full-unit build
   differs from the verifier's pruned unit, use the existing build-verifiable-impl.sh workflow and
   rehearse the exact candidate runtime before deploying. Never deploy an unverified variant.

## Activation

After release review, deploy the new library and the implementation linked to that exact library
and the verified existing dependencies. Prepare the Safe schedule/execute operations using the
live controller's delay and roles; the documented current delay is 12 hours. Keep transaction JSON
and Safe payloads private, outside repositories and public hosting. The implementation is inert
until the proxy upgrade executes. No initializer or storage migration is required.

Preserve the haircut (currently zero), hedger recipient, staking shares, existing vesting and keeper
journal. Coordinate activation away from a keeper run in flight. The first harvest after activation
uses the new policy for all pending yield, including yield accrued before activation. Historical
payouts are not recomputed. Preserve the daily 03:00 UTC schedule.

After activation, verify version 1.5.0 and the exact implementation/library runtime hashes; update
deployment provenance only from confirmed transactions. Invalidate/refresh version and fee snapshots.
Confirm the preview has hedgerBase = 0 and haircut-only payout. Observe the first actual harvest:
USDC allocations reconcile, the recipient receives no payout at zero haircut, QEURO is credited to
stakers, syncVesting confirms, and the keeper reports a healthy served slot without duplicate harvests.

If these checks fail, stop further keeper attempts and investigate with the writer journal intact.
Corrective upgrades follow governance; completed payouts cannot be rolled back automatically.
