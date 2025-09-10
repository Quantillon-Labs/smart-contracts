#!/bin/bash

# Script to copy contract ABIs to the frontend
# Usage: ./scripts/copy-abis.sh

echo "Copying contract ABIs to frontend..."

# Define paths
FRONTEND_ABI_DIR="../../../quantillon-dapp/src/lib/contracts/abis/"
SMART_CONTRACTS_OUT="../out/"

# Create frontend ABI directory if it doesn't exist
mkdir -p "$FRONTEND_ABI_DIR"

# List of contracts to copy
contracts=("QEUROToken" "ChainlinkOracle" "QuantillonVault" "QTIToken" "stQEUROToken" "UserPool" "HedgerPool" "YieldShift")

# Copy each contract ABI
for contract in "${contracts[@]}"; do
    source_file="${SMART_CONTRACTS_OUT}${contract}.sol/${contract}.json"
    dest_file="${FRONTEND_ABI_DIR}${contract}.json"
    
    if [ -f "$source_file" ]; then
        cp "$source_file" "$dest_file"
        echo "✅ Copied ${contract} ABI"
    else
        echo "❌ ${contract} ABI not found at $source_file"
    fi
done

echo "ABI copying completed!"
echo "Frontend ABIs updated in: $FRONTEND_ABI_DIR"
