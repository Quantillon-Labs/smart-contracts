#!/bin/bash

# Quantillon Protocol - Localhost Deployment Script
# Deploys contracts to localhost Anvil for development and testing
# Usage: ./scripts/deploy-localhost.sh [--with-mock-usdc]

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
RESULTS_DIR="deployments"

# Parse command line arguments
WITH_MOCK_USDC=false
if [ "$1" = "--with-mock-usdc" ]; then
    WITH_MOCK_USDC=true
fi

if [ "$WITH_MOCK_USDC" = true ]; then
    echo -e "${BLUE}🚀 Quantillon Protocol - Localhost Deployment with MockUSDC${NC}"
    echo "=============================================================="
else
    echo -e "${BLUE}🚀 Quantillon Protocol - Localhost Deployment${NC}"
    echo "=================================================="
fi

# Check if Anvil is running
echo -e "${YELLOW}🔍 Checking if Anvil is running...${NC}"
if ! curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' $RPC_URL > /dev/null 2>&1; then
    echo -e "${RED}❌ Error: Anvil is not running on $RPC_URL${NC}"
    echo -e "${YELLOW}💡 Please start Anvil first:${NC}"
    echo "   anvil --host 0.0.0.0 --port 8545 --accounts 10 --balance 10000"
    exit 1
fi

echo -e "${GREEN}✅ Anvil is running on $RPC_URL${NC}"

# Check if deployment scripts exist
if [ ! -f "$DEPLOYMENT_SCRIPT" ]; then
    echo -e "${RED}❌ Error: Deployment script not found: $DEPLOYMENT_SCRIPT${NC}"
    exit 1
fi

if [ "$WITH_MOCK_USDC" = true ] && [ ! -f "$MOCK_USDC_SCRIPT" ]; then
    echo -e "${RED}❌ Error: MockUSDC deployment script not found: $MOCK_USDC_SCRIPT${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Deployment scripts found${NC}"

# Create deployments directory if it doesn't exist
mkdir -p "$RESULTS_DIR"

# Deploy MockUSDC first if requested
if [ "$WITH_MOCK_USDC" = true ]; then
    echo -e "${YELLOW}🚀 Deploying MockUSDC to localhost...${NC}"
    echo "=================================================="

    if forge script "$MOCK_USDC_SCRIPT" --rpc-url "$RPC_URL" --broadcast; then
        echo -e "${GREEN}✅ MockUSDC deployment completed successfully!${NC}"
    else
        echo -e "${RED}❌ MockUSDC deployment failed!${NC}"
        exit 1
    fi
fi

# Deploy main contracts
echo -e "${YELLOW}🚀 Deploying main contracts to localhost...${NC}"
echo "=================================================="

if forge script "$DEPLOYMENT_SCRIPT" --rpc-url "$RPC_URL" --broadcast; then
    echo -e "${GREEN}✅ Main contracts deployment completed successfully!${NC}"
else
    echo -e "${RED}❌ Main contracts deployment failed!${NC}"
    exit 1
fi

# Get the latest deployment addresses from broadcast files
echo -e "${YELLOW}📋 Extracting deployment addresses...${NC}"

# Find the latest broadcast files
BROADCAST_DIR_MAIN="broadcast/DeployQuantillon.s.sol"
BROADCAST_DIR_USDC="broadcast/DeployMockUSDC.s.sol"

echo -e "${BLUE}📄 Deployed Contract Addresses:${NC}"
echo "=================================================="

# Extract MockUSDC address if deployed
if [ "$WITH_MOCK_USDC" = true ] && [ -d "$BROADCAST_DIR_USDC" ]; then
    LATEST_RUN_USDC=$(find "$BROADCAST_DIR_USDC" -name "run-latest.json" | head -1)
    if [ -n "$LATEST_RUN_USDC" ]; then
        echo -e "${GREEN}✅ Found MockUSDC deployment broadcast file${NC}"
        
        if command -v jq > /dev/null 2>&1; then
            echo "MockUSDC addresses:"
            jq -r '.transactions[] | select(.contractName != null) | "\(.contractName): \(.contractAddress)"' "$LATEST_RUN_USDC" 2>/dev/null || echo "Could not parse MockUSDC addresses with jq"
        fi
    fi
fi

# Extract main contract addresses
if [ -d "$BROADCAST_DIR_MAIN" ]; then
    LATEST_RUN_MAIN=$(find "$BROADCAST_DIR_MAIN" -name "run-latest.json" | head -1)
    if [ -n "$LATEST_RUN_MAIN" ]; then
        echo -e "${GREEN}✅ Found main contracts deployment broadcast file${NC}"
        
        if command -v jq > /dev/null 2>&1; then
            echo "Main contract addresses:"
            jq -r '.transactions[] | select(.contractName != null) | "\(.contractName): \(.contractAddress)"' "$LATEST_RUN_MAIN" 2>/dev/null || echo "Could not parse main contract addresses with jq"
        else
            echo "jq not available, showing raw broadcast file location:"
            echo "Broadcast file: $LATEST_RUN_MAIN"
        fi
    else
        echo -e "${YELLOW}⚠️  No run-latest.json found in broadcast directory${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  No broadcast directory found${NC}"
fi

echo "=================================================="
if [ "$WITH_MOCK_USDC" = true ]; then
    echo -e "${GREEN}🎉 Localhost deployment with MockUSDC completed!${NC}"
else
    echo -e "${GREEN}🎉 Localhost deployment completed!${NC}"
fi
echo ""
echo -e "${BLUE}💡 Next steps:${NC}"
echo "1. Check contract addresses in the output above"
echo "2. Use 'cast code <ADDRESS> --rpc-url $RPC_URL' to verify deployment"
echo "3. Interact with contracts using cast or your dApp"
if [ "$WITH_MOCK_USDC" = true ]; then
    echo "4. Use MockUSDC faucet: cast send <MOCKUSDC_ADDRESS> 'faucet(uint256)' 1000000000 --rpc-url $RPC_URL --private-key <PRIVATE_KEY>"
fi
echo ""
echo -e "${YELLOW}📝 Example verification:${NC}"
echo "   cast code <CONTRACT_ADDRESS> --rpc-url $RPC_URL"
echo ""
echo -e "${BLUE}🔗 RPC URL: $RPC_URL${NC}"
