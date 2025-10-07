# Quantillon Protocol - Secure Deployment Guide

This directory contains the unified deployment infrastructure for the Quantillon Protocol with enterprise-grade security using [Dotenvx](https://dotenvx.com/) encryption.

## 🔐 Security Features

- **🔒 Encrypted Environment Variables**: All secrets protected with AES-256 encryption
- **🔑 Separate Key Storage**: Decryption keys stored separately from encrypted files
- **🛡️ Safe to Commit**: Encrypted `.env` files can be safely committed to version control
- **👥 Team Collaboration**: Shared encrypted environment files with individual decryption keys

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

### 🔧 Deployment Options

| Option | Description | Example |
|--------|-------------|---------|
| `--with-mocks` | Deploy mock contracts (localhost only) | `./deploy.sh localhost --with-mocks` |
| `--verify` | Verify contracts on block explorer | `./deploy.sh base-sepolia --verify` |
| `--production` | Use production deployment script | `./deploy.sh base --production` |
| `--dry-run` | Simulate deployment without broadcasting | `./deploy.sh localhost --dry-run` |
| `--phased` | Use phased/atomic deployment (default on) | `./deploy.sh localhost --phased` |
| `--help` | Show help message | `./deploy.sh --help` |

### 🔄 Multi-Phase Deployment

The default phased deployment splits the process into 4 atomic phases (A→B→C→D) to stay within the 24.9M gas limit per transaction on Base Sepolia/Mainnet. Each phase is optimized to fit comfortably under the limit with safety margins.

#### Phase Structure

| Phase | Gas Used | Contracts Deployed | Purpose |
|-------|----------|-------------------|---------|
| **Phase A** | ~17M | TimeProvider, ChainlinkOracle, QEUROToken, FeeCollector, QuantillonVault | Core infrastructure & vault |
| **Phase B** | ~16M | QTIToken, AaveVault, stQEUROToken | Token layer & yield integration |
| **Phase C** | ~11M | UserPool, HedgerPool | Pool layer for users & hedgers |
| **Phase D** | ~7M | YieldShift + wiring | Yield management & integrations |

#### How It Works

1. **Automatic Phase Execution**: Running `./deploy.sh` automatically executes all 4 phases in sequence
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

## 🎯 Quick Start (per-network encrypted env files)

### 1. Environment Setup (per network)

```bash
# Localhost
cp .env.localhost.unencrypted .env.localhost.unencrypted  # ensure it exists and fill values
npx dotenvx encrypt -f .env.localhost.unencrypted --stdout > .env.localhost

# Base Sepolia
cp .env.base-sepolia.unencrypted .env.base-sepolia.unencrypted  # ensure it exists and fill values
npx dotenvx encrypt -f .env.base-sepolia.unencrypted --stdout > .env.base-sepolia

# Base mainnet
cp .env.base.unencrypted .env.base.unencrypted  # ensure it exists and fill values
npx dotenvx encrypt -f .env.base.unencrypted --stdout > .env.base
```

### 2. Deploy to Localhost

```bash
# Start Anvil
anvil --host 0.0.0.0 --port 8545 --accounts 10 --balance 10000

# Deploy with mock contracts
./scripts/deployment/deploy.sh localhost --with-mocks
```

### 3. Deploy to Testnet

```bash
# Deploy to Base Sepolia with verification
./scripts/deployment/deploy.sh base-sepolia --verify
```

### 4. Deploy to Production

```bash
# Deploy to Base mainnet with production settings
./scripts/deployment/deploy.sh base --production --verify
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

### Environment Variable Encryption (per network)

The protocol uses [Dotenvx](https://dotenvx.com/) for enterprise-grade security:

```bash
# Encrypt localhost env → writes encrypted content to stdout, redirect to .env.localhost
npx dotenvx encrypt -f .env.localhost.unencrypted --stdout > .env.localhost

# Encrypt Base Sepolia env
npx dotenvx encrypt -f .env.base-sepolia.unencrypted --stdout > .env.base-sepolia

# Encrypt Base mainnet env
npx dotenvx encrypt -f .env.base.unencrypted --stdout > .env.base

# Decryption keys live in .env.keys (NEVER commit)
```

### File Structure

```
.env.localhost                 # Encrypted env for localhost (safe to commit)
.env.base-sepolia              # Encrypted env for Base Sepolia (safe to commit)
.env.base                      # Encrypted env for Base mainnet (safe to commit)
.env.localhost.unencrypted     # Unencrypted source for localhost (DO NOT commit)
.env.base-sepolia.unencrypted  # Unencrypted source for Base Sepolia (DO NOT commit)
.env.base.unencrypted          # Unencrypted source for Base mainnet (DO NOT commit)
.env.keys                      # Private decryption key (NEVER commit - in .gitignore)
```

### Security Benefits

- **AES-256 Encryption**: Each secret encrypted with unique ephemeral key
- **Elliptic Curve Cryptography**: Secp256k1 for key management (same as Bitcoin)
- **Separate Key Storage**: Encrypted file and decryption key stored separately
- **Computationally Infeasible**: Breaking encryption requires brute-forcing both AES-256 and ECC

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
# 1. Share encrypted per-network env files (safe to commit)
git add .env.localhost .env.base-sepolia .env.base
git commit -m "Update encrypted env files"

# 2. Each developer needs their own .env.keys file (never commit)

# 3. Use a specific env file when running commands
npx dotenvx run --env-file=.env.localhost -- forge script scripts/deployment/DeployQuantillon.s.sol --rpc-url http://localhost:8545
```

## 📊 Deployment Examples

### Localhost Development

```bash
# Basic localhost deployment
./scripts/deployment/deploy.sh localhost

# With mock contracts
./scripts/deployment/deploy.sh localhost --with-mocks

# Dry run (test without broadcasting)
./scripts/deployment/deploy.sh localhost --dry-run
```

### Testnet Deployment

```bash
# Deploy to Base Sepolia
./scripts/deployment/deploy.sh base-sepolia --verify

# With production script
./scripts/deployment/deploy.sh base-sepolia --production --verify
```

### Production Deployment

```bash
# Deploy to Base mainnet
./scripts/deployment/deploy.sh base --production --verify

# Ensure you have:
# - MULTISIG_WALLET set in .env
# - All network-specific variables configured
# - Proper private key with sufficient ETH
```

## 🔧 Troubleshooting

### Common Issues

#### Missing .env.keys file
```bash
# Error: .env.keys file not found
# Solution: Ensure you have the decryption key
# Get it from another team member or re-encrypt a per-network file
npx dotenvx encrypt -f .env.localhost.unencrypted --stdout > .env.localhost
```

#### Environment variables not loading
```bash
# Test decryption
npx dotenvx run -- echo "PRIVATE_KEY: $PRIVATE_KEY"

# If this fails, check your .env.keys file
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

They will re-exec under `dotenvx` with `--env-file=$ENV_FILE` and load variables from that file.

### Getting Help

```bash
# Show help for deployment script
./scripts/deployment/deploy.sh --help

# Test environment setup
npx dotenvx run -- forge script DeployQuantillon.s.sol --dry-run
```

## 📚 Additional Resources

- **[Main README](../README.md)** - Complete project overview
- **[Secure Deployment Guide](../SECURE_DEPLOYMENT.md)** - Detailed security implementation
- **[API Documentation](../docs/API.md)** - Contract API reference
- **[Dotenvx Documentation](https://dotenvx.com/)** - Environment variable encryption

## 🚨 Security Notes

1. **Never commit `.env.keys`** - it's in .gitignore for security
2. **Each developer needs their own `.env.keys`** file
3. **The encrypted `.env` file can be safely shared** with the team
4. **For production, use secure key management** (AWS Secrets Manager, etc.)
5. **Rotate keys regularly** for enhanced security

## 🤝 Contributing

When contributing to deployment scripts:

1. **Test with dry-run first**: `./deploy.sh localhost --dry-run`
2. **Use encrypted environment variables**: Never commit plain text secrets
3. **Update documentation**: Keep this README current
4. **Follow security best practices**: Use the unified deployment script
5. **Test on testnet**: Always test on Base Sepolia before mainnet
