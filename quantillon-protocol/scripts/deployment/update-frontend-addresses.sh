#!/bin/bash

# Script to update frontend addresses.json with latest deployment
# 
# Usage: ./scripts/deployment/update-frontend-addresses.sh [environment]
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

# Determine which env file to use (honor ENV_FILE if provided)
EFFECTIVE_ENV_FILE="${ENV_FILE:-.env}"

# Load environment variables directly


# Load environment variables from env file if it exists
# Note: Command line variables will override .env variables
if [ -f "$EFFECTIVE_ENV_FILE" ]; then
    echo -e " Loading environment variables from $EFFECTIVE_ENV_FILE file..."
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
    done < "$EFFECTIVE_ENV_FILE"
fi

echo -e " Updating frontend addresses.json with latest deployment..."

# Get flags and environment from args
PHASED_FLAG=false
WITH_MOCKS=false
ARG_ENV=""
for arg in "$@"; do
    case "$arg" in
        --phased)
            PHASED_FLAG=true
            shift
            ;;
        --with-mocks)
            WITH_MOCKS=true
            shift
            ;;
        localhost|base-sepolia|base|ethereum-sepolia|ethereum)
            ARG_ENV="$arg"
            shift
            ;;
        *)
            ;;
    esac
done

# Allow PHASED to be provided via environment variable too
if [ "${PHASED:-}" = "true" ]; then
    PHASED_FLAG=true
fi

# Environment (default localhost)
ENVIRONMENT=${ARG_ENV:-localhost}
echo -e "Environment: $ENVIRONMENT"
echo -e "Phased mode: $PHASED_FLAG"

# Allow override of phase script name for split-phase deployments
PHASE_SCRIPT_NAME="${PHASE_SCRIPT:-DeployQuantillonPhased.s.sol}"
echo -e "Phase script: $PHASE_SCRIPT_NAME"

# Define paths based on environment
# Priority: 1) Environment variables from env file, 2) Environment-specific defaults
case $ENVIRONMENT in
    "localhost")
        FRONTEND_ADDRESSES_FILE="${FRONTEND_ADDRESSES_FILE:-../../../quantillon-dapp/src/config/addresses.json}"
        ;;
    "base-sepolia")
        FRONTEND_ADDRESSES_FILE="${FRONTEND_ADDRESSES_FILE:-../../../quantillon-dapp/src/config/addresses.json}"
        ;;
    "base")
        FRONTEND_ADDRESSES_FILE="${FRONTEND_ADDRESSES_FILE:-../../../quantillon-dapp/src/config/addresses.json}"
        ;;
    "ethereum-sepolia")
        FRONTEND_ADDRESSES_FILE="${FRONTEND_ADDRESSES_FILE:-../../../quantillon-dapp/src/config/addresses.json}"
        ;;
    "ethereum")
        FRONTEND_ADDRESSES_FILE="${FRONTEND_ADDRESSES_FILE:-../../../quantillon-dapp/src/config/addresses.json}"
        ;;
    *)
        echo -e " Error: Unknown environment '$ENVIRONMENT'"
        echo -e " Usage: $0 [localhost|base-sepolia|base|ethereum-sepolia|ethereum]"
        exit 1
        ;;
esac

echo -e "📁 Frontend addresses file: $FRONTEND_ADDRESSES_FILE"

# Detect which network was deployed (check for broadcast files)
# For multi-phase deployments, check all phase broadcast files
BROADCAST_FILES=()

# Determine target network based on argument or auto-detect
if [ "$ARG_ENV" = "base-sepolia" ]; then
    TARGET_CHAIN_ID="84532"
    TARGET_NETWORK="base-sepolia"
elif [ "$ARG_ENV" = "base" ]; then
    TARGET_CHAIN_ID="8453"
    TARGET_NETWORK="base"
elif [ "$ARG_ENV" = "ethereum-sepolia" ]; then
    TARGET_CHAIN_ID="11155111"
    TARGET_NETWORK="ethereum-sepolia"
elif [ "$ARG_ENV" = "ethereum" ]; then
    TARGET_CHAIN_ID="1"
    TARGET_NETWORK="ethereum"
elif [ "$ARG_ENV" = "localhost" ]; then
    TARGET_CHAIN_ID="31337"
    TARGET_NETWORK="localhost"
