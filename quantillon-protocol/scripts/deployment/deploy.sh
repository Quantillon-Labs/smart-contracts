#!/bin/bash

# =============================================================================
# QUANTILLON PROTOCOL - UNIFIED DEPLOYMENT SCRIPT
# =============================================================================
# 
# A unified deployment script that handles all networks and environments
# with built-in security using dotenvx encryption.
#
# Usage:
#   ./scripts/deployment/deploy.sh [environment] [options]
#
# Examples:
#   ./scripts/deployment/deploy.sh localhost --with-mocks
#   ./scripts/deployment/deploy.sh base-sepolia --verify
#   ./scripts/deployment/deploy.sh base --production
# =============================================================================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# =============================================================================
# CONFIGURATION
# =============================================================================

# Default values
ENVIRONMENT=""
WITH_MOCKS=false
VERIFY=false
PRODUCTION=false
DRY_RUN=false
DEPLOYMENT_SCRIPT=""
ENV_FILE=""

# Network configurations
declare -A NETWORKS=(
    ["localhost"]="http://localhost:8545|31337|Anvil Localhost"
    ["base-sepolia"]="https://sepolia.base.org|84532|Base Sepolia"
    ["base"]="https://mainnet.base.org|8453|Base Mainnet"
)

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

show_help() {
    echo -e "${BLUE}🚀 Quantillon Protocol - Unified Deployment Script${NC}"
    echo "=============================================================="
    echo ""
    echo -e "Usage:"
    echo "  $0 [environment] [options]"
    echo ""
    echo -e "Environments:"
    echo "  localhost     - Deploy to local Anvil (development)"
    echo "  base-sepolia  - Deploy to Base Sepolia (testnet)"
    echo "  base          - Deploy to Base Mainnet (production)"
    echo ""
    echo -e "Environment Files:"
    echo "  The script automatically selects environment files:"
    echo "  - .env.localhost    - For localhost deployments"
    echo "  - .env.base-sepolia - For Base Sepolia deployments"
    echo "  - .env.base         - For Base mainnet deployments"
    echo "  - .env              - Fallback default file"
    echo ""
    echo -e "Options:"
    echo "  --with-mocks     - Deploy mock contracts (localhost & testnet only)"
    echo "  --verify         - Verify contracts on block explorer (testnet & production only)"
    echo "  --production     - Use production deployment script with UUPS proxies & multisig"
    echo "  --dry-run        - Simulate deployment without broadcasting"
    echo "  --help           - Show this help message"
    echo ""
    echo -e "Examples:"
    echo "  $0 localhost --with-mocks"
    echo "  $0 base-sepolia --verify"
    echo "  $0 base --production --verify"
    echo ""
    echo -e "Environment vs Production Flag:"
    echo "  'base' environment = Deploy to Base mainnet network"
    echo "  '--production' flag = Use production deployment script (UUPS proxies + multisig)"
    echo "  You can combine them: $0 base --production --verify"
    echo ""
    echo -e "Environment Setup:"
    echo "  # For localhost deployment"
    echo "  cp .env.localhost.unencrypted .env.localhost"
    echo "  npx dotenvx encrypt -f .env.localhost.unencrypted --stdout > .env.localhost"
    echo "  $0 localhost --with-mocks"
    echo ""
    echo "  # For testnet deployment"
    echo "  cp .env.base-sepolia.unencrypted .env.base-sepolia"
    echo "  npx dotenvx encrypt -f .env.base-sepolia.unencrypted --stdout > .env.base-sepolia"
    echo "  $0 base-sepolia --verify"
    echo ""
    echo "  # For production deployment"
    echo "  cp .env.base.unencrypted .env.base"
    echo "  npx dotenvx encrypt -f .env.base.unencrypted --stdout > .env.base"
    echo "  $0 base --production --verify"
    echo ""
}

log_info() {
    echo -e "  $1"
}

log_success() {
    echo -e " $1"
}

log_warning() {
    echo -e "  $1"
}

log_error() {
    echo -e " $1"
}

log_step() {
    echo -e "🔧 $1"
}

# =============================================================================
# ENVIRONMENT VALIDATION
# =============================================================================

