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

This is enforced in CI by `make check-version-bump`: it hashes each versioned unit's **import closure** (deterministic, build-independent) and **fails** if a source dependency changed without a `version()` bump — comment and NatSpec edits count as changes. After an intentional bump, re-baseline with `scripts/check-version-bump.sh --update` (commits the new hash+version to `version-baseline/`).

**Deployed-version manifest.** `deployments/{chainId}/versions.json` is the single source of truth for what version is live, written automatically by the `UpgradeBase` scripts after a completed proxy upgrade (each entry: `proxy`, `implementation`, `version`, `gitCommit`, `deployedAt`). Candidate-only actions (`deploy-only`, `propose`, and `approve`) leave it unchanged. Pass `GIT_COMMIT=$(git rev-parse HEAD)` to the upgrade scripts so the commit is recorded.

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
# Requires CAST_ACCOUNT, RPC_URL, RELEASE_MANIFEST and private VERIFIABLE_OUTDIR.
# Uses a Foundry keystore; raw keys never enter cast arguments. Continue the
# Safe/timelock flow with the verified implementation address.
scripts/deployment/build-verifiable-impl.sh QuantillonVault \
  --lib src/libraries/StakingYieldLibrary.sol:StakingYieldLibrary=<addr> \
  --lib src/libraries/TreasuryRecoveryLibrary.sol:TreasuryRecoveryLibrary=<addr> \
  --deploy
