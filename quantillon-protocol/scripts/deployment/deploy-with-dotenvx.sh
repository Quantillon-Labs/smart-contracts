#!/bin/bash

# Quantillon Protocol - Secure Deployment Script
# Uses dotenvx to securely load environment variables

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔐 Quantillon Protocol - Secure Deployment${NC}"
echo "======================================================"

# Check if .env.keys exists
if [ ! -f ".env.keys" ]; then
    echo -e "${RED}❌ Error: .env.keys file not found${NC}"
    echo -e "${YELLOW}💡 Please ensure you have the decryption key for your encrypted .env file${NC}"
    echo -e "${YELLOW}   The .env.keys file should contain your DOTENV_PRIVATE_KEY${NC}"
    exit 1
fi

# Check if .env is encrypted
if ! grep -q "DOTENV_PUBLIC_KEY" .env; then
    echo -e "${YELLOW}⚠️  Warning: .env file doesn't appear to be encrypted${NC}"
    echo -e "${YELLOW}   Consider running: npx dotenvx encrypt .env${NC}"
fi

echo -e "${GREEN}✅ Environment files found${NC}"

# Get the deployment script from command line argument
DEPLOYMENT_SCRIPT="$1"

if [ -z "$DEPLOYMENT_SCRIPT" ]; then
    echo -e "${RED}❌ Error: No deployment script specified${NC}"
    echo -e "${YELLOW}💡 Usage: $0 <deployment-script> [forge-options]${NC}"
    echo -e "${YELLOW}   Example: $0 scripts/deployment/DeployQuantillon.s.sol --rpc-url localhost --broadcast${NC}"
    exit 1
fi

# Check if deployment script exists
if [ ! -f "$DEPLOYMENT_SCRIPT" ]; then
    echo -e "${RED}❌ Error: Deployment script not found: $DEPLOYMENT_SCRIPT${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Deployment script found: $DEPLOYMENT_SCRIPT${NC}"

# Shift to get remaining arguments
shift

# Run the deployment with dotenvx
echo -e "${YELLOW}🚀 Running secure deployment...${NC}"
echo "======================================================"

npx dotenvx run -- forge script "$DEPLOYMENT_SCRIPT" "$@"

echo "======================================================"
echo -e "${GREEN}🎉 Secure deployment completed!${NC}"
