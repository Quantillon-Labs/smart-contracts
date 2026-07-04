# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# Quantillon Protocol Smart Contracts

Production-grade DeFi smart contracts for the Quantillon Protocol - a Euro-native stablecoin ecosystem with dual-pool architecture, yield generation, and governance.

## Purpose

Core smart contracts implementing:
- **QEURO**: Euro-pegged stablecoin (1:1 via EUR/USD oracle)
- **stQEURO**: Yield-bearing auto-compounding wrapper
- **stQEUROFactory**: Deploys one stQEURO proxy per external vault, registry by `vaultId`
- **QTI**: Governance token with vote-escrow mechanics (dormant — no mint path wired, supply currently 0)
- **QuantillonVault**: Main USDC ↔ QEURO vault (overcollateralized ≥105%, liquidation at 101%)
- **UserPool / HedgerPool**: Dual-pool architecture for deposits and hedging
- **FeeCollector**: Fee distribution with 60/25/15 split (treasury/dev/community)
- **YieldShift**: Dynamic yield distribution between pools (eligible-pool sizing + gradual adjustment, 7-day holding period)
- **AaveStakingVaultAdapter / MorphoStakingVaultAdapter**: Lightweight non-upgradeable adapters (symmetric pattern) wrapping mock vaults for localhost development

## Tech Stack

- **Solidity 0.8.24** (EVM Shanghai)
- **Foundry** (Forge, Anvil, Cast)
- **OpenZeppelin Contracts** (upgradeable, access control)
- **Hyperliquid (active) + Chainlink (fallback) + Stork (parked)** oracle feeds, switchable via OracleRouter
- **Slither + Mythril** (security analysis)

## Working Directory

All `make` commands and `forge` commands must be run from inside `quantillon-protocol/`:

```bash
cd quantillon-protocol
```

## Development Commands

```bash
# Build & Test
make build              # Compile all contracts
make test               # Run all tests (FOUNDRY_PROFILE=test)
make coverage           # Generate lcov coverage report
make clean              # Clean build artifacts and results

# Run a single test contract
FOUNDRY_PROFILE=test forge test --match-contract QuantillonVault -vvv

# Run a single test function
FOUNDRY_PROFILE=test forge test --match-test test_MintQEURO -vvv

# Security
make slither            # Static analysis
make mythril            # Symbolic execution
make security           # build + slither + mythril
make validate-natspec   # Documentation validation

# Analysis
make gas-analysis       # Gas optimization analysis
make analyze-contract-sizes  # EIP-170 size check

# Upgrade-safety gates (storage-frozen / size-critical contracts)
make check-storage-layout    # append-only storage-layout diff vs storage-layout/ baselines
make check-abi               # additive-only ABI/selector diff vs abi-baseline/ baselines
make check-version-bump      # require a version() semver bump when deployed bytecode changes (vs version-baseline/)
make check-deployed-versions # report deployed-vs-source versions (which contracts need an upgrade)
make check-verifiable-bytecode CONTRACT=Name # pre-deploy per impl: pruned verification unit must byte-match the build artifact (via_ir source-set sensitivity); on FAIL deploy via scripts/deployment/build-verifiable-impl.sh
make check-upgrade-safety    # build + size + storage-layout + ABI + version-bump (the PR gate)

# Documentation
make docs               # Generate HTML docs (forge doc)

# Deployment
make deploy-localhost           # With mock contracts (requires: anvil --port 8545)
make deploy-base-sepolia        # Base Sepolia testnet
make deploy-base                # Base mainnet
make deploy-dry-run             # Test without broadcast
make deploy-secure-localhost    # With pre-checks (slither + natspec)

# Full CI Pipeline
make ci                 # build, test, slither, natspec, gas, warnings, sizes
```

## Environment Setup

```bash
cd quantillon-protocol
cp .env.localhost .env   # or .env.base-sepolia / .env.base for other networks
```

**Key Variables**:
```
ETHERSCAN_API_KEY=...
PRIVATE_KEY=...
RPC_URL=http://localhost:8545
```

## Architecture Overview

### Contract Dependency Chain

