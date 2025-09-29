#!/bin/bash

# Quantillon Protocol - Localhost Deployment Script
# Deploys contracts to localhost Anvil for development and testing
# Usage: ./scripts/deploy-localhost.sh [--with-mock-usdc|--with-mock-feeds|--with-all-mocks]

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
RPC_URL="http://localhost:8545"
DEPLOYMENT_SCRIPT="scripts/deployment/DeployQuantillon.s.sol"
MOCK_USDC_SCRIPT="scripts/deployment/DeployMockUSDC.s.sol"
MOCK_FEEDS_SCRIPT="scripts/deployment/DeployMockFeeds.s.sol"

# Load environment variables using shared utility
source "$(dirname "${BASH_SOURCE[0]}")/../utils/load-env.sh"
setup_environment

# Parse command line arguments
WITH_MOCK_USDC=false
WITH_MOCK_FEEDS=false
if [ "$1" = "--with-mock-usdc" ]; then
    WITH_MOCK_USDC=true
elif [ "$1" = "--with-mock-feeds" ]; then
    WITH_MOCK_FEEDS=true
elif [ "$1" = "--with-all-mocks" ]; then
    WITH_MOCK_USDC=true
    WITH_MOCK_FEEDS=true
fi

if [ "$WITH_MOCK_USDC" = true ] && [ "$WITH_MOCK_FEEDS" = true ]; then
    echo "Quantillon Protocol - Localhost Deployment with All Mocks"
    echo "=============================================================="
elif [ "$WITH_MOCK_USDC" = true ]; then
    echo "Quantillon Protocol - Localhost Deployment with MockUSDC"
    echo "=============================================================="
elif [ "$WITH_MOCK_FEEDS" = true ]; then
    echo "Quantillon Protocol - Localhost Deployment with Mock Feeds"
    echo "=============================================================="
else
    echo "Quantillon Protocol - Localhost Deployment"
    echo "=================================================="
fi

# Check if Anvil is running
echo "Checking if Anvil is running..."
if ! curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' $RPC_URL > /dev/null 2>&1; then
    echo "ERROR: Anvil is not running on $RPC_URL"
    echo "Please start Anvil first:"
    echo "   anvil --host 0.0.0.0 --port 8545 --accounts 10 --balance 10000"
    exit 1
fi

echo "SUCCESS: Anvil is running on $RPC_URL"

# Check if deployment scripts exist
if [ ! -f "$DEPLOYMENT_SCRIPT" ]; then
    echo "ERROR: Deployment script not found: $DEPLOYMENT_SCRIPT"
    exit 1
fi

if [ "$WITH_MOCK_USDC" = true ] && [ ! -f "$MOCK_USDC_SCRIPT" ]; then
    echo "ERROR: MockUSDC deployment script not found: $MOCK_USDC_SCRIPT"
    exit 1
fi

if [ "$WITH_MOCK_FEEDS" = true ] && [ ! -f "$MOCK_FEEDS_SCRIPT" ]; then
    echo "ERROR: MockFeeds deployment script not found: $MOCK_FEEDS_SCRIPT"
    exit 1
fi

echo "SUCCESS: Deployment scripts found"

# Create deployments directory if it doesn't exist
mkdir -p "$RESULTS_DIR"

# Deploy MockUSDC first if requested
if [ "$WITH_MOCK_USDC" = true ]; then
    echo "Deploying MockUSDC to localhost..."
    echo "=================================================="

    if npx dotenvx run -- forge script "$MOCK_USDC_SCRIPT" --rpc-url "$RPC_URL" --broadcast; then
        echo "MockUSDC deployment completed successfully!"
    else
        echo "MockUSDC deployment failed!"
        exit 1
    fi
fi

# Deploy MockFeeds if requested
if [ "$WITH_MOCK_FEEDS" = true ]; then
    echo "Deploying Mock Price Feeds to localhost..."
    echo "=================================================="

    if npx dotenvx run -- forge script "$MOCK_FEEDS_SCRIPT" --rpc-url "$RPC_URL" --broadcast; then
        echo "Mock Price Feeds deployment completed successfully!"
    else
        echo "Mock Price Feeds deployment failed!"
        exit 1
    fi
fi

# Deploy main contracts
echo "Deploying main contracts to localhost..."
echo "=================================================="

if npx dotenvx run -- forge script "$DEPLOYMENT_SCRIPT" --rpc-url "$RPC_URL" --broadcast; then
    echo "Main contracts deployment completed successfully!"
else
    echo "Main contracts deployment failed!"
    exit 1
fi

# Get the latest deployment addresses from broadcast files
echo "Extracting deployment addresses..."

# Find the latest broadcast files
BROADCAST_DIR_MAIN="broadcast/DeployQuantillon.s.sol"
BROADCAST_DIR_USDC="broadcast/DeployMockUSDC.s.sol"
BROADCAST_DIR_FEEDS="broadcast/DeployMockFeeds.s.sol"

