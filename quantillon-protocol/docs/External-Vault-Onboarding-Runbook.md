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
cast logs --rpc-url "$RPC_URL" --address "$QUANTILLON_VAULT" "DefaultStakingVaultUpdated(uint256)"
cast logs --rpc-url "$RPC_URL" --address "$QUANTILLON_VAULT" "RedemptionPriorityUpdated(uint256[])"
```

If `--yield-shift` was used, verify source authorization/binding:

```bash
cast call "$YIELD_SHIFT" "authorizedYieldSources(address)(bool)" 0xAdapterA --rpc-url "$RPC_URL"
cast call "$YIELD_SHIFT" "sourceToVaultId(address)(uint256)" 0xAdapterA --rpc-url "$RPC_URL"
cast call "$YIELD_SHIFT" "enforceSourceVaultBinding()(bool)" --rpc-url "$RPC_URL"
```