else
    # Auto-detect based on available files
    if [ -f "./broadcast/DeployQuantillonPhaseA.s.sol/84532/run-latest.json" ]; then
        TARGET_CHAIN_ID="84532"
        TARGET_NETWORK="base-sepolia"
    elif [ -f "./broadcast/DeployQuantillonPhaseA.s.sol/8453/run-latest.json" ]; then
        TARGET_CHAIN_ID="8453"
        TARGET_NETWORK="base"
    elif [ -f "./broadcast/DeployQuantillonPhaseA.s.sol/11155111/run-latest.json" ]; then
        TARGET_CHAIN_ID="11155111"
        TARGET_NETWORK="ethereum-sepolia"
    elif [ -f "./broadcast/DeployQuantillonPhaseA.s.sol/1/run-latest.json" ]; then
        TARGET_CHAIN_ID="1"
        TARGET_NETWORK="ethereum"
    elif [ -f "./broadcast/DeployQuantillonPhaseA.s.sol/31337/run-latest.json" ]; then
        TARGET_CHAIN_ID="31337"
        TARGET_NETWORK="localhost"
    else
        echo -e " No deployment broadcast files found"
        exit 1
    fi
fi

if [ "$PHASED_FLAG" = true ] && [ "$PHASE_SCRIPT_NAME" = "DeployQuantillonPhased.s.sol" ]; then
    # Multi-phase deployment: check A, B, C, D
    if [ "$TARGET_CHAIN_ID" = "31337" ] && [ -f "./broadcast/DeployQuantillonPhaseA.s.sol/31337/run-latest.json" ]; then
        CHAIN_ID="31337"
        NETWORK="localhost"
        BROADCAST_FILES=(
            "./broadcast/DeployQuantillonPhaseA.s.sol/31337/run-latest.json"
            "./broadcast/DeployQuantillonPhaseB.s.sol/31337/run-latest.json"
            "./broadcast/DeployQuantillonPhaseC.s.sol/31337/run-latest.json"
            "./broadcast/DeployQuantillonPhaseD.s.sol/31337/run-latest.json"
            "./broadcast/DeployMockUSDC.s.sol/31337/run-latest.json"
        )
        echo -e "📡 Detected localhost multi-phase deployment"
    elif [ "$TARGET_CHAIN_ID" = "84532" ] && [ -f "./broadcast/DeployQuantillonPhaseA.s.sol/84532/run-latest.json" ]; then
        CHAIN_ID="84532"
        NETWORK="base-sepolia"
        BROADCAST_FILES=(
            "./broadcast/DeployQuantillonPhaseA.s.sol/84532/run-latest.json"
            "./broadcast/DeployQuantillonPhaseB.s.sol/84532/run-latest.json"
            "./broadcast/DeployQuantillonPhaseC.s.sol/84532/run-latest.json"
            "./broadcast/DeployQuantillonPhaseD.s.sol/84532/run-latest.json"
            "./broadcast/DeployMockUSDC.s.sol/84532/run-latest.json"
        )
        echo -e "📡 Detected Base Sepolia multi-phase deployment"
    elif [ "$TARGET_CHAIN_ID" = "8453" ] && [ -f "./broadcast/DeployQuantillonPhaseA.s.sol/8453/run-latest.json" ]; then
        CHAIN_ID="8453"
        NETWORK="base"
        BROADCAST_FILES=(
            "./broadcast/DeployQuantillonPhaseA.s.sol/8453/run-latest.json"
            "./broadcast/DeployQuantillonPhaseB.s.sol/8453/run-latest.json"
            "./broadcast/DeployQuantillonPhaseC.s.sol/8453/run-latest.json"
            "./broadcast/DeployQuantillonPhaseD.s.sol/8453/run-latest.json"
            "./broadcast/DeployMockUSDC.s.sol/8453/run-latest.json"
        )
        echo -e "📡 Detected Base multi-phase deployment"
    elif [ "$TARGET_CHAIN_ID" = "11155111" ] && [ -f "./broadcast/DeployQuantillonPhaseA.s.sol/11155111/run-latest.json" ]; then
        CHAIN_ID="11155111"
        NETWORK="ethereum-sepolia"
        BROADCAST_FILES=(
            "./broadcast/DeployQuantillonPhaseA.s.sol/11155111/run-latest.json"
            "./broadcast/DeployQuantillonPhaseB.s.sol/11155111/run-latest.json"
            "./broadcast/DeployQuantillonPhaseC.s.sol/11155111/run-latest.json"
            "./broadcast/DeployQuantillonPhaseD.s.sol/11155111/run-latest.json"
            "./broadcast/DeployMockUSDC.s.sol/11155111/run-latest.json"
        )
        echo -e "📡 Detected Ethereum Sepolia multi-phase deployment"
    elif [ "$TARGET_CHAIN_ID" = "1" ] && [ -f "./broadcast/DeployQuantillonPhaseA.s.sol/1/run-latest.json" ]; then
        CHAIN_ID="1"
        NETWORK="ethereum"
        BROADCAST_FILES=(
            "./broadcast/DeployQuantillonPhaseA.s.sol/1/run-latest.json"
            "./broadcast/DeployQuantillonPhaseB.s.sol/1/run-latest.json"
            "./broadcast/DeployQuantillonPhaseC.s.sol/1/run-latest.json"
            "./broadcast/DeployQuantillonPhaseD.s.sol/1/run-latest.json"
            "./broadcast/DeployMockUSDC.s.sol/1/run-latest.json"
        )
        echo -e "📡 Detected Ethereum multi-phase deployment"
    else
        echo -e " No multi-phase deployment broadcast files found for $TARGET_NETWORK"
        exit 1
    fi
