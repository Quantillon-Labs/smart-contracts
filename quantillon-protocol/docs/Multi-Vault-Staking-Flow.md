# Multi-Vault Staking Runtime Flow

This note describes the current `vaultId`-based runtime behavior for staking, minting, redemption, and hedger liquidity flows.

## Core Runtime State

`QuantillonVault` tracks:
- `defaultStakingVaultId`
- `stakingVaultAdapterById[vaultId]`
- `stakingVaultActiveById[vaultId]`
- `redemptionPriorityVaultIds[]`
- `stQEUROTokenByVaultId[vaultId]`
- `principalUsdcByVaultId[vaultId]`
- `totalUsdcHeld`
- `totalUsdcInExternalVaults`

## Mint and Stake Flows

### 1) Mint (default routing)
- `mintQEURO(usdcAmount, minQeuroOut)` calls internal mint flow with `defaultStakingVaultId`.
- If default vault id is non-zero and valid, net USDC is auto-deployed to that vault adapter.
- If default vault id is `0`, net USDC remains in `totalUsdcHeld`.

### 2) Mint (explicit vault)
- `mintQEUROToVault(usdcAmount, minQeuroOut, vaultId)` uses provided `vaultId`.

### 3) Mint + Stake (one-step)
- `mintAndStakeQEURO(usdcAmount, minQeuroOut, vaultId, minStQEUROOut)`:
  - Mints QEURO via the same vault-aware mint flow.
  - Resolves `stQEUROTokenByVaultId[vaultId]`.
  - Stakes and transfers stQ token to caller.

### Auto-deploy implementation
- `_mintQEUROCommit` moves net amount from held balance to per-vault principal accounting when `targetVaultId != 0`.
- `_autoDeployToVault(vaultId, usdcAmount)` deposits through configured adapter and emits `UsdcDeployedToExternalVault`.

## Yield Distribution to Stakers

QuantillonVault 1.4.0 allocates realized strategy yield by current economic capital: hedger
collateral yield to the configured hedger recipient, staked QEURO backing yield to stQEURO,
and unstaked QEURO backing yield to treasury. A governance-configurable haircut of 0–100%
of gross staking yield (default zero) goes to the hedger before existing staking fees.

This distribution release accepts one funded strategy and one outstanding staking series;
other registered empty strategies are allowed. It rejects unsupported multiple-strategy
allocation instead of misclassifying another series' backing as unstaked.

The keeper uses `yieldDistributionConfig` and the on-chain preview on 1.4.0, retaining
legacy configuration reads on older deployments. See [Staking Yield Distribution](./Staking-Yield-Distribution.md)
for formulas, compatibility, vesting and the upgrade procedure.

## Redemption Flow

`redeemQEURO(qeuroAmount, minUsdcOut)` (normal mode):
- Computes required USDC and checks total collateral availability.
- Uses `_planExternalVaultWithdrawal(requiredUsdc)` to compute deficit vs `totalUsdcHeld`.
- Commit phase withdraws deficit through `_withdrawUsdcFromExternalVaults` when needed.

Withdrawal source order:
- First: `redemptionPriorityVaultIds` (if configured).
- Fallback: single-item array with `defaultStakingVaultId`.
- If neither exists and held balance is insufficient, redemption reverts (`InsufficientBalance`).

Liquidation-mode redemption uses the same external-withdraw planning pattern.

## Hedger Flow

### Hedger opens / adds margin
- `HedgerPool` transfers USDC into `QuantillonVault`.
- `vault.addHedgerDeposit(...)` increases `totalUsdcHeld`.

### Hedger closes / removes margin / liquidation payout
- `HedgerPool` calls `vault.withdrawHedgerDeposit(...)`.
- Vault uses held USDC first; if needed, it withdraws from external vaults using the same priority logic as redemptions.

## Governance and Operator Controls

`QuantillonVault` controls:
- `setStakingVault(vaultId, adapter, active)` (`GOVERNANCE_ROLE`)
- `setDefaultStakingVaultId(vaultId)` (`GOVERNANCE_ROLE`)
- `setRedemptionPriority(vaultIds[])` (`GOVERNANCE_ROLE`)
- `harvestAndDistributeVaultYield(vaultId)` (`YIELD_DISTRIBUTOR_ROLE`) — harvest + 3-way split to stakers/hedger/treasury
- `creditVaultYield(vaultId, usdcAmount)` (`YIELD_DISTRIBUTOR_ROLE`) — credit USDC into stQEURO as QEURO backing
- `setFundingRateAnnualBps(bps)` / `setHedgerYieldRecipient(addr)` (`GOVERNANCE_ROLE`)
- `deployUsdcToVault(vaultId, usdcAmount)` (`VAULT_OPERATOR_ROLE`)

Factory binding:
- `selfRegisterStQEURO(factory, vaultId, vaultName)` links vault id to stQ token (`GOVERNANCE_ROLE`).

## Automatic vs Operational Actions

Automatic:
- Mint routing to default/explicit vault (if configured).
- Redemption and hedger withdrawals sourcing liquidity from external vaults when needed.

Operational:
- Adapter configuration and activation.
- Default vault and redemption-priority policy.
- Deploying idle held USDC (`deployUsdcToVault`).
- Harvesting + distributing adapter yield (`harvestAndDistributeVaultYield`).

## Key Events for Indexer and Admin Read Models

- `VaultRegistered` (factory)
- `StakingVaultConfigured`
- `DefaultStakingVaultUpdated`
- `RedemptionPriorityUpdated`
- `UsdcDeployedToExternalVault`
- `UsdcWithdrawnFromExternalVault`
- `VaultYieldDistributed` (harvest + 3-way split)

## Practical Ops Notes

- If `vaultId` config is missing/inactive, vault-aware actions revert (`InvalidVault` / config errors).
- If held + external principal cannot satisfy required payouts, flows revert (`InsufficientBalance`).
- Correct default and priority setup is critical to predictable redemption behavior.

## Source Files

- `src/core/QuantillonVault.sol`
- `src/core/HedgerPool.sol`
- `src/core/stQEUROFactory.sol`