validate_environment() {
    if [ -z "$ENVIRONMENT" ]; then
        log_error "No environment specified"
        show_help
        exit 1
    fi

    if [[ ! ${NETWORKS[$ENVIRONMENT]+_} ]]; then
        log_error "Unknown environment: $ENVIRONMENT"
        log_info "Available environments: ${!NETWORKS[@]}"
        exit 1
    fi

    # Validate --verify flag usage
    if [ "$VERIFY" = true ] && [ "$ENVIRONMENT" = "localhost" ]; then
        log_warning "Contract verification is not supported for localhost environment"
        log_info "Ignoring --verify flag for $ENVIRONMENT"
        VERIFY=false
    fi

    # Validate --with-mocks flag usage
    if [ "$WITH_MOCKS" = true ] && [ "$ENVIRONMENT" = "base" ]; then
        log_warning "Mock contracts are not supported for production environment"
        log_info "Ignoring --with-mocks flag for $ENVIRONMENT"
        WITH_MOCKS=false
    fi
}

# =============================================================================
# SECURITY VALIDATION
# =============================================================================

validate_security() {
    log_step "Validating security configuration..."
    
    # Determine environment file to use
    local network_env_file=".env.${ENVIRONMENT}"
    local network_env_unencrypted=".env.${ENVIRONMENT}.unencrypted"
    local default_env_file=".env"
    
    # Check for unencrypted network-specific file first, then fallback to default
    if [ -f "$network_env_unencrypted" ]; then
        log_info "Found unencrypted environment file: $network_env_unencrypted"
        log_info "Encrypting environment file to: $network_env_file"
        npx dotenvx encrypt -f "$network_env_unencrypted" --stdout > "$network_env_file"
        if [ $? -eq 0 ]; then
            ENV_FILE="$network_env_file"
            log_success "Environment file encrypted successfully: $ENV_FILE"
        else
            log_error "Failed to encrypt environment file"
            exit 1
        fi
    elif [ -f "$default_env_file" ]; then
        ENV_FILE="$default_env_file"
        log_info "Using default environment file: $ENV_FILE"
    else
        log_error "No environment file found"
        log_info "Expected files: $network_env_file, $network_env_unencrypted, or $default_env_file"
        log_info "Please create an environment file for your network"
        exit 1
    fi
    
    # Check if .env.keys exists
    if [ ! -f ".env.keys" ]; then
        log_error ".env.keys file not found"
        log_info "Please ensure you have the decryption key for your encrypted .env file"
        log_info "The .env.keys file should contain your DOTENV_PRIVATE_KEY"
        exit 1
    fi

    # Check if selected .env file is encrypted
    if ! grep -q "DOTENV_PUBLIC_KEY" "$ENV_FILE"; then
        log_warning "Environment file $ENV_FILE doesn't appear to be encrypted"
        log_info "Consider running: npx dotenvx encrypt $ENV_FILE"
    fi

    log_success "Security validation passed"
}

# =============================================================================
# NETWORK VALIDATION
# =============================================================================

validate_network() {
    local network_info="${NETWORKS[$ENVIRONMENT]}"
    local rpc_url=$(echo "$network_info" | cut -d'|' -f1)
    local chain_id=$(echo "$network_info" | cut -d'|' -f2)
    local network_name=$(echo "$network_info" | cut -d'|' -f3)

    log_step "Validating network connection..."

    if [ "$ENVIRONMENT" = "localhost" ]; then
        # Check if Anvil is running
        if ! curl -s -X POST -H "Content-Type: application/json" \
             --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
             "$rpc_url" > /dev/null 2>&1; then
            log_error "Anvil is not running on $rpc_url"
            log_info "Please start Anvil: anvil --host 0.0.0.0 --port 8545"
            exit 1
        fi
        log_success "Anvil is running on $rpc_url"
    else
        # Test network connectivity
        if ! curl -s -X POST -H "Content-Type: application/json" \
             --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
             "$rpc_url" > /dev/null 2>&1; then
            log_warning "Could not connect to $network_name"
            log_info "Continuing anyway - network might be temporarily unavailable"
        else
            log_success "Connected to $network_name"
        fi
    fi
}

# =============================================================================
# DEPLOYMENT SCRIPT SELECTION
# =============================================================================

