#!/bin/bash

# Quantillon Protocol - Base Sepolia Deployment Script
# Deploys contracts to Base Sepolia testnet with MockUSDC

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
RPC_URL="https://sepolia.base.org"
DEPLOYMENT_SCRIPT="scripts/deployment/DeployQuantillon.s.sol"
NETWORK="base-sepolia"

# Load environment variables using shared utility
source "$(dirname "${BASH_SOURCE[0]}")/../utils/load-env.sh"
setup_environment

echo -e " Quantillon Protocol - Base Sepolia Deployment"
echo "======================================================"

# Check if required environment variables are set
if [ -z "$PRIVATE_KEY" ]; then
    echo -e " Error: PRIVATE_KEY environment variable is not set"
    echo -e " Please set your private key:"
    echo "   export PRIVATE_KEY=0xYourPrivateKey"
    exit 1
fi

if [ -z "$BASESCAN_API_KEY" ]; then
    echo -e "  Warning: BASESCAN_API_KEY not set. Contract verification will be skipped."
    echo -e " To enable verification, set:"
    echo "   export BASESCAN_API_KEY=YourBaseScanAPIKey"
fi

echo -e " Environment variables configured"

# Check if deployment script exists
if [ ! -f "$DEPLOYMENT_SCRIPT" ]; then
    echo -e " Error: Deployment script not found: $DEPLOYMENT_SCRIPT"
    exit 1
fi

echo -e " Deployment script found: $DEPLOYMENT_SCRIPT"

# Create deployments directory if it doesn't exist
mkdir -p "$RESULTS_DIR"

# Deploy contracts
echo -e " Deploying contracts to Base Sepolia..."
echo "======================================================"

if forge script "$DEPLOYMENT_SCRIPT" --rpc-url "$RPC_URL" --broadcast --verify; then
    echo -e " Deployment completed successfully!"
else
    echo -e " Deployment failed!"
    exit 1
fi

# Get the latest deployment addresses from broadcast files
echo -e " Extracting deployment addresses..."

# Find the latest broadcast file
BROADCAST_DIR="broadcast/DeployQuantillon.s.sol"
if [ -d "$BROADCAST_DIR" ]; then
    LATEST_RUN=$(find "$BROADCAST_DIR" -name "run-latest.json" | head -1)
    if [ -n "$LATEST_RUN" ]; then
        echo -e " Found deployment broadcast file: $LATEST_RUN"
        
        # Extract contract addresses
        echo -e " Deployed Contract Addresses:"
        echo "======================================================"
        
        if command -v jq > /dev/null 2>&1; then
            echo "Contract addresses:"
            jq -r '.transactions[] | select(.contractName != null) | "\(.contractName): \(.contractAddress)"' "$LATEST_RUN" 2>/dev/null || echo "Could not parse addresses with jq"
        else
            echo "jq not available, showing raw broadcast file location:"
            echo "Broadcast file: $LATEST_RUN"
        fi
        
        # Save deployment info to JSON file
        DEPLOYMENT_FILE="$RESULTS_DIR/$NETWORK-$(date +%Y%m%d_%H%M%S).json"
        echo -e "💾 Saving deployment info to: $DEPLOYMENT_FILE"
        
        # Create deployment info JSON
        cat > "$DEPLOYMENT_FILE" << EOF
{
  "network": "$NETWORK",
  "chainId": 84532,
  "rpcUrl": "$RPC_URL",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "deployer": "$(cast wallet address --private-key $PRIVATE_KEY)",
  "contracts": {
    "MockUSDC": "$(jq -r '.transactions[] | select(.contractName == "MockUSDC") | .contractAddress' "$LATEST_RUN" 2>/dev/null || echo "null")",
    "TimeProvider": "$(jq -r '.transactions[] | select(.contractName == "TimeProvider") | .contractAddress' "$LATEST_RUN" 2>/dev/null || echo "null")",
    "ChainlinkOracle": "$(jq -r '.transactions[] | select(.contractName == "ChainlinkOracle") | .contractAddress' "$LATEST_RUN" 2>/dev/null || echo "null")",
    "QEUROToken": "$(jq -r '.transactions[] | select(.contractName == "QEUROToken") | .contractAddress' "$LATEST_RUN" 2>/dev/null || echo "null")",
    "QTIToken": "$(jq -r '.transactions[] | select(.contractName == "QTIToken") | .contractAddress' "$LATEST_RUN" 2>/dev/null || echo "null")",
    "QuantillonVault": "$(jq -r '.transactions[] | select(.contractName == "QuantillonVault") | .contractAddress' "$LATEST_RUN" 2>/dev/null || echo "null")",
    "UserPool": "$(jq -r '.transactions[] | select(.contractName == "UserPool") | .contractAddress' "$LATEST_RUN" 2>/dev/null || echo "null")",
    "HedgerPool": "$(jq -r '.transactions[] | select(.contractName == "HedgerPool") | .contractAddress' "$LATEST_RUN" 2>/dev/null || echo "null")",
    "stQEUROToken": "$(jq -r '.transactions[] | select(.contractName == "stQEUROToken") | .contractAddress' "$LATEST_RUN" 2>/dev/null || echo "null")",
    "AaveVault": "$(jq -r '.transactions[] | select(.contractName == "AaveVault") | .contractAddress' "$LATEST_RUN" 2>/dev/null || echo "null")",
    "YieldShift": "$(jq -r '.transactions[] | select(.contractName == "YieldShift") | .contractAddress' "$LATEST_RUN" 2>/dev/null || echo "null")"
  },
  "externalAddresses": {
    "EUR_USD_FEED": "0x443c8906D15c131C52463a8384dCc0c65Dce3a96",
    "USDC_USD_FEED": "0x4aDC67696bA383F43DD60A9e78F2C97Fbbfc7cb1",
    "USDC_TOKEN": "0x036CbD53842c5426634e7929541eC2318f3dCF7e",
    "AAVE_POOL": "0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951"
  }
}
EOF
        
        echo -e " Deployment info saved to $DEPLOYMENT_FILE"
    else
        echo -e "  No run-latest.json found in broadcast directory"
    fi
else
    echo -e "  No broadcast directory found"
fi

echo "======================================================"
echo -e " Base Sepolia deployment completed!"
echo ""
echo -e " Next steps:"
echo "1. Check contract addresses in the output above"
echo "2. Verify contracts on BaseScan: https://sepolia.basescan.org/"
echo "3. Test contract interactions using cast or your dApp"
echo "4. Update frontend configuration with new addresses"
echo ""
echo -e " Example verification:"
echo "   cast code <CONTRACT_ADDRESS> --rpc-url $RPC_URL"
echo ""
echo -e " Network Info:"
echo "   RPC URL: $RPC_URL"
echo "   Chain ID: 84532"
echo "   Explorer: https://sepolia.basescan.org/"
echo ""
echo -e "💰 Get testnet ETH:"
echo "   https://www.coinbase.com/faucets/base-ethereum-sepolia-faucet"
