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

# GitHub Actions checks out encrypted files when git-crypt keys are unavailable.
# Guard against sourcing encrypted .env files in CI-only analysis jobs.
is_sourceable_env_file() {
    local env_file="$1"

    while IFS= read -r line || [ -n "$line" ]; do
        local trimmed_line="${line#"${line%%[![:space:]]*}"}"

        if [ -z "$trimmed_line" ] || [[ "$trimmed_line" == \#* ]]; then
            continue
        fi

        if [[ ! "$trimmed_line" =~ ^(export[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*= ]]; then
            return 1
        fi
    done < "$env_file"

    return 0
}

# Function to load environment variables from appropriate .env file
load_environment_variables() {
    local allow_missing="${1:-false}"

    echo "🔐 Loading environment variables..."
    
    # Determine which environment file to use
    local network="${NETWORK:-localhost}"
    local network_env_file=".env.${network}"
    local default_env_file=".env"

    local env_file
    for env_file in "$network_env_file" "$default_env_file"; do
        if [ ! -f "$env_file" ]; then
            continue
        fi

        if ! is_sourceable_env_file "$env_file"; then
            echo "⚠️  Skipping unreadable or encrypted environment file: $env_file"
            continue
        fi

        if [ "$env_file" = "$network_env_file" ]; then
            echo "📁 Using network-specific environment file: $network_env_file"
        else
            echo "📁 Using default environment file: $default_env_file"
        fi

        set -a
        source "$env_file"
        set +a
        echo "✅ Environment variables loaded successfully"
        return 0
    done

    if [ "$allow_missing" = "true" ]; then
        echo "⚠️  No readable environment file found; continuing with defaults"
        return 0
    fi

    echo "❌ No readable environment file found"
    echo "Expected files: $network_env_file or $default_env_file"
    echo "Please create or decrypt an environment file for your network"
    return 1
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
    local allow_missing="false"

    if [ "${1:-}" = "--allow-missing" ]; then
        allow_missing="true"
    fi

    load_environment_variables "$allow_missing"
    set_default_environment_values
}

# Auto-execute if script is sourced directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script is being executed directly
    setup_environment
else
    # Script is being sourced - export the functions for use
    export -f is_sourceable_env_file
    export -f load_environment_variables
    export -f set_default_environment_values
    export -f setup_environment
fi
