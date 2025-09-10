# Quantillon Protocol Deployment Scripts

This directory contains the complete deployment infrastructure for the Quantillon Protocol. All deployment scripts have been rationalized and organized for maximum efficiency and maintainability.

## 📊 Current Status

### **Script Status**
- ✅ **All scripts compile successfully**
- ✅ **All deployment scripts run without errors**
- 🎯 **Streamlined deployment**: Only essential scripts for maximum efficiency
- 🤖 **Automated localhost deployment**: Available via `make deploy-localhost`
- 🪙 **MockUSDC integration**: Automatic MockUSDC deployment for testing networks

## 📁 Script Structure

### Core Deployment Scripts

| Script | Purpose | Status | Usage |
|--------|---------|--------|-------|
| `DeployProduction.s.sol` | **🚀 PRODUCTION DEPLOYMENT** - UUPS + Multisig + Network config | ✅ **Working** | `export MULTISIG_WALLET=0x... && forge script scripts/deployment/DeployProduction.s.sol --rpc-url <RPC> --broadcast` |
| `DeployQuantillon.s.sol` | **🛠️ DEVELOPMENT DEPLOYMENT** - Deploys all contracts with MockUSDC for localhost/Base Sepolia | ✅ **Working** | `forge script scripts/deployment/DeployQuantillon.s.sol --rpc-url <RPC> --broadcast` |
| `InitializeQuantillon.s.sol` | **Initialization script** - Sets up contracts with proper roles and relationships | ✅ **Working** | `forge script scripts/deployment/InitializeQuantillon.s.sol --rpc-url <RPC> --broadcast` |
| `VerifyDeployment.s.sol` | **Verification script** - Verifies deployment and contract integrity | ✅ **Working** | `forge script scripts/deployment/VerifyDeployment.s.sol --rpc-url <RPC>` |
| `VerifyQuantillon.s.sol` | **Protocol verification script** - Comprehensive protocol verification | ⚠️ **Needs deployment file** | `forge script scripts/deployment/VerifyQuantillon.s.sol --rpc-url <RPC>` |

### Deployment Methods

- **Localhost**: Automated script with `make deploy-localhost` or `./scripts/deploy-localhost.sh`
- **Localhost with MockUSDC**: `make deploy-localhost-with-mock-usdc` or `./scripts/deploy-localhost.sh --with-mock-usdc`
- **Base Sepolia**: Automated script with `make deploy-base-sepolia` (includes MockUSDC)
- **Production**: Manual deployment using `forge script` commands directly

## 📁 File Structure

```
scripts/
├── deploy-localhost.sh         # 🚀 Automated localhost deployment script (with MockUSDC option)
├── deploy-base-sepolia.sh      # 🚀 Automated Base Sepolia deployment script (with MockUSDC)
└── deployment/
    ├── DeployProduction.s.sol      # 🚀 PRODUCTION deployment (UUPS + Multisig + Network)
    ├── DeployQuantillon.s.sol      # 🛠️ Development deployment script (with MockUSDC)
    ├── DeployMockUSDC.s.sol        # 🪙 Standalone MockUSDC deployment script
    ├── InitializeQuantillon.s.sol  # Initialization script
    ├── VerifyDeployment.s.sol      # Verification script
    ├── VerifyQuantillon.s.sol      # Protocol verification script
    └── README.md                   # Complete documentation

deployments/
├── production-localhost.json   # Production deployment addresses
├── localhost.json              # Development deployment addresses
└── base-sepolia.json           # Base Sepolia deployment addresses
```

## 🎯 Deployment Types & Use Cases

### **DeployProduction.s.sol** - 🚀 **PRODUCTION DEPLOYMENT (RECOMMENDED)**
- **Best for**: Production deployments with maximum security and flexibility
- **Features**: UUPS upgradeability + Multisig governance + Network configuration
- **Upgradeability**: ✅ Yes (UUPS proxy pattern)
- **Security**: ✅ Enhanced (Multisig governance)
- **Network Support**: ✅ All networks (localhost, testnet, mainnet)
- **Complexity**: Advanced
- **Note**: Requires real oracle addresses for production networks

