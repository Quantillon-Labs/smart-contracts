#!/bin/bash

# Script to copy contract ABIs to the frontend
# 
# Usage: ./scripts/deployment/copy-abis.sh [environment]
# 
# Environment options:
#   localhost (default)
#   testnet
#   mainnet
#
# Configuration:
#   The script automatically loads environment variables from .env file if present.
#   Define FRONTEND_ABI_DIR and SMART_CONTRACTS_OUT in .env for consistent paths.
#
# Environment Variables (from .env file or command line):
#   FRONTEND_ABI_DIR     - Frontend ABI directory path (relative to smart-contracts root)
#   SMART_CONTRACTS_OUT  - Smart contracts out directory path (relative to smart-contracts root)
#
# Examples:
#   ./scripts/deployment/copy-abis.sh                    # Uses .env variables or defaults
#   ./scripts/deployment/copy-abis.sh localhost          # Explicit localhost
#   ./scripts/deployment/copy-abis.sh testnet            # Testnet environment
#   FRONTEND_ABI_DIR="/custom/path" ./scripts/deployment/copy-abis.sh  # Override .env

set -e  # Exit on any error

# Check if dotenvx is available and environment is encrypted
if [ -f ".env.keys" ] && grep -q "DOTENV_PUBLIC_KEY" .env 2>/dev/null && [ -z "$DOTENVX_RUNNING" ]; then
    # Use dotenvx for encrypted environment
    echo -e "\033[0;34m🔐 Using encrypted environment variables\033[0m"
    export DOTENVX_RUNNING=1
    exec npx dotenvx run -- "$0" "$@"
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get environment from command line argument or default to localhost
ENVIRONMENT=${1:-localhost}

# Load environment variables from .env file if it exists
# Note: Command line variables will override .env variables
if [ -f ".env" ]; then
    echo -e "${BLUE}📄 Loading environment variables from .env file...${NC}"
    # Only export variables that aren't already set (command line takes precedence)
    while IFS= read -r line; do
        # Skip comments and empty lines
        if [[ ! "$line" =~ ^[[:space:]]*# ]] && [[ -n "$line" ]]; then
            var_name=$(echo "$line" | cut -d'=' -f1)
            if [[ -z "${!var_name}" ]]; then
                # Remove quotes from the value if present
                var_value=$(echo "$line" | cut -d'=' -f2- | sed 's/^"//;s/"$//')
                export "${var_name}=${var_value}"
            fi
        fi
    done < .env
fi

echo -e "${BLUE}📋 Copying contract ABIs to frontend...${NC}"
echo -e "${YELLOW}Environment: $ENVIRONMENT${NC}"

# Define paths based on environment
# Priority: 1) Environment variables from .env file, 2) Environment-specific defaults
case $ENVIRONMENT in
    "localhost")
        # Localhost paths - use .env variables if available, otherwise defaults
        FRONTEND_ABI_DIR="${FRONTEND_ABI_DIR:-../../../quantillon-dapp/src/lib/contracts/abis/}"
        SMART_CONTRACTS_OUT="${SMART_CONTRACTS_OUT:-./out/}"
        ;;
    "testnet")
        # Testnet paths - use .env variables if available, otherwise placeholders
        FRONTEND_ABI_DIR="${FRONTEND_ABI_DIR:-/path/to/testnet/frontend/src/lib/contracts/abis/}"
        SMART_CONTRACTS_OUT="${SMART_CONTRACTS_OUT:-/path/to/testnet/smart-contracts/out/}"
        ;;
    "mainnet")
        # Mainnet paths - use .env variables if available, otherwise placeholders
        FRONTEND_ABI_DIR="${FRONTEND_ABI_DIR:-/path/to/mainnet/frontend/src/lib/contracts/abis/}"
        SMART_CONTRACTS_OUT="${SMART_CONTRACTS_OUT:-/path/to/mainnet/smart-contracts/out/}"
        ;;
    *)
        echo -e "${RED}❌ Error: Unknown environment '$ENVIRONMENT'${NC}"
        echo -e "${YELLOW}💡 Usage: $0 [localhost|testnet|mainnet]${NC}"
        exit 1
        ;;
esac

echo -e "${BLUE}📁 Frontend ABI directory: $FRONTEND_ABI_DIR${NC}"
echo -e "${BLUE}📁 Smart contracts out directory: $SMART_CONTRACTS_OUT${NC}"

# Validate that source directory exists
if [ ! -d "$SMART_CONTRACTS_OUT" ]; then
    echo -e "${RED}❌ Error: Smart contracts out directory not found: $SMART_CONTRACTS_OUT${NC}"
    echo -e "${YELLOW}💡 Please build the contracts first: forge build${NC}"
    exit 1
fi

# Create frontend ABI directory if it doesn't exist
mkdir -p "$FRONTEND_ABI_DIR"

# List of contracts to copy
contracts=("QEUROToken" "ChainlinkOracle" "QuantillonVault" "QTIToken" "stQEUROToken" "UserPool" "HedgerPool" "YieldShift" "MockUSDC" "AaveVault")

echo -e "${BLUE}📄 Copying ABIs for ${#contracts[@]} contracts...${NC}"

# Copy each contract ABI
success_count=0
error_count=0

for contract in "${contracts[@]}"; do
    source_file="${SMART_CONTRACTS_OUT}${contract}.sol/${contract}.json"
    dest_file="${FRONTEND_ABI_DIR}${contract}.json"
    
    if [ -f "$source_file" ]; then
        cp "$source_file" "$dest_file"
        echo -e "${GREEN}✅ Copied ${contract} ABI${NC}"
        success_count=$((success_count + 1))
    else
        echo -e "${RED}❌ ${contract} ABI not found at $source_file${NC}"
        error_count=$((error_count + 1))
    fi
done

echo ""
echo -e "${BLUE}📊 ABI Copying Summary:${NC}"
echo -e "${GREEN}✅ Successfully copied: $success_count ABIs${NC}"
if [ $error_count -gt 0 ]; then
    echo -e "${RED}❌ Failed to copy: $error_count ABIs${NC}"
fi
echo -e "${BLUE}📁 Frontend ABIs updated in: $FRONTEND_ABI_DIR${NC}"

# Exit with error code if any ABIs failed to copy
if [ $error_count -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Some ABIs were not found. Make sure contracts are built with 'forge build'${NC}"
    exit 1
fi

echo -e "${GREEN}🎉 All ABIs copied successfully!${NC}"
