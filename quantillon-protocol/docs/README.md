# Quantillon Protocol Documentation

Welcome to the comprehensive documentation for the Quantillon Protocol - a next-generation DeFi ecosystem featuring a euro-pegged stablecoin, advanced yield management, and sophisticated risk management tools.

## 📚 Documentation Overview

### [API Documentation](./API.md)
Complete API reference for all smart contract interfaces, including function signatures, parameters, return values, events, and integration examples.

### [Technical API Reference](./API-Reference.md)
Detailed technical specifications, error codes, gas estimates, and implementation details for developers.

### [Quick Start Guide](./Quick-Start.md)
Get up and running quickly with the Quantillon Protocol. Includes installation, basic integration examples, and common patterns.

### [Integration Examples](./Integration-Examples.md)
Comprehensive integration examples for common use cases, including portfolio management, yield optimization, and error handling.

### [Architecture Overview](./Architecture.md)
High-level overview of the protocol architecture, components, and their interactions.

### [Security Guide](./Security.md)
Security best practices, audit reports, and risk management guidelines.

### [Deployment Guide](./Deployment.md)
Step-by-step instructions for deploying and configuring the protocol.

### [stQEUROFactory Technical Upgrade](./stQEUROFactory.md)
Detailed technical note for the multi-vault staking refactor (`stQEUROFactory`, vault self-registration, YieldShift routing by `vaultId`).

---

## 🚀 Quick Links

### For Developers
- [**API Documentation**](./API.md) - Complete function reference
- [**Quick Start**](./Quick-Start.md) - Get started in minutes
- [**Technical Reference**](./API-Reference.md) - Deep technical details

