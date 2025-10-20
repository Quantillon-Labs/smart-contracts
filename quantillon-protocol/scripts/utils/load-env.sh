#!/bin/bash

# Quantillon Protocol - Environment Variables Loader
# Shared utility for loading environment variables
# Usage: source scripts/utils/load-env.sh

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to load environment variables from appropriate .env file
load_environment_variables() {
    echo "🔐 Loading environment variables..."
    
    # Determine which environment file to use
    local network="${NETWORK:-localhost}"
    local network_env_file=".env.${network}"
    local default_env_file=".env"
    
    # Check for network-specific file first, then fallback to default
    if [ -f "$network_env_file" ]; then
        echo "📁 Using network-specific environment file: $network_env_file"
        set -a
        source "$network_env_file"
        set +a
        echo "✅ Environment variables loaded successfully"
    elif [ -f "$default_env_file" ]; then
        echo "📁 Using default environment file: $default_env_file"
        set -a
        source "$default_env_file"
        set +a
        echo "✅ Environment variables loaded successfully"
    else
        echo "❌ No environment file found"
        echo "Expected files: $network_env_file or $default_env_file"
        echo "Please create an environment file for your network"
        return 1
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