```
OracleRouter (slot 1: HyperliquidEurUsdOracle [ACTIVE] | slot 0: ChainlinkOracle [fallback])
     ↓
QuantillonVault  ←→  QEUROToken (mint/burn)
     ↓
UserPool  ←→  stQEUROFactory → stQEUROToken (per-vault)
     ↓
HedgerPool  ←→  YieldShift (distributes yield between pools)
     ↓
AaveStakingVaultAdapter / MorphoStakingVaultAdapter (external yield)
     ↓
FeeCollector (60/25/15 treasury/dev/community)
```

### Core Contracts

| Contract | Purpose |
|----------|---------|
| **QEUROToken** | Euro-pegged stablecoin, 18 decimals, mint/burn with rate limiting |
| **QTIToken** | Governance token, 100M supply cap, vote-escrow with 4× voting power. **Dormant: no mint path is wired, so supply is 0 and lock/vote/propose are inactive until an activation upgrade mints the cap** |
| **QuantillonVault** | Main USDC→QEURO swap, oracle-priced, fee management |
| **FeeCollector** | Fee distribution with per-token accounting |
| **UserPool** | USDC deposits, QEURO staking, unstaking cooldown; user yield accrues via stQEURO (the staking-reward claim path was removed) |
| **HedgerPool** | EUR/USD short positions (hedgers are SHORT EUR), margin management, liquidation at 101% CR |
| **stQEUROFactory** | Factory deploying one stQEURO proxy per vault, `vaultId` registry |
| **stQEUROToken** | Yield-bearing wrapper, exchange rate increases as yield accrues (similar to stETH) |
| **YieldShift** | Dynamic yield split between UserPool/HedgerPool, 7-day holding period; binding allocation uses holding-period-filtered eligible-pool sizes + gradual adjustment (TWAP helpers feed historical metrics only) |
| **OracleRouter** | Single price entry point with two switchable slots; slot 1 currently hosts HyperliquidEurUsdOracle (active), slot 0 ChainlinkOracle (fallback) |
| **HyperliquidEurUsdOracle** | ACTIVE EUR/USD oracle: Hyperliquid EUR perp mid-price read from SlippageStorage (900 s staleness, 1 h hard cap); USDC/USD delegated to ChainlinkOracle |
| **SlippageStorage** | On-chain price store written by the off-chain publisher (dapp slippage-monitor), read by HyperliquidEurUsdOracle |
| **TimeProvider** | Centralized `block.timestamp` wrapper used across contracts |

### HedgerPool P&L Model

Hedgers are SHORT EUR (they owe QEURO to users):
- `totalUnrealizedPnL = FilledVolume - (QEUROBacked × OraclePrice / 1e30)`
- `effectiveMargin = margin + netUnrealizedPnL`
- Liquidation mode (CR ≤ 101%): `effectiveMargin = 0`

### Oracle Architecture

