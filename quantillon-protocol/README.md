# Quantillon Protocol Smart Contracts

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.24-blue.svg)](https://soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Foundry-Latest-orange.svg)](https://getfoundry.sh/)
[![Tests](https://img.shields.io/badge/Tests-678%20passed%20%7C%200%20failed-green.svg)](https://github.com/quantillon/smart-contracts)
[![Security](https://img.shields.io/badge/Security-0%20Critical%20%7C%200%20Medium-green.svg)](https://github.com/quantillon/smart-contracts)
[![Security](https://img.shields.io/badge/Environment-Secure-green.svg)](https://github.com/quantillon)

> **Euro-pegged stablecoin protocol with dual-pool architecture, yield generation, and governance mechanisms**

## 📖 Overview

Quantillon Protocol is a comprehensive DeFi ecosystem built around QEURO, a Euro-pegged stablecoin. The protocol features a dual-pool architecture that separates user deposits from hedging operations, enabling efficient yield generation while maintaining stability.

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
- **🔐 Secure Environment Variables**: Enterprise-grade security with standard .env files

## 🏗️ Architecture

### Core Contracts

| Contract | Purpose | Key Features |
|----------|---------|--------------|
| **QEUROToken** | Euro-pegged stablecoin | Mint/burn controls, rate limiting, compliance features, 18 decimals |
| **QTIToken** | Governance token | Vote-escrow mechanics, fixed supply, lock periods, voting power multipliers |
| **QuantillonVault** | Main vault | Overcollateralized minting, liquidation system, fee management |
| **UserPool** | User deposits | Staking rewards, yield distribution, deposit/withdrawal management |
| **HedgerPool** | Hedging operations | EUR/USD positions, margin management, liquidation system |
| **stQEUROToken** | Yield-bearing wrapper | Automatic yield accrual, exchange rate mechanism |
| **AaveVault** | Aave integration | Automated yield farming, risk management, emergency controls |
| **YieldShift** | Yield management | Dynamic yield distribution, pool rebalancing, performance metrics |
| **ChainlinkOracle** | Price feeds | EUR/USD and USDC/USD price feeds with circuit breakers |

## 🚀 Quick Start

### Prerequisites

- [Foundry](https://getfoundry.sh/) (latest version)
- [Node.js](https://nodejs.org/) (v18 or later)
- [Anvil](https://book.getfoundry.sh/anvil/) for local development

### 1. Clone and Setup

```bash
git clone https://github.com/quantillon/smart-contracts.git
cd smart-contracts/quantillon-protocol
npm install
```

### 2. Environment Configuration

```bash
# Copy environment template
cp .env.example .env

# Fill in your values (API keys, private keys, etc.)
# Edit .env with your actual configuration

# Environment variables are ready to use
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

## 🚀 Deployment

### 🔐 Multi-Phase Deployment Strategy

The protocol uses a **4-phase atomic deployment** (A→B→C→D) to stay within Base Sepolia/Mainnet's 24.9M gas limit per transaction:

| Phase | Gas | Contracts | Purpose |
|-------|-----|-----------|---------|
| **A** | ~17M | TimeProvider, Oracle, QEURO, FeeCollector, Vault | Core infrastructure |
| **B** | ~16M | QTI, AaveVault, stQEURO | Token layer |
| **C** | ~11M | UserPool, HedgerPool | Pool layer |
| **D** | ~7M | YieldShift + wiring | Yield management |

**Key Features:**
- ✅ All phases well under 24.9M limit (8-13M gas headroom)
- ✅ Automatic address passing between phases
- ✅ Minimal initialization with governance setters for post-deployment wiring
- ✅ Frontend address updater merges all phase broadcasts automatically

See [Deployment Guide](https://smartcontracts.quantillon.money/Deployment.html) for complete details.

### 🔐 Secure Deployment

The protocol uses standard environment variable configuration:

```bash
# Deploy to localhost with mock contracts
./scripts/deployment/deploy.sh localhost --with-mocks

# Deploy to Base Sepolia testnet
./scripts/deployment/deploy.sh base-sepolia --verify

# Deploy to Base mainnet (production)
./scripts/deployment/deploy.sh base --verify

# Deploy to Ethereum Sepolia testnet
./scripts/deployment/deploy.sh ethereum-sepolia --with-mocks --verify

# Deploy to Ethereum mainnet (production)
./scripts/deployment/deploy.sh ethereum --verify
```

### 📋 Deployment Options

| Environment | Command | Description |
|-------------|---------|-------------|
| **localhost** | `./scripts/deployment/deploy.sh localhost --with-mocks` | Development with Anvil and mock contracts |
| **base-sepolia** | `./scripts/deployment/deploy.sh base-sepolia --verify` | Testnet deployment with contract verification |
| **base** | `./scripts/deployment/deploy.sh base --production --verify` | Production deployment with multisig governance |

### 🔧 Deployment Features

- **🔐 Secure Environment Variables**: Manage secrets with standard `.env` files (never commit them)
- **🌐 Multi-Network Support**: Localhost, Base Sepolia, and Base Mainnet
- **🎭 Mock Contract Handling**: Automatic mock deployment for localhost
- **✅ Contract Verification**: Automatic verification on block explorers
- **🧪 Dry-Run Capability**: Test deployments without broadcasting
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

# Security tests
forge test --match-contract SecurityTests
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
```

### Security Features

- **Role-Based Access Control**: Granular permissions for different operations
- **Reentrancy Protection**: Comprehensive reentrancy guards
- **Emergency Pause**: Circuit breakers for critical functions
- **Input Validation**: Extensive parameter validation
- **Overflow Protection**: Safe math operations throughout
- **Secret Handling**: Environment variables loaded from `.env` during development

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
- **Test Coverage**: Extensive test suite with 678+ tests
- **Security Analysis**: Regular security audits and static analysis
- **Gas Optimization**: Optimized for deployment size and execution cost

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines

- Follow Solidity style guide
- Write comprehensive tests
- Update documentation
- Ensure security best practices
- Protect secrets; never commit `.env`

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
