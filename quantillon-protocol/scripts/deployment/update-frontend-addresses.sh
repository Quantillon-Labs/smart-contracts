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

# Check if dotenvx is available and environment is encrypted
if [ -f ".env.keys" ] && grep -q "DOTENV_PUBLIC_KEY" .env 2>/dev/null && [ -z "$DOTENVX_RUNNING" ]; then
    # Use dotenvx for encrypted environment
    echo -e " Using encrypted environment variables"
    export DOTENVX_RUNNING=1
    exec npx dotenvx run -- "$0" "$@"
fi


# Load environment variables from .env file if it exists
# Note: Command line variables will override .env variables
if [ -f ".env" ]; then
    echo -e " Loading environment variables from .env file..."
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

echo -e " Updating frontend addresses.json with latest deployment..."

# Define paths - use .env variables if available, otherwise defaults
FRONTEND_ADDRESSES_FILE="${FRONTEND_ADDRESSES_FILE:-../../../quantillon-dapp/src/config/addresses.json}"

echo -e "📁 Frontend addresses file: $FRONTEND_ADDRESSES_FILE"

# Detect which network was deployed (check for broadcast files)
LOCALHOST_BROADCAST="./broadcast/DeployQuantillon.s.sol/31337/run-latest.json"
BASE_SEPOLIA_BROADCAST="./broadcast/DeployQuantillon.s.sol/84532/run-latest.json"

if [ -f "$LOCALHOST_BROADCAST" ]; then
    BROADCAST_FILE="$LOCALHOST_BROADCAST"
    NETWORK="localhost"
    CHAIN_ID="31337"
    echo -e "📡 Detected localhost deployment"
elif [ -f "$BASE_SEPOLIA_BROADCAST" ]; then
    BROADCAST_FILE="$BASE_SEPOLIA_BROADCAST"
    NETWORK="base-sepolia"
    CHAIN_ID="84532"
    echo -e "📡 Detected Base Sepolia deployment"
else
    echo -e " No deployment broadcast file found"
    echo -e " Please run deployment first:"
    echo -e "   make deploy-localhost (for localhost)"
    echo -e "   make deploy-base-sepolia (for Base Sepolia)"
    exit 1
fi

echo -e " Using broadcast file: $BROADCAST_FILE"

# Extract addresses using jq
echo -e " Extracting deployment addresses..."

# Function to get proxy address for a given implementation address
get_proxy_address() {
    local impl_address="$1"
    # Convert to lowercase for case-insensitive comparison
    local impl_lower=$(echo "$impl_address" | tr '[:upper:]' '[:lower:]')
    jq -r --arg impl "$impl_lower" '.transactions[] | select(.contractName == "ERC1967Proxy" and .arguments[0] != null and (.arguments[0] | ascii_downcase) == $impl) | .contractAddress' "$BROADCAST_FILE" | head -1
}

# Extract implementation addresses first
MOCK_USDC_IMPL=$(jq -r '.transactions[] | select(.contractName == "MockUSDC") | .contractAddress' "$BROADCAST_FILE" | head -1)
QEURO_TOKEN_IMPL=$(jq -r '.transactions[] | select(.contractName == "QEUROToken") | .contractAddress' "$BROADCAST_FILE" | tail -1)  # Get the real QEURO token (last one)
QUANTILLON_VAULT_IMPL=$(jq -r '.transactions[] | select(.contractName == "QuantillonVault") | .contractAddress' "$BROADCAST_FILE" | head -1)
QTI_TOKEN_IMPL=$(jq -r '.transactions[] | select(.contractName == "QTIToken") | .contractAddress' "$BROADCAST_FILE" | head -1)
STQEURO_TOKEN_IMPL=$(jq -r '.transactions[] | select(.contractName == "stQEUROToken") | .contractAddress' "$BROADCAST_FILE" | head -1)
# Handle different oracle contract names based on network
if [ "$NETWORK" = "localhost" ]; then
    CHAINLINK_ORACLE_IMPL=$(jq -r '.transactions[] | select(.contractName == "MockChainlinkOracle") | .contractAddress' "$BROADCAST_FILE" | head -1)
else
    CHAINLINK_ORACLE_IMPL=$(jq -r '.transactions[] | select(.contractName == "ChainlinkOracle") | .contractAddress' "$BROADCAST_FILE" | head -1)
fi
USER_POOL_IMPL=$(jq -r '.transactions[] | select(.contractName == "UserPool") | .contractAddress' "$BROADCAST_FILE" | head -1)
HEDGER_POOL_IMPL=$(jq -r '.transactions[] | select(.contractName == "HedgerPool") | .contractAddress' "$BROADCAST_FILE" | head -1)
YIELD_SHIFT_IMPL=$(jq -r '.transactions[] | select(.contractName == "YieldShift") | .contractAddress' "$BROADCAST_FILE" | head -1)
AAVE_VAULT_IMPL=$(jq -r '.transactions[] | select(.contractName == "AaveVault") | .contractAddress' "$BROADCAST_FILE" | head -1)
TIME_PROVIDER_IMPL=$(jq -r '.transactions[] | select(.contractName == "TimeProvider") | .contractAddress' "$BROADCAST_FILE" | head -1)

