# External Vault Onboarding Runbook (`setup-external-vaults.sh`)

## Why This Exists

Core deployment (`DeployQuantillon`) intentionally **does not** bootstrap external adapters.
After core deploy:
- `defaultStakingVaultId = 0`
- redemption priority is empty
- no adapter is registered via `setStakingVault`

Use this runbook to onboard staking vault adapters post-deploy.

## Script

```bash
./scripts/deployment/setup-external-vaults.sh
```

The script performs, for each `--vault` entry:
1. Grant `VAULT_FACTORY_ROLE` to `QuantillonVault` on `stQEUROFactory`.
2. Register the vault token via `selfRegisterStQEURO(factory, vaultId, vaultName)`.
3. Configure adapter binding via `setStakingVault(vaultId, adapter, true)`.
4. Grant `VAULT_MANAGER_ROLE` to `QuantillonVault` **on the adapter** (`adapter.grantRole(VAULT_MANAGER_ROLE, vault)`).

> Adapter yield is distributed via `QuantillonVault.harvestAndDistributeVaultYield` — grant
> `YIELD_DISTRIBUTOR_ROLE` to the yield keeper separately (yield distribution no longer routes
> through YieldShift).

> **Required — do not skip.** The vault calls `adapter.depositUnderlying` /
> `withdrawUnderlying` / `harvestYieldToVault`, all gated by `VAULT_MANAGER_ROLE` on the adapter. The
> adapter constructor grants that role only to its admin, so without step 4 every external-vault
> deploy / redeem-sourcing / harvest **reverts**. Step 4's signer must hold the adapter's
> `DEFAULT_ADMIN_ROLE`.

> **Recommended — seed each new stQEURO series.** To avoid the well-known first-depositor
> donation/rounding edge case, the operator should make the first stake into each newly registered
> stQEURO vault (a small deposit) so it is never bootstrapped by an arbitrary first external user.

Then it sets:
- `setDefaultStakingVaultId(...)`
- `setRedemptionPriority(...)`

## Prerequisites

- Foundry installed (`cast` available in `PATH`)
- Core deployment completed (`QuantillonVault`, `stQEUROFactory`, and optionally `YieldShift` addresses)
- Deployer/admin key with required governance/role permissions
- RPC URL for target chain

## Parameters

- `--rpc-url <url>`: chain RPC endpoint
- `--private-key <hex>`: signer private key
- `--quantillon-vault <address>`: deployed `QuantillonVault`
- `--factory <address>`: deployed `stQEUROFactory`
- `--vault <vaultId:vaultName:adapterAddress>`: repeatable vault definition
  - `vaultId`: positive integer
  - `vaultName`: uppercase/digits token label (factory validation applies)
  - `adapterAddress`: external strategy adapter for that vault id
- `--default-vault-id <vaultId>`: optional, defaults to first `--vault` item

## Ready-To-Run Examples

> The `AAVE1` entries below are localhost / testnet examples over mock adapters. On Base mainnet only `vaultId = 2` (`MORPHO1`, `MetaMorphoStakingVaultAdapter`) is registered; there is no Aave vault in production.

### Localhost (`31337`)

```bash
./scripts/deployment/setup-external-vaults.sh \
  --rpc-url http://localhost:8545 \
  --private-key "$PRIVATE_KEY" \
  --quantillon-vault 0xQuantillonVault \
  --factory 0xStQEUROFactory \
  --vault 1:AAVE1:0xMockAaveAdapter \
  --vault 2:MORPHO1:0xMorphoAdapter \
  --default-vault-id 2
```

### Base Sepolia (`84532`)

```bash
./scripts/deployment/setup-external-vaults.sh \
  --rpc-url https://sepolia.base.org \
  --private-key "$PRIVATE_KEY" \
  --quantillon-vault 0xQuantillonVault \
  --factory 0xStQEUROFactory \
  --vault 1:AAVE1:0xAdapterA \
  --vault 2:MORPHO1:0xAdapterB
```

## Verification Commands

Export addresses once:

```bash
export RPC_URL=http://localhost:8545
export QUANTILLON_VAULT=0xQuantillonVault
export FACTORY=0xStQEUROFactory
export YIELD_SHIFT=0xYieldShift
```

Check default vault:

```bash
cast call "$QUANTILLON_VAULT" "defaultStakingVaultId()(uint256)" --rpc-url "$RPC_URL"
```

Check per-vault token + adapter exposure:

```bash
cast call "$FACTORY" "getStQEUROByVaultId(uint256)(address)" 1 --rpc-url "$RPC_URL"
cast call "$QUANTILLON_VAULT" "getVaultExposure(uint256)(address,bool,uint256,uint256)" 1 --rpc-url "$RPC_URL"
```

Check routing events:

