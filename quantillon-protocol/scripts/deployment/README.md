# Quantillon Protocol - Secure Deployment Guide

This directory contains the unified deployment infrastructure for the Quantillon Protocol with enterprise-grade security using standard environment variables.

## 🔐 Security Features

- **Environment Variables**: Use standard `.env` files (never commit them)
- **Secret Management**: Use a secret manager for production (e.g., AWS Secrets Manager)
- **Team Collaboration**: Share values securely via organizational tooling

## 🚀 Unified Deployment Script

### **`deploy.sh` - Universal Deployment Script**

The new unified deployment script handles all environments with built-in security:

```bash
./scripts/deployment/deploy.sh [environment] [options]
```

### 📋 Supported Environments

| Environment | Description | RPC URL | Chain ID |
|-------------|-------------|---------|----------|
| **localhost** | Local Anvil development | `http://localhost:8545` | `31337` |
| **base-sepolia** | Base Sepolia testnet | `https://sepolia.base.org` | `84532` |
| **base** | Base mainnet production | `https://mainnet.base.org` | `8453` |
| **ethereum-sepolia** | Ethereum Sepolia testnet | `https://ethereum-sepolia-rpc.publicnode.com` | `11155111` |
| **ethereum** | Ethereum mainnet production | `https://ethereum-rpc.publicnode.com` | `1` |

### 🔧 Deployment Options

| Option | Description | Example |
|--------|-------------|---------|
| `--with-mocks` | Deploy all mock contracts (MockUSDC + Mock Oracle feeds) | `./deploy.sh localhost --with-mocks` |
| `--with-mock-usdc` | Deploy MockUSDC contract but use real Chainlink feeds | `./deploy.sh localhost --with-mock-usdc` |
| `--with-mock-oracle` | Deploy Mock Oracle feeds but use real USDC | `./deploy.sh localhost --with-mock-oracle` |
| *(no mock flags)* | Use real USDC and real Chainlink feeds (no mocks) | `./deploy.sh localhost` |
| `--verify` | Verify contracts on block explorer (testnet & mainnet) | `./deploy.sh base-sepolia --verify` |
| `--dry-run` | Simulate deployment without broadcasting | `./deploy.sh localhost --dry-run` |
| `--clean-cache` | Force full recompilation by cleaning cache (slower) | `./deploy.sh localhost --clean-cache` |
| `--help` | Show help message | `./deploy.sh --help` |

**Note:** All deployments use multi-phase atomic deployment (A→B→C→D) automatically. There is no flag to enable/disable this.

### 🎭 Granular Mock Control

The deployment script supports granular control over which contracts are mocked:

- **`--with-mocks`**: Deploys both MockUSDC and Mock Oracle feeds (equivalent to `--with-mock-usdc --with-mock-oracle`)
- **`--with-mock-usdc`**: Only mocks the USDC token contract; uses real Chainlink price feeds from the forked network
- **`--with-mock-oracle`**: Only mocks the Chainlink Oracle feeds; uses real USDC from the forked network
- **No flags**: Uses real USDC and real Chainlink feeds (production-like setup)

**Use Cases:**
- `--with-mock-usdc`: Test with real price feeds but control USDC supply
- `--with-mock-oracle`: Test with real USDC but control price feed values
- `--with-mocks`: Full mock setup for isolated testing
- No flags: Production-like testing with real contracts from the forked network

### ⚡ Compilation Cache

The deployment script **preserves the Foundry compilation cache by default** for faster deployments. This means:

- **Faster deployments**: Contracts are only recompiled if source code changed
- **Cache preserved**: The `cache/` folder is kept between deployments
- **Force recompilation**: Use `--clean-cache` when you need a full rebuild (e.g., after dependency updates or compiler changes)

**When to use `--clean-cache`:**
- After updating dependencies (OpenZeppelin, Chainlink, etc.)
- After changing compiler settings in `foundry.toml`
- When experiencing compilation issues that might be cache-related
- For production deployments where you want a clean build