echo "Deployed Contract Addresses:"
echo "=================================================="

# Extract MockUSDC address if deployed
if [ "$WITH_MOCK_USDC" = true ] && [ -d "$BROADCAST_DIR_USDC" ]; then
    LATEST_RUN_USDC=$(find "$BROADCAST_DIR_USDC" -name "run-latest.json" | head -1)
    if [ -n "$LATEST_RUN_USDC" ]; then
        echo "Found MockUSDC deployment broadcast file"
        
        if command -v jq > /dev/null 2>&1; then
            echo "MockUSDC addresses:"
            jq -r '.transactions[] | select(.contractName != null) | "\(.contractName): \(.contractAddress)"' "$LATEST_RUN_USDC" 2>/dev/null || echo "Could not parse MockUSDC addresses with jq"
        fi
    fi
fi

# Extract MockFeeds addresses if deployed
if [ "$WITH_MOCK_FEEDS" = true ] && [ -d "$BROADCAST_DIR_FEEDS" ]; then
    LATEST_RUN_FEEDS=$(find "$BROADCAST_DIR_FEEDS" -name "run-latest.json" | head -1)
    if [ -n "$LATEST_RUN_FEEDS" ]; then
        echo "Found MockFeeds deployment broadcast file"
        
        if command -v jq > /dev/null 2>&1; then
            echo "Mock Price Feed addresses:"
            jq -r '.transactions[] | select(.contractName != null) | "\(.contractName): \(.contractAddress)"' "$LATEST_RUN_FEEDS" 2>/dev/null || echo "Could not parse MockFeeds addresses with jq"
        fi
    fi
fi

# Extract main contract addresses
if [ -d "$BROADCAST_DIR_MAIN" ]; then
    LATEST_RUN_MAIN=$(find "$BROADCAST_DIR_MAIN" -name "run-latest.json" | head -1)
    if [ -n "$LATEST_RUN_MAIN" ]; then
        echo "Found main contracts deployment broadcast file"
        
        if command -v jq > /dev/null 2>&1; then
            echo "Main contract addresses:"
            jq -r '.transactions[] | select(.contractName != null) | "\(.contractName): \(.contractAddress)"' "$LATEST_RUN_MAIN" 2>/dev/null || echo "Could not parse main contract addresses with jq"
        else
            echo "jq not available, showing raw broadcast file location:"
            echo "Broadcast file: $LATEST_RUN_MAIN"
        fi
    else
        echo " No run-latest.json found in broadcast directory"
    fi
else
    echo " No broadcast directory found"
fi

echo "=================================================="
if [ "$WITH_MOCK_USDC" = true ] && [ "$WITH_MOCK_FEEDS" = true ]; then
    echo "Localhost deployment with all mocks completed!"
elif [ "$WITH_MOCK_USDC" = true ]; then
    echo "Localhost deployment with MockUSDC completed!"
elif [ "$WITH_MOCK_FEEDS" = true ]; then
    echo "Localhost deployment with Mock Feeds completed!"
else
    echo "Localhost deployment completed!"
fi

# Automatically update frontend with new ABIs and addresses
echo ""
echo "Updating frontend with new ABIs and addresses..."
echo ""

# Copy ABIs to frontend
echo "Copying contract ABIs to frontend..."
if ./scripts/deployment/copy-abis.sh; then
    echo "ABIs copied successfully!"
else
    echo "Failed to copy ABIs"
    exit 1
fi

echo ""

# Update frontend addresses
echo "Updating frontend addresses..."
if ./scripts/deployment/update-frontend-addresses.sh; then
    echo "Frontend addresses updated successfully!"
else
    echo "Failed to update frontend addresses"
    exit 1
fi

echo ""
echo "Frontend integration completed!"
echo ""
echo "Next steps:"
echo "1. Check contract addresses in the output above"
echo "2. Use 'cast code <ADDRESS> --rpc-url $RPC_URL' to verify deployment"
echo "3. Interact with contracts using cast or your dApp"
echo "4. Frontend is ready with updated ABIs and addresses"
if [ "$WITH_MOCK_USDC" = true ]; then
    echo "5. Use MockUSDC faucet: cast send <MOCKUSDC_ADDRESS> 'faucet(uint256)' 1000000000 --rpc-url $RPC_URL --private-key <PRIVATE_KEY>"
fi
if [ "$WITH_MOCK_FEEDS" = true ]; then
    echo "6. Mock price feeds are deployed and initialized with realistic prices"
    echo "7. EUR/USD: 1.08 USD, USDC/USD: 1.00 USD"
fi
echo ""
echo "Example verification:"
echo "   cast code <CONTRACT_ADDRESS> --rpc-url $RPC_URL"
echo ""
echo "RPC URL: $RPC_URL"