```

### Base deployment reconciliation — September 20, 2026

HedgerPool **1.3.0** is active at proxy `0xff5D7cE5c7671B2EA805Ee752B4f8eC9Ecf2975A`,
using implementation `0x8d83F7463CbFfd188Df7bC4302900151e273435a` and
HedgerPoolAccountingLibrary **1.1.0** at `0x4FDA47d379f00f849808500DD52b5106825ce5f1`.
Both implementations were deployed at Base block **51,522,127**. The pool upgrade and
one-time legacy correction executed together at block **51,548,748**, September 20 at
06:47:23 UTC, in [the completed Safe transaction](https://basescan.org/tx/0x5fd056f9c7f48dd36e6b158a749d6a483e0137882279e3540f1e4d778c9c41c9).

The correction assigned **0.388448 USDC** of existing unallocated backing to the current
Safe hedger position's margin without transferring tokens or minting QEURO. The correction
marker is already set; this is a record of completed execution, not a pending operation.
The reconciled source and regression tests are recorded in commit
`37d2381fbe0ed73bc28160fa46d335f6a73de265` (committed after deployment).

The same reconciliation corrected the stale QuantillonVault manifest entry to **1.2.1**,
implementation `0xdA2eF3B9CCD2b819806b29A5Ac65abCf689E2227`, activated at block **51,202,101**
on September 12 at 06:12:29 UTC in
[its existing upgrade transaction](https://basescan.org/tx/0x94a7ad653db940378407de75e4b5cfd5aafb1222ac0dc5c1c3609f0a7f0d5f44).
The source is commit `03d8120181ea919dddc3ea7cd203b4793e0999cf`; no new vault upgrade was performed.

For all three units, a fresh Solidity 0.8.24 verification-unit build (`via_ir`, optimizer
runs 0) reproduced the complete deployed runtime after applying the live library addresses
and constructor immutables, checked at block **51,571,753**. The manifest records the runtime
code hashes and separates implementation deployment from proxy activation. All 31 hedger
accounting/correction regression tests passed, including the pinned Base fork; ABI, storage
layout, contract size, and version checks passed.

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

### Current Base release (22 September 2026)

The live versions and runtime hashes are recorded in `deployments/8453/versions.json`.
Proxy addresses are unchanged. This record describes activated contracts; it does not
mean every contract in the source tree is deployed at its latest version. Run
`make check-deployed-versions` to identify other components needing a separate
release. The active contracts in this release are QuantillonVault **1.3.4**,
per-vault stQEUROToken **1.2.4**, HyperliquidEurUsdOracle **1.0.5**, and
ExecutionPricing **1.3.2**. The vault links ExecutionPricingLibrary **1.1.1**,
StakingYieldLibrary **1.3.2**, TreasuryRecoveryLibrary **1.0.1**, and
SecureUpgradeLibrary **1.0.1**.

| Component | Current address |
| --- | --- |
| ExecutionPricing | `0xFA894CD2e0C8030c95925FfF3b8206F397e0D897` |
| PublicationBatcher (price/depth) | `0xFB9C8Bb7003e8b4E2F158ee8F72eCdA38A81c9AE` |
| ReportPublicationBatcher (active publisher route) | `0xBdd672FB97ecC9f5c8eBcD783a2Fe1234cA1a5FB` |

`QuantillonVault.executionPricing()` is authoritative for the active module.
The local, gitignored `deployments/8453/addresses.json` and dapp
`src/config/addresses.json` must agree with it. Preserve the zero-address
`stQEUROToken` placeholder in those registries: resolve each live token through
the factory; the manifest records the vaultId-2 proxy explicitly.

Before switching publisher configuration, verify `writer()`, `priceStore()`, and
`depthStore()` on the selected batcher. The active **ReportPublicationBatcher**
needs all three grants: SlippageStorage `WRITER_ROLE`, ExecutionPricing
`WRITER_ROLE`, and ExecutionPricing `REPORTER_ROLE`. A grant to PublicationBatcher
or the publisher EOA does not confer permission on ReportPublicationBatcher.
Set `EXECUTION_PRICING_ADDRESS`, `PUBLICATION_BATCHER_ADDRESS`, and
`REPORT_PUBLICATION_BATCHER_ADDRESS` to the same deployment generation. Append
both new batcher-to-module mappings to the indexer's `PUBLICATION_BATCHERS`;
retain historical mappings for decoding older events.

Verify accepted price, book and capacity events on chain, fresh observations,
usable mint/redeem previews, token state and hedger reconciliation before opening
the vault. Execution depth and capacity expire after **60 seconds** on this module;
the batch heartbeat is `min(PUBLISHER_INTERVAL_S, maxAge / 2)` (30 seconds with
the 60-second publisher interval). Partial price/depth reports may restore oracle
health before capacity can be certified. Health endpoints alone do not prove that
all reports were accepted. If the watchdog owns a pause, let its configured
recovery checks complete before resuming operation.

### Coordinated core implementation release

Treat a coordinated release as one reviewed package with two mandatory governance
steps: schedule the complete timelocked batch, then activate all components in one
atomic Safe transaction after the controller's live minimum delay. Direct-Safe
oracle and fee upgrades can share that activation transaction with the timelock
execution, configuration calls and adapter migration. Scheduling must not change
runtime addresses or pause production. Execution time is measured from the
confirmed scheduling block, not proposal submission.

The approved release includes the strict Chainlink EUR/USD cross-check:
`setReferenceCheck(200, 300, 8100)`, after upgrading the independent reference
probe. Verify all three values after execution and test that stale, unavailable
and divergent references reject minting and normal redemption. This applies on
weekends too; there is no stale-reference bypass. See
[Oracle Architecture](./Oracle-Architecture.md#independent-reference-configuration).

Inventory factory implementation templates and every registered staking series
separately from the factory proxy. Update the template even when existing series
already use the desired token implementation. Include funded non-upgradeable
adapters using the [atomic migration procedure](./External-Vault-Onboarding-Runbook.md#replacing-a-funded-metamorpho-adapter).
The retired Stork proxy, standalone production time provider and OpenZeppelin
controller are not automatically upgrade targets for similarly named source
contracts; verify their actual deployment type and active consumers first.

Rehearse the exact Safe hashes, all implementation slots and runtime hashes,
library links, temporary role revocation, retained yield and unchanged supply,
collateral and hedger accounting. Test the dapp's mint, redeem, stake and withdrawal
paths plus keeper harvesting against the upgraded state. An isolated time-warped
governance rehearsal proves delay enforcement; it cannot certify live report
freshness. Repeat fresh-price integration checks separately and recheck production
readiness before executing the queued package.

Deploy the coordinated core implementations from the release manifest. Read
target versions from `version-baseline/` and live `versions.json`; do not reuse
the historical version list in older runbooks.
Link the vault using the library addresses recorded for its selected implementation
in `versions.json`; preserve the pool library links recorded for that release. Preserve each implementation's existing
TimeProvider constructor argument. Check the factory registry for all token
proxies; the zero `stQEUROToken` entry in `addresses.json` is not an upgrade target.

The base timing helper uses `block.timestamp`; contracts with a TimeProvider
read that provider directly. Before upgrading, check the provider's offset and
ensure no emergency-disable proposal spans a change of clock.

For the Base controller, schedule all implementation upgrades with
`TimelockController.scheduleBatch` from the governance Safe. Read `getMinDelay()`
and wait for readiness. The Safe's execution batch must pause vault and pool, execute the timelocked
implementation upgrades, perform explicitly listed governance activation, and
unpause only after post-upgrade checks pass. For every existing stQEURO proxy,
keep the vault paused and call `syncVesting()` immediately after the
implementation upgrade. Verify the `YieldVestingSynced` event,
`totalAssets() <= asset balance`, and the expected accounted/unvested balances
from the implementation state before allowing deposits or unpausing. A plain `upgradeToAndCall(newImpl, "")`
does not run the token initializer, so omitting this sync exposes historical
donations through the first read path.

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

The combined Base release activated on 11 September 2026 at 06:54:31 UTC in
[the Safe execution transaction](https://basescan.org/tx/0xe44a00334ce1d49c7bb8f7e31e2e31237b55029d4d7e5b7ee4c2030e137604d4).
That launch used `0x57fBdf17a55D8F1d89E244D8D88937a867FfD063`; the current
module is listed in [Current Base release](#current-base-release-22-september-2026).
The following launch configuration is recorded in
`deployments/8453/execution-pricing-candidate.json`; the active module's getters
remain the source of truth for current values. Verified deployed versions are
recorded in `deployments/8453/versions.json`.

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
- After deployment, transfer core default-admin roles to the configured controller and operational governance/emergency roles to the multisig; verify the handover before enabling deposits

### Never Commit Secrets
- `.env`, `.env.base`, `.env.base-sepolia` and `.env.localhost` are **tracked but git-crypt encrypted** (`.gitattributes`): never commit them in plaintext and never disable the git-crypt filter
- Use a secret manager (AWS Secrets Manager, HashiCorp Vault) for production CI/CD

---

*Maintained by Quantillon Labs.*

### Reviewed release bindings and controller administration

`build-upgrade-safe-txs.sh <implementation> <version>` requires `RPC_URL`,
`RELEASE_MANIFEST` and `SAFE_TX_OUT_DIR`. Both staging directories must be private
(mode 0700), outside repositories and web roots. Never publish generated payloads.
The manifest is a reviewed local JSON object containing `chainId`, `sourceCommit`
(full Git SHA), `safe`, `timelock`, `minimumDelay`, `contracts`, and `libraries`.
Each contract entry contains `name`, `address` (candidate), `version`,
`runtimeCodeHash`, `proxy`, and `currentImplementation`. Each library entry
contains `name`, `fqn`, `address`, `version`, and `runtimeCodeHash`. Derive expected
hashes from the reproducible, reviewed build and verified library links; do not
blindly bless whatever code an address currently returns.

The builder checks chain, runtime hashes, versions, UUPS identity, current
implementation, controller, Safe permissions and the live delay. It creates a
unique salt and matching schedule, execute and cancel payloads. Rehearse the exact
payload on a pinned fork before proposing it. `build-verifiable-impl.sh` requires
the same reviewed library bindings for every `--lib`; an address alone is insufficient.
`UpgradeBase` and the vault upgrade script detect OZ controllers and direct
operators to this Safe builder instead of the legacy proposal-registry interface.

The coordinated core activation grants the controller default-admin authority on
all seven core proxies and every registered staking token, checks that authority
through the scheduled batch, and renounces the Safe's default-admin role in the
same atomic transaction. Preserve all operational roles and verify immediate
Safe pause/resume plus delayed role grants/revocations in the rehearsal. The dapp
reads current authority and produces matched schedule/execute actions when a
controller is required. New staking series must complete the same admin handover
before users can deposit; retain Safe governance/emergency roles separately.

After the confirmed activation, reconcile each proxy and linked library against
the reviewed runtime hashes, read versions from live storage, and run the upgrade
scripts' `record` action with the release commit, or the release manifest tool's `record-live` mode. The latter requires `RELEASE_ACTIVATION_TX`, plus `executionSafeTxHash` and `operationId` in the reviewed manifest; it checks the successful canonical Safe receipt, completed controller operation, and every live implementation/library binding before atomically updating `versions.json`. This is a required release-close
step, not a candidate-deployment step. Update adapter inventory and all affected
address/documentation entries only after their bindings change on chain. Re-run
`make check-deployed-versions` and the dapp contract-drift check; verify production
publisher, watchdog and rebalancer health before closing the release.

Storage gates recursively compare mappings, arrays and struct members and keep an
append-only registry of assembly storage anchors and schemas. `--update` cannot
approve an incompatible existing recursive layout. Run the gate's Python regression
tests as well as Solidity tests. Static analysis includes every installed High/Medium
detector and fails on unreviewed production results; stage reports privately.
