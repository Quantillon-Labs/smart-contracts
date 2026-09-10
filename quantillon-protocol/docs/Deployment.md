# Quantillon Protocol — Deployment Guide

## Overview

This guide covers deploying and configuring the Quantillon Protocol smart contracts using Foundry. Core contracts are deployed in a single `forge script` invocation via `DeployQuantillon.s.sol`, which writes the deployed addresses to `deployments/{chainId}/addresses.json`.

---

## Versioning & Provenance

Every core contract implements `IVersioned.version()` — a `pure` semver getter that, read through the proxy, reflects the **deployed implementation**. Linked libraries expose `version()`; inlined libraries carry a `VERSION` constant.

**Golden rule — every change is traced through a version bump.** Any change to a deployed contract or library (correction, bug fix, update, or upgrade) MUST bump its `version()` per semver:

- **PATCH** (`1.0.0 → 1.0.1`): bug fix or internal-logic change.
- **MINOR** (`1.0.0 → 1.1.0`): new function or externally-observable behavior (ABI-additive).
- **MAJOR**: reserved — storage-layout / ABI breaks are disallowed by the upgrade-safety gates.

This is enforced in CI by `make check-version-bump`: it hashes each versioned unit's **source file** (deterministic, build-independent) and **fails** if the source changed without a `version()` bump — comment and NatSpec edits count as changes. After an intentional bump, re-baseline with `scripts/check-version-bump.sh --update` (commits the new hash+version to `version-baseline/`).

**Deployed-version manifest.** `deployments/{chainId}/versions.json` is the single source of truth for what version is live, written automatically by the `UpgradeBase` scripts after a completed proxy upgrade (each entry: `proxy`, `implementation`, `version`, `gitCommit`, `deployedAt`). Candidate-only actions (`deploy-only`, `propose`, and `approve`) leave it unchanged. Pass `GIT_COMMIT=$(git rev-parse --short HEAD)` to the upgrade scripts so the commit is recorded.

**Answering "what is deployed / what needs upgrading?"**

```bash
# On-chain: read the live implementation's version directly
cast call <proxy> "version()(string)" --rpc-url $RPC_URL

# Report deployed-vs-source for every contract (flags which need an upgrade)
make check-deployed-versions

# One-time seed of versions.json for contracts deployed before versioning existed
RPC_URL=$RPC_URL GIT_COMMIT=<sha> scripts/deployment/backfill-versions.sh 8453
```

**Basescan verifiability — check BEFORE every implementation deploy.** Under `via_ir`,
a contract's optimized bytecode can depend on the *full* compilation unit, while
`forge verify-contract` submits a standard-json pruned to the contract's dependency
closure — if the two compiles diverge, the deployed implementation can never be
verified (QuantillonVault v1.1.1, 2026-07-04; ~67 bytes of drift). Whether a given
contract/version diverges is per-compile luck, so gate every impl:

```bash
# ok  -> deploy normally (UpgradeBase deploy-only); standard verification will match
# FAIL-> deploy the pruned-unit bytecode instead, so verification matches by construction
make check-verifiable-bytecode CONTRACT=QuantillonVault

# On FAIL: same sources & settings, equally valid compile — but reproducible by the verifier.
# Deploys with PRIVATE_KEY/RPC_URL from .env, writes records to deployments/verifiable/,
# and prints the exact verification command. Continue the normal Safe/timelock flow with
# the printed implementation address.
scripts/deployment/build-verifiable-impl.sh QuantillonVault \
  --lib src/libraries/StakingYieldLibrary.sol:StakingYieldLibrary=<addr> \
  --lib src/libraries/TreasuryRecoveryLibrary.sol:TreasuryRecoveryLibrary=<addr> \
  --deploy
```

### HedgerPool remaining-cost accounting activation

HedgerPool v1.1.0 values `filledVolume` as the original USDC cost of the remaining
QEURO backing. Deploy its implementation with HedgerPoolLogicLibrary v1.0.1 and
HedgerPoolRedeemMathLibrary v1.0.1. Fresh proxies activate this model in `initialize`.
Build and verify with `FOUNDRY_PROFILE=production` (`optimizer_runs = 0`), using an
isolated output/cache directory when test builds are running concurrently.

