#!/bin/bash

# Quantillon Protocol - Localhost Deployment Script
# Deploys contracts to localhost Anvil for development and testing

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
RESULTS_DIR="deployments"

echo -e "${BLUE}🚀 Quantillon Protocol - Localhost Deployment${NC}"
echo "=================================================="

# Check if Anvil is running
echo -e "${YELLOW}🔍 Checking if Anvil is running...${NC}"
if ! curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' $RPC_URL > /dev/null 2>&1; then
    echo -e "${RED}❌ Error: Anvil is not running on $RPC_URL${NC}"
    echo -e "${YELLOW}💡 Please start Anvil first:${NC}"
    echo "   anvil --host 0.0.0.0 --port 8545 --accounts 10 --balance 10000"
    exit 1
fi

echo -e "${GREEN}✅ Anvil is running on $RPC_URL${NC}"

# Check if deployment script exists
if [ ! -f "$DEPLOYMENT_SCRIPT" ]; then
    echo -e "${RED}❌ Error: Deployment script not found: $DEPLOYMENT_SCRIPT${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Deployment script found: $DEPLOYMENT_SCRIPT${NC}"

# Create deployments directory if it doesn't exist
mkdir -p "$RESULTS_DIR"

# Deploy contracts
echo -e "${YELLOW}🚀 Deploying contracts to localhost...${NC}"
echo "=================================================="

if forge script "$DEPLOYMENT_SCRIPT" --rpc-url "$RPC_URL" --broadcast; then
    echo -e "${GREEN}✅ Deployment completed successfully!${NC}"
else
    echo -e "${RED}❌ Deployment failed!${NC}"
    exit 1
fi

# Get the latest deployment addresses from broadcast files
echo -e "${YELLOW}📋 Extracting deployment addresses...${NC}"

# Find the latest broadcast file
BROADCAST_DIR="broadcast/DeployQuantillon.s.sol"
if [ -d "$BROADCAST_DIR" ]; then
    LATEST_RUN=$(find "$BROADCAST_DIR" -name "run-latest.json" | head -1)
    if [ -n "$LATEST_RUN" ]; then
        echo -e "${GREEN}✅ Found deployment broadcast file: $LATEST_RUN${NC}"
        
        # Extract contract addresses (basic extraction)
        echo -e "${BLUE}📄 Deployed Contract Addresses:${NC}"
        echo "=================================================="
        
        # Try to extract addresses from the broadcast file
        if command -v jq > /dev/null 2>&1; then
            echo "Using jq to extract addresses..."
            jq -r '.transactions[] | select(.contractName != null) | "\(.contractName): \(.contractAddress)"' "$LATEST_RUN" 2>/dev/null || echo "Could not parse addresses with jq"
        else
            echo "jq not available, showing raw broadcast file location:"
            echo "Broadcast file: $LATEST_RUN"
        fi
    else
        echo -e "${YELLOW}⚠️  No run-latest.json found in broadcast directory${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  No broadcast directory found${NC}"
fi

echo "=================================================="
echo -e "${GREEN}🎉 Localhost deployment completed!${NC}"
echo ""
echo -e "${BLUE}💡 Next steps:${NC}"
echo "1. Check contract addresses in the output above"
echo "2. Use 'cast code <ADDRESS> --rpc-url $RPC_URL' to verify deployment"
echo "3. Interact with contracts using cast or your dApp"
echo ""
echo -e "${YELLOW}📝 Example verification:${NC}"
echo "   cast code <CONTRACT_ADDRESS> --rpc-url $RPC_URL"
echo ""
echo -e "${BLUE}🔗 RPC URL: $RPC_URL${NC}"
