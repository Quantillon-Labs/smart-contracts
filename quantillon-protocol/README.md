# Quantillon Protocol Smart Contracts

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.24-blue.svg)](https://soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Foundry-Latest-orange.svg)](https://getfoundry.sh/)
[![Tests](https://img.shields.io/badge/Tests-Foundry%20suite%20(make%20test)-green.svg)](https://github.com/Quantillon-Labs/smart-contracts/actions)
[![Security](https://img.shields.io/badge/Security-0%20Critical%20%7C%200%20Medium-green.svg)](https://github.com/Quantillon-Labs/smart-contracts)
[![Security](https://img.shields.io/badge/Environment-Secure-green.svg)](https://github.com/Quantillon-Labs/smart-contracts)

> **Euro-pegged stablecoin protocol with dual-pool architecture, yield generation, and governance mechanisms**

## 📖 Overview

Quantillon Protocol is a comprehensive DeFi ecosystem built around QEURO, a Euro-pegged stablecoin. The protocol features a dual-pool architecture that separates user deposits from hedging operations, enabling efficient yield generation while maintaining stability. The codebase ships an extensive Foundry test suite (unit, fuzz, integration, invariants), custom errors and centralized validation libraries, and role-based access control.

## 📚 Documentation

- **[API Reference](https://smartcontracts.quantillon.money/API-Reference.html)** - Complete API reference for all smart contracts
- **[Architecture Overview](https://smartcontracts.quantillon.money/Architecture.html)** - Components, flows, roles and the upgrade model
- **[Oracle Architecture](https://smartcontracts.quantillon.money/Oracle-Architecture.html)** - Hedge-aligned EUR/USD pricing (Hyperliquid active, Chainlink fallback)
- **[Quick Start Guide](https://smartcontracts.quantillon.money/Quick-Start.html)** - Get started quickly with integration examples
- **[Integration Examples](https://smartcontracts.quantillon.money/Integration-Examples.html)** - Comprehensive integration examples and patterns
- **[Deployment Guide](https://smartcontracts.quantillon.money/Deployment.html)** - Complete deployment instructions and procedures
- **[Security Guide](https://smartcontracts.quantillon.money/Security.html)** - Security practices and considerations
- **[stQEUROFactory Technical Upgrade](https://smartcontracts.quantillon.money/stQEUROFactory.html)** - Multi-vault staking refactor details and runbook
- **[Multi-Vault Staking Runtime Flow](https://smartcontracts.quantillon.money/Multi-Vault-Staking-Flow.html)** - Contract-level mint/redeem/hedger routing behavior after the `vaultId` refactor
- **[Staking Yield Distribution](https://smartcontracts.quantillon.money/Staking-Yield-Distribution.html)** - How yield reaches stQEURO stakers (hedger-first three-way split)
- **[External Vault Onboarding Runbook](https://smartcontracts.quantillon.money/External-Vault-Onboarding-Runbook.html)** - Operator guide for `setup-external-vaults.sh`
- **[Documentation Hub](https://smartcontracts.quantillon.money/)** - Comprehensive documentation overview

### 🎯 Key Features

- **Euro-Pegged Stablecoin**: QEURO maintains 1:1 peg with Euro through sophisticated mechanisms
- **Dual-Pool Architecture**: Separates user deposits from hedging operations for optimal risk management
- **Yield Generation**: Multiple yield sources including protocol fees, interest differentials, and yield farming
- **Governance Token**: QTI token with vote-escrow mechanics for decentralized governance (not yet activated — token supply not minted, governance dormant until launch)
- **Advanced Hedging**: EUR/USD hedging positions with margin management and liquidation systems
- **Yield-Bearing Wrapper**: stQEURO token that automatically accrues yield for holders
- **External Adapter Integration**: Multi-vault adapter model with post-deploy onboarding
- **Comprehensive Security**: Role-based access control, reentrancy protection, and emergency pause mechanisms
- **Gas-Optimized Design**: Custom errors, centralized validation, and consolidated error libraries

## 🏗️ Architecture

### Core Contracts

| Contract | Purpose | Key Features |
|----------|---------|--------------|
| **QEUROToken** | Euro-pegged stablecoin | Mint/burn controls, rate limiting, compliance features, 18 decimals |
| **QTIToken** | Governance token | Vote-escrow mechanics, 100M supply cap, lock periods, 4× voting power. **Governance dormant: no mint path is wired yet, so supply is 0 and lock/vote/propose are inactive until a future activation upgrade mints the cap.** |
| **QuantillonVault** | Main vault | Overcollateralized minting (governance-set floor: 105% at launch, 102.5% under the September 2026 margin policy), liquidation mode at 101%, fee management |
| **FeeCollector** | Fee distribution | 60/25/15 split to treasury/dev/community, per-token accounting |
| **UserPool** | User deposits | USDC deposits, QEURO staking, unstaking cooldown; user yield accrues via stQEURO (no staking-reward claim) |
| **HedgerPool** | Hedging operations | EUR/USD short positions, margin management, liquidation at 101% CR |
| **stQEUROFactory** | Multi-vault staking factory | Deploys one stQEURO proxy per vault, registry by `vaultId` |
| **stQEUROToken** | Yield-bearing wrapper | Automatic yield accrual via exchange rate, no lock-up |
| **MetaMorphoStakingVaultAdapter** | Live external vault adapter | Non-upgradeable `IExternalStakingVault` adapter over the MetaMorpho USDC vault on Base (vaultId 2); `AaveStakingVaultAdapter` / `MorphoStakingVaultAdapter` wrap mock vaults for localhost |
| **YieldShift** | Yield management | Dynamic distribution between pools, 7-day holding period; allocation uses holding-period-filtered eligible-pool sizes with gradual adjustment (TWAP helpers exist but inform historical metrics, not the binding shift) |
| **OracleRouter** | Oracle routing | Single price entry point with two switchable slots; slot 1 currently hosts HyperliquidEurUsdOracle (**active**), slot 0 ChainlinkOracle (fallback) |
| **HyperliquidEurUsdOracle** | Active EUR/USD oracle | Hyperliquid EUR perp mid-price read from SlippageStorage; 15 min staleness (1 h hard cap), circuit breakers |
| **ChainlinkOracle** | Fallback price feeds | EUR/USD (2 h staleness) and USDC/USD (25 h staleness) via Chainlink, circuit breakers |
| **StorkOracle** | Stork price feeds (parked) | EUR/USD and USDC/USD via Stork Network; replaced in the router slot by HyperliquidEurUsdOracle |
| **SlippageStorage** | On-chain price store | Written by the off-chain publisher, read by HyperliquidEurUsdOracle |
| **LighterEurUsdOracle** | Inert oracle (historical) | Deployed 2026-07-17 for a second hedge venue that was not adopted (2026-09-01); no router slot |
| **TimeProvider** | Time utilities | Centralized `block.timestamp` wrapper for consistent time management |

## 🚀 Quick Start

### Prerequisites

- [Foundry](https://getfoundry.sh/) (latest version)
- [Node.js](https://nodejs.org/) (v18 or later)
- [Anvil](https://book.getfoundry.sh/anvil/) for local development

### 1. Clone and Setup

```bash
git clone https://github.com/Quantillon-Labs/smart-contracts.git
cd smart-contracts/quantillon-protocol
npm install
```

> **Note**: `scripts/deployment/` (deployment and upgrade scripts), the `.env*` templates and `CLAUDE.private.md` are git-crypt encrypted; the rest of `scripts/` is plaintext so CI can run it. Building and testing does not need the key — contact the maintainers only if you need the deployment tooling.

### 2. Environment Configuration

```bash
# Copy an environment template for your target network
cp .env.localhost .env        # for local Anvil development
cp .env.base-sepolia .env     # for Base Sepolia testnet
cp .env.base .env             # for Base mainnet
```

### 3. Build and Test

```bash
# Build contracts
make build

# Run tests
make test

# Run security analysis
make slither
```

**Testing conventions:** Run `make test` before pushing; run `make ci` for full checks (build, test, Slither, NatSpec, gas and size analysis). CI (GitHub Actions, `.github/workflows/quantillon-protocol-tests.yml` at the repository root) splits all test files across four runners on push and pull requests to main. Reproduce one shard with `bash scripts/ci-test-shard.sh 0 4` (indices 0–3); each uses the normal test profile and fuzz/invariant settings. The gating job requires every shard to pass, then runs `make build` and the upgrade-safety gate (`make analyze-contract-sizes check-storage-layout check-abi check-version-bump`). The nightly heavy suite runs `make ci`. Use `test_*`, `testFuzz_*`, and `invariant_*` naming; avoid new `assertTrue(true, ...)` placeholders—convert or explicitly skip with rationale. See the `test/` directory for test structure and coverage.

## 🚀 Deployment

### 🔐 Unified Deployment

Core contracts are deployed in a single `forge script` invocation via `DeployQuantillon.s.sol`. Deployed addresses are written to `deployments/{chainId}/addresses.json`.

```bash
# Deploy to localhost with mock contracts
./scripts/deployment/deploy.sh localhost --with-mocks

# Deploy to Base Sepolia testnet
./scripts/deployment/deploy.sh base-sepolia --verify

# Deploy to Base mainnet (production)
./scripts/deployment/deploy.sh base --verify --production

# Then onboard external vault adapters (post-core step)
./scripts/deployment/setup-external-vaults.sh --help
```

### 📋 Deployment Options

| Environment | Command | Description |
|-------------|---------|-------------|
| **localhost** | `./scripts/deployment/deploy.sh localhost --with-mocks` | Development with all mock contracts |
| **localhost** | `./scripts/deployment/deploy.sh localhost --with-mock-usdc` | Development with MockUSDC, real Chainlink feeds |
| **localhost** | `./scripts/deployment/deploy.sh localhost --with-mock-oracle` | Development with Mock Oracle, real USDC |
| **localhost** | `./scripts/deployment/deploy.sh localhost` | Development with no mocks (real contracts) |
| **base-sepolia** | `./scripts/deployment/deploy.sh base-sepolia --verify` | Testnet deployment with contract verification |
| **base** | `./scripts/deployment/deploy.sh base --verify` | Production deployment with verification |

### 🔧 Deployment Features

- **🔐 Secure Environment Variables**: `.env*` templates are tracked git-crypt encrypted — never commit them in plaintext
- **🌐 Multi-Network Support**: Localhost (31337), Base Sepolia (84532), Base Mainnet (8453)
- **🎭 Granular Mock Control**: Choose which contracts to mock (`--with-mocks`, `--with-mock-usdc`, `--with-mock-oracle`)
- **✅ Contract Verification**: Automatic verification on block explorers via `--verify`
- **🧪 Dry-Run Capability**: Test deployments without broadcasting via `--dry-run`
- **⚡ Smart Caching**: Compilation cache preserved by default for faster deployments (use `--clean-cache` to force full rebuild)
- **📝 Post-Deployment Tasks**: Automatic ABI copying and address updates

### 🛡️ Security Features

- **Environment Variables**: `.env*` templates are tracked git-crypt encrypted — never commit them in plaintext, never disable the filter
- **Secret Management**: Prefer a secret manager for production (e.g., AWS Secrets Manager)

## 🧪 Testing

### Run All Tests

```bash
make test
```

### Run Specific Test Suites

```bash
# Core protocol tests
forge test --match-contract QuantillonVault

# Integration tests
forge test --match-contract IntegrationTests

# Reentrancy and security-oriented tests
forge test --match-contract ReentrancyTests
```

### Gas Analysis

```bash
make gas-analysis
```

## 🔍 Security

### Automated Security Analysis

```bash
# Run Slither static analysis
make slither

# Run Mythril analysis
make mythril

# Validate NatSpec documentation
make validate-natspec

# Check contract bytecode size limits (EIP-170)
make analyze-contract-sizes

# Enforce a personal EIP-170 budget (example: 97%)
EIP170_PERSONAL_LIMIT_PERCENT=97 make analyze-contract-sizes
```

### Security And Quality Reports

Analysis outputs are written under `scripts/results/`:

- `scripts/results/slither/slither-report.txt` - Slither executive summary and unresolved/suppressed/excluded sections
- `scripts/results/mythril-reports/` - Mythril per-contract JSON and timestamped text summaries
- `scripts/results/natspec-validation-report.txt` - NatSpec validation coverage report
- `scripts/results/contract-sizes/contract-sizes-summary.txt` - EIP-170 size compliance summary
- `scripts/results/gas-analysis/` - Gas analysis outputs

### Security Features

- **Role-Based Access Control**: Granular permissions for different operations
- **Reentrancy Protection**: Comprehensive reentrancy guards
- **Emergency Pause**: Circuit breakers for critical functions
- **Input Validation**: Extensive parameter validation with centralized libraries
- **Overflow Protection**: Safe math operations throughout
- **Flash Loan Protection**: Balance checks to prevent flash loan attacks
- **Custom Errors**: Gas-efficient error handling with clear error messages
- **Secret Handling**: Environment variables loaded from `.env` during development
- **🔐 Encrypted Paths**: `scripts/deployment/`, `.env*` and `CLAUDE.private.md` are git-crypt encrypted (see `.gitattributes`); everything else is plaintext

## 📊 Development

### Available Commands

```bash
# Build contracts
make build

# Run tests
make test

# Run security analysis
make slither

# Generate documentation
make docs

# Clean build artifacts
make clean

# Gas analysis
make gas-analysis
```

### Code Quality

- **NatSpec Documentation**: Comprehensive documentation for all functions
- **Test Coverage**: Extensive test suite (unit, fuzz, integration, invariants) — `make test`
- **Security Analysis**: Regular security audits and static analysis
- **Gas Optimization**: Optimized for deployment size and execution cost
- **Error Handling**: Custom errors for gas efficiency and better error messages
- **Code Deduplication**: Consolidated validation functions and error libraries
- **Stack Optimization**: Fixed stack too deep issues through struct-based refactoring

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines

- Follow Solidity style guide
- Write comprehensive tests (aim for 100% coverage)
- Update documentation
- Ensure security best practices
- Protect secrets: `.env*` files are tracked but git-crypt encrypted — never commit them in plaintext, never disable the filter
- Use custom errors instead of `require()` strings for gas efficiency
- Consolidate duplicate code into libraries
- Follow the centralized error library pattern (`CommonErrorLibrary`)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](./LICENSE) file for details.

## 🔗 Links

- **Website**: [https://quantillon.money](https://quantillon.money)
- **Documentation**: [https://docs.quantillon.money](https://docs.quantillon.money)
- **Discord**: [discord.gg/uk8T9GqdE5](https://discord.gg/uk8T9GqdE5)
- **X (Twitter)**: [@QuantillonLabs](https://x.com/QuantillonLabs)
- **Telegram**: [@QuantillonLabs](https://t.me/QuantillonLabs)

## 🙏 Acknowledgments

- [OpenZeppelin](https://openzeppelin.com/) for secure contract libraries
- [Chainlink](https://chain.link/) for reliable price feeds
- [Morpho](https://morpho.org/) (MetaMorpho vaults) for the live external yield venue and [Hyperliquid](https://hyperliquid.xyz/) for the hedge venue and EUR/USD market price
- [Foundry](https://getfoundry.sh/) for development framework
- Standard .env files for environment variable management
