# Staking yield distribution

## Capital-based distribution (QuantillonVault 1.4.0)

This source describes the proposed 1.4.0 implementation. Deploying application changes alone does not activate it. Confirm `version()` on the target proxy; earlier versions retain the annual-funding model until upgraded.

Yield from the single funded external strategy belongs to three economic allocations:

- Hedgers receive yield attributable to their effective collateral.
- Stakers receive yield attributable to the backing of staked QEURO.
- Treasury receives yield attributable to unstaked QEURO backing and existing protocol fees.

Governance may additionally redirect a percentage of **gross earned staking yield** to the configured hedger recipient. `hedgerStakingYieldHaircutBps` defaults to zero; 100 is 1%, 200 is 2%, and the maximum is 10,000 (100%). This is never an annual rate or a deduction from principal. The haircut applies before the existing staking yield fee.

## Calculation

Immediately before harvesting, snapshot:

- `H`: `HedgerPool.getTotalEffectiveHedgerCollateral(price)`, including its existing P&L treatment.
- `U`: QEURO total supply valued in USDC at a fresh validated EUR/USD reference price (`supply * price / 1e30`).
- `S`: QEURO balance of the selected stQEURO token, capped at QEURO supply, or zero if there are no shareholders. This includes credited but unvested QEURO: vesting affects redemption, not economic ownership.
- `Q`: QEURO total supply.
- `Y`: USDC yield actually realized by the adapter, excluding tracked principal.

```
hedgerBase   = floor(Y * H / (H + U))
userPool     = Y - hedgerBase
stakerGross  = Q == 0 ? 0 : floor(userPool * S / Q)
treasuryBase = userPool - stakerGross
haircut      = floor(stakerGross * haircutBps / 10000)
hedgerShare  = hedgerBase + haircut
userShare    = stakerGross - haircut
```

If `H + U == 0`, orphaned yield goes to treasury. All amounts conserve realized yield; floor rounding remains in the residual allocations. A nonzero hedger payment requires a configured nonzero recipient: there is no implicit treasury fallback.

The snapshot uses economic ownership at harvest, including changes to balances or exchange rates before the transaction. It is not time-weighted participation accounting. Idle and deployed capital use the same pooled ownership weights; only strategy yield that is actually harvested is paid out.

### Example

At 1 QEURO = 1 USDC, take 1,000 USDC of effective hedger collateral, 100 QEURO outstanding, 50 staked, and 110 USDC harvested:

| Haircut | Hedger | Staker allocation | Treasury base |
|---|---:|---:|---:|
| 0% | 100 USDC | 5 USDC | 5 USDC |
| 1% | 100.05 USDC | 4.95 USDC | 5 USDC |
| 2% | 100.10 USDC | 4.90 USDC | 5 USDC |
| 100% | 105 USDC | 0 USDC | 5 USDC |

Staker allocations above are before the existing staking fee and execution conversion into QEURO.

## Credit, fees and vesting

`harvestAndDistributeVaultYield(vaultId)` remains role-gated, paused with the vault, and non-reentrant. The staker allocation goes through the existing `_creditVaultYield` path: staking yield fee, execution-pricing admission, collateralization validation and QEURO minting into stQEURO. The public mint fee is not additionally charged. Zero staker allocations skip crediting entirely.

There is no claim call. Credited QEURO vests under the token's existing schedule and increases redeemable value per share. Including unvested QEURO in the ownership snapshot does not make it immediately withdrawable. A failed admission, mint, transfer or oracle validation reverts the entire harvest, including its timestamp and transfers.

The initial release supports one funded strategy. Distribution rejects other deployed strategy principal, other registered strategies with underlying assets, or another registered series with outstanding shares. Registered empty series remain allowed. Factory registration must retain the existing factory so its registry remains complete. Multiple-strategy capital attribution requires a later extension.

## Interfaces and compatibility

- `setHedgerStakingYieldHaircutBps(uint256)`: governance-only, accepts 0–10,000; emits `HedgerStakingYieldHaircutUpdated`.
- `hedgerStakingYieldHaircutBps()`: public getter.
- `yieldDistributionConfig(vaultId)`: `(haircutBps, hedgerRecipient, lastHarvest)`.
- `previewVaultYieldDistribution(vaultId)`: returns `(realizedYield, hedgerBase, haircut, hedgerShare, userShare, treasuryShare)` as a struct. Invoke using `eth_call`/`simulateContract`; the oracle's stateful interface means this is not a Solidity view. Shares calculation and validation with execution; realized yield and balances may change before mining.
- `VaultYieldDistributed`: existing conserved aggregate event; `userShare` is after haircut but before existing staking fees.
- `VaultYieldBreakdown`: supplemental event exposing hedger base and haircut separately.
- `harvestConfig`: deprecated read; the first value is always zero after upgrade. Recipient and timestamp remain available.
- `setFundingRateAnnualBps`: retained selector, explicitly reverts. The old storage slot stays in place and cannot initialize the new haircut.

Keepers continue to use `lastHarvest` for idempotency. There is no funding clock, time prorating, or first-harvest funding exemption. Clients identify contract semantics by version and do not relabel old funding data as a haircut.

## Upgrade procedure

1. Validate storage layout, ABI compatibility, semantic versions, runtime size and verification reproducibility. Deploy only the reviewed library/implementation artifacts through the normal authorized release process.
2. Rehearse on a pinned Base fork through the protocol RPC API. Preserve balances, shares, vesting, execution configuration and harvest timestamps; prove a nonzero old funding rate becomes a zero new haircut.
3. Stop recurring harvests. Settle accrued yield under the old implementation immediately before coordinated activation. If that cannot succeed, stop activation and resolve it rather than silently change the allocation of pending yield.
4. Confirm one funded strategy and the intended nonzero hedger recipient. Follow the governance Safe/Timelock upgrade procedure; haircut starts at zero.
5. Deploy compatible API, keeper and UI changes before resuming. Confirm configuration and the first distribution against the preview and events.
6. Any later haircut change is a separate governance action.

Transaction proposals and review artifacts remain private. Never publish transaction JSON or Safe payloads in docs, public assets or releases.

Tests: `StQEUROYieldDistribution.t.sol` covers allocation, fees, vesting ownership, rollback and boundary cases; `StakingYieldUpgradeFork.t.sol` rehearses the UUPS upgrade in a local Base fork.