elif [ "$PHASED_FLAG" = true ] && [ -f "./broadcast/DeployQuantillonPhaseA.s.sol/$TARGET_CHAIN_ID/run-latest.json" ]; then
    # Multi-phase deployment: check A, B, C, D (fallback detection)
    CHAIN_ID="$TARGET_CHAIN_ID"
    NETWORK="$TARGET_NETWORK"
    BROADCAST_FILES=(
        "./broadcast/DeployQuantillonPhaseA.s.sol/$TARGET_CHAIN_ID/run-latest.json"
        "./broadcast/DeployQuantillonPhaseB.s.sol/$TARGET_CHAIN_ID/run-latest.json"
        "./broadcast/DeployQuantillonPhaseC.s.sol/$TARGET_CHAIN_ID/run-latest.json"
        "./broadcast/DeployQuantillonPhaseD.s.sol/$TARGET_CHAIN_ID/run-latest.json"
        "./broadcast/DeployMockUSDC.s.sol/$TARGET_CHAIN_ID/run-latest.json"
    )
    echo -e "📡 Detected $TARGET_NETWORK multi-phase deployment (fallback)"
elif [ "$PHASED_FLAG" = true ]; then
    # Single-phase phased deployment
    LOCALHOST_BROADCAST="./broadcast/${PHASE_SCRIPT_NAME}/31337/run-latest.json"
    BASE_SEPOLIA_BROADCAST="./broadcast/${PHASE_SCRIPT_NAME}/84532/run-latest.json"
    if [ -f "$LOCALHOST_BROADCAST" ]; then
        BROADCAST_FILES=("$LOCALHOST_BROADCAST")
        NETWORK="localhost"
        CHAIN_ID="31337"
        echo -e "📡 Detected localhost deployment"
    elif [ -f "$BASE_SEPOLIA_BROADCAST" ]; then
        BROADCAST_FILES=("$BASE_SEPOLIA_BROADCAST")
        NETWORK="base-sepolia"
        CHAIN_ID="84532"
        echo -e "📡 Detected Base Sepolia deployment"
    else
        echo -e " No deployment broadcast file found"
        exit 1
    fi
else
    # Non-phased deployment
    LOCALHOST_BROADCAST="./broadcast/DeployQuantillon.s.sol/31337/run-latest.json"
    BASE_SEPOLIA_BROADCAST="./broadcast/DeployQuantillon.s.sol/84532/run-latest.json"
    if [ -f "$LOCALHOST_BROADCAST" ]; then
        BROADCAST_FILES=("$LOCALHOST_BROADCAST")
        NETWORK="localhost"
        CHAIN_ID="31337"
        echo -e "📡 Detected localhost deployment"
    elif [ -f "$BASE_SEPOLIA_BROADCAST" ]; then
        BROADCAST_FILES=("$BASE_SEPOLIA_BROADCAST")
        NETWORK="base-sepolia"
        CHAIN_ID="84532"
        echo -e "📡 Detected Base Sepolia deployment"
    else
        echo -e " No deployment broadcast file found"
        exit 1
    fi
fi

echo -e " Using broadcast files: ${BROADCAST_FILES[@]}"

# Extract addresses using jq
echo -e " Extracting deployment addresses..."