# Get proxy addresses for upgradeable contracts
echo -e " Finding proxy addresses for upgradeable contracts..."
CHAINLINK_ORACLE=$(get_proxy_address "$CHAINLINK_ORACLE_IMPL")
QEURO_TOKEN=$(get_proxy_address "$QEURO_TOKEN_IMPL")
QUANTILLON_VAULT=$(get_proxy_address "$QUANTILLON_VAULT_IMPL")
QTI_TOKEN=$(get_proxy_address "$QTI_TOKEN_IMPL")
STQEURO_TOKEN=$(get_proxy_address "$STQEURO_TOKEN_IMPL")
USER_POOL=$(get_proxy_address "$USER_POOL_IMPL")
HEDGER_POOL=$(get_proxy_address "$HEDGER_POOL_IMPL")
YIELD_SHIFT=$(get_proxy_address "$YIELD_SHIFT_IMPL")
AAVE_VAULT=$(get_proxy_address "$AAVE_VAULT_IMPL")

# Non-upgradeable contracts use implementation addresses directly
MOCK_USDC="$MOCK_USDC_IMPL"
TIME_PROVIDER="$TIME_PROVIDER_IMPL"

# Validate that all proxy addresses were found
echo -e " Validating proxy addresses..."
if [ "$CHAINLINK_ORACLE" = "null" ] || [ -z "$CHAINLINK_ORACLE" ]; then
    echo -e " Failed to find ChainlinkOracle proxy address"
    exit 1
fi
if [ "$QEURO_TOKEN" = "null" ] || [ -z "$QEURO_TOKEN" ]; then
    echo -e " Failed to find QEUROToken proxy address"
    exit 1
fi
if [ "$QUANTILLON_VAULT" = "null" ] || [ -z "$QUANTILLON_VAULT" ]; then
    echo -e " Failed to find QuantillonVault proxy address"
    exit 1
fi
if [ "$USER_POOL" = "null" ] || [ -z "$USER_POOL" ]; then
    echo -e " Failed to find UserPool proxy address"
    exit 1
fi

echo -e " All proxy addresses found successfully"

# Extract mock price feed addresses
MOCK_EUR_USD=$(jq -r '.transactions[] | select(.contractName == "MockAggregatorV3") | .contractAddress' "$BROADCAST_FILE" | head -1)
MOCK_USDC_USD=$(jq -r '.transactions[] | select(.contractName == "MockAggregatorV3") | .contractAddress' "$BROADCAST_FILE" | tail -1)

# Fallback for MockUSDC if not found
if [ "$MOCK_USDC" = "null" ] || [ -z "$MOCK_USDC" ]; then
    echo -e "  MockUSDC not found in deployment, using placeholder address"
    MOCK_USDC="0x0000000000000000000000000000000000000000"
fi

# Create updated addresses.json
echo -e " Creating updated addresses.json..."
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
      "MockChainlinkOracle": "$CHAINLINK_ORACLE",
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

echo -e " Frontend addresses.json updated successfully!"
echo ""
echo -e " Updated addresses for $NETWORK (using proxy addresses for upgradeable contracts):"
echo -e "   MockUSDC: $MOCK_USDC"
echo -e "   QEUROToken (proxy): $QEURO_TOKEN"
echo -e "   QuantillonVault (proxy): $QUANTILLON_VAULT"
echo -e "   QTIToken (proxy): $QTI_TOKEN"
echo -e "   stQEUROToken (proxy): $STQEURO_TOKEN"
echo -e "   ChainlinkOracle (proxy): $CHAINLINK_ORACLE"
echo -e "   UserPool (proxy): $USER_POOL"
echo -e "   HedgerPool (proxy): $HEDGER_POOL"
echo -e "   YieldShift (proxy): $YIELD_SHIFT"
echo -e "   AaveVault (proxy): $AAVE_VAULT"
echo -e "   TimeProvider: $TIME_PROVIDER"
echo ""
echo -e " Implementation addresses (for reference):"
echo -e "   QEUROToken impl: $QEURO_TOKEN_IMPL"
echo -e "   QuantillonVault impl: $QUANTILLON_VAULT_IMPL"
echo -e "   UserPool impl: $USER_POOL_IMPL"
echo -e "   ChainlinkOracle impl: $CHAINLINK_ORACLE_IMPL"
echo ""
echo -e "📁 Frontend addresses file: $FRONTEND_ADDRESSES_FILE"
echo -e " Addresses update completed!"
