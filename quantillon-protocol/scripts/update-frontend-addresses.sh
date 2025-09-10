#!/bin/bash

# Script to update frontend addresses.json with latest deployment
# Usage: ./scripts/update-frontend-addresses.sh

echo "Updating frontend addresses.json with latest deployment..."

# Define paths
FRONTEND_ADDRESSES_FILE="../../../quantillon-dapp/src/config/addresses.json"
BROADCAST_FILE="../broadcast/DeployQuantillon.s.sol/31337/run-latest.json"

# Check if broadcast file exists
if [ ! -f "$BROADCAST_FILE" ]; then
    echo "❌ Broadcast file not found: $BROADCAST_FILE"
    echo "Please run deployment first: make deploy-localhost"
    exit 1
fi

# Extract addresses using jq
echo "📋 Extracting deployment addresses..."

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
  "31337": {
    "name": "Anvil Localhost",
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
      "USDC": "0x036CbD53842c5426634e7929541eC2318f3dCF7e"
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
echo "   QEUROToken: $QEURO_TOKEN"
echo "   QuantillonVault: $QUANTILLON_VAULT"
echo "   QTIToken: $QTI_TOKEN"
echo "   stQEUROToken: $STQEURO_TOKEN"
echo "   ChainlinkOracle: $CHAINLINK_ORACLE"
echo "   UserPool: $USER_POOL"
echo "   HedgerPool: $HEDGER_POOL"
echo "   YieldShift: $YIELD_SHIFT"
