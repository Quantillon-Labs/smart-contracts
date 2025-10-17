# Quantillon Protocol - Scripts Documentation

This directory contains all deployment and utility scripts for the Quantillon Protocol with enterprise-grade security using standard environment variables.

## 🔐 Security Overview

All scripts now use **standard environment variables** for maximum security:

- **🔒 AES-256 Encryption**: All secrets protected with strong cryptography
- **🔑 Separate Key Storage**: Decryption keys stored separately from encrypted files
- **🛡️ Safe to Commit**: Encrypted `.env` files can be safely committed to version control
- **👥 Team Collaboration**: Shared encrypted environment files with individual decryption keys

## 🚀 Deployment Scripts

### **Unified Deployment Script**

The new **`deploy.sh`** script provides a unified interface for all deployments:

```bash
./scripts/deployment/deploy.sh [environment] [options]
```

#### Supported Environments

| Environment | Description | Usage |
|-------------|-------------|-------|
| **localhost** | Local Anvil development | `./deploy.sh localhost --with-mocks` |
| **base-sepolia** | Base Sepolia testnet | `./deploy.sh base-sepolia --verify` |
| **base** | Base mainnet production | `./deploy.sh base --production --verify` |

#### Deployment Options

| Option | Description | Example |
|--------|-------------|---------|
| `--with-mocks` | Deploy mock contracts (localhost only) | `./deploy.sh localhost --with-mocks` |
| `--verify` | Verify contracts on block explorer | `./deploy.sh base-sepolia --verify` |
| `--production` | Use production deployment script | `./deploy.sh base --production` |
| `--dry-run` | Simulate deployment without broadcasting | `./deploy.sh localhost --dry-run` |

### Core Deployment Scripts

| Script | Purpose | Environment | Security |
|--------|---------|-------------|----------|
| **`deploy.sh`** | **🚀 UNIFIED DEPLOYMENT** - Universal deployment script | All networks | ✅ Encrypted |
| `DeployProduction.s.sol` | Production deployment with multisig governance | Mainnet/Testnet | ✅ Encrypted |
| `DeployQuantillon.s.sol` | Standard deployment for all environments | All networks | ✅ Encrypted |
| `DeployMockUSDC.s.sol` | Mock USDC token deployment | Localhost/Testnet | ✅ Encrypted |
| `DeployMockFeeds.s.sol` | Mock Chainlink price feeds | Localhost | ✅ Encrypted |
| `DeployOracleWithProxy.s.sol` | Oracle deployment with ERC1967 proxy | All networks | ✅ Encrypted |
| `InitializeQuantillon.s.sol` | Contract initialization and role setup | All networks | ✅ Encrypted |

## 🛠️ Utility Scripts

### ABI Management

| Script | Purpose | Description |
|--------|---------|-------------|
| `copy-abis.sh` | ABI copying | Copies contract ABIs to frontend after deployment (supports `--phased`) |
| `update-frontend-addresses.sh` | Address updates | Updates frontend with deployed contract addresses (supports `--phased`) |

### Usage Examples

```bash
# Copy ABIs to frontend (phased)
./scripts/deployment/copy-abis.sh localhost --phased

# Update frontend addresses (phased)
./scripts/deployment/update-frontend-addresses.sh localhost --phased
```

## 🔐 Environment Setup

### 1. Initial Setup

```bash
# Copy environment template
cp .env.example .env

# Fill in your values (API keys, private keys, etc.)
# Edit .env with your actual configuration

# Encrypt environment variables
# Environment variables are ready to use
```

### 2. Environment Files

```
.env                 # Encrypted environment variables (safe to commit)
.env.example        # Template for new developers
.env.backup         # Backup of original environment file
```

### 3. Security Validation

```bash
# Test environment decryption
echo "PRIVATE_KEY: $PRIVATE_KEY"

# If this fails, check your environment file
```

## 📋 Quick Start Guide

### Local Development

```bash
# 1. Start Anvil
anvil --host 0.0.0.0 --port 8545 --accounts 10 --balance 10000

# 2. Deploy with mock contracts
./scripts/deployment/deploy.sh localhost --with-mocks

# 3. Test your changes
forge test
```

### Testnet Deployment

```bash
# Deploy to Base Sepolia with verification
./scripts/deployment/deploy.sh base-sepolia --verify
```

### Production Deployment

```bash
# Deploy to Base mainnet with production settings
./scripts/deployment/deploy.sh base --production --verify
```

## 🔧 Development Workflow

### 1. Environment Configuration

```bash
# Set up encrypted environment
cp .env.example .env
# Edit .env with your values
# Environment variables are ready to use
```

### 2. Local Development

```bash
# Deploy to localhost
./scripts/deployment/deploy.sh localhost --with-mocks

# Run tests
forge test

# Make changes to contracts
# Redeploy as needed
```

### 3. Testnet Testing

```bash
# Deploy to testnet
./scripts/deployment/deploy.sh base-sepolia --verify

# Test on testnet
# Verify contracts on block explorer
```

### 4. Production Deployment

```bash
# Deploy to mainnet
./scripts/deployment/deploy.sh base --production --verify

# Monitor deployment
# Update frontend with new addresses
```

## 🛡️ Security Best Practices

### Environment Variables

- **Never commit `.env` files** - they're in .gitignore for security
- **Each developer needs their own environment files**
- **The encrypted `.env` file can be safely shared** with the team
- **For production, use secure key management** (AWS Secrets Manager, etc.)

### Deployment Security

- **Always use encrypted environment variables**
- **Test on testnet before mainnet**
- **Use dry-run for testing**: `./deploy.sh localhost --dry-run`
- **Verify contracts on block explorer**
- **Monitor deployments carefully**

## 🔍 Troubleshooting

### Common Issues

#### Missing environment file
```bash
# Error: .env.keys file not found
# Solution: Ensure you have the decryption key
# Environment variables are ready to use
```

#### Environment variables not loading
```bash
# Test decryption
echo "PRIVATE_KEY: $PRIVATE_KEY"
```

#### Network connection issues
```bash
# Test network connectivity
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  https://sepolia.base.org
```

### Getting Help

```bash
# Show help for deployment script
./scripts/deployment/deploy.sh --help

# Test environment setup
forge script DeployQuantillon.s.sol --dry-run
```

## 📚 Additional Resources

- **[Deployment Guide](deployment/README.md)** - Detailed deployment instructions
- **[Secure Deployment Guide](../SECURE_DEPLOYMENT.md)** - Security implementation details
- **[Main README](../README.md)** - Complete project overview
- **Standard .env files** - Environment variable management

## 🤝 Contributing

When contributing to scripts:

1. **Test with dry-run first**: `./deploy.sh localhost --dry-run`
2. **Use encrypted environment variables**: Never commit plain text secrets
3. **Update documentation**: Keep this README current
4. **Follow security best practices**: Use the unified deployment script
5. **Test on testnet**: Always test on Base Sepolia before mainnet

## 🚨 Security Notes

1. **Environment variables are secure by default** - use standard .env files for all deployments
2. **Never commit environment files** - `.env` files are in .gitignore
3. **Test deployments with dry-run** before broadcasting
4. **Verify contracts on block explorer** for transparency
5. **Use secure key management** for production deployments