### 🔄 Multi-Phase Deployment

All deployments automatically use a 4-phase atomic deployment (A→B→C→D) to stay within the 24.9M gas limit per transaction. Each phase is optimized to fit comfortably under the limit with safety margins.

#### Phase Structure

| Phase | Gas Used | Contracts Deployed | Purpose |
|-------|----------|-------------------|---------|
| **Phase A** | ~17M | TimeProvider, ChainlinkOracle, QEUROToken, FeeCollector, QuantillonVault | Core infrastructure & vault |
| **Phase B** | ~16M | QTIToken, AaveVault, stQEUROToken | Token layer & yield integration |
| **Phase C** | ~11M | UserPool, HedgerPool | Pool layer for users & hedgers |
| **Phase D** | ~7M | YieldShift + wiring | Yield management & integrations |

#### How It Works

1. **Automatic Phase Execution**: Running `./deploy.sh` automatically executes all 4 phases in sequence (no flag needed)
2. **Address Passing**: Deployed contract addresses are automatically extracted and passed between phases via environment variables
3. **Minimal Initialization**: Contract `initialize()` functions are kept minimal; complex wiring happens in separate transactions
4. **Governance Setters**: Contracts include governance-only setters (`updateOracle`, `updateYieldShift`, etc.) for post-deployment wiring
5. **Broadcast Merging**: The frontend address updater (`update-frontend-addresses.sh`) automatically merges all 4 phase broadcasts

#### Key Features for Gas Optimization

- **24.9M gas cap enforced** on all environments (including localhost) to prevent surprises on testnet
- **Minimal initializers**: Optional parameters (like `yieldShift`) can be zero during init and set later via governance setters
- **Separate wiring transactions**: Role grants, vault pool updates, and fee source authorizations happen in atomic Phase D transactions
- **Contract splitting**: Heavy contracts like `YieldShift` remain intact but deploy in isolated phases

#### Why Not Split Further?

All phases are well under the limit with 8-13M gas headroom. Splitting to 1-contract-per-script would:
- Require 12+ separate script runs (very slow on testnets)
- Add complexity in address passing between many scripts
- Provide no additional safety benefit

Current structure balances **speed, safety, and maintainability**.

#### Contract Modifications for Phased Deployment

To support minimal initialization and post-deployment wiring, the following governance-only setters were added:

**UserPool:**
- `updateYieldShift(address)` - Set YieldShift address after Phase D deployment

**HedgerPool:**
- `updateOracle(address)` - Set Oracle address post-deployment
- `updateYieldShift(address)` - Set YieldShift address after Phase D deployment

**YieldShift:**
- `updateUserPool(address)` - Wire UserPool after Phase C
- `updateHedgerPool(address)` - Wire HedgerPool after Phase C  
- `updateAaveVault(address)` - Wire AaveVault after Phase B
- `updateStQEURO(address)` - Wire stQEURO after Phase B

These setters allow contracts to be deployed with minimal initialization (only critical addresses), then wired together in separate atomic transactions during Phase D.

## 🎯 Quick Start (per-network env files)

### 1. Environment Setup (per network)

```bash
# Localhost (recommended: use per-network file directly)
cp .env.example .env.localhost && edit .env.localhost

# Base Sepolia
cp .env.example .env.base-sepolia && edit .env.base-sepolia

# Base mainnet
cp .env.example .env.base && edit .env.base
```

### 2. Deploy to Localhost

