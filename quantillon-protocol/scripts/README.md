# Smart Contract Deployment Scripts

This directory contains deployment scripts for the Quantillon Protocol smart contracts.

## Deployment Scripts

- `DeployQuantillon.s.sol` - Main deployment script for development and testing (includes MockUSDC for localhost/Base Sepolia)
- `DeployProduction.s.sol` - Production deployment script with UUPS proxies and multisig governance
- `DeployMockUSDC.s.sol` - Standalone MockUSDC deployment script
- `DeployOracleWithProxy.s.sol` - Oracle deployment with ERC1967 proxy
- `DeployMockFeeds.s.sol` - Mock Chainlink price feeds for testing

## ABI Management

The deployment scripts automatically copy contract ABIs to the frontend after deployment:

### Automatic ABI Copying

When you run deployment scripts, they will automatically copy the latest ABIs to:
```
../quantillon-dapp/src/lib/contracts/abis/
```

### Manual ABI Copying

If you need to manually copy ABIs (e.g., after contract changes without redeployment):

```bash
# From the smart-contracts directory
./scripts/copy-abis.sh
```

This script copies all contract ABIs to the frontend, ensuring the dApp always has the latest contract interfaces.

### Supported Contracts

The following contracts have their ABIs automatically copied:
- MockUSDC (for localhost/Base Sepolia deployments)
- QEUROToken
- ChainlinkOracle  
- QuantillonVault
- QTIToken
- stQEUROToken
- UserPool
- HedgerPool
- YieldShift

## Usage

### Development Deployment
1. Deploy contracts: `forge script DeployQuantillon.s.sol --rpc-url <RPC_URL> --broadcast`
2. MockUSDC is automatically deployed for localhost and Base Sepolia
3. ABIs are automatically copied to frontend
4. Frontend will use the latest contract interfaces

### Production Deployment
1. Set multisig wallet: `export MULTISIG_WALLET=0xYourMultisigWalletAddress`
2. Deploy contracts: `forge script DeployProduction.s.sol --rpc-url <RPC_URL> --broadcast`
3. ABIs are automatically copied to frontend

## Frontend Integration

The frontend automatically imports ABIs from `src/lib/contracts/abis/` and uses them for contract interactions. No manual ABI updates needed in the frontend code.