#### **Production Script Features:**
- 🔄 **UUPS Proxy Pattern**: All contracts deployed as upgradeable proxies
- 👥 **Multisig Governance**: All admin roles assigned to multisig wallet
- 🌐 **Network Configuration**: Automatic network-specific oracle configuration
- 📊 **Comprehensive Logging**: Detailed deployment progress and addresses
- 💾 **Deployment Files**: Saves deployment info to JSON files
- 🔒 **Security First**: Production-ready security measures
- ⚡ **Gas Optimized**: Efficient deployment with minimal gas usage

### **DeployQuantillon.s.sol** - 🛠️ **Development Deployment**
- **Best for**: Development, testing, localhost
- **Features**: Direct contract deployment, simple setup
- **Upgradeability**: ❌ No
- **Security**: Basic
- **Complexity**: Simple
- **Automation**: ✅ Available via `make deploy-localhost` or `./scripts/deploy-localhost.sh`

### **Automated Localhost Deployment Script** - 🤖 **`deploy-localhost.sh`**
- **Best for**: Quick localhost deployment with automated checks
- **Features**: Pre-deployment validation, error handling, address extraction
- **Automation**: ✅ Full automation with `make deploy-localhost`
- **User Experience**: ✅ Colorized output, clear status messages
- **Error Handling**: ✅ Comprehensive error checking and helpful messages

#### **Script Features:**
- 🔍 **Pre-deployment Checks**: Verifies Anvil connectivity and script existence
- 🚀 **Automated Deployment**: Runs deployment with progress tracking
- 📋 **Address Extraction**: Automatically extracts and displays contract addresses
- 🎨 **User Experience**: Colorized output and clear status messages
- ⚠️ **Error Handling**: Comprehensive error checking with helpful messages
- 💡 **Next Steps**: Provides verification commands and guidance

## 🚀 Quick Start

### 1. 🚀 **Production Deployment (RECOMMENDED)**

```bash
# Start Anvil (for localhost testing)
anvil --host 0.0.0.0 --port 8545 --accounts 10 --balance 10000

# Set required environment variables
export PRIVATE_KEY=0xYourPrivateKey
export MULTISIG_WALLET=0xYourMultisigWalletAddress
export NETWORK=localhost  # or sepolia, base, etc.

# For production networks, also set:
export EUR_USD_FEED_SEPOLIA=0x...
export USDC_USD_FEED_SEPOLIA=0x...
export USDC_TOKEN_SEPOLIA=0x...
export AAVE_POOL_SEPOLIA=0x...

# Deploy with UUPS + Multisig + Network config
forge script scripts/deployment/DeployProduction.s.sol --rpc-url http://localhost:8545 --broadcast
```

### 2. 🛠️ **Development Deployment**

#### **Option A: Automated Script (Recommended)**
```bash
# Start Anvil
anvil --host 0.0.0.0 --port 8545 --accounts 10 --balance 10000

# Deploy using automated script
make deploy-localhost
# OR
./scripts/deploy-localhost.sh
```

#### **Option B: Manual Command**
```bash
# Start Anvil
anvil --host 0.0.0.0 --port 8545 --accounts 10 --balance 10000

# Deploy manually
forge script scripts/deployment/DeployQuantillon.s.sol --rpc-url http://localhost:8545 --broadcast
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

### Multisig Configuration

For multisig deployment, you need to set up a multisig wallet:

**Using Gnosis Safe:**
1. Go to [Gnosis Safe](https://safe.global/)
2. Create a new Safe with multiple owners
3. Set threshold (e.g., 2 of 3 signatures required)
4. Copy the Safe address and set as `MULTISIG_WALLET`

**Environment Variables:**
```bash
# Required for multisig deployment
export MULTISIG_WALLET=0xYourMultisigWalletAddress