### For Integrators
- [**Integration Examples**](./API.md#integration-examples) - Code examples
- [**Error Handling**](./API-Reference.md#error-handling) - Error codes and handling
- [**Gas Optimization**](./API-Reference.md#gas-optimization) - Performance tips
- [**stQEURO Multi-Vault Upgrade**](./stQEUROFactory.md) - Implementation and runbook

### For Auditors
- [**Security Guide**](./Security.md) - Security considerations
- [**Architecture**](./Architecture.md) - System design
- [**Access Control**](./API-Reference.md#access-control-roles) - Role definitions
- [**stQEUROFactory Upgrade Note**](./stQEUROFactory.md) - Breaking changes and verification map

---

## 🏗️ Protocol Components

### Core Contracts
- **QuantillonVault** - Main vault: USDC ↔ QEURO swaps, ≥105% collateralization, liquidation at 101%
- **QEUROToken** - Euro-pegged stablecoin: mint/burn via vault, rate limiting, compliance (blacklist/whitelist)
- **QTIToken** - Governance token: vote-escrow, fixed 100M supply, up to 4× voting power multiplier
- **FeeCollector** - Protocol fee aggregation and distribution (60% treasury / 25% dev / 15% community)
- **UserPool** - User deposits (USDC), QEURO staking, yield distribution with 7-day holding period
- **HedgerPool** - EUR/USD short positions for hedgers, margin management, liquidation at 101% CR
- **stQEUROFactory** - Multi-vault staking token factory: one stQEURO token proxy per staking vault
- **stQEUROToken** - Vault-level yield-bearing QEURO wrapper implementation deployed by the factory

### Yield Management
- **AaveVault** - USDC yield farming via Aave v3: supply, harvest rewards, emergency withdrawal
- **YieldShift** - Dynamic yield allocation between UserPool and HedgerPool; TWAP-based balancing

### Oracle System
- **OracleRouter** - Oracle-agnostic router implementing `IOracle`; routes to Chainlink or Stork (switchable by governance)
- **ChainlinkOracle** - EUR/USD + USDC/USD via Chainlink AggregatorV3; 1-hour staleness; 5% deviation circuit breaker
- **StorkOracle** - EUR/USD + USDC/USD via Stork Network; same validation as Chainlink

### Utilities
- **TimeProvider** - Centralized `block.timestamp` wrapper used by all time-sensitive contracts

---

## 🔧 Development Tools

### Testing
```bash
# Run all tests
make test

# Run specific test suite
forge test --match-contract QuantillonVault

# Run with coverage
make coverage
```

### Security Analysis
```bash
# Run Slither analysis
make slither

# Run Mythril symbolic execution analysis
make mythril

# Run comprehensive security analysis
make security

# Validate NatSpec coverage
make validate-natspec

# Verify EIP-170 contract size limits
make analyze-contract-sizes
```

### Documentation Generation
```bash
# Generate HTML documentation (forge doc)
make docs

# Validate NatSpec coverage
make validate-natspec
```

---

## 📊 Protocol Metrics

### Current Status
- **Test Suite**: 1,300+ tests passing (unit, fuzz, integration, invariants)
- **Security**: Slither/Mythril runs are tracked in versioned artifacts under `scripts/results/`
- **Build**: Compile, warning analysis, gas analysis, and contract-size checks are part of the Makefile workflow
- **Documentation**: NatSpec coverage is validated with `make validate-natspec`

### Analysis Artifacts
- `scripts/results/slither/slither-report.txt` - unresolved/suppressed/excluded Slither findings
- `scripts/results/mythril-reports/` - Mythril JSON outputs and text summaries
- `scripts/results/natspec-validation-report.txt` - NatSpec coverage details
- `scripts/results/contract-sizes/contract-sizes-summary.txt` - EIP-170 status per contract
- `scripts/results/gas-analysis/` - gas report history

---

## 🌐 Network Support

### Mainnet
- **Base**: `./scripts/deployment/deploy.sh base --verify --production`

### Testnets
- **Base Sepolia**: `./scripts/deployment/deploy.sh base-sepolia --verify`

### Local Development
- **Localhost (Anvil)**: `./scripts/deployment/deploy.sh localhost --with-mocks`

---

## 🔐 Security

### Audits
- **Quantillon Protocol v1.0**: Coming soon

### Bug Bounty
- **Program**: Coming soon
- **Rewards**: Up to $100,000
- **Scope**: All smart contracts
- **Contact**: team@quantillon.money

### Security Best Practices
1. Always validate inputs
2. Use slippage protection
3. Check contract state before transactions
4. Implement proper error handling
5. Monitor events for state changes
6. Run regular security analysis (Slither + Mythril)
7. Review security reports before deployment

---

## 📞 Support

### Technical Support
- **Email**: team@quantillon.money
- **Discord**: [discord.gg/uk8T9GqdE5](https://discord.gg/uk8T9GqdE5)
- **Telegram**: [@QuantillonLabs](https://t.me/QuantillonLabs)

### Community
- **Twitter**: [@QuantillonLabs](https://twitter.com/QuantillonLabs)
- **Medium**: [medium.com/@quantillonlabs](https://medium.com/@quantillonlabs)
- **GitHub**: [github.com/QuantillonLabs](https://github.com/Quantillon-Labs)

### Documentation Issues
- **GitHub Issues**: [Report documentation issues](https://github.com/Quantillon-Labs/smart-contracts/issues)
- **Pull Requests**: [Contribute to documentation](https://github.com/Quantillon-Labs/smart-contracts/pulls)

---

## 📝 Contributing

We welcome contributions to the documentation! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### Documentation Standards
- Use clear, concise language
- Include code examples
- Provide error handling examples
- Update version numbers
- Test all code examples

### Pull Request Process
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

---

## 📄 License

This documentation is licensed under the [MIT License](LICENSE).

---

## 🔄 Version History

### v1.0.0 (Current)
- Initial release
- Core protocol functionality
- Complete API documentation
- Security audit completed

### v1.1.0 (Planned)
- Enhanced yield management
- Additional vault strategies
- Cross-chain support
- Improved gas optimization

---

*This documentation is maintained by Quantillon Labs and updated regularly.*

**Quantillon Protocol** - Building the future of decentralized finance with euro-pegged stability and intelligent yield management.