An existing proxy requires settlement before upgrading: position 1 must be inactive,
`totalMargin`, `totalExposure`, and `totalFilledExposure` must be zero, and the vault's
`totalMinted()` must be at most `QEURO_DUST_THRESHOLD`. Reconcile the position and vault
balances before closure; this upgrade does not convert an active position's balances.

After settlement, pause the pool through `EMERGENCY_ROLE`, execute the implementation
upgrade through the configured timelock, and call `initializeCostBasisAccounting()`
through `GOVERNANCE_ROLE` while the pool remains paused. Verify
`costBasisAccountingInitialized() == true` before unpausing. Installing the implementation
alone leaves mint/redeem accounting, margin changes, normal exits, and effective-collateral
queries blocked until activation. The generic upgrade script does not perform this
governance activation call.

### Coordinated core implementation release

Deploy the seven core implementations together: QuantillonVault v1.2.0,
HedgerPool v1.1.0, QEUROToken v1.0.7, QTIToken v1.0.3, UserPool v1.0.4,
stQEUROFactory v1.0.2, and each registered stQEUROToken proxy at v1.0.4.
Link the vault to ExecutionPricingLibrary v1.0.1 and the pool to the two
HedgerPool libraries listed above. Preserve each implementation's existing
TimeProvider constructor argument. Check the factory registry for all token
proxies; the zero `stQEUROToken` entry in `addresses.json` is not an upgrade target.

The base timing helper uses `block.timestamp`; contracts with a TimeProvider
read that provider directly. Before upgrading, check the provider's offset and
ensure no emergency-disable proposal spans a change of clock.

For the Base controller, schedule all implementation upgrades with
`TimelockController.scheduleBatch` from the governance Safe. Read `getMinDelay()`
and wait for readiness. The Safe's execution batch must then pause vault and pool,
call `TimelockController.executeBatch`, call `HedgerPool.initializeCostBasisAccounting()`
directly as governance, update the factory's `tokenImplementation` to the new
stQEUROToken implementation, and unpause pool and vault. Use an atomic Safe batch
so failure of activation also rolls back the implementation upgrades. Settlement
must satisfy the activation conditions at execution time.

Installing QuantillonVault v1.2.0 leaves `executionPricing()` at zero on an existing
proxy. This installs pricing support while retaining reference-price settlement.
Pricing can be activated in the same release by deploying a vault-bound module
with explicit writer/reporter addresses, reserve recipient and risk limits.
Configure the publisher and hedge reporter against that module before execution.
Align report freshness, hedge tolerance and execution-impact limits with the
hedge engine. Both depth and capacity reports must remain fresh through the
upgrade window.

For coordinated pricing activation, add the Safe's call to
`QuantillonVault.configureExecutionPricing(module)` after P&L activation and before
unpausing. Check that the module has fresh depth, reconciled hedge exposure,
positive executable capacity and usable previews before enabling settlement.
An implementation upgrade alone does not activate the pricing module.

Rehearse the exact staged bytecode and controller calls on a pinned Base fork
with `scripts/deployment/DryRunCombinedRelease.s.sol`. Its deployment input contains
library link offsets, constructor arguments and the seven proxy addresses; the
script never broadcasts. Independently validate storage, ABI, versions, runtime
size and reproducible verification inputs before deploying implementations.

#### Execution-pricing launch configuration

The Base release candidate uses the following configuration, recorded in
`deployments/8453/execution-pricing-candidate.json`. These are deployment settings;
the active module and its getters remain the source of truth for live values.

| Setting | Selected value | Purpose |
| --- | --- | --- |
| Maximum depth/account age | 60 seconds | Reject stale book or margin observations; the execution publisher refreshes on the 10-second polling loop when due. |
| Maximum execution impact | 25 bps (0.25%) | Total per-level price limit relative to the reference oracle, consistent with the hedge engine's existing limit. |
| Execution buffer | 10 bps (0.10%) | Included in the execution rate and inside the 25 bps ceiling; covers venue fees plus a limited timing allowance. |
| Maximum unacknowledged exposure | EUR 1,000 | Aggregate across mint and redeem directions; additionally limited by current depth and reporter-certified margin capacity. |
| Published depth | Up to 10 observed levels per side | Keeps cold publication within the writer's existing gas ceiling; omitted depth never contributes to capacity. |
| Base confirmations for reporting | 4 blocks | Reporter uses confirmed supply and admission counters and checks the block hash again. |
| Hedge acknowledgment tolerance | EUR 1 | Matches the engine's existing target tolerance; bounds residual exposure, rather than asserting an exactly matched hedge. |
| Writer and reporter | `0xC57bF47310897B49aa72503AE568Fa46f2a5E008` | Existing publisher; both roles use its single durable transaction journal. |
| Spread reserve recipient | `0x8DAD1B6c1A40e2649d50952977b5af1992f098d1` | Existing hedge-funding account; governance withdrawals pay this fixed recipient. |