# Function to search for contract across all broadcast files
find_contract() {
    local contract_name="$1"
    for broadcast_file in "${BROADCAST_FILES[@]}"; do
        if [ -f "$broadcast_file" ]; then
            local result=$(jq -r ".transactions[] | select(.contractName == \"$contract_name\") | .contractAddress" "$broadcast_file" | head -1)
            if [ -n "$result" ] && [ "$result" != "null" ]; then
                echo "$result"
                return
            fi
        fi
    done
    echo ""
}

# Function to get proxy address for a given implementation address
get_proxy_address() {
    local impl_address="$1"
    # Convert to lowercase for case-insensitive comparison
    local impl_lower=$(echo "$impl_address" | tr '[:upper:]' '[:lower:]')
    for broadcast_file in "${BROADCAST_FILES[@]}"; do
        if [ -f "$broadcast_file" ]; then
            local result=$(jq -r --arg impl "$impl_lower" '.transactions[] | select(.contractName == "ERC1967Proxy" and .arguments[0] != null and (.arguments[0] | ascii_downcase) == $impl) | .contractAddress' "$broadcast_file" | head -1)
            if [ -n "$result" ] && [ "$result" != "null" ]; then
                echo "$result"
                return
            fi
        fi
    done
    echo ""
}

# Extract implementation addresses first
# Prioritize MockUSDC from DeployMockUSDC.s.sol to avoid conflicts with Phase A deployment
MOCK_USDC_IMPL=""
for broadcast_file in "${BROADCAST_FILES[@]}"; do
    if [[ "$broadcast_file" == *"DeployMockUSDC.s.sol"* ]]; then
        if [ -f "$broadcast_file" ]; then
            MOCK_USDC_IMPL=$(jq -r '.transactions[] | select(.contractName == "MockUSDC") | .contractAddress' "$broadcast_file" | head -1)
            if [ -n "$MOCK_USDC_IMPL" ] && [ "$MOCK_USDC_IMPL" != "null" ]; then
                echo "Found MockUSDC from DeployMockUSDC.s.sol: $MOCK_USDC_IMPL"
                break
            fi
        fi
    fi
done

# Fallback to searching all broadcast files if not found in DeployMockUSDC.s.sol
if [ -z "$MOCK_USDC_IMPL" ] || [ "$MOCK_USDC_IMPL" = "null" ]; then
    MOCK_USDC_IMPL=$(find_contract "MockUSDC")
fi
QEURO_TOKEN_IMPL=$(find_contract "QEUROToken")
QUANTILLON_VAULT_IMPL=$(find_contract "QuantillonVault")
QTI_TOKEN_IMPL=$(find_contract "QTIToken")
STQEURO_TOKEN_IMPL=$(find_contract "stQEUROToken")
FEE_COLLECTOR_IMPL=$(find_contract "FeeCollector")
# Handle different oracle contract names based on network and mock flag
# Try both contract names and use whichever is found and proxied
CHAINLINK_ORACLE_IMPL=$(find_contract "ChainlinkOracle")
MOCK_CHAINLINK_ORACLE_IMPL=$(find_contract "MockChainlinkOracle")
# If ChainlinkOracle not found, try MockChainlinkOracle as fallback
if [ -z "$CHAINLINK_ORACLE_IMPL" ] || [ "$CHAINLINK_ORACLE_IMPL" = "null" ]; then
    CHAINLINK_ORACLE_IMPL="$MOCK_CHAINLINK_ORACLE_IMPL"
fi
USER_POOL_IMPL=$(find_contract "UserPool")
HEDGER_POOL_IMPL=$(find_contract "HedgerPool")
YIELD_SHIFT_IMPL=$(find_contract "YieldShift")
AAVE_VAULT_IMPL=$(find_contract "AaveVault")
TIME_PROVIDER_IMPL=$(find_contract "TimeProvider")

# Get proxy addresses for upgradeable contracts
echo -e " Finding proxy addresses for upgradeable contracts..."
CHAINLINK_ORACLE=$(get_proxy_address "$CHAINLINK_ORACLE_IMPL")
QEURO_TOKEN=$(get_proxy_address "$QEURO_TOKEN_IMPL")
QUANTILLON_VAULT=$(get_proxy_address "$QUANTILLON_VAULT_IMPL")
QTI_TOKEN=$(get_proxy_address "$QTI_TOKEN_IMPL")
STQEURO_TOKEN=$(get_proxy_address "$STQEURO_TOKEN_IMPL")
FEE_COLLECTOR=$(get_proxy_address "$FEE_COLLECTOR_IMPL")
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

