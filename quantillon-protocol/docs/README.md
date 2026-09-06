# Quantillon Protocol Documentation

Welcome to the comprehensive documentation for the Quantillon Protocol - a next-generation DeFi ecosystem featuring a euro-pegged stablecoin, advanced yield management, and sophisticated risk management tools.

## 📚 Documentation Overview

### [Technical API Reference](./API-Reference.md)
Detailed technical specifications, addresses, roles, constants and the error catalogue for developers.

### [Quick Start Guide](./Quick-Start.md)
Get up and running quickly with the Quantillon Protocol. Includes installation, basic integration examples, and common patterns.

### [Integration Examples](./Integration-Examples.md)
Comprehensive integration examples for common use cases, including portfolio management, yield optimization, and error handling.

### [Architecture Overview](./Architecture.md)
High-level overview of the protocol architecture, components, and their interactions.

### [Security Guide](./Security.md)
Security best practices, responsible disclosure, and risk management guidelines.

### [Deployment Guide](./Deployment.md)
Step-by-step instructions for deploying and configuring the protocol.

### [stQEUROFactory Technical Upgrade](./stQEUROFactory.md)
Detailed technical note for the multi-vault staking refactor (`stQEUROFactory`, vault self-registration, YieldShift routing by `vaultId`).

### [Multi-Vault Staking Runtime Flow](./Multi-Vault-Staking-Flow.md)
Contract runtime behavior for mint/stake/redeem/hedger flows after the `vaultId` refactor (default vault, redemption priority, adapter routing).

### [Staking Yield Distribution](./Staking-Yield-Distribution.md)
How yield reaches stQEURO stakers: the share-price accrual model, the hedger-first three-way split (hedger funding / stakers / treasury), `harvestAndDistributeVaultYield`, parameters, roles, events, and the operator runbook.

### [External Vault Onboarding Runbook](./External-Vault-Onboarding-Runbook.md)
Operator guide for post-core onboarding with `setup-external-vaults.sh` (prereqs, parameters, examples, verification).

---

## 🚀 Quick Links

### For Developers
- [**Technical Reference**](./API-Reference.md) - Complete function reference, addresses, and constants
- [**Quick Start**](./Quick-Start.md) - Get started in minutes

### For Integrators
- [**Integration Examples**](./API-Reference.md#solidity-integration-examples) - Code examples
- [**Error Handling**](./API-Reference.md#error-handling) - Error codes and handling
- [**Gas Optimization**](./API-Reference.md#gas-optimization) - Performance tips
- [**stQEURO Multi-Vault Upgrade**](./stQEUROFactory.md) - Implementation and runbook
- [**Multi-Vault Runtime Flow**](./Multi-Vault-Staking-Flow.md) - Mint/redeem/hedger runtime routing guide
- [**External Vault Onboarding Runbook**](./External-Vault-Onboarding-Runbook.md) - Post-core setup for adapters/default/redemption routing

### For Auditors
- [**Security Guide**](./Security.md) - Security considerations
- [**Architecture**](./Architecture.md) - System design
- [**Access Control**](./API-Reference.md#access-control-roles) - Role definitions
- [**stQEUROFactory Upgrade Note**](./stQEUROFactory.md) - Breaking changes and verification map
- [**Multi-Vault Runtime Flow**](./Multi-Vault-Staking-Flow.md) - Runtime behavior and operations map

---

## 🏗️ Protocol Components

### Core Contracts
- **QuantillonVault** - Main vault: USDC ↔ QEURO swaps, governance-set minting floor (102.5% live since 2026-09-02; 105% at launch), liquidation mode at 101%
- **QEUROToken** - Euro-pegged stablecoin: mint/burn via vault, rate limiting, compliance (blacklist/whitelist)
- **QTIToken** - Governance token: vote-escrow, 100M supply cap, up to 4× voting power multiplier (dormant — no mint path wired, supply currently 0)
- **FeeCollector** - Protocol fee aggregation and distribution (60% treasury / 25% dev / 15% community)
- **UserPool** - USDC deposits, QEURO staking with a 7-day unstaking cooldown; user yield accrues via stQEURO (no reward claim)
- **HedgerPool** - EUR/USD short positions for hedgers, margin management, liquidation at 101% CR
- **stQEUROFactory** - Multi-vault staking token factory: one stQEURO token proxy per staking vault
- **stQEUROToken** - Vault-level yield-bearing QEURO wrapper implementation deployed by the factory

### Yield Management
- **MetaMorphoStakingVaultAdapter** - Live external vault adapter (vaultId 2, MetaMorpho USDC vault on Base); `AaveStakingVaultAdapter` / `MorphoStakingVaultAdapter` wrap the mock vaults in `src/mocks/` for localhost and testnets
- **YieldShift** - Dynamic yield allocation between UserPool and HedgerPool: eligible-pool sizing (7-day holding period) with gradual adjustment; TWAP helpers feed historical metrics only

External adapters are onboarded post-core deployment with `setup-external-vaults.sh` (in the git-crypt-encrypted `scripts/deployment/`). See the [External Vault Onboarding Runbook](./External-Vault-Onboarding-Runbook.md).

### Oracle System
- **OracleRouter** - Oracle-agnostic router implementing `IOracle`; two switchable slots — slot 1 currently hosts **HyperliquidEurUsdOracle (the active oracle)**, slot 0 ChainlinkOracle (fallback)
- **HyperliquidEurUsdOracle** - **ACTIVE** EUR/USD source: Hyperliquid EUR perp mid-price published into SlippageStorage; 900 s staleness (1 h hard cap); 5% deviation circuit breaker
- **ChainlinkOracle** - Fallback EUR/USD (2-hour staleness) + USDC/USD (25-hour staleness) via Chainlink AggregatorV3; 5% deviation circuit breaker
- **StorkOracle** - EUR/USD + USDC/USD via Stork Network; parked (replaced in the router slot by HyperliquidEurUsdOracle)
- **SlippageStorage** - On-chain price store written by the off-chain publisher (`WRITER_ROLE`), read by HyperliquidEurUsdOracle
- **LighterEurUsdOracle** - Deployed 2026-07-17, inert (no router slot); the Lighter venue was not adopted (2026-09-01)

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

# Enforce a personal EIP-170 budget (example: 97%)
EIP170_PERSONAL_LIMIT_PERCENT=97 make analyze-contract-sizes
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
- **Test Suite**: unit, fuzz, integration and invariant tests — run `make test` for the current count
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
- Independent security audit completed; the resulting on-chain remediation went live in July 2026

### Bug Bounty
- **Program**: planned (not yet open)
- **Scope**: all smart contracts
- **Contact**: team@quantillon.money — see [Responsible Disclosure](./Security.md#responsible-disclosure)

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
- **X (Twitter)**: [@QuantillonLabs](https://x.com/QuantillonLabs)
- **Medium**: [medium.com/@quantillonlabs](https://medium.com/@quantillonlabs)
- **GitHub**: [github.com/Quantillon-Labs](https://github.com/Quantillon-Labs)

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

## 🔄 Deployed Versions

Live contract versions are recorded in [`deployments/8453/versions.json`](../deployments/8453/versions.json) (proxy, implementation, `version()`, commit) and can be read on-chain with `cast call <proxy> "version()(string)"`. Release procedures live in the [Deployment Guide](./Deployment.md) and the [2026-08-26 Bundle Release Runbook](./Bundle-Release-2026-08-26.md).

---

*This documentation is maintained by Quantillon Labs and updated regularly.*

**Quantillon Protocol** - Building the future of decentralized finance with euro-pegged stability and intelligent yield management.