The reporter permits at most one wei of difference between the engine's indexed
target and confirmed QEURO supply to accommodate the residue after full redemption.
This bookkeeping tolerance is separate from the EUR 1 actual hedge-exposure check.

At selection, the unified Hyperliquid account held approximately 108.43 USDC.
EUR 1,000 at the observed 1.16355 reference price requires approximately 23.27 USDC
of margin at the engine's existing 50x leverage, before its 1 USDC cushion. This
is a launch ceiling, not an assertion that this capacity is always available.
The reporter reduces admission as available funding decreases; no additional
leverage is enabled by this configuration.

The observed `xyz:EUR` market had growth mode enabled and deployer fee scale 1.
With the account's 0.045% base taker rate and no referral discount, the documented
fee formula gives approximately 0.009% (0.9 bps), before any aligned-collateral
discount. Fees and market conditions can change; the buffer does not guarantee a
hedge fill. See [Hyperliquid's fee formula](https://hyperliquid.gitbook.io/hyperliquid-docs/trading/fees#fee-formula-for-developers).

ExecutionPricing v1.1.0 lets governance update age, impact, buffer and the exposure
ceiling through `updateRiskLimits(age, impact, buffer, outstandingLimit)`. The vault
must be paused and outstanding admission must be zero. The update invalidates both
depth and capacity; new reports must carry source timestamps strictly after the
update. Keep settlement paused until those reports restore usable quotes.

The admin Parameters tab provides editable inputs, validates contract bounds and
generates the governance Safe transaction. It displays release settings separately
from live on-chain values and quote status. The reserve recipient remains fixed;
changing that address requires replacing the module. Publisher confirmations and
hedge tolerance are service configuration, separate from the four contract limits.

### LighterEurUsdOracle (historical — venue not adopted)

`LighterEurUsdOracle` was deployed on 2026-07-17 as the candidate market oracle for a second hedge venue and upgraded to 1.0.1 in the 2026-08-26 bundle; on 2026-09-01 the Lighter venue was ruled out for good, so the proxy stays deployed and **inert** (no router slot, no consumer) as a historical record and no activation is planned. Like the other oracle proxies it is plain UUPS controlled by `UPGRADER_ROLE` (Safe direct, no timelock), and its upgrade script (`scripts/deployment/UpgradeLighterOracle.s.sol`, `UPGRADE_ACTION=deploy-only` then `record`) follows the pattern described above — kept only so the inert deployment can be maintained if ever required.

---

## Prerequisites

### Required Tools

- **Foundry** (forge, cast, anvil): `curl -L https://foundry.paradigm.xyz | bash && foundryup`
- **jq**: for post-deployment address parsing (`sudo apt install jq` or `brew install jq`)
- **Node.js 18+** (for NatSpec validation and size analysis scripts)

### Environment File

Copy the appropriate template and fill in your values:

```bash
# Localhost development
cp .env.localhost .env

# Base Sepolia testnet
cp .env.base-sepolia .env

# Base mainnet production
cp .env.base .env
```

**Required variables:**

| Variable | Description |
|----------|-------------|
| `PRIVATE_KEY` | Deployer private key |
| `ETHERSCAN_API_KEY` | BaseScan API key (needed for `--verify`) |

**Optional variables (default to deployer address if not set):**

| Variable | Description |
|----------|-------------|
| `TREASURY` | FeeCollector treasury wallet |
| `DEV_FUND` | FeeCollector dev fund wallet |
| `COMMUNITY_FUND` | FeeCollector community fund wallet |
| `SINGLE_HEDGER` | Initial single hedger address on HedgerPool |
| `USDC` | USDC address override (auto-selected by network if not set) |
| `STORK_CONTRACT_ADDRESS` | Stork oracle contract override |

---

## Deployment Architecture

`DeployQuantillon.s.sol` deploys all contracts in this dependency order within a single broadcast session:

```
TimeProvider
    └── ChainlinkOracle (or MockChainlinkOracle) + ERC1967Proxy
    └── StorkOracle (or MockStorkOracle) + ERC1967Proxy
    └── OracleRouter + ERC1967Proxy
            │
            ├── FeeCollector + ERC1967Proxy
            │       └── QEUROToken + ERC1967Proxy
            │               └── QuantillonVault + ERC1967Proxy
            │
            ├── QTIToken + ERC1967Proxy
            │
            ├── UserPool + ERC1967Proxy
            ├── HedgerPool + ERC1967Proxy
            ├── YieldShift + ERC1967Proxy
            ├── stQEUROToken (implementation)
            └── stQEUROFactory + ERC1967Proxy
                    └── _wireContracts() — configures dependencies/roles and enforces required post-deploy wiring (no vault registration)
```

After deployment, addresses are written to `deployments/{chainId}/addresses.json`.

Required post-deploy wiring now enforced in-script (deployment reverts if any check fails):
- `quantillonVault.initializePriceCache()`
- `yieldShift.configureDependencies(...)`
- `yieldShift.bootstrapDefaults()`
- `hedgerPool.configureDependencies(...)` (includes `feeCollector`)
- `feeCollector.authorizeFeeSource(quantillonVault)`
- `feeCollector.authorizeFeeSource(hedgerPool)`

Vault registration is intentionally deferred: `DeployQuantillon.s.sol` does not register any stQEURO vault token or adapter on initialization.
Use `scripts/deployment/setup-external-vaults.sh` for post-core onboarding.

### Network Configuration

| Network | Chain ID | USDC | Stork (deploy-script input; parked on mainnet) | Chainlink EUR/USD |
|---------|----------|------|-------|-------------------|
| Localhost (Anvil) | 31337 | Base mainnet USDC or MockUSDC | Mock | Mock (or real on fork) |
| Base Sepolia | 84532 | `0x036CbD53842c5426634e7929541eC2318f3dCF7e` | Mock | `0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165` |
| Base Mainnet | 8453 | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` | `0x647DFd812BC1e116c6992CB2bC353b2112176fD6` | `0xc91D87E81faB8f93699ECf7Ee9B44D11e1D53F0F` |

> **Production oracle stack.** `DeployQuantillon.s.sol` deploys `ChainlinkOracle`, `StorkOracle` and `OracleRouter`. The live market oracle on Base — `SlippageStorage` + `HyperliquidEurUsdOracle` (router slot 1, active since 2026-06-25) — is deployed by its dedicated scripts under `scripts/deployment/` (`DeployHyperliquidOracle.s.sol` for the oracle) and wired into the router by the Safe (`updateOracleAddresses`, then `switchOracle(1)`). `StorkOracle` is parked on mainnet. See [Oracle Architecture](./Oracle-Architecture.md).

---

## Localhost Deployment

### Start Anvil

```bash
# Plain local node (all mocks required)
anvil --host 0.0.0.0 --port 8545 --accounts 10 --balance 10000

# Or fork Base mainnet (allows using real oracle feeds without mocks)
anvil --host 0.0.0.0 --port 8545 --fork-url https://mainnet.base.org --chain-id 31337
```

### Deploy

```bash
# All mocks (MockUSDC + MockChainlinkOracle + MockStorkOracle)
./scripts/deployment/deploy.sh localhost --with-mocks

# Mock oracle only (real USDC from fork)
./scripts/deployment/deploy.sh localhost --with-mock-oracle

# No mocks (assumes Base mainnet fork with real contracts)
./scripts/deployment/deploy.sh localhost
```

### Output

```
deployments/31337/addresses.json
```

---

## Testnet Deployment (Base Sepolia)

```bash
# With mock contracts (recommended for testing)
./scripts/deployment/deploy.sh base-sepolia --with-mocks --verify

# With real Chainlink feeds + real USDC
./scripts/deployment/deploy.sh base-sepolia --verify
```

The script automatically:
- Sets gas price to 2 gwei
- Uses `--slow` to send transactions one-at-a-time (avoids nonce desync with public RPCs)
- Polls for stable nonce before broadcasting

### Output

```
deployments/84532/addresses.json
```

---

## Mainnet Deployment (Base)

### Pre-Deployment Checklist

Before deploying to Base mainnet:

- [ ] Set `TREASURY`, `DEV_FUND`, `COMMUNITY_FUND` to governance-controlled multisig addresses in `.env.base`
- [ ] Set `SINGLE_HEDGER` to the authorized hedger address
- [ ] Verify `PRIVATE_KEY` belongs to a dedicated deployment wallet with sufficient ETH
- [ ] Set `ETHERSCAN_API_KEY` for contract verification
- [ ] Run a dry-run first: `./scripts/deployment/deploy.sh base --dry-run`
- [ ] Test on Base Sepolia with the same configuration

### Deploy

```bash
# Production deployment with verification and the size-minimising production profile
./scripts/deployment/deploy.sh base --verify --production
```

The `--production` flag sets `FOUNDRY_PROFILE=production`, which compiles with `optimizer_runs = 0` (defined in `foundry.toml`): runtime bytecode is minimised to stay under the EIP-170 limit (`via_ir` is on in every profile; the test/coverage profiles use 200 runs).

### Output

```
deployments/8453/addresses.json
```

---

## Dry Run

Test the deployment without broadcasting any transactions:

```bash
./scripts/deployment/deploy.sh localhost --dry-run
./scripts/deployment/deploy.sh base-sepolia --dry-run
./scripts/deployment/deploy.sh base --dry-run
```

---

## Post-Deployment

`deploy.sh` automatically runs these after a successful deployment:

### 1. Copy ABIs to Frontend

```bash
./scripts/deployment/copy-abis.sh localhost
```

Copies all contract JSON artifacts from `out/` to the path specified in `FRONTEND_ABI_DIR`.

### 2. Update Frontend Addresses

```bash
./scripts/deployment/update-frontend-addresses.sh localhost
```

Reads `deployments/{chainId}/addresses.json` and writes the frontend `addresses.json` to `FRONTEND_ADDRESSES_FILE`.

### 3. Onboard External Vaults (Required for Multi-Vault Staking)

Core deploy does not set adapter routing/defaults. Onboard vaults with:

```bash
./scripts/deployment/setup-external-vaults.sh \
  --rpc-url http://localhost:8545 \
  --private-key "$PRIVATE_KEY" \
  --quantillon-vault 0xQuantillonVault \
  --factory 0xStQEUROFactory \
  --yield-shift 0xYieldShift \
  --vault 1:AAVE1:0xMockAaveAdapter \
  --vault 2:MORPHO1:0xMorphoAdapter \
  --default-vault-id 2 \
  --enforce-source-bindings
```

See the dedicated runbook: `docs/External-Vault-Onboarding-Runbook.md`.

### 4. Seed the Version Manifest (one-time, per chain)

`deployments/{chainId}/versions.json` is the source of truth for *what version is deployed*. After upgrades it is maintained automatically by the `UpgradeBase` scripts, but it must be **seeded once** for contracts that were deployed before `version()` existed. This step reads each proxy's current implementation from its EIP-1967 slot on-chain.

> **Read-only — no private key required.** It only issues `eth_getStorageAt` reads via `cast`; it sends no transactions and spends no gas. It needs **only a Base RPC URL**.

```bash
# chainId defaults to 8453 (Base mainnet). GIT_COMMIT tags the pre-versioning baseline.
RPC_URL="$BASE_RPC_URL" GIT_COMMIT=f1c55ad \
  ./scripts/deployment/backfill-versions.sh 8453
```

> `versions.json` is **committed** (a `.gitignore` exception re-includes `deployments/*/versions.json`
> while the rest of `deployments/` stays ignored), so deployed-version provenance syncs across
> workstations via `git pull`. Seed it once with the backfill above; thereafter the `UpgradeBase`
> scripts keep it current on each upgrade — **commit the updated manifest** so other machines pick it up.

After seeding, verify and inspect drift vs source:

```bash
make check-deployed-versions          # lists contracts whose deployed version != source version()
cast call <proxy> "version()(string)" --rpc-url "$BASE_RPC_URL"   # once a version()-bearing impl is live
```

Before the July 2026 implementation upgrades the manifest showed every contract as `0.0.0-unversioned` (deployed) vs `1.0.0` (source) — i.e. "needs upgrade" — because no live implementation carried `version()` yet. Today every proxy except `StorkOracle` (parked) and `TimeProvider` (not a proxy) reports a live `version()`; each `UpgradeBase` run overwrites that contract's entry with the real deployed version + commit.

---

## Accessing Deployed Addresses

`deployments/{chainId}/addresses.json` is a flat map keyed by **PascalCase contract name** (plus the external dependencies). On Base mainnet the key set is:

```
QuantillonVault, QEUROToken, QTIToken, UserPool, HedgerPool, FeeCollector, YieldShift,
stQEUROFactory, stQEUROToken (zero address: resolved per vault via stQEUROFactory),
OracleRouter, ChainlinkOracle, HyperliquidEurUsdOracle, LighterEurUsdOracle (inert), StorkOracle,
SlippageStorage, TimeProvider, Timelock, Multisig, USDC, EURUSD, USDCUSD
```

The file is a local deployment artifact (gitignored — only `versions.json` is tracked); the [API Reference](./API-Reference.md#contract-addresses) mirrors the mainnet values.

### Programmatically (shell)

```bash
jq -r '.QEUROToken' deployments/8453/addresses.json
# "0x69aD4e6c49d6275D0e11b5515D98a89f029869AA"
```

### Frontend format

`update-frontend-addresses.sh` writes the frontend `addresses.json` (`FRONTEND_ADDRESSES_FILE`) with the same PascalCase keys, nested per chain id:

```json
{
  "8453": {
    "name": "Base",
    "isTestnet": false,
    "contracts": {
      "QuantillonVault": "0x...",
      "QEUROToken": "0x...",
      "QTIToken": "0x...",
      "UserPool": "0x...",
      "HedgerPool": "0x...",
      "FeeCollector": "0x...",
      "YieldShift": "0x...",
      "stQEUROFactory": "0x...",
      "stQEUROToken": "0x0000000000000000000000000000000000000000",
      "OracleRouter": "0x...",
      "ChainlinkOracle": "0x...",
      "HyperliquidEurUsdOracle": "0x...",
      "StorkOracle": "0x...",
      "TimeProvider": "0x...",
      "USDC": "0x..."
    }
  }
}
```

---

## Contract Verification

Contracts are verified automatically when `--verify` is passed. For manual re-verification:

```bash
# Example: re-verify QEUROToken proxy on Base Sepolia
forge verify-contract \
  <PROXY_ADDRESS> \
  lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy \
  --chain-id 84532 \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

---

## Troubleshooting

### Anvil not running
```bash
anvil --host 0.0.0.0 --port 8545 --accounts 10 --balance 10000
```

### Missing environment file
```bash
cp .env.localhost .env
# or
cp .env.base-sepolia .env
```

### Nonce desync on testnet
The deploy script polls for a stable nonce before broadcasting. If it keeps failing, try a different RPC URL (the default `https://sepolia.base.org` can occasionally lag). You can override by editing the `NETWORKS` map in `deploy.sh`.

### Verification failed
Ensure `ETHERSCAN_API_KEY` is set and valid. If automatic verification fails, contracts can be re-verified using `forge verify-contract` after deployment.

### USDC address is zero on localhost
Set `USDC=<mock_address>` in `.env.localhost` after deploying MockUSDC, or let deploy.sh handle it automatically with `--with-mock-usdc`.

---

## Security Considerations

### Private Key Management
- Use a **dedicated deployment wallet** — never your main wallet
- For production, use a hardware wallet or a cloud HSM
- Rotate deployment keys after production deployment

### Production Role Configuration
- `TREASURY`, `DEV_FUND`, and `COMMUNITY_FUND` should be multisig wallets (e.g., Safe)
- `SINGLE_HEDGER` should be an audited, authorized hedger address
- After deployment, transfer admin roles to the governance multisig

### Never Commit Secrets
- `.env`, `.env.base`, `.env.base-sepolia` and `.env.localhost` are **tracked but git-crypt encrypted** (`.gitattributes`): never commit them in plaintext and never disable the git-crypt filter
- Use a secret manager (AWS Secrets Manager, HashiCorp Vault) for production CI/CD

---

*Maintained by Quantillon Labs.*