```bash
cast logs --rpc-url "$RPC_URL" --address "$QUANTILLON_VAULT" "StakingVaultConfigured(uint256,address,bool)"
cast logs --rpc-url "$RPC_URL" --address "$QUANTILLON_VAULT" "DefaultStakingVaultUpdated(uint256,uint256)"
cast logs --rpc-url "$RPC_URL" --address "$QUANTILLON_VAULT" "RedemptionPriorityUpdated(uint256[])"
```

If `--yield-shift` was used, verify source authorization/binding:

```bash
cast call "$YIELD_SHIFT" "authorizedYieldSources(address)(bool)" 0xAdapterA --rpc-url "$RPC_URL"
cast call "$YIELD_SHIFT" "sourceToVaultId(address)(uint256)" 0xAdapterA --rpc-url "$RPC_URL"
cast call "$YIELD_SHIFT" "enforceSourceVaultBinding()(bool)" --rpc-url "$RPC_URL"
```
## Routing configuration coverage

Starting with QuantillonVault 1.5.1, the effective redemption set must include all tracked external principal. A nonempty priority list is the effective set; an empty list selects only the default vault. Both `setRedemptionPriority` and `setDefaultStakingVaultId` reject a resulting set whose included principal differs from `totalUsdcInExternalVaults`.

When changing the default while the old default remains funded, first configure an explicit priority list containing every funded vault. Then change the default. Retain the old vault in the priority list until its tracked principal is withdrawn or its loss is recognized. Zero reported NAV alone does not allow removal. A complete explicit list can also restore coverage to an existing configuration.

## stQEURO reserve activation

stQEUROToken 1.3.0 uses matched virtual reserves while retaining 18-decimal shares and the existing ERC-4626 interface. New and empty series start at parity. A populated series calibrates its reserve ceiling to its current share price at the first accounting synchronization; that ceiling remains fixed until the series empties. The effective reserve is capped by backing after losses so withdrawals cannot quote more than the real assets. Vesting and the deposit round-trip loss bound remain in force.

For an existing proxy, rehearse the upgrade against a recent pinned block and verify its share precision, balances, supply, metadata, and withdrawal quotes. While the series is unpaused, execute `upgradeToAndCall(newImplementation, abi.encodeCall(syncVesting, ()))` through the authorized controller so reserve activation is atomic with the upgrade. For paused maintenance, use one authorized Safe batch to pause, execute the controller's scheduled upgrade, call `syncVesting` from the Safe holding `GOVERNANCE_ROLE`, and unpause. A paused token rejects a sync from a controller without that role. Verify all roles during rehearsal and recheck the live state before execution.

Calibration preserves the existing exchange rate; it does not reset a series with an already extreme asset-to-share ratio. If ordinary deposit previews are zero or fail the round-trip loss bound before activation, stop that series' rollout and resolve its migration without changing existing holders' claims. Update the factory's token implementation separately for future series; that setting does not upgrade existing token proxies.

## Adapter withdrawal and migration invariants

An adapter must report the actual USDC withdrawn. A one-unit ERC-4626 rounding shortfall is permitted only when the aggregate flow can still satisfy the payout; principal trackers follow the actual return. Changing the ERC-4626 endpoint inside a current adapter requires zero old shares. Replacing an adapter must be rehearsed atomically while the vault is paused.

### Replacing a funded MetaMorpho adapter

`MetaMorphoAdapterMigration` is a one-use, Safe-called helper bound at construction
to one vault id and one old/new adapter pair using the same USDC and MetaMorpho
vault. It reads the current principal at execution, withdraws it, collects the
remaining yield, deposits the principal into the replacement, and leaves yield
as uncredited USDC at the replacement. It changes neither QEURO supply nor the
vault's tracked principal. Redeposition may lose at most one USDC base unit to
ERC-4626 rounding, and replacement backing must still cover all principal.

In one Safe transaction: pause the vault, grant the helper temporary manager
roles on both adapters and governance on the vault, grant the vault manager
access to the replacement, call `migrate()`, revoke all temporary roles, retire
the vault's manager role on the old adapter, and remove the Safe's direct manager
role on the replacement. Verify the configured adapter and preserved accounting
before resuming operations. Failure anywhere reverts the entire transaction.

The retired legacy adapter must have zero principal and zero valued underlying.
Its withdrawal-only interface can leave fractional ERC-4626 shares worth zero
USDC base units; retain its address in the deployment history and record that
residue explicitly. The migration rejects losses, unavailable liquidity and
principal mismatches, and cannot be reused or directed to another destination.

### New-series authority check

After creating a staking series, preserve the governance and emergency roles
assigned to the Safe, grant `DEFAULT_ADMIN_ROLE` to the configured controller,
verify its controller configuration, and renounce the Safe's default-admin role.
Complete creation, role handover and registry activation in one reviewed Safe
batch while deposits are paused. The factory's initial `tokenAdmin` is a bootstrap
identity; changing it to the controller alone would also redirect governance and
emergency roles, so it is not a substitute for this explicit handover. Verify all
role holders before unpausing and include the new series in subsequent upgrade inventories.
