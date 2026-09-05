# Smart Contracts - Quantillon Protocol

<div align="center">
  <img src="quantillon-protocol/docs/banner.png" alt="Quantillon Protocol Banner" width="100%">
</div>

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.24-blue.svg)](https://soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Foundry-Latest-orange.svg)](https://getfoundry.sh/)
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/Quantillon-Labs/smart-contracts)

> **Smart Contracts Repository for Quantillon Protocol - Euro-pegged stablecoin ecosystem with dual-pool architecture**

## 📁 Repository Structure

This repository contains the complete smart contract implementation for the Quantillon Protocol. All development files are organized in the `quantillon-protocol` directory.

```
smart-contracts/
├── quantillon-protocol/          # Main project directory
│   ├── src/                     # Smart contract source code
│   │   ├── core/               # Core protocol contracts
│   │   ├── interfaces/         # Contract interfaces
│   │   ├── libraries/          # Utility libraries
│   │   └── oracle/             # Oracle integration
│   ├── test/                   # Comprehensive test suite
│   ├── scripts/                # Build and deployment scripts
│   ├── docs/                   # Hand-written guides + generated NatSpec reference (docs/src/)
│   ├── lib/                    # External dependencies
│   ├── foundry.toml           # Foundry configuration
│   └── README.md              # Detailed project documentation
└── README.md                   # This file
```

## 🚀 Quick Navigation

### Main Project
**[📁 quantillon-protocol/](./quantillon-protocol/)** - Complete smart contract implementation

### Key Directories
- **[📄 Source Code](./quantillon-protocol/src/)** - All smart contracts and libraries
- **[🧪 Tests](./quantillon-protocol/test/)** - Comprehensive test suite
- **[📚 Documentation](./quantillon-protocol/docs/)** - Hand-written guides plus the generated NatSpec reference (`docs/src/`)
- **[🔧 Scripts](./quantillon-protocol/scripts/)** - Build and deployment scripts

## 🎯 What is Quantillon Protocol?

Quantillon Protocol is a comprehensive DeFi ecosystem built around **QEURO**, a Euro-pegged stablecoin. The protocol features a dual-pool architecture that separates user deposits from hedging operations, enabling efficient yield generation while maintaining stability.

### Core Components

- **QEUROToken**: Euro-pegged stablecoin — no fixed tokenomic supply cap (supply bounded by hedging capacity); governance-raisable safety ceiling and mint/burn rate limiting
- **QTIToken**: Governance token with vote-escrow mechanics and voting power multipliers (governance dormant — no mint path wired yet, so supply is 0 until a future activation upgrade)
- **QuantillonVault**: Main vault for overcollateralized QEURO minting
- **UserPool**: Batch deposits and QEURO staking with an unstaking cooldown (user yield accrues via stQEURO)
- **HedgerPool**: EUR/USD hedging operations with margin management (single-hedger model)
- **stQEUROFactory / stQEUROToken**: One ERC-4626 yield-bearing stQEURO token per external staking vault
- **FeeCollector**: Protocol fee aggregation and 60/25/15 distribution (treasury / dev / community)
- **YieldShift**: Dynamic yield allocation between UserPool and HedgerPool
- **OracleRouter + HyperliquidEurUsdOracle (active) / ChainlinkOracle (fallback)**: EUR/USD pricing aligned with the hedge venue; **SlippageStorage** holds the published venue mid
- **MetaMorphoStakingVaultAdapter**: Live external yield adapter (MetaMorpho USDC vault on Base, vaultId 2)
- **TimeProvider**: Centralized `block.timestamp` wrapper

### Key Features
- **Dual-pool architecture** separating user deposits from hedging operations
- **Role-based access control** for all critical operations
- **Emergency pause mechanisms** for crisis situations
- **Upgradeable architecture** via UUPS pattern
- **On-chain versioning** — every core contract exposes `version()`; any change is traced through a semver bump (CI-enforced), with deployed versions tracked in `deployments/{chainId}/versions.json`
- **Hedge-aligned pricing**: EUR/USD is the Hyperliquid EUR perp mid (the hedge venue) read through `OracleRouter`, with Chainlink as the one-transaction fallback
- **Governance**: a 2-of-3 Gnosis Safe holds every privileged role; upgrades of the core `SecureUpgradeable` proxies pass through a 12 h OpenZeppelin `TimelockController`
- **Yield generation** through external staking vaults (MetaMorpho live), protocol fees and interest differentials

## 🏃‍♂️ Getting Started

