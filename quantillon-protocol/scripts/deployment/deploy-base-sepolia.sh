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

# Deploy contracts in phases to respect per-tx gas cap
echo -e " Deploying contracts to Base Sepolia..."
echo "======================================================"

# Use dotenvx environment to run forge with decrypted env vars (mirrors localhost script behavior)
# Force legacy txs and explicit gas price to respect per-tx gas cap
# Allow overriding GAS_PRICE via env (e.g., GAS_PRICE=0.25gwei)
GAS_PRICE_ARG=${GAS_PRICE:-0.20gwei}

refresh_broadcast() {
    local dir="broadcast/DeployQuantillon.s.sol"
    if [ -d "$dir" ]; then
        # most recent run-latest.json by mtime
        LATEST_RUN=$(find "$dir" -type f -name "run-latest.json" -printf '%T@ %p\n' | sort -nr | awk 'NR==1{print $2}')
    else
        LATEST_RUN=""
    fi
}

# Resolve latest known address for a given contract name across all recent broadcasts
get_addr() {
    local name="$1"
    local dir="broadcast/DeployQuantillon.s.sol"
    local found=""
    if [ -d "$dir" ]; then
        # search most-recent JSONs first
        while IFS= read -r json; do
            addr=$(jq -r ".transactions[] | select(.contractName == \"$name\") | .contractAddress" "$json" 2>/dev/null | tail -1)
            if [ -n "$addr" ] && [ "$addr" != "null" ]; then
                found="$addr"; break
            fi
        done < <(find "$dir" -type f -name "*.json" -printf '%T@ %p\n' | sort -nr | awk '{print $2}')
    fi
    echo "$found"
}

# Set a VAR to latest non-empty address for CONTRACT if found (do not overwrite with empty)
set_if_present() {
    local varname="$1"; shift
    local contract="$1"
    local val
    val=$(get_addr "$contract")
    if [ -n "$val" ] && [ "$val" != "null" ]; then
        eval "$varname=$val"
    fi
}

run_phase() {
    PHASE_NAME="$1"
    shift
    echo -e " Running $PHASE_NAME..."
    # Pass phase flags as env var prefixes before the command
    if USE_PHASE1=$USE_PHASE1_FLAG USE_PHASE2=$USE_PHASE2_FLAG USE_PHASE3=$USE_PHASE3_FLAG USE_PHASE4=$USE_PHASE4_FLAG USE_PHASE5=$USE_PHASE5_FLAG \
       TIME_PROVIDER="$TIME_PROVIDER_VAL" CHAINLINK_ORACLE="$CHAINLINK_ORACLE_VAL" QEURO_TOKEN="$QEURO_TOKEN_VAL" FEE_COLLECTOR="$FEE_COLLECTOR_VAL" QUANTILLON_VAULT="$QUANTILLON_VAULT_VAL" \
       USER_POOL="$USER_POOL_VAL" HEDGER_POOL="$HEDGER_POOL_VAL" STQEURO_TOKEN="$STQEURO_TOKEN_VAL" AAVE_VAULT="$AAVE_VAULT_VAL" YIELDSHIFT="$YIELDSHIFT_VAL" \
       npx dotenvx run -- forge script "$DEPLOYMENT_SCRIPT" --rpc-url "$RPC_URL" --legacy --with-gas-price "$GAS_PRICE_ARG" --gas-limit 25000000 --broadcast; then
        echo -e " $PHASE_NAME completed"
    else
        echo -e " $PHASE_NAME failed"
        exit 1
    fi
}

# Phase 1
USE_PHASE1_FLAG=true; USE_PHASE2_FLAG=false; USE_PHASE3_FLAG=false; USE_PHASE4_FLAG=false; USE_PHASE5_FLAG=false
TIME_PROVIDER_VAL=""; CHAINLINK_ORACLE_VAL=""; QEURO_TOKEN_VAL=""; FEE_COLLECTOR_VAL=""; QUANTILLON_VAULT_VAL=""; USER_POOL_VAL=""; HEDGER_POOL_VAL=""; STQEURO_TOKEN_VAL=""; AAVE_VAULT_VAL=""; YIELDSHIFT_VAL=""
run_phase "Phase 1"
refresh_broadcast
# Persist core addresses snapshot from Phase 1 to a session file to avoid overwrites by later runs
PHASE_FILE="$RESULTS_DIR/phase-addresses.json"
mkdir -p "$RESULTS_DIR"
CORE_TIME_PROVIDER=$(jq -r '.transactions[] | select(.contractName == "TimeProvider") | .contractAddress' "$LATEST_RUN" 2>/dev/null || echo "")
CORE_ORACLE=$(jq -r '.transactions[] | select(.contractName == "ChainlinkOracle" or .contractName == "MockChainlinkOracle") | .contractAddress' "$LATEST_RUN" 2>/dev/null || echo "")
CORE_QEURO=$(jq -r '.transactions[] | select(.contractName == "QEUROToken") | .contractAddress' "$LATEST_RUN" 2>/dev/null || echo "")
CORE_FEE_COLLECTOR=$(jq -r '.transactions[] | select(.contractName == "FeeCollector") | .contractAddress' "$LATEST_RUN" 2>/dev/null || echo "")
CORE_VAULT=$(jq -r '.transactions[] | select(.contractName == "QuantillonVault") | .contractAddress' "$LATEST_RUN" 2>/dev/null || echo "")
cat > "$PHASE_FILE" <<EOF
{
  "TimeProvider": "$CORE_TIME_PROVIDER",
  "ChainlinkOracle": "$CORE_ORACLE",
  "QEUROToken": "$CORE_QEURO",
  "FeeCollector": "$CORE_FEE_COLLECTOR",
  "QuantillonVault": "$CORE_VAULT"
}
EOF