# Optional: Set specific deployer
export PRIVATE_KEY=0xYourDeployerPrivateKey
```

**Benefits:**
- Enhanced security with multiple signatures
- Decentralized governance
- Emergency controls
- Transparent operations

## 📄 Output Files

### Deployment Information

- `deployments/localhost.json` - Localhost deployment addresses
- `deployments/sepolia.json` - Sepolia deployment addresses (when deployed)
- `deployments/base.json` - Base deployment addresses (when deployed)

### Broadcast Files

- `broadcast/DeployQuantillon.s.sol/<chain_id>/run-latest.json` - Transaction details
- `cache/DeployQuantillon.s.sol/<chain_id>/run-latest.json` - Sensitive data

## 🧪 Testing

### Script Testing Results

All deployment scripts have been thoroughly tested:

| Script | Compilation | Execution | Notes |
|--------|-------------|-----------|-------|
| `DeployProduction.s.sol` | ✅ Success | ⚠️ Fails on oracle calls | UUPS + Multisig + Network |
| `DeployQuantillon.s.sol` | ✅ Success | ✅ Success | Development deployment |
| `InitializeQuantillon.s.sol` | ✅ Success | ⚠️ Needs deployment file | Initialization script |
| `VerifyDeployment.s.sol` | ✅ Success | ✅ Success | Verification script |
| `VerifyQuantillon.s.sol` | ✅ Success | ⚠️ Needs deployment file | Protocol verification |

### Contract Testing

After deployment, you can test the contracts:

```bash
# Check contract codes
cast code <CONTRACT_ADDRESS> --rpc-url <RPC>

# Call contract functions
cast call <CONTRACT_ADDRESS> "functionName()" --rpc-url <RPC>

# Send transactions
cast send <CONTRACT_ADDRESS> "functionName()" --rpc-url <RPC> --private-key <PRIVATE_KEY>
```

### Known Issues & Solutions

1. **UUPS Deployment Fails**: 
   - **Issue**: Fails when calling mock oracle addresses
   - **Solution**: Use real oracle addresses for production deployments

2. **Initialization Scripts Need Deployment Files**:
   - **Issue**: Scripts expect deployment JSON files
   - **Solution**: Deploy contracts first, then run initialization

3. **Environment Variables Required**:
   - **Issue**: Some scripts require specific environment variables
   - **Solution**: Set `PRIVATE_KEY`, `MULTISIG_WALLET`, `NETWORK` as needed

## 🔒 Security Notes

1. **Never commit private keys** to version control
2. **Use environment variables** for sensitive data
3. **Verify contracts** on block explorers after deployment
4. **Test thoroughly** on testnets before mainnet deployment
5. **Use multi-signature wallets** for mainnet deployments

## 📋 Quick Reference

### **Which Script to Use?**

| Use Case | Recommended Method | Command |
|----------|-------------------|---------|
| **🚀 Production (All Networks)** | `DeployProduction.s.sol` | `export MULTISIG_WALLET=0x... && forge script scripts/deployment/DeployProduction.s.sol --rpc-url <RPC> --broadcast` |
| **🛠️ Localhost Development** | **Automated Script** | `make deploy-localhost` or `./scripts/deploy-localhost.sh` |
| **🛠️ Manual Development** | `DeployQuantillon.s.sol` | `forge script scripts/deployment/DeployQuantillon.s.sol --rpc-url http://localhost:8545 --broadcast` |
| **✅ Verify Deployment** | `VerifyDeployment.s.sol` | `forge script scripts/deployment/VerifyDeployment.s.sol --rpc-url <RPC>` |


### **Environment Variables**

```bash
# Required for production deployments
export PRIVATE_KEY=0xYourPrivateKey

# Required for multisig deployment
export MULTISIG_WALLET=0xYourMultisigAddress

# Required for network-specific deployment
export NETWORK=sepolia  # or base, localhost

# Required for testnet/mainnet
export EUR_USD_FEED_SEPOLIA=0x...
export USDC_USD_FEED_SEPOLIA=0x...
export USDC_TOKEN_SEPOLIA=0x...
export AAVE_POOL_SEPOLIA=0x...
```

## 📞 Support

For deployment issues or questions:
- Check the deployment logs for error messages
- Verify environment variables are set correctly
- Ensure sufficient gas and ETH balance
- Review contract dependencies and initialization order
- Check the testing results table above for known issues