# Extract mock price feed addresses (search across all broadcast files)
# Get all MockAggregatorV3 contracts
MOCK_AGGREGATORS=()
for broadcast_file in "${BROADCAST_FILES[@]}"; do
    if [ -f "$broadcast_file" ]; then
        while IFS= read -r addr; do
            if [ -n "$addr" ] && [ "$addr" != "null" ]; then
                MOCK_AGGREGATORS+=("$addr")
            fi
        done < <(jq -r '.transactions[] | select(.contractName == "MockAggregatorV3") | .contractAddress' "$broadcast_file")
    fi
done

# Assign the first two MockAggregatorV3 contracts to EUR/USD and USDC/USD feeds
if [ ${#MOCK_AGGREGATORS[@]} -ge 2 ]; then
    MOCK_EUR_USD="${MOCK_AGGREGATORS[0]}"
    MOCK_USDC_USD="${MOCK_AGGREGATORS[1]}"
else
    MOCK_EUR_USD=""
    MOCK_USDC_USD=""
fi

# Fallback for MockUSDC if not found
if [ "$MOCK_USDC" = "null" ] || [ -z "$MOCK_USDC" ]; then
    echo -e "  MockUSDC not found in deployment, using placeholder address"
    MOCK_USDC="0x0000000000000000000000000000000000000000"
fi

# =============================================================================
# REAL CONTRACT ADDRESSES (when not using mocks)
# =============================================================================

# Real contract addresses for Base Sepolia
REAL_CHAINLINK_ORACLE="0x91D4a4C3D448c7f3CB477332B1c7D420a5810aC3"
REAL_USDC="0x036CbD53842c5426634e7929541eC2318f3dCF7e"

# Determine which addresses to use based on --with-mocks flag
if [ "$WITH_MOCKS" = true ]; then
    echo -e " Using MOCK contract addresses"
    FINAL_CHAINLINK_ORACLE="$CHAINLINK_ORACLE"
    FINAL_USDC="$MOCK_USDC"
    FINAL_MOCK_CHAINLINK_ORACLE="$CHAINLINK_ORACLE"
    FINAL_MOCK_USDC="$MOCK_USDC"
else
    echo -e " Using REAL contract addresses"
    FINAL_CHAINLINK_ORACLE="$REAL_CHAINLINK_ORACLE"
    FINAL_USDC="$REAL_USDC"
    FINAL_MOCK_CHAINLINK_ORACLE="$CHAINLINK_ORACLE"  # Keep mock for fallback
    FINAL_MOCK_USDC="$MOCK_USDC"  # Keep mock for fallback
fi

# Create updated addresses.json
echo -e " Creating updated addresses.json..."
cat > "$FRONTEND_ADDRESSES_FILE" << EOF
{
  "$CHAIN_ID": {
    "name": "$(if [ "$NETWORK" = "localhost" ]; then echo "Anvil Localhost"; elif [ "$NETWORK" = "base-sepolia" ]; then echo "Base Sepolia"; elif [ "$NETWORK" = "base" ]; then echo "Base Mainnet"; elif [ "$NETWORK" = "ethereum-sepolia" ]; then echo "Ethereum Sepolia"; elif [ "$NETWORK" = "ethereum" ]; then echo "Ethereum Mainnet"; else echo "Unknown Network"; fi)",
    "isTestnet": $(if [ "$NETWORK" = "localhost" ] || [ "$NETWORK" = "base-sepolia" ] || [ "$NETWORK" = "ethereum-sepolia" ]; then echo "true"; else echo "false"; fi),
    "contracts": {
      "TimeProvider": "$TIME_PROVIDER",
      "ChainlinkOracle": "$FINAL_CHAINLINK_ORACLE",
      "MockChainlinkOracle": "$FINAL_MOCK_CHAINLINK_ORACLE",
      "QEUROToken": "$QEURO_TOKEN",
      "FeeCollector": "$FEE_COLLECTOR",
      "QuantillonVault": "$QUANTILLON_VAULT",
      "QTIToken": "$QTI_TOKEN",
      "AaveVault": "$AAVE_VAULT",
      "stQEUROToken": "$STQEURO_TOKEN",
      "UserPool": "$USER_POOL",
      "HedgerPool": "$HEDGER_POOL",
      "YieldShift": "$YIELD_SHIFT",
      "USDC": "$FINAL_USDC",
      "MockUSDC": "$FINAL_MOCK_USDC",
      "MockEURUSD": "$MOCK_EUR_USD",
      "MockUSDCUSD": "$MOCK_USDC_USD"
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
