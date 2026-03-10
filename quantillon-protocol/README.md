# Quantillon Protocol Smart Contracts

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.24-blue.svg)](https://soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Foundry-Latest-orange.svg)](https://getfoundry.sh/)
[![Tests](https://img.shields.io/badge/Tests-1300%2B%20passed%20%7C%200%20failed-green.svg)](https://github.com/Quantillon-Labs/smart-contracts)
[![Security](https://img.shields.io/badge/Security-0%20Critical%20%7C%200%20Medium-green.svg)](https://github.com/Quantillon-Labs/smart-contracts)
[![Security](https://img.shields.io/badge/Environment-Secure-green.svg)](https://github.com/Quantillon-Labs/smart-contracts)

> **Euro-pegged stablecoin protocol with dual-pool architecture, yield generation, and governance mechanisms**

## 📖 Overview

Quantillon Protocol is a comprehensive DeFi ecosystem built around QEURO, a Euro-pegged stablecoin. The protocol features a dual-pool architecture that separates user deposits from hedging operations, enabling efficient yield generation while maintaining stability. The codebase includes 1,300+ tests, custom errors and centralized validation libraries, and role-based access control.

## 📚 Documentation

- **[API Documentation](https://smartcontracts.quantillon.money/API.html)** - Complete API reference for all smart contracts
- **[Technical Reference](https://smartcontracts.quantillon.money/API-Reference.html)** - Detailed technical specifications and implementation details
- **[Quick Start Guide](https://smartcontracts.quantillon.money/Quick-Start.html)** - Get started quickly with integration examples
- **[Integration Examples](https://smartcontracts.quantillon.money/Integration-Examples.html)** - Comprehensive integration examples and patterns
- **[Deployment Guide](https://smartcontracts.quantillon.money/Deployment.html)** - Complete deployment instructions and procedures
- **[Security Guide](https://smartcontracts.quantillon.money/Security.html)** - Security practices and considerations
- **[Documentation Hub](https://smartcontracts.quantillon.money/)** - Comprehensive documentation overview

### 🎯 Key Features

- **Euro-Pegged Stablecoin**: QEURO maintains 1:1 peg with Euro through sophisticated mechanisms
- **Dual-Pool Architecture**: Separates user deposits from hedging operations for optimal risk management
- **Yield Generation**: Multiple yield sources including protocol fees, interest differentials, and yield farming
- **Governance Token**: QTI token with vote-escrow mechanics for decentralized governance
- **Advanced Hedging**: EUR/USD hedging positions with margin management and liquidation systems
- **Yield-Bearing Wrapper**: stQEURO token that automatically accrues yield for holders
- **Aave Integration**: Automated yield farming through Aave protocol integration
- **Comprehensive Security**: Role-based access control, reentrancy protection, and emergency pause mechanisms
- **Gas-Optimized Design**: Custom errors, centralized validation, and consolidated error libraries

## 🏗️ Architecture

### Core Contracts

| Contract | Purpose | Key Features |
|----------|---------|--------------|
| **QEUROToken** | Euro-pegged stablecoin | Mint/burn controls, rate limiting, compliance features, 18 decimals |
| **QTIToken** | Governance token | Vote-escrow mechanics, fixed supply (100M), lock periods, 4× voting power |
| **QuantillonVault** | Main vault | Overcollateralized minting (≥105%), liquidation at 101%, fee management |
| **FeeCollector** | Fee distribution | 60/25/15 split to treasury/dev/community, per-token accounting |
| **UserPool** | User deposits | USDC deposits, QEURO staking, unstaking cooldown, yield distribution |
| **HedgerPool** | Hedging operations | EUR/USD short positions, margin management, liquidation at 101% CR |
| **stQEUROToken** | Yield-bearing wrapper | Automatic yield accrual via exchange rate, no lock-up |
| **AaveVault** | Aave v3 integration | Automated USDC yield farming, reward harvesting, emergency controls |
| **YieldShift** | Yield management | Dynamic distribution between pools, 7-day holding period, TWAP-based allocation |
| **OracleRouter** | Oracle routing | Routes between Chainlink and Stork oracles, switchable by governance |
| **ChainlinkOracle** | Chainlink price feeds | EUR/USD and USDC/USD via Chainlink, 1 hr staleness check, circuit breakers |
| **StorkOracle** | Stork price feeds | EUR/USD and USDC/USD via Stork Network, same validation as Chainlink |
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

> **Note**: Some folders (`scripts/`) are encrypted with git-crypt for privacy concerns. If you need access to these files, you'll need the encryption key. Contact the maintainers for access.

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

**Testing conventions:** Run `make test` before pushing; run `make ci` for full checks (build, test, Slither, NatSpec, gas and size analysis). CI (GitHub Actions) runs `make build && make test` on push and pull requests to main. Use `test_*`, `testFuzz_*`, and `invariant_*` naming; avoid new `assertTrue(true, ...)` placeholders—convert or explicitly skip with rationale. See the `test/` directory for test structure and coverage.

## 🚀 Deployment

### 🔐 Unified Deployment

All 13 contracts are deployed in a single `forge script` invocation via `DeployQuantillon.s.sol`. Deployed addresses are written to `deployments/{chainId}/addresses.json`.

```bash
# Deploy to localhost with mock contracts
./scripts/deployment/deploy.sh localhost --with-mocks

# Deploy to Base Sepolia testnet
./scripts/deployment/deploy.sh base-sepolia --verify

# Deploy to Base mainnet (production)
./scripts/deployment/deploy.sh base --verify --production
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

- **🔐 Secure Environment Variables**: Manage secrets with standard `.env` files (never commit them)
- **🌐 Multi-Network Support**: Localhost (31337), Base Sepolia (84532), Base Mainnet (8453)
- **🎭 Granular Mock Control**: Choose which contracts to mock (`--with-mocks`, `--with-mock-usdc`, `--with-mock-oracle`)
- **✅ Contract Verification**: Automatic verification on block explorers via `--verify`
- **🧪 Dry-Run Capability**: Test deployments without broadcasting via `--dry-run`
- **⚡ Smart Caching**: Compilation cache preserved by default for faster deployments (use `--clean-cache` to force full rebuild)
- **📝 Post-Deployment Tasks**: Automatic ABI copying and address updates

### 🛡️ Security Features

- **Environment Variables**: Use standard `.env` files (never commit them)
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
- **🔐 Encrypted Folders**: Some folders (e.g., `scripts/`) are encrypted with git-crypt for privacy and security. These files require the encryption key to decrypt and access.

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
- **Test Coverage**: Extensive test suite with 1,300+ tests (100% passing)
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
- Protect secrets; never commit `.env`
- Use custom errors instead of `require()` strings for gas efficiency
- Consolidate duplicate code into libraries
- Follow the centralized error library pattern (`CommonErrorLibrary`)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](./LICENSE) file for details.

## 🔗 Links

- **Website**: [https://quantillon.money](https://quantillon.money)
- **Documentation**: [https://docs.quantillon.money](https://docs.quantillon.money)
- **Discord**: [https://discord.gg/quantillon](https://discord.gg/quantillon)
- **Twitter**: [@QuantillonLabs](https://twitter.com/QuantillonLabs)

## 🙏 Acknowledgments

- [OpenZeppelin](https://openzeppelin.com/) for secure contract libraries
- [Chainlink](https://chain.link/) for reliable price feeds
- [Aave](https://aave.com/) for yield farming integration
- [Foundry](https://getfoundry.sh/) for development framework
- Standard .env files for environment variable management