# Phase 2
USE_PHASE1_FLAG=false; USE_PHASE2_FLAG=true; USE_PHASE3_FLAG=false; USE_PHASE4_FLAG=false; USE_PHASE5_FLAG=false
# Inject addresses from Phase 1 snapshot (never blank them accidentally)
TIME_PROVIDER_VAL=$(jq -r '.TimeProvider' "$PHASE_FILE")
CHAINLINK_ORACLE_VAL=$(jq -r '.ChainlinkOracle' "$PHASE_FILE")
QEURO_TOKEN_VAL=$(jq -r '.QEUROToken' "$PHASE_FILE")
FEE_COLLECTOR_VAL=$(jq -r '.FeeCollector' "$PHASE_FILE")
QUANTILLON_VAULT_VAL=$(jq -r '.QuantillonVault' "$PHASE_FILE")
run_phase "Phase 2"
refresh_broadcast
# Append Phase 2 outputs to snapshot
PH2_STQ=$(jq -r '.transactions[] | select(.contractName == "stQEUROToken") | .contractAddress' "$LATEST_RUN" 2>/dev/null || echo "")
PH2_AAVE=$(jq -r '.transactions[] | select(.contractName == "AaveVault") | .contractAddress' "$LATEST_RUN" 2>/dev/null || echo "")
jq --arg st "$PH2_STQ" --arg av "$PH2_AAVE" '. + {"stQEUROToken": $st, "AaveVault": $av}' "$PHASE_FILE" > "$PHASE_FILE.tmp" && mv "$PHASE_FILE.tmp" "$PHASE_FILE"

# Phase 3
USE_PHASE1_FLAG=false; USE_PHASE2_FLAG=false; USE_PHASE3_FLAG=true; USE_PHASE4_FLAG=false; USE_PHASE5_FLAG=false
USER_POOL_VAL=""; HEDGER_POOL_VAL=""; STQEURO_TOKEN_VAL=$(jq -r '.stQEUROToken' "$PHASE_FILE") ; AAVE_VAULT_VAL=$(jq -r '.AaveVault' "$PHASE_FILE")
run_phase "Phase 3"
refresh_broadcast
# Append Phase 3 outputs to snapshot
PH3_USER=$(jq -r '.transactions[] | select(.contractName == "UserPool") | .contractAddress' "$LATEST_RUN" 2>/dev/null || echo "")
PH3_HEDGER=$(jq -r '.transactions[] | select(.contractName == "HedgerPool") | .contractAddress' "$LATEST_RUN" 2>/dev/null || echo "")
PH3_YIELD=$(jq -r '.transactions[] | select(.contractName == "YieldShift") | .contractAddress' "$LATEST_RUN" 2>/dev/null || echo "")
jq --arg up "$PH3_USER" --arg hp "$PH3_HEDGER" --arg ys "$PH3_YIELD" '. + {"UserPool": $up, "HedgerPool": $hp, "YieldShift": $ys}' "$PHASE_FILE" > "$PHASE_FILE.tmp" && mv "$PHASE_FILE.tmp" "$PHASE_FILE"

# Phase 4
USE_PHASE1_FLAG=false; USE_PHASE2_FLAG=false; USE_PHASE3_FLAG=false; USE_PHASE4_FLAG=true; USE_PHASE5_FLAG=false
# Pull everything from snapshot
TIME_PROVIDER_VAL=$(jq -r '.TimeProvider' "$PHASE_FILE")
CHAINLINK_ORACLE_VAL=$(jq -r '.ChainlinkOracle' "$PHASE_FILE")
QEURO_TOKEN_VAL=$(jq -r '.QEUROToken' "$PHASE_FILE")
FEE_COLLECTOR_VAL=$(jq -r '.FeeCollector' "$PHASE_FILE")
QUANTILLON_VAULT_VAL=$(jq -r '.QuantillonVault' "$PHASE_FILE")
USER_POOL_VAL=$(jq -r '.UserPool' "$PHASE_FILE")
HEDGER_POOL_VAL=$(jq -r '.HedgerPool' "$PHASE_FILE")
run_phase "Phase 4"

# Phase 5
USE_PHASE1_FLAG=false; USE_PHASE2_FLAG=false; USE_PHASE3_FLAG=false; USE_PHASE4_FLAG=false; USE_PHASE5_FLAG=true
# Capture core + YieldShift from snapshot
TIME_PROVIDER_VAL=$(jq -r '.TimeProvider' "$PHASE_FILE")
CHAINLINK_ORACLE_VAL=$(jq -r '.ChainlinkOracle' "$PHASE_FILE")
QEURO_TOKEN_VAL=$(jq -r '.QEUROToken' "$PHASE_FILE")
FEE_COLLECTOR_VAL=$(jq -r '.FeeCollector' "$PHASE_FILE")
QUANTILLON_VAULT_VAL=$(jq -r '.QuantillonVault' "$PHASE_FILE")
YIELDSHIFT_VAL=$(jq -r '.YieldShift' "$PHASE_FILE")
run_phase "Phase 5"

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

# Automatically update frontend with new ABIs and addresses (mirrors localhost script behavior)
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