```bash
# Start Anvil (forking Base mainnet for real contracts)
anvil --host 0.0.0.0 --port 8545 --fork-url https://mainnet.base.org --chain-id 31337 --accounts 10 --balance 10000

# Deploy with all mock contracts (uses cache for faster compilation)
./scripts/deployment/deploy.sh localhost --with-mocks

# Deploy with MockUSDC but real Chainlink feeds
./scripts/deployment/deploy.sh localhost --with-mock-usdc

# Deploy with Mock Oracle feeds but real USDC
./scripts/deployment/deploy.sh localhost --with-mock-oracle

# Deploy with no mocks (real USDC + real Chainlink feeds)
./scripts/deployment/deploy.sh localhost

# Force full recompilation (if needed)
./scripts/deployment/deploy.sh localhost --with-mocks --clean-cache
```

### 3. Deploy to Testnet

```bash
# Deploy to Base Sepolia with verification
./scripts/deployment/deploy.sh base-sepolia --verify

# Deploy to Ethereum Sepolia with mocks and verification
./scripts/deployment/deploy.sh ethereum-sepolia --with-mocks --verify
```

### 4. Deploy to Production

```bash
# Deploy to Base mainnet with verification
./scripts/deployment/deploy.sh base --verify

# Deploy to Ethereum mainnet with verification
./scripts/deployment/deploy.sh ethereum --verify
```

## 📁 Script Structure

### Core Deployment Scripts

| Script | Purpose | Environment | Security |
|--------|---------|-------------|----------|
| **`deploy.sh`** | **🚀 UNIFIED DEPLOYMENT** - Orchestrates multi-phase deployment | All networks | ✅ Encrypted |
| `DeployMockUSDC.s.sol` | Mock USDC deployment | Localhost/Testnet | ✅ Encrypted |
| `DeployMockFeeds.s.sol` | Mock price feeds deployment | Localhost/Testnet | ✅ Encrypted |

### Phase Scripts (A→B→C→D)

| Script | Phase | Contracts | Gas | Notes |
|--------|-------|-----------|-----|-------|
| `DeployQuantillonPhaseA.s.sol` | A | TimeProvider, Oracle, QEURO, FeeCollector, Vault | ~17M | Core infrastructure |
| `DeployQuantillonPhaseB.s.sol` | B | QTI, AaveVault, stQEURO | ~16M | Token layer |
| `DeployQuantillonPhaseC.s.sol` | C | UserPool, HedgerPool | ~11M | Pool layer |
| `DeployQuantillonPhaseD.s.sol` | D | YieldShift + wiring | ~7M | Yield & integrations |

### Utility Scripts

| Script | Purpose | Description |
|--------|---------|-------------|
| `copy-abis.sh` | ABI copying | Copies contract ABIs to frontend (supports `--phased`) |
| `update-frontend-addresses.sh` | Address updates | Merges addresses from all phase broadcasts and updates frontend `addresses.json` |

## 🔐 Security Implementation

### Environment Variables (per network)

The protocol uses standard environment variables:

```bash
# Use per-network files directly (no encryption)
# .env.localhost, .env.base-sepolia, .env.base
```

### File Structure

```
.env.localhost     # Environment file for localhost (DO NOT commit)
.env.base-sepolia  # Environment file for Base Sepolia (DO NOT commit)
.env.base          # Environment file for Base mainnet (DO NOT commit)
.env.example       # Template
```

### Security Benefits

- **Standard Environment Variables**: Use `.env` files for local development
- **Secret Management**: Use a secret manager for production (AWS Secrets Manager, etc.)
- **Never Commit Secrets**: Keep `.env` files out of version control
- **Team Collaboration**: Share secrets securely via organizational tooling

## 🛠️ Development Workflow

### Local Development

```bash
# 1. Start Anvil
anvil --host 0.0.0.0 --port 8545 --accounts 10 --balance 10000

# 2. Deploy with mocks
./scripts/deployment/deploy.sh localhost --with-mocks

# 3. Test your changes
forge test

# 4. Deploy to testnet
./scripts/deployment/deploy.sh base-sepolia --verify
```

### Team Collaboration

```bash
# 1. Do NOT commit `.env*` files
# 2. Share secrets via your organization's secret manager
# 3. Each developer maintains their own `.env.<network>` files
```