`OracleRouter` implements `IOracle` and routes to one of two slots — `enum OracleType { CHAINLINK, STORK }`. Slot 1 keeps its historical `STORK` name for ABI stability but currently hosts **`HyperliquidEurUsdOracle`, the ACTIVE production oracle** (`activeOracle = 1`, live since 2026-06-25); slot 0 is `ChainlinkOracle` (fallback and USDC/USD source); `StorkOracle` is parked. All protocol contracts depend only on `IOracle` (oracle-agnostic). HyperliquidEurUsdOracle reads the Hyperliquid EUR perp mid-price from `SlippageStorage` (published on-chain by the dapp's slippage-monitor; 900 s staleness default, 1 h hard cap); ChainlinkOracle validates EUR/USD and USDC/USD feeds with staleness checks (2h EUR/USD, 25h USDC/USD). Both enforce 0.80-1.40 price bounds and 5% deviation circuit breakers.

- **`getEurUsdPrice()` is non-`view` by design**: on a fresh valid read it commits the price into the deviation-baseline cache (`lastValidEurUsdPrice`/`lastPriceUpdateTime`/`lastPriceUpdateBlock`) and emits `PriceUpdated`. So every price read is a state write, and consumers such as `QuantillonVault.shouldTriggerLiquidationLive()` are non-`view` too. Integrators that only need a cheap read should use the cached getters rather than `getEurUsdPrice()`.
- **Failover is manual**: `OracleRouter` routes to a single `activeOracle` with no automatic fallback or disagreement handling. If the active oracle returns `isValid=false`, callers revert; switching is a deliberate governance action via `switchOracle` (`ORACLE_MANAGER_ROLE`). Operate a monitor/alert on oracle health.

## Coding Conventions

**File Organization**:
```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// =============================================================================
// IMPORTS
// =============================================================================
import {OpenZeppelin} from "...";
import {Internal} from "...";

// =============================================================================
// CONTRACT
// =============================================================================
contract MyContract is Initializable, SecureUpgradeable {
    bytes32 public constant ROLE = keccak256("ROLE");
    mapping(address => uint256) private _balances;
    event ActionPerformed(address indexed user);
    // Errors: use library errors only (CommonErrorLibrary, etc.)
}
```

**Naming**:
- Contracts: `PascalCase`; Functions: `camelCase`; Constants: `UPPER_CASE`; Private/internal: `_leadingUnderscore`
- Custom errors: `PascalCase` via error library (e.g. `CommonErrorLibrary.InvalidAmount`)

**NatSpec** (100% coverage required):
```solidity
/// @notice Brief description
/// @dev Implementation details
/// @param name Parameter description
/// @return Description of return value
/// @custom:security Security considerations
/// @custom:access Required role
```

## Architecture Patterns

1. **UUPS Upgradeable**: All core contracts use OpenZeppelin UUPS proxy via `SecureUpgradeable` base (a `timelock` pointer gates upgrades; a quorum-gated 24hr emergency-disable path exists in the base). **Live trust model (Base mainnet, since 2026-06-15; threshold verified on-chain 2026-07-02):** all privileged roles are held by a **2-of-3 Gnosis Safe** (`0x1d7fF432…e6cd`); each core proxy's `timelock` is an **OpenZeppelin `TimelockController`** (`0x7Ade8f3B…8342`, 12h delay, Safe = sole proposer/executor); the deployer EOA is fully de-privileged (retains only SlippageStorage `WRITER`). Upgrades run `Safe → controller.schedule → wait 12h → controller.execute`.
2. **Role-Based Access**: `AccessControlUpgradeable` with defined roles (`MINTER_ROLE`, `PAUSER_ROLE`, `UPGRADER_ROLE`, etc.)
3. **Library Pattern**: Business logic extracted to libraries to stay under EIP-170 bytecode limit — 22 libraries in `src/libraries/`
4. **Error Libraries**: Custom errors in domain-specific libraries (`CommonErrorLibrary`, `VaultErrorLibrary`, `HedgerPoolErrorLibrary`, `TokenErrorLibrary`, etc.) for gas efficiency
5. **Reentrancy Protection**: `ReentrancyGuardUpgradeable` on all state-changing functions
6. **Emergency Pause**: `PausableUpgradeable` with `PAUSER_ROLE`
7. **Symmetric Adapter Pattern**: Non-upgradeable adapters (`AaveStakingVaultAdapter`, `MorphoStakingVaultAdapter`) wrap simple mock vaults with identical `IExternalStakingVault` interface
8. **Versioning (`IVersioned`)**: Every core contract implements `IVersioned.version()` — a `pure` semver getter (no storage slot; read through the proxy it reflects the deployed implementation). Linked libraries expose `version()`; inlined libraries carry a `VERSION` constant. **Rule: ANY change to a deployed contract/library — correction, bug fix, update, or upgrade — MUST be traced through a semver bump of its `version()`** (PATCH = bugfix/internal, MINOR = new function/behavior; storage/ABI breaks are disallowed by the gates). Enforced by `make check-version-bump`. Deployed versions live in `deployments/{chainId}/versions.json` (written by the `UpgradeBase` scripts on every upgrade); `make check-deployed-versions` reports which contracts are out of date.

## Deployment Strategy

Single unified deployment script (`DeployQuantillon.s.sol`) deploys all core contracts in one forge invocation via `deploy.sh`. Post-core step: onboard external vault adapters via `setup-external-vaults.sh`. Deployed addresses written to `deployments/{chainId}/addresses.json` via `vm.writeJson()`.

Networks: localhost (31337), Base Sepolia (84532), Base Mainnet (8453).

## Documentation Site

The public docs site (https://smartcontracts.quantillon.money) is an mdBook built by `make docs` → `scripts/build-docs.sh` → `forge doc --build`, reading `docs/book.toml` (`src = "src"`). **Critical for editing: most of `docs/` is generated — know which files are source before touching anything.**

**Generated by `forge doc` — DO NOT hand-edit (overwritten on every `make docs`):**
- `docs/book.toml`
- `docs/src/README.md` — copied verbatim from the repo-root `README.md` (this is the site homepage)
- `docs/src/SUMMARY.md` — auto TOC (`Home` + contract API only; guide pages are merged in by the publish step, not committed here)
- `docs/src/src/**` — the entire contract/interface/library reference, generated from NatSpec
- The stale guide copies under `docs/src/*.md` (e.g. `docs/src/External-Vault-Onboarding-Runbook.md`) are leftover build artifacts — ignore them

**Hand-maintained SOURCE — edit these:**
- Repo-root `README.md` → becomes the site homepage. Link to guides with absolute `https://smartcontracts.quantillon.money/<Name>.html` URLs; relative `./docs/X.md` links work on GitHub but **404 on the published book**.
- `docs/SUMMARY.md` → site nav for the guide pages (its `# src` contract tree should mirror what `forge doc` emits into `docs/src/src/**`).
- `docs/README.md` → the "Documentation Hub" page.
- Top-level guides published as `…/<Name>.html`: `API-Reference.md`, `Quick-Start.md`, `Integration-Examples.md`, `Architecture.md`, `Oracle-Architecture.md`, `Security.md`, `Deployment.md`, `stQEUROFactory.md`, `Multi-Vault-Staking-Flow.md`, `Staking-Yield-Distribution.md`, `External-Vault-Onboarding-Runbook.md`.

**Keep in sync:** `docs/API-Reference.md` Contract Addresses must match `deployments/8453/addresses.json` (Base mainnet). External vault adapters are onboarded per `vaultId` and live in `deployments/8453/*-adapter.json`, not in `addresses.json`.

## Testing Standards

- **57 test files, 1,415 passing tests** (0 failing, 11 skipped)
- Fuzz tests: 1000 runs; Invariant tests: 256 runs, depth 15
- Naming: `test_*`, `testFuzz_*`, `invariant_*`
- 11 explicit skips with documented rationale (the misleading pure-skip attack stubs were removed; real attack coverage lives in `EconomicAttackVectorsIntegration` + integration tests)
- Run `FOUNDRY_PROFILE=test forge test` (or `make test`) before pushing

## Security Notes

- Security contact: team@quantillon.money
- **Governance (Base mainnet, since 2026-06-15; threshold verified on-chain 2026-07-02):** 2-of-3 Gnosis Safe (`0x1d7fF432…e6cd`) holds all privileged roles; upgrades route through an OZ `TimelockController` (`0x7Ade8f3B…8342`, 12h delay, Safe = proposer/executor); deployer EOA de-privileged (only SlippageStorage `WRITER` retained). **Audit fixes F-3/4/5/6/8/11/14/15/19 deployed 2026-06-17** via the Timelock (finalize tx `0x50d8…b46`); the prior `toggleSecureUpgrades(false)` instant-disable bypass (F-5) is now closed on all 7 SecureUpgradeable proxies. **Accepted risk (F-2, 2026-06-17):** OracleRouter / ChainlinkOracle / StorkOracle / FeeCollector are plain-UUPS, upgradeable by the Safe *directly* (no 12h Timelock) — a deliberate choice to keep oracle/fee upgrades fast in a crisis; the 2-of-3 Safe is the sole gate (the single-key risk that drove F-2 is already eliminated).
- Slither: 0 Critical, 0 Medium findings
- Custom errors required (not `require` strings)
- NatSpec 100% coverage enforced via `make validate-natspec`
- Scripts in `scripts/deployment/` are git-crypt encrypted

## Important Caveats

- Compiler: `via_ir=true` enabled on all profiles
- Optimizer: `optimizer_runs=0` (minimizes runtime bytecode size to satisfy EIP-170); test/coverage profiles use 200 runs
- Contract size limit: 24576 bytes (EIP-170) — check with `make analyze-contract-sizes`
- Never commit `.env` files
- ABIs exported to dapp via `scripts/deployment/copy-abis.sh`

## graphify

This project has a graphify knowledge graph at graphify-out/.

Rules:
- Before answering architecture or codebase questions, read graphify-out/GRAPH_REPORT.md for god nodes and community structure
- If graphify-out/wiki/index.md exists, navigate it instead of reading raw files
- After modifying code files in this session, run `python3 -c "from graphify.watch import _rebuild_code; from pathlib import Path; _rebuild_code(Path('.'))"` to keep the graph current
