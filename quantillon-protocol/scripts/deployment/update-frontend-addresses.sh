#!/bin/bash

# Script to update frontend addresses.json with latest deployment
# 
# Usage: ./scripts/deployment/update-frontend-addresses.sh
#
# Configuration:
#   The script automatically loads environment variables from .env file if present.
#   Define FRONTEND_ADDRESSES_FILE in .env for consistent paths.
#
# Environment Variables (from .env file or command line):
#   FRONTEND_ADDRESSES_FILE - Frontend addresses.json file path (relative to smart-contracts root)
#
# Examples:
#   ./scripts/deployment/update-frontend-addresses.sh                    # Uses .env variables or defaults
#   FRONTEND_ADDRESSES_FILE="/custom/path" ./scripts/deployment/update-frontend-addresses.sh  # Override .env

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

echo -e "${BLUE}📋 Updating frontend addresses.json with latest deployment...${NC}"

# Define paths - use .env variables if available, otherwise defaults
FRONTEND_ADDRESSES_FILE="${FRONTEND_ADDRESSES_FILE:-../../../quantillon-dapp/src/config/addresses.json}"

echo -e "${BLUE}📁 Frontend addresses file: $FRONTEND_ADDRESSES_FILE${NC}"

# Detect which network was deployed (check for broadcast files)
LOCALHOST_BROADCAST="./broadcast/DeployQuantillon.s.sol/31337/run-latest.json"
BASE_SEPOLIA_BROADCAST="./broadcast/DeployQuantillon.s.sol/84532/run-latest.json"

if [ -f "$LOCALHOST_BROADCAST" ]; then
    BROADCAST_FILE="$LOCALHOST_BROADCAST"
    NETWORK="localhost"
    CHAIN_ID="31337"
    echo -e "${GREEN}📡 Detected localhost deployment${NC}"
elif [ -f "$BASE_SEPOLIA_BROADCAST" ]; then
    BROADCAST_FILE="$BASE_SEPOLIA_BROADCAST"
    NETWORK="base-sepolia"
    CHAIN_ID="84532"
    echo -e "${GREEN}📡 Detected Base Sepolia deployment${NC}"
else
    echo -e "${RED}❌ No deployment broadcast file found${NC}"
    echo -e "${YELLOW}💡 Please run deployment first:${NC}"
    echo -e "${YELLOW}   make deploy-localhost (for localhost)${NC}"
    echo -e "${YELLOW}   make deploy-base-sepolia (for Base Sepolia)${NC}"
    exit 1
fi

echo -e "${BLUE}📄 Using broadcast file: $BROADCAST_FILE${NC}"

# Extract addresses using jq
echo -e "${BLUE}📋 Extracting deployment addresses...${NC}"

# Extract all contract addresses
MOCK_USDC=$(jq -r '.transactions[] | select(.contractName == "MockUSDC") | .contractAddress' "$BROADCAST_FILE" | head -1)
QEURO_TOKEN=$(jq -r '.transactions[] | select(.contractName == "QEUROToken") | .contractAddress' "$BROADCAST_FILE" | head -1)
QUANTILLON_VAULT=$(jq -r '.transactions[] | select(.contractName == "QuantillonVault") | .contractAddress' "$BROADCAST_FILE" | head -1)
QTI_TOKEN=$(jq -r '.transactions[] | select(.contractName == "QTIToken") | .contractAddress' "$BROADCAST_FILE" | head -1)
STQEURO_TOKEN=$(jq -r '.transactions[] | select(.contractName == "stQEUROToken") | .contractAddress' "$BROADCAST_FILE" | head -1)
CHAINLINK_ORACLE=$(jq -r '.transactions[] | select(.contractName == "ERC1967Proxy") | .contractAddress' "$BROADCAST_FILE" | head -1)
USER_POOL=$(jq -r '.transactions[] | select(.contractName == "UserPool") | .contractAddress' "$BROADCAST_FILE" | head -1)
HEDGER_POOL=$(jq -r '.transactions[] | select(.contractName == "HedgerPool") | .contractAddress' "$BROADCAST_FILE" | head -1)
YIELD_SHIFT=$(jq -r '.transactions[] | select(.contractName == "YieldShift") | .contractAddress' "$BROADCAST_FILE" | head -1)
AAVE_VAULT=$(jq -r '.transactions[] | select(.contractName == "AaveVault") | .contractAddress' "$BROADCAST_FILE" | head -1)
TIME_PROVIDER=$(jq -r '.transactions[] | select(.contractName == "TimeProvider") | .contractAddress' "$BROADCAST_FILE" | head -1)

