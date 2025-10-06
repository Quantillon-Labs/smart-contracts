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
| `--help` | Show help message | `./deploy.sh --help` |

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
| **`deploy.sh`** | **🚀 UNIFIED DEPLOYMENT** - Universal deployment script | All networks | ✅ Encrypted |
| `DeployProduction.s.sol` | Production deployment with multisig | Mainnet/Testnet | ✅ Encrypted |
| `DeployQuantillon.s.sol` | Standard deployment | All networks | ✅ Encrypted |
| `DeployMockUSDC.s.sol` | Mock USDC deployment | Localhost/Testnet | ✅ Encrypted |
| `DeployMockFeeds.s.sol` | Mock price feeds deployment | Localhost | ✅ Encrypted |

### Utility Scripts

| Script | Purpose | Description |
|--------|---------|-------------|
| `copy-abis.sh` | ABI copying | Copies contract ABIs to frontend |
| `update-frontend-addresses.sh` | Address updates | Updates frontend with deployed addresses |

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

- `copy-abis.sh` is executed as `ENV_FILE=".env.<env>" ./scripts/deployment/copy-abis.sh <environment>`
- `update-frontend-addresses.sh` is executed as `ENV_FILE=".env.<env>" ./scripts/deployment/update-frontend-addresses.sh <environment>`

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
