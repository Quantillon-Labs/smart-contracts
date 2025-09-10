# Smart Contract Deployment Scripts

This directory contains deployment scripts for the Quantillon Protocol smart contracts.

## Deployment Scripts

- `DeployQuantillon.s.sol` - Main deployment script for all contracts
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
- QEUROToken
- ChainlinkOracle  
- QuantillonVault
- QTIToken
- stQEUROToken
- UserPool
- HedgerPool
- YieldShift

## Usage

1. Deploy contracts: `forge script DeployQuantillon.s.sol --rpc-url <RPC_URL> --broadcast`
2. ABIs are automatically copied to frontend
3. Frontend will use the latest contract interfaces

## Frontend Integration

The frontend automatically imports ABIs from `src/lib/contracts/abis/` and uses them for contract interactions. No manual ABI updates needed in the frontend code.