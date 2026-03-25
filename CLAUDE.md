# Quantillon Protocol Smart Contracts

Production-grade DeFi smart contracts for the Quantillon Protocol - a Euro-native stablecoin ecosystem with dual-pool architecture, yield generation, and governance.

## Purpose

Core smart contracts implementing:
- **QEURO**: Euro-pegged stablecoin (1:1 via EUR/USD oracle)
- **stQEURO**: Yield-bearing auto-compounding wrapper
- **QTI**: Governance token with vote-escrow mechanics
- **QuantillonVault**: Main USDC ↔ QEURO vault
- **UserPool / HedgerPool**: Dual-pool architecture for deposits and hedging
- **YieldShift**: Dynamic yield distribution
- **AaveVaultAdapter**: UUPS-upgradeable Aave V3 adapter for yield generation
- **AaveStakingVaultAdapter / MorphoStakingVaultAdapter**: Lightweight non-upgradeable adapters (symmetric pattern) wrapping mock vaults for localhost development

## Tech Stack

- **Solidity 0.8.24** (EVM Paris)
- **Foundry** (Forge, Anvil, Cast)
- **OpenZeppelin Contracts** (upgradeable, access control)
- **Chainlink** (oracle feeds)
- **Slither + Mythril** (security analysis)

## Repository Structure

```
smart-contracts/
└── quantillon-protocol/           # Main project directory
    ├── src/
    │   ├── core/                  # Core contracts
    │   │   ├── QEUROToken.sol
    │   │   ├── QTIToken.sol
    │   │   ├── QuantillonVault.sol
    │   │   ├── UserPool.sol
    │   │   ├── HedgerPool.sol
    │   │   ├── stQEUROToken.sol
    │   │   ├── FeeCollector.sol
    │   │   ├── SecureUpgradeable.sol
    │   │   ├── TimelockUpgradeable.sol
    │   │   ├── vaults/
    │   │   │   ├── AaveVaultAdapter.sol         # UUPS-upgradeable Aave V3 adapter
    │   │   │   ├── AaveStakingVaultAdapter.sol  # Lightweight adapter for MockAaveVault
    │   │   │   └── MorphoStakingVaultAdapter.sol # Lightweight adapter for MockMorphoVault
    │   │   └── yieldmanagement/
    │   │       └── YieldShift.sol
    │   ├── oracle/
    │   │   ├── ChainlinkOracle.sol
    │   │   ├── OracleRouter.sol
    │   │   └── StorkOracle.sol
    │   ├── interfaces/            # 17 interface files
    │   ├── libraries/             # 18 utility libraries
    │   └── mocks/                 # Test mocks (MockAaveVault, MockMorphoVault, MockUSDC, etc.)
    ├── test/                      # 57 test files (~1,471 tests)
    ├── scripts/
    │   ├── deployment/            # Deploy scripts (git-crypt encrypted)
    │   ├── analyze-gas.sh
    │   ├── run-slither.sh
    │   └── validate-natspec.js
    ├── foundry.toml               # Foundry configuration
    ├── Makefile                   # Build commands
    ├── slither.config.json
    └── .env.localhost             # Environment templates
```

## Development Commands

```bash
# Build & Test
make build              # Compile all contracts
make test               # Run all tests (1,471+ tests)
make coverage           # Generate coverage report
make clean              # Clean artifacts

# Security
make slither            # Static analysis
make mythril            # Symbolic execution
make security           # All security checks
make validate-natspec   # Documentation validation

# Analysis
make gas-analysis       # Gas optimization analysis
make analyze-contract-sizes  # EIP-170 size check

# Documentation
make docs               # Generate HTML docs (forge doc)

# Deployment
make deploy-localhost           # With mock contracts
make deploy-base-sepolia        # Base Sepolia testnet
make deploy-base                # Base mainnet
make deploy-dry-run             # Test without broadcast
make deploy-secure-localhost    # With pre-checks

# Full CI Pipeline
make ci                 # build, test, slither, natspec, gas, warnings, sizes
```

## Environment Setup

```bash
# Copy environment template
cp .env.localhost .env

# Or use symlink (default)
ln -sf .env.localhost .env
```

**Key Variables**:
```
ETHERSCAN_API_KEY=...
PRIVATE_KEY=...
RPC_URL=http://localhost:8545
```

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
    // Constants
    bytes32 public constant ROLE = keccak256("ROLE");

    // State variables
    mapping(address => uint256) private _balances;

    // Events
    event ActionPerformed(address indexed user);

    // Errors (custom, not require strings)
    // ... use library errors

    // Functions
}
```

**Naming**:
- Contracts: `PascalCase` (QEUROToken, QuantillonVault)
- Functions: `camelCase` (validateNonZeroAddress)
- Constants: `UPPER_CASE` (MINTER_ROLE)
- Private/internal: leading underscore (_roles)
- Custom errors: `PascalCase` via library (CommonErrorLibrary.InvalidAmount)

**NatSpec Documentation**:
```solidity
/// @notice Brief description
/// @dev Implementation details
/// @param name Parameter description
/// @return Description of return value
/// @custom:security Security considerations
/// @custom:access Required role
```

## Architecture Patterns

1. **UUPS Upgradeable**: All core contracts use OpenZeppelin UUPS proxy
2. **Role-Based Access**: AccessControlUpgradeable with defined roles
3. **Library Pattern**: Centralized logic in libraries for bytecode reduction
4. **Error Libraries**: Custom errors in CommonErrorLibrary for gas efficiency
5. **Reentrancy Protection**: ReentrancyGuardUpgradeable on all state-changing functions
6. **Emergency Pause**: PausableUpgradeable with PAUSER_ROLE
7. **Symmetric Adapter Pattern**: Lightweight non-upgradeable adapters (`AaveStakingVaultAdapter`, `MorphoStakingVaultAdapter`) wrap simple mock vaults (`MockAaveVault`, `MockMorphoVault`) with identical interfaces — deploy Step 1: mock vault, Step 2: adapter pointing to it

## Deployment Strategy

Single unified deployment script (`DeployQuantillon.s.sol`) deploys all 13 contracts in one forge invocation.
Deployed addresses are written to `deployments/{chainId}/addresses.json` via `vm.writeJson()`.
Networks: localhost (31337), Base Sepolia (84532), Base Mainnet (8453).

## Testing Standards

- **1,471+ tests passing** (100% pass rate, 57 test files)
- Fuzz tests: 1000 runs
- Invariant tests: 256 runs, depth 15
- Naming: `test_*`, `testFuzz_*`, `invariant_*`
- ~46 explicit skips with documented rationale
- Run `make test` before pushing

## Security Notes

- Security contact: team@quantillon.money
- Slither: 0 Critical, 0 Medium findings
- Custom errors required (not require strings)
- NatSpec 100% coverage required
- Scripts in `scripts/deployment/` are git-crypt encrypted

## Important Caveats

- Compiler: `via_ir=true` enabled
- Optimizer: 200 runs default, 1M for production
- Contract size limit: 24576 bytes (EIP-170)
- Never commit `.env` files
- ABIs exported to dapp via `scripts/deployment/copy-abis.sh`
