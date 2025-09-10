#!/bin/bash

# Script to update frontend addresses.json with latest deployment
# Usage: ./scripts/update-frontend-addresses.sh

echo "Updating frontend addresses.json with latest deployment..."

# Define paths
FRONTEND_ADDRESSES_FILE="../../../quantillon-dapp/src/config/addresses.json"

# Detect which network was deployed (check for broadcast files)
LOCALHOST_BROADCAST="../broadcast/DeployQuantillon.s.sol/31337/run-latest.json"
BASE_SEPOLIA_BROADCAST="../broadcast/DeployQuantillon.s.sol/84532/run-latest.json"

if [ -f "$LOCALHOST_BROADCAST" ]; then
    BROADCAST_FILE="$LOCALHOST_BROADCAST"
    NETWORK="localhost"
    CHAIN_ID="31337"
    echo "📡 Detected localhost deployment"
elif [ -f "$BASE_SEPOLIA_BROADCAST" ]; then
    BROADCAST_FILE="$BASE_SEPOLIA_BROADCAST"
    NETWORK="base-sepolia"
    CHAIN_ID="84532"
    echo "📡 Detected Base Sepolia deployment"
else
    echo "❌ No deployment broadcast file found"
    echo "Please run deployment first:"
    echo "  make deploy-localhost (for localhost)"
    echo "  make deploy-base-sepolia (for Base Sepolia)"
    exit 1
fi

echo "Using broadcast file: $BROADCAST_FILE"

# Extract addresses using jq
echo "📋 Extracting deployment addresses..."

MOCK_USDC=$(jq -r '.transactions[] | select(.contractName == "MockUSDC") | .contractAddress' "$BROADCAST_FILE" | head -1)

# Fallback for MockUSDC if not found
if [ "$MOCK_USDC" = "null" ] || [ -z "$MOCK_USDC" ]; then
    echo "⚠️  MockUSDC not found in deployment, using placeholder address"
    MOCK_USDC="0x0000000000000000000000000000000000000000"
fi
QEURO_TOKEN=$(jq -r '.transactions[] | select(.contractName == "QEUROToken") | .contractAddress' "$BROADCAST_FILE" | head -1)
QUANTILLON_VAULT=$(jq -r '.transactions[] | select(.contractName == "QuantillonVault") | .contractAddress' "$BROADCAST_FILE" | head -1)
QTI_TOKEN=$(jq -r '.transactions[] | select(.contractName == "QTIToken") | .contractAddress' "$BROADCAST_FILE" | head -1)
STQEURO_TOKEN=$(jq -r '.transactions[] | select(.contractName == "stQEUROToken") | .contractAddress' "$BROADCAST_FILE" | head -1)
CHAINLINK_ORACLE=$(jq -r '.transactions[] | select(.contractName == "ChainlinkOracle") | .contractAddress' "$BROADCAST_FILE" | head -1)
USER_POOL=$(jq -r '.transactions[] | select(.contractName == "UserPool") | .contractAddress' "$BROADCAST_FILE" | head -1)
HEDGER_POOL=$(jq -r '.transactions[] | select(.contractName == "HedgerPool") | .contractAddress' "$BROADCAST_FILE" | head -1)
YIELD_SHIFT=$(jq -r '.transactions[] | select(.contractName == "YieldShift") | .contractAddress' "$BROADCAST_FILE" | head -1)

# Create updated addresses.json
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
      "USDC": "$MOCK_USDC"
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

echo "✅ Frontend addresses.json updated successfully!"
echo "📄 Updated addresses:"
echo "   MockUSDC: $MOCK_USDC"
echo "   QEUROToken: $QEURO_TOKEN"
echo "   QuantillonVault: $QUANTILLON_VAULT"
echo "   QTIToken: $QTI_TOKEN"
echo "   stQEUROToken: $STQEURO_TOKEN"
echo "   ChainlinkOracle: $CHAINLINK_ORACLE"
echo "   UserPool: $USER_POOL"
echo "   HedgerPool: $HEDGER_POOL"
echo "   YieldShift: $YIELD_SHIFT"