select_deployment_script() {
    log_step "Selecting deployment script..."

    if [ "$PRODUCTION" = true ]; then
        DEPLOYMENT_SCRIPT="scripts/deployment/DeployProduction.s.sol"
        log_info "Using production deployment script"
    else
        DEPLOYMENT_SCRIPT="scripts/deployment/DeployQuantillon.s.sol"
        log_info "Using standard deployment script"
    fi

    # Check if deployment script exists
    if [ ! -f "$DEPLOYMENT_SCRIPT" ]; then
        log_error "Deployment script not found: $DEPLOYMENT_SCRIPT"
        exit 1
    fi

    log_success "Deployment script: $DEPLOYMENT_SCRIPT"
}

# =============================================================================
# MOCK CONTRACTS HANDLING
# =============================================================================

deploy_mocks() {
    if [ "$WITH_MOCKS" = true ] && ([ "$ENVIRONMENT" = "localhost" ] || [ "$ENVIRONMENT" = "base-sepolia" ]); then
        log_step "Deploying mock contracts..."
        
        # Get network configuration
        local network_info="${NETWORKS[$ENVIRONMENT]}"
        local rpc_url=$(echo "$network_info" | cut -d'|' -f1)
        
        # Deploy MockUSDC
        log_info "Deploying MockUSDC..."
        npx dotenvx run --env-file="$ENV_FILE" -- forge script scripts/deployment/DeployMockUSDC.s.sol --rpc-url "$rpc_url" --broadcast
        
        # Deploy Mock Feeds
        log_info "Deploying Mock Price Feeds..."
        npx dotenvx run --env-file="$ENV_FILE" -- forge script scripts/deployment/DeployMockFeeds.s.sol --rpc-url "$rpc_url" --broadcast
        
        log_success "Mock contracts deployed"
    elif [ "$WITH_MOCKS" = true ] && [ "$ENVIRONMENT" = "base" ]; then
        log_warning "Mock contracts are not supported for production environment"
        log_info "Ignoring --with-mocks flag for $ENVIRONMENT"
    fi
}

# =============================================================================
# MAIN DEPLOYMENT
# =============================================================================

run_deployment() {
    local network_info="${NETWORKS[$ENVIRONMENT]}"
    local rpc_url=$(echo "$network_info" | cut -d'|' -f1)
    local chain_id=$(echo "$network_info" | cut -d'|' -f2)
    local network_name=$(echo "$network_info" | cut -d'|' -f3)

    log_step "Starting deployment to $network_name..."

    # Build forge command
    local forge_cmd="forge script $DEPLOYMENT_SCRIPT --rpc-url $rpc_url"
    
    if [ "$DRY_RUN" = false ]; then
        forge_cmd="$forge_cmd --broadcast"
    fi
    
    if [ "$VERIFY" = true ]; then
        forge_cmd="$forge_cmd --verify"
    fi

    # Run deployment with dotenvx using the selected environment file
    log_info "Running: $forge_cmd"
    log_info "Using environment file: $ENV_FILE"
    echo "=============================================================="
    
    npx dotenvx run --env-file="$ENV_FILE" -- $forge_cmd
    
    echo "=============================================================="
    log_success "Deployment completed successfully!"
}

# =============================================================================
# POST-DEPLOYMENT TASKS
# =============================================================================

post_deployment() {
    log_step "Running post-deployment tasks..."
    
    # Copy ABIs to frontend
    log_info "Copying ABIs to frontend..."
    ENV_FILE="$ENV_FILE" ./scripts/deployment/copy-abis.sh "$ENVIRONMENT"
    
    # Update frontend addresses
    log_info "Updating frontend addresses..."
    ENV_FILE="$ENV_FILE" ./scripts/deployment/update-frontend-addresses.sh "$ENVIRONMENT"
    
    log_success "Post-deployment tasks completed"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            localhost|base-sepolia|base)
                ENVIRONMENT="$1"
                shift
                ;;
            --with-mocks)
                WITH_MOCKS=true
                shift
                ;;
            --verify)
                VERIFY=true
                shift
                ;;
            --production)
                PRODUCTION=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # Validate and execute
    validate_environment
    validate_security
    validate_network
    select_deployment_script
    deploy_mocks
    run_deployment
    
    if [ "$DRY_RUN" = false ]; then
        post_deployment
    fi

    log_success " Deployment process completed successfully!"
}

# Run main function
main "$@"
