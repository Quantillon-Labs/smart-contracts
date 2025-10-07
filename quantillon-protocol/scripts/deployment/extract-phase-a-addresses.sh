#!/bin/bash

# Extract deployed addresses from Phase A broadcast and export as env vars for Phase B

BROADCAST_FILE="$1"

if [ ! -f "$BROADCAST_FILE" ]; then
    echo "Error: Broadcast file not found: $BROADCAST_FILE"
    exit 1
fi

# Simple extraction by contract name and order
export TIME_PROVIDER=$(jq -r '.transactions[] | select(.contractName == "TimeProvider") | .contractAddress' "$BROADCAST_FILE" | head -1)
export USDC=$(jq -r '.transactions[] | select(.contractName == "MockUSDC") | .contractAddress' "$BROADCAST_FILE" | head -1)

# Extract proxies by counting order (more reliable than regex matching)
PROXIES=($(jq -r '.transactions[] | select(.contractName == "ERC1967Proxy") | .contractAddress' "$BROADCAST_FILE"))

# Proxy order in Phase A: Oracle, QEURO, FeeCollector, Vault, QTI, AaveVault, stQEURO, UserPool, HedgerPool
if [ ${#PROXIES[@]} -ge 9 ]; then
    export CHAINLINK_ORACLE="${PROXIES[0]}"
    export QEURO_TOKEN="${PROXIES[1]}"
    export FEE_COLLECTOR="${PROXIES[2]}"
    export QUANTILLON_VAULT="${PROXIES[3]}"
    export QTI_TOKEN="${PROXIES[4]}"
    export AAVE_VAULT="${PROXIES[5]}"
    export STQEURO_TOKEN="${PROXIES[6]}"
    export USER_POOL="${PROXIES[7]}"
    export HEDGER_POOL="${PROXIES[8]}"
else
    echo "Warning: Expected 9 proxies, found ${#PROXIES[@]}"
fi

echo "Extracted Phase A addresses:"
echo "  TIME_PROVIDER=$TIME_PROVIDER"
echo "  CHAINLINK_ORACLE=$CHAINLINK_ORACLE"
echo "  QEURO_TOKEN=$QEURO_TOKEN"
echo "  FEE_COLLECTOR=$FEE_COLLECTOR"
echo "  QUANTILLON_VAULT=$QUANTILLON_VAULT"
echo "  QTI_TOKEN=$QTI_TOKEN"
echo "  AAVE_VAULT=$AAVE_VAULT"
echo "  STQEURO_TOKEN=$STQEURO_TOKEN"
echo "  USER_POOL=$USER_POOL"
echo "  HEDGER_POOL=$HEDGER_POOL"
echo "  USDC=$USDC"