# Extract mock price feed addresses
MOCK_EUR_USD=$(jq -r '.transactions[] | select(.contractName == "MockAggregatorV3") | .contractAddress' "$BROADCAST_FILE" | head -1)
MOCK_USDC_USD=$(jq -r '.transactions[] | select(.contractName == "MockAggregatorV3") | .contractAddress' "$BROADCAST_FILE" | tail -1)

# Fallback for MockUSDC if not found
if [ "$MOCK_USDC" = "null" ] || [ -z "$MOCK_USDC" ]; then
    echo -e "${YELLOW}⚠️  MockUSDC not found in deployment, using placeholder address${NC}"
    MOCK_USDC="0x0000000000000000000000000000000000000000"
fi

# Create updated addresses.json
echo -e "${BLUE}📝 Creating updated addresses.json...${NC}"
cat > "$FRONTEND_ADDRESSES_FILE" << EOF
{
  "$CHAIN_ID": {
    "name": "$(if [ "$NETWORK" = "localhost" ]; then echo "Anvil Localhost"; else echo "Base Sepolia"; fi)",
    "isTestnet": true,
    "contracts": {
      "QEUROToken": "$QEURO_TOKEN",
      "QuantillonVault": "$QUANTILLON_VAULT",
      "QTIToken": "$QTI_TOKEN",
      "stQEUROToken": "$STQEURO_TOKEN",
      "ChainlinkOracle": "$CHAINLINK_ORACLE",
      "UserPool": "$USER_POOL",
      "HedgerPool": "$HEDGER_POOL",
      "YieldShift": "$YIELD_SHIFT",
      "AaveVault": "$AAVE_VAULT",
      "TimeProvider": "$TIME_PROVIDER",
      "USDC": "$MOCK_USDC",
      "MockUSDC": "$MOCK_USDC",
      "MockEURUSD": "$MOCK_EUR_USD",
      "MockUSDCUSD": "$MOCK_USDC_USD"
    }
  },
  "84532": {
    "name": "Base Sepolia",
    "isTestnet": true,
    "contracts": {
      "QEUROToken": "0x0000000000000000000000000000000000000000",
      "QuantillonVault": "0x0000000000000000000000000000000000000000",
      "QTIToken": "0x0000000000000000000000000000000000000000",
      "stQEUROToken": "0x0000000000000000000000000000000000000000",
      "ChainlinkOracle": "0x0000000000000000000000000000000000000000",
      "UserPool": "0x0000000000000000000000000000000000000000",
      "HedgerPool": "0x0000000000000000000000000000000000000000",
      "YieldShift": "0x0000000000000000000000000000000000000000",
      "USDC": "0x0000000000000000000000000000000000000000"
    }
  },
  "8453": {
    "name": "Base",
    "isTestnet": false,
    "contracts": {
      "QEUROToken": "0x0000000000000000000000000000000000000000",
      "QuantillonVault": "0x0000000000000000000000000000000000000000",
      "QTIToken": "0x0000000000000000000000000000000000000000",
      "stQEUROToken": "0x0000000000000000000000000000000000000000",
      "ChainlinkOracle": "0x0000000000000000000000000000000000000000",
      "UserPool": "0x0000000000000000000000000000000000000000",
      "HedgerPool": "0x0000000000000000000000000000000000000000",
      "YieldShift": "0x0000000000000000000000000000000000000000",
      "USDC": "0x0000000000000000000000000000000000000000"
    }
  }
}
EOF

echo -e "${GREEN}✅ Frontend addresses.json updated successfully!${NC}"
echo ""
echo -e "${BLUE}📄 Updated addresses for $NETWORK:${NC}"
echo -e "${GREEN}   MockUSDC: $MOCK_USDC${NC}"
echo -e "${GREEN}   QEUROToken: $QEURO_TOKEN${NC}"
echo -e "${GREEN}   QuantillonVault: $QUANTILLON_VAULT${NC}"
echo -e "${GREEN}   QTIToken: $QTI_TOKEN${NC}"
echo -e "${GREEN}   stQEUROToken: $STQEURO_TOKEN${NC}"
echo -e "${GREEN}   ChainlinkOracle: $CHAINLINK_ORACLE${NC}"
echo -e "${GREEN}   UserPool: $USER_POOL${NC}"
echo -e "${GREEN}   HedgerPool: $HEDGER_POOL${NC}"
echo -e "${GREEN}   YieldShift: $YIELD_SHIFT${NC}"
echo -e "${GREEN}   AaveVault: $AAVE_VAULT${NC}"
echo -e "${GREEN}   TimeProvider: $TIME_PROVIDER${NC}"
echo ""
echo -e "${BLUE}📁 Frontend addresses file: $FRONTEND_ADDRESSES_FILE${NC}"
echo -e "${GREEN}🎉 Addresses update completed!${NC}"
