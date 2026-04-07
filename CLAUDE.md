# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# Quantillon Protocol Smart Contracts

Production-grade DeFi smart contracts for the Quantillon Protocol - a Euro-native stablecoin ecosystem with dual-pool architecture, yield generation, and governance.

## Purpose

Core smart contracts implementing:
- **QEURO**: Euro-pegged stablecoin (1:1 via EUR/USD oracle)
- **stQEURO**: Yield-bearing auto-compounding wrapper
- **stQEUROFactory**: Deploys one stQEURO proxy per external vault, registry by `vaultId`
- **QTI**: Governance token with vote-escrow mechanics
- **QuantillonVault**: Main USDC ↔ QEURO vault (overcollateralized ≥105%, liquidation at 101%)
- **UserPool / HedgerPool**: Dual-pool architecture for deposits and hedging
- **FeeCollector**: Fee distribution with 60/25/15 split (treasury/dev/community)
- **YieldShift**: Dynamic yield distribution between pools (TWAP-based, 7-day holding period)
- **AaveStakingVaultAdapter / MorphoStakingVaultAdapter**: Lightweight non-upgradeable adapters (symmetric pattern) wrapping mock vaults for localhost development

## Tech Stack

- **Solidity 0.8.24** (EVM Shanghai)
- **Foundry** (Forge, Anvil, Cast)
- **OpenZeppelin Contracts** (upgradeable, access control)
- **Chainlink + Stork** (oracle feeds, switchable via OracleRouter)
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
OracleRouter (ChainlinkOracle | StorkOracle)
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
| **QTIToken** | Governance token, fixed 100M supply, vote-escrow with 4× voting power |
| **QuantillonVault** | Main USDC→QEURO swap, oracle-priced, fee management |
| **FeeCollector** | Fee distribution with per-token accounting |
| **UserPool** | USDC deposits, QEURO staking, unstaking cooldown, yield routing |
| **HedgerPool** | EUR/USD short positions (hedgers are SHORT EUR), margin management, liquidation at 101% CR |
| **stQEUROFactory** | Factory deploying one stQEURO proxy per vault, `vaultId` registry |
| **stQEUROToken** | Yield-bearing wrapper, exchange rate increases as yield accrues (similar to stETH) |
| **YieldShift** | Dynamic yield split between UserPool/HedgerPool, TWAP-based, 7-day holding period |
| **OracleRouter** | Routes between Chainlink and Stork oracles, switchable by governance |
| **TimeProvider** | Centralized `block.timestamp` wrapper used across contracts |

### HedgerPool P&L Model

Hedgers are SHORT EUR (they owe QEURO to users):
- `totalUnrealizedPnL = FilledVolume - (QEUROBacked × OraclePrice / 1e30)`
- `effectiveMargin = margin + netUnrealizedPnL`
- Liquidation mode (CR ≤ 101%): `effectiveMargin = 0`

### Oracle Architecture

`OracleRouter` implements `IOracle` and routes to either `ChainlinkOracle` or `StorkOracle`. All protocol contracts depend only on `IOracle` (oracle-agnostic). Both oracle adapters validate EUR/USD and USDC/USD feeds with 1hr staleness checks and circuit breakers.

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

1. **UUPS Upgradeable**: All core contracts use OpenZeppelin UUPS proxy via `SecureUpgradeable` base (adds timelock + multi-sig requirement for upgrades, 24hr emergency-disable delay, quorum of 2)
2. **Role-Based Access**: `AccessControlUpgradeable` with defined roles (`MINTER_ROLE`, `PAUSER_ROLE`, `UPGRADER_ROLE`, etc.)
3. **Library Pattern**: Business logic extracted to libraries to stay under EIP-170 bytecode limit — 24 libraries in `src/libraries/`
4. **Error Libraries**: Custom errors in domain-specific libraries (`CommonErrorLibrary`, `VaultErrorLibrary`, `HedgerPoolErrorLibrary`, `TokenErrorLibrary`, etc.) for gas efficiency
5. **Reentrancy Protection**: `ReentrancyGuardUpgradeable` on all state-changing functions
6. **Emergency Pause**: `PausableUpgradeable` with `PAUSER_ROLE`
7. **Symmetric Adapter Pattern**: Non-upgradeable adapters (`AaveStakingVaultAdapter`, `MorphoStakingVaultAdapter`) wrap simple mock vaults with identical `IExternalStakingVault` interface

## Deployment Strategy

Single unified deployment script (`DeployQuantillon.s.sol`) deploys all core contracts in one forge invocation via `deploy.sh`. Post-core step: onboard external vault adapters via `setup-external-vaults.sh`. Deployed addresses written to `deployments/{chainId}/addresses.json` via `vm.writeJson()`.

Networks: localhost (31337), Base Sepolia (84532), Base Mainnet (8453).

## Testing Standards

- **57 test files, 1,471+ tests** (100% pass rate)
- Fuzz tests: 1000 runs; Invariant tests: 256 runs, depth 15
- Naming: `test_*`, `testFuzz_*`, `invariant_*`
- ~46 explicit skips with documented rationale
- Run `FOUNDRY_PROFILE=test forge test` (or `make test`) before pushing

## Security Notes

- Security contact: team@quantillon.money
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
