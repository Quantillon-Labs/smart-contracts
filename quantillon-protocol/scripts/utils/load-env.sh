#!/bin/bash

# Quantillon Protocol - Environment Variables Loader
# Shared utility for loading encrypted environment variables using dotenvx
# Usage: source scripts/utils/load-env.sh

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to load environment variables from .env file using dotenvx
load_environment_variables() {
    echo "🔐 Loading environment variables from .env file..."
    
    if command -v dotenvx >/dev/null 2>&1; then
        # Use dotenvx to decrypt and load environment variables
        # Parse the output and export only our project-specific variables
        while IFS= read -r line; do
            # Skip comments and empty lines
            if [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "$line" ]]; then
                continue
            fi
            # Check if line contains a variable we want to load
            if [[ "$line" =~ ^(RESULTS_DIR|BASESCAN_API_KEY|PRIVATE_KEY|FRONTEND_ABI_DIR|FRONTEND_ADDRESSES_FILE|SMART_CONTRACTS_OUT|MULTISIG_WALLET|NETWORK)= ]]; then
                export "$line"
            fi
        done < <(dotenvx decrypt --stdout)
        echo "✅ Environment variables loaded successfully with dotenvx"
    else
        echo "⚠️  dotenvx not found, falling back to direct .env loading"
        if [ -f ".env" ]; then
            # Fallback: load .env file directly (without decryption)
            set -a
            source .env
            set +a
        fi
    fi
}

# Function to set default values for environment variables
set_default_environment_values() {
    # Set default values for environment variables if not already set
    RESULTS_DIR="${RESULTS_DIR:-scripts/results}"
    NETWORK="${NETWORK:-localhost}"
    
    # Log the resolved values
    echo "📁 Using RESULTS_DIR: $RESULTS_DIR"
    if [ -n "$NETWORK" ] && [ "$NETWORK" != "localhost" ]; then
        echo "🌐 Using NETWORK: $NETWORK"
    fi
}

# Main function to load and configure environment variables
setup_environment() {
    load_environment_variables
    set_default_environment_values
}

# Auto-execute if script is sourced directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script is being executed directly
    setup_environment
else
    # Script is being sourced - export the functions for use
    export -f load_environment_variables
    export -f set_default_environment_values
    export -f setup_environment
fi
