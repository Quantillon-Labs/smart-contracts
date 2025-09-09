# Quantillon Protocol Deployment Scripts

This directory contains the complete deployment infrastructure for the Quantillon Protocol. All deployment scripts have been rationalized and organized for maximum efficiency and maintainability.

## 📁 Script Structure

### Core Deployment Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| `DeployQuantillon.s.sol` | **Main deployment script** - Deploys all contracts in correct order | `forge script scripts/deployment/DeployQuantillon.s.sol --rpc-url <RPC> --broadcast` |
| `InitializeQuantillon.s.sol` | **Initialization script** - Sets up contracts with proper roles and relationships | `forge script scripts/deployment/InitializeQuantillon.s.sol --rpc-url <RPC> --broadcast` |
| `VerifyDeployment.s.sol` | **Verification script** - Verifies deployment and contract integrity | `forge script scripts/deployment/VerifyDeployment.s.sol --rpc-url <RPC>` |
| `DeployNetwork.s.sol` | **Network-specific deployment** - Supports different networks with proper configuration | `NETWORK=sepolia forge script scripts/deployment/DeployNetwork.s.sol --rpc-url <RPC> --broadcast` |

### Makefile Integration

The deployment scripts are integrated with the project Makefile for easy execution:

| Makefile Target | Description | Command |
|-----------------|-------------|---------|
| `make deploy-localhost` | Deploy to localhost (Anvil) | `make deploy-localhost` |
| `make deploy-sepolia` | Deploy to Sepolia testnet | `make deploy-sepolia` |
| `make deploy-base` | Deploy to Base mainnet | `make deploy-base` |
| `make deploy-partial` | Deploy contracts only | `make deploy-partial` |
| `make deploy-full` | Full deployment + initialization | `make deploy-full` |
| `make deploy-verify` | Verify deployed contracts | `make deploy-verify` |

## 📁 File Structure

```
scripts/deployment/
├── DeployQuantillon.s.sol      # Main deployment script
├── InitializeQuantillon.s.sol  # Initialization script
├── VerifyDeployment.s.sol      # Verification script
├── DeployNetwork.s.sol         # Network-specific deployment
├── README.md                   # Complete documentation
└── DEPLOYMENT_SUMMARY.md       # Deployment status and addresses

deployments/
└── localhost.json              # Deployment addresses
```

## 🚀 Quick Start

### 1. Deploy to Localhost

```bash
# Start Anvil
anvil --host 0.0.0.0 --port 8545 --accounts 10 --balance 10000

# Deploy all contracts
make deploy-full
```

### 2. Deploy to Testnet

```bash
# Set environment variables
export PRIVATE_KEY=your_private_key
export NETWORK=sepolia
export EUR_USD_FEED_SEPOLIA=0x...
export USDC_USD_FEED_SEPOLIA=0x...
export USDC_TOKEN_SEPOLIA=0x...
export AAVE_POOL_SEPOLIA=0x...

# Deploy
make deploy-sepolia
```

## 📋 Deployment Order

The deployment follows a specific order to handle dependencies:

### Phase 1: Core Infrastructure
1. **TimeProvider** - Time management library
2. **ChainlinkOracle** - Price feed oracle
3. **QEUROToken** - Euro-pegged stablecoin

### Phase 2: Core Protocol
4. **QTIToken** - Governance token
5. **QuantillonVault** - Main vault contract

### Phase 3: Pool Contracts
6. **UserPool** - User deposit pool
7. **HedgerPool** - Hedger pool
8. **stQEUROToken** - Staked QEURO token

### Phase 4: Yield Management
9. **AaveVault** - Aave integration vault
10. **YieldShift** - Yield distribution manager

## 🔧 Configuration

### Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `PRIVATE_KEY` | Deployer private key | Yes |
| `NETWORK` | Target network (localhost, sepolia, base) | No (defaults to localhost) |
| `EUR_USD_FEED_<NETWORK>` | Chainlink EUR/USD price feed | For testnet/mainnet |
| `USDC_USD_FEED_<NETWORK>` | Chainlink USDC/USD price feed | For testnet/mainnet |
| `USDC_TOKEN_<NETWORK>` | USDC token address | For testnet/mainnet |
| `AAVE_POOL_<NETWORK>` | Aave pool address | For testnet/mainnet |

### Mock Addresses (Localhost)

For localhost deployment, the following mock addresses are used:

- EUR/USD Feed: `0x1234567890123456789012345678901234567890`
- USDC/USD Feed: `0x2345678901234567890123456789012345678901`
- USDC Token: `0x3456789012345678901234567890123456789012`
- Aave Pool: `0x4567890123456789012345678901234567890123`

## 📄 Output Files

### Deployment Information

- `deployments/localhost.json` - Localhost deployment addresses
- `deployments/sepolia.json` - Sepolia deployment addresses (when deployed)
- `deployments/base.json` - Base deployment addresses (when deployed)

### Broadcast Files

- `broadcast/DeployQuantillon.s.sol/<chain_id>/run-latest.json` - Transaction details
- `cache/DeployQuantillon.s.sol/<chain_id>/run-latest.json` - Sensitive data

## 🧪 Testing

After deployment, you can test the contracts:

```bash
# Check contract codes
cast code <CONTRACT_ADDRESS> --rpc-url <RPC>

# Call contract functions
cast call <CONTRACT_ADDRESS> "functionName()" --rpc-url <RPC>

# Send transactions
cast send <CONTRACT_ADDRESS> "functionName()" --rpc-url <RPC> --private-key <PRIVATE_KEY>
```

## 🔒 Security Notes

1. **Never commit private keys** to version control
2. **Use environment variables** for sensitive data
3. **Verify contracts** on block explorers after deployment
4. **Test thoroughly** on testnets before mainnet deployment
5. **Use multi-signature wallets** for mainnet deployments

## 📞 Support

For deployment issues or questions:
- Check the deployment logs for error messages
- Verify environment variables are set correctly
- Ensure sufficient gas and ETH balance
- Review contract dependencies and initialization order