## 📊 Deployment Examples

### Localhost Development

```bash
# Basic localhost deployment - no mocks (real USDC + real Chainlink feeds)
./scripts/deployment/deploy.sh localhost

# With all mock contracts (MockUSDC + Mock Oracle feeds)
./scripts/deployment/deploy.sh localhost --with-mocks

# With MockUSDC only (real Chainlink feeds)
./scripts/deployment/deploy.sh localhost --with-mock-usdc

# With Mock Oracle feeds only (real USDC)
./scripts/deployment/deploy.sh localhost --with-mock-oracle

# Dry run (test without broadcasting)
./scripts/deployment/deploy.sh localhost --dry-run

# Force full recompilation (after dependency updates, etc.)
./scripts/deployment/deploy.sh localhost --with-mocks --clean-cache
```

### Testnet Deployment

```bash
# Deploy to Base Sepolia
./scripts/deployment/deploy.sh base-sepolia --verify

# Deploy to Ethereum Sepolia with mocks
./scripts/deployment/deploy.sh ethereum-sepolia --with-mocks --verify
```

### Production Deployment

```bash
# Deploy to Base mainnet (recommended: use --clean-cache for production)
./scripts/deployment/deploy.sh base --verify --clean-cache

# Deploy to Ethereum mainnet (recommended: use --clean-cache for production)
./scripts/deployment/deploy.sh ethereum --verify --clean-cache

# Ensure you have:
# - MULTISIG_WALLET set in .env (if applicable)
# - All network-specific variables configured
# - Proper private key with sufficient ETH
# - Consider using --clean-cache for a clean build
```

## 🔧 Troubleshooting

### Common Issues

#### Missing environment file
```bash
# Error: .env file not found
# Solution: Copy the appropriate network environment file
cp .env.localhost .env
```

#### Environment variables not loading
```bash
# Print variables to verify
set -o allexport; source .env.localhost; set +o allexport; env | grep -E 'PRIVATE_KEY|RPC_URL'
```

#### Network connection issues
```bash
# Test network connectivity
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  https://sepolia.base.org
```

### Helper scripts env usage
Both helper scripts honor the same env file passed by `deploy.sh`:

- `copy-abis.sh` is executed as `ENV_FILE=".env.<env>" ./scripts/deployment/copy-abis.sh <environment> [--phased]`
- `update-frontend-addresses.sh` is executed as `ENV_FILE=".env.<env>" ./scripts/deployment/update-frontend-addresses.sh <environment> [--phased]`

When `--phased` (or `PHASED=true`) is set, address extraction reads broadcast files under `broadcast/DeployQuantillonPhased.s.sol/...`; otherwise it reads `broadcast/DeployQuantillon.s.sol/...`.

They will load variables directly from the specified environment file.

### Getting Help

```bash
# Show help for deployment script
./scripts/deployment/deploy.sh --help

# Test environment setup
forge script DeployQuantillon.s.sol --dry-run
```

## 📚 Additional Resources

- **[Main README](../README.md)** - Complete project overview
- **[Secure Deployment Guide](../SECURE_DEPLOYMENT.md)** - Detailed security implementation
- **[API Documentation](../docs/API.md)** - Contract API reference
- **Standard .env files** - Environment variable management

## 🚨 Security Notes

1. **Never commit `.env` files** - they're in .gitignore for security
2. **Each developer needs their own environment files**
3. **For production, use secure key management** (AWS Secrets Manager, etc.)
4. **Rotate keys regularly** for enhanced security

## 🤝 Contributing

When contributing to deployment scripts:

1. **Test with dry-run first**: `./deploy.sh localhost --dry-run`
2. **Protect secrets**: Never commit plain text secrets
3. **Update documentation**: Keep this README current
4. **Follow security best practices**: Use the unified deployment script
5. **Test on testnet**: Always test on Base Sepolia before mainnet