### Prerequisites
- [Foundry](https://getfoundry.sh/) (latest version)
- Git

### Quick Start
```bash
# Clone the repository
git clone https://github.com/Quantillon-Labs/smart-contracts.git
cd smart-contracts

# Navigate to the main project
cd quantillon-protocol

# Install dependencies and build
forge install
forge build

# Run tests
forge test
```

## 📚 Documentation

### Generated Documentation
```bash
cd quantillon-protocol
forge doc --build
forge doc --serve
```

### Contract Documentation
- **[QEUROToken](./quantillon-protocol/docs/src/src/core/QEUROToken.sol/contract.QEUROToken.md)** - Euro-pegged stablecoin
- **[QTIToken](./quantillon-protocol/docs/src/src/core/QTIToken.sol/contract.QTIToken.md)** - Governance token
- **[QuantillonVault](./quantillon-protocol/docs/src/src/core/QuantillonVault.sol/contract.QuantillonVault.md)** - Main vault
- **[UserPool](./quantillon-protocol/docs/src/src/core/UserPool.sol/contract.UserPool.md)** - User deposits
- **[HedgerPool](./quantillon-protocol/docs/src/src/core/HedgerPool.sol/contract.HedgerPool.md)** - Hedging operations
- **[stQEUROToken](./quantillon-protocol/docs/src/src/core/stQEUROToken.sol/contract.stQEUROToken.md)** - Yield-bearing wrapper

## 🏗️ Core Contracts

| Contract | Purpose | Location |
|----------|---------|----------|
| **QEUROToken** | Euro-pegged stablecoin | `quantillon-protocol/src/core/QEUROToken.sol` |
| **QTIToken** | Governance token | `quantillon-protocol/src/core/QTIToken.sol` |
| **QuantillonVault** | Main vault | `quantillon-protocol/src/core/QuantillonVault.sol` |
| **UserPool** | User deposits | `quantillon-protocol/src/core/UserPool.sol` |
| **HedgerPool** | Hedging operations | `quantillon-protocol/src/core/HedgerPool.sol` |
| **stQEUROToken** | Yield-bearing wrapper (ERC-4626) | `quantillon-protocol/src/core/stQEUROToken.sol` |
| **stQEUROFactory** | Per-vault stQEURO factory | `quantillon-protocol/src/core/stQEUROFactory.sol` |
| **FeeCollector** | Fee distribution | `quantillon-protocol/src/core/FeeCollector.sol` |
| **YieldShift** | Yield allocation between pools | `quantillon-protocol/src/core/yieldmanagement/YieldShift.sol` |
| **MetaMorphoStakingVaultAdapter** | Live external vault adapter | `quantillon-protocol/src/core/vaults/MetaMorphoStakingVaultAdapter.sol` |
| **OracleRouter** | Price entry point (two switchable slots) | `quantillon-protocol/src/oracle/OracleRouter.sol` |
| **HyperliquidEurUsdOracle** | Active EUR/USD oracle | `quantillon-protocol/src/oracle/HyperliquidEurUsdOracle.sol` |
| **ChainlinkOracle** | Fallback EUR/USD + USDC/USD | `quantillon-protocol/src/oracle/ChainlinkOracle.sol` |
| **SlippageStorage** | On-chain venue-mid store | `quantillon-protocol/src/oracle/SlippageStorage.sol` |
| **TimeProvider** | Timestamp wrapper | `quantillon-protocol/src/libraries/TimeProviderLibrary.sol` |

## 🧪 Testing

```bash
cd quantillon-protocol

# Run all tests
forge test

# Run with verbose output
forge test -vvv

# Generate coverage
forge coverage
```

## 🔧 Development

```bash
cd quantillon-protocol

# Format code
forge fmt

# Build contracts
forge build

# Deploy to a local Anvil node (scripts/deployment/ is git-crypt encrypted; needs the key)
./scripts/deployment/deploy.sh localhost --with-mocks   # or: make deploy-localhost
```

### Development Tools

The protocol includes comprehensive development and analysis tools:

```bash
# Code Quality & Analysis
make gas-analysis      # Comprehensive gas optimization analysis
make analyze-warnings  # Analyze and categorize build warnings
make validate-natspec  # Validate NatSpec documentation coverage
make slither          # Security vulnerability analysis

# Documentation & Testing
make docs             # Generate HTML documentation
make test             # Run comprehensive test suite
make coverage         # Generate test coverage report

# Complete Development Pipeline
make all              # Run all checks (build, test, coverage, docs, analysis)
```

**Key Features:**
- **Gas Analysis**: Contract size optimization, function visibility analysis, storage layout optimization
- **Warning Analysis**: Categorizes build warnings by type with actionable recommendations
- **NatSpec Validation**: Ensures 100% documentation coverage for security audits
- **Security Analysis**: Comprehensive vulnerability detection with Slither
- **Documentation**: Auto-generated HTML documentation from NatSpec comments

## 🔒 Security

- **Security Contact**: `team@quantillon.money`
- **Security Features**: Role-based access control, reentrancy protection, emergency pause mechanisms
- **Security Analysis**: Integrated Slither analysis with `make slither`
- **Warning Analysis**: Comprehensive build warning analysis with `make analyze-warnings`

For detailed security information, see the [main project README](./quantillon-protocol/README.md#security).

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](./quantillon-protocol/docs/CONTRIBUTING.md) for details.

### Development Workflow
1. Fork the repository
2. Create a feature branch
3. Make your changes in the `quantillon-protocol` directory
4. Add tests and update documentation
5. Submit a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](./quantillon-protocol/LICENSE) file for details.

## 🌐 Links

- **Website**: [quantillon.money](https://quantillon.money)
- **Documentation**: [docs.quantillon.money](https://docs.quantillon.money)
- **X (Twitter)**: [@QuantillonLabs](https://x.com/QuantillonLabs)
- **Discord**: [discord.gg/uk8T9GqdE5](https://discord.gg/uk8T9GqdE5)
- **Telegram**: [@QuantillonLabs](https://t.me/QuantillonLabs)

## 📖 Detailed Documentation

For comprehensive documentation, setup instructions, and development guides, please see:

**[📁 quantillon-protocol/README.md](./quantillon-protocol/README.md)**

---

**Built with ❤️ by the Quantillon Labs team**
