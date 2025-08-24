# Quantillon Protocol Smart Contracts

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.24-blue.svg)](https://soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Foundry-Latest-orange.svg)](https://getfoundry.sh/)

> **Euro-pegged stablecoin protocol with dual-pool architecture, yield generation, and governance mechanisms**

## 📖 Overview

Quantillon Protocol is a comprehensive DeFi ecosystem built around QEURO, a Euro-pegged stablecoin. The protocol features a dual-pool architecture that separates user deposits from hedging operations, enabling efficient yield generation while maintaining stability.

### 🎯 Key Features (as documented in contracts)

- **Euro-Pegged Stablecoin**: QEURO maintains 1:1 peg with Euro through sophisticated mechanisms
- **Dual-Pool Architecture**: Separates user deposits from hedging operations for optimal risk management
- **Yield Generation**: Multiple yield sources including protocol fees, interest differentials, and yield farming
- **Governance Token**: QTI token with vote-escrow mechanics for decentralized governance
- **Advanced Hedging**: EUR/USD hedging positions with margin management and liquidation systems
- **Yield-Bearing Wrapper**: stQEURO token that automatically accrues yield for holders

## 🏗️ Architecture

### Core Contracts

| Contract | Purpose | Key Features (as documented) |
|----------|---------|--------------|
| **QEUROToken** | Euro-pegged stablecoin | Mint/burn controls, rate limiting (10M QEURO/hour), compliance features, 18 decimals |
| **QTIToken** | Governance token | Vote-escrow mechanics, 100M fixed supply, 7 days-4 years lock periods, 4x max voting power |
| **QuantillonVault** | Main vault | Overcollateralized minting, liquidation system, fee management |
| **UserPool** | User deposits | Staking rewards, yield distribution, deposit/withdrawal management |
| **HedgerPool** | Hedging operations | EUR/USD positions, margin management, liquidation system |
| **stQEUROToken** | Yield-bearing wrapper | Automatic yield accrual, exchange rate mechanism |

### Protocol Flow

```mermaid
graph TD
    A[User Deposits USDC] --> B[UserPool]
    B --> C[Mint QEURO]
    C --> D[User Receives QEURO]
    D --> E[User Can Stake QEURO]
    E --> F[stQEURO Token]
    F --> G[Automatic Yield Accrual]
    
    H[Hedgers] --> I[HedgerPool]
    I --> J[EUR/USD Positions]
    J --> K[Yield Generation]
    K --> L[Protocol Fees]
    L --> G
    
    M[Governance] --> N[QTIToken]
    N --> O[Vote-escrow System]
    O --> P[Proposal Execution]
```

## 🚀 Quick Start

### Prerequisites

- [Foundry](https://getfoundry.sh/) (latest version)
- Node.js 18+ (for additional tooling)
- Git

### Installation

```bash
# Clone the repository
git clone https://github.com/quantillon/smart-contracts.git
cd smart-contracts/quantillon-protocol

# Install dependencies
forge install

# Build contracts
forge build

# Run tests
forge test
```

### Environment Setup

Create a `.env` file in the project root:

```bash
# Network RPC URLs
ETHEREUM_RPC_URL=https://eth.llamarpc.com
BASE_RPC_URL=https://mainnet.base.org
BASE_SEPOLIA_RPC_URL=https://sepolia.base.org

# API Keys
BASESCAN_API_KEY=your_basescan_api_key
ETHERSCAN_API_KEY=your_etherscan_api_key

# Deployment
PRIVATE_KEY=your_private_key
```

## 📚 Documentation

### Generated Documentation

The protocol includes comprehensive NatSpec documentation for all contracts:

```bash
# Generate documentation
forge doc --build

# Serve documentation locally
forge doc --serve
```

Documentation will be available at `http://localhost:3000`

### Contract Documentation

- **[QEUROToken](./docs/src/src/core/QEUROToken.sol/contract.QEUROToken.md)**: Euro-pegged stablecoin implementation
- **[QTIToken](./docs/src/src/core/QTIToken.sol/contract.QTIToken.md)**: Governance token with vote-escrow
- **[QuantillonVault](./docs/src/src/core/QuantillonVault.sol/contract.QuantillonVault.md)**: Main vault for overcollateralized minting
- **[UserPool](./docs/src/src/core/UserPool.sol/contract.UserPool.md)**: User deposit and staking management
- **[HedgerPool](./docs/src/src/core/HedgerPool.sol/contract.HedgerPool.md)**: EUR/USD hedging operations
- **[stQEUROToken](./docs/src/src/core/stQEUROToken.sol/contract.stQEUROToken.md)**: Yield-bearing wrapper token

## 🧪 Testing

### Run All Tests

```bash
# Run all tests
forge test

# Run with verbose output
forge test -vvv

# Run specific test file
forge test --match-contract QEUROToken
```

### Test Coverage

```bash
# Generate coverage report
forge coverage

# Generate coverage report with lcov
forge coverage --report lcov
```

### Gas Optimization

```bash
# Generate gas report
forge test --gas-report
```

## 🔧 Development

### Code Quality

```bash
# Format code
forge fmt

# Lint code
forge build --sizes

# Check for common issues
forge build --force
```

### Deployment

```bash
# Deploy to local network
forge script script/deploy/DeployProtocol.s.sol --rpc-url http://localhost:8545 --broadcast

# Deploy to testnet
forge script script/deploy/DeployProtocol.s.sol --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast --verify

# Deploy to mainnet
forge script script/deploy/DeployProtocol.s.sol --rpc-url $BASE_RPC_URL --broadcast --verify
```

### Verification

```bash
# Verify contracts on Basescan
forge verify-contract <CONTRACT_ADDRESS> src/core/QEUROToken.sol:QEUROToken --chain-id 8453 --etherscan-api-key $BASESCAN_API_KEY
```

## 📊 Protocol Parameters (as documented in contracts)

### QEURO Token
- **Decimals**: 18 (as documented in QEUROToken.sol)
- **Max Supply**: 100,000,000 QEURO (DEFAULT_MAX_SUPPLY constant)
- **Rate Limit**: 10,000,000 QEURO per hour (MAX_RATE_LIMIT constant)
- **Precision**: 1e18 (PRECISION constant)

### QTI Governance Token
- **Total Supply**: 100,000,000 QTI (TOTAL_SUPPLY_CAP constant)
- **Max Lock Time**: 4 years (MAX_LOCK_TIME constant)
- **Min Lock Time**: 7 days (MIN_LOCK_TIME constant)
- **Max Voting Power**: 4x multiplier (MAX_VE_QTI_MULTIPLIER constant)
- **Week Duration**: 7 days (WEEK constant)

### Fee Structure (as documented in contract initializations)
- **QEUROToken**: Rate limiting and compliance features
- **QuantillonVault**: Protocol fee and mint fee (configurable)
- **UserPool**: Deposit fee, withdrawal fee, performance fee (configurable)
- **HedgerPool**: Entry fee, exit fee, margin fee (configurable)
- **stQEUROToken**: Yield fee (configurable)

*Note: Specific fee percentages are configurable by governance and not hardcoded in contracts*

## 🔒 Security

### Security Features (as documented in contracts)

- **Role-Based Access Control**: Granular permissions for all critical operations
- **Reentrancy Protection**: All external calls protected against reentrancy attacks
- **Emergency Pause**: Ability to pause operations in crisis situations
- **Rate Limiting**: Prevents abuse and provides time for emergency response
- **Oracle Validation**: Price feed validation and precision checks
- **Upgradeable Architecture**: UUPS pattern for future improvements

### Security Contact

For security issues, please contact: `team@quantillon.money` (as documented in all contracts)

### Audit Status

*Note: Audit status information is not documented in the contracts and should be verified through official channels*

## 🤝 Contributing

We welcome contributions from the community! Please see our [Contributing Guidelines](./CONTRIBUTING.md) for details.

### Development Workflow

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Code Standards

- Follow Solidity style guide
- Add comprehensive tests for new features
- Update documentation for any changes
- Ensure all tests pass before submitting PR

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](./LICENSE) file for details.

## 🌐 Links

- **Website**: [quantillon.money](https://quantillon.money)
- **Documentation**: [docs.quantillon.money](https://docs.quantillon.money)
- **X (Twitter)**: [@QuantillonLabs](https://x.com/QuantillonLabs)
- **Discord**: [discord.gg/uk8T9GqdE5](https://discord.gg/uk8T9GqdE5)
- **Telegram**: [@QuantillonLabs](https://t.me/QuantillonLabs)

## 🙏 Acknowledgments

- OpenZeppelin for secure contract libraries
- Chainlink for reliable price feeds
- Foundry team for excellent development tools
- The broader DeFi community for inspiration and feedback

---

**Built with ❤️ by the Quantillon Labs team**
