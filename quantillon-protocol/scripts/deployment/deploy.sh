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
    echo -e "${CYAN}Usage:${NC}"
    echo "  $0 [environment] [options]"
    echo ""
    echo -e "${CYAN}Environments:${NC}"
    echo "  localhost     - Deploy to local Anvil (development)"
    echo "  base-sepolia  - Deploy to Base Sepolia (testnet)"
    echo "  base          - Deploy to Base Mainnet (production)"
    echo ""
    echo -e "${CYAN}Options:${NC}"
    echo "  --with-mocks     - Deploy mock contracts (localhost only)"
    echo "  --verify         - Verify contracts on block explorer"
    echo "  --production     - Use production deployment script"
    echo "  --dry-run        - Simulate deployment without broadcasting"
    echo "  --help           - Show this help message"
    echo ""
    echo -e "${CYAN}Examples:${NC}"
    echo "  $0 localhost --with-mocks"
    echo "  $0 base-sepolia --verify"
    echo "  $0 base --production --verify"
    echo ""
}

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_step() {
    echo -e "${PURPLE}🔧 $1${NC}"
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
}

# =============================================================================
# SECURITY VALIDATION
# =============================================================================

validate_security() {
    log_step "Validating security configuration..."
    
    # Check if .env.keys exists
    if [ ! -f ".env.keys" ]; then
        log_error ".env.keys file not found"
        log_info "Please ensure you have the decryption key for your encrypted .env file"
        log_info "The .env.keys file should contain your DOTENV_PRIVATE_KEY"
        exit 1
    fi

    # Check if .env is encrypted
    if ! grep -q "DOTENV_PUBLIC_KEY" .env; then
        log_warning ".env file doesn't appear to be encrypted"
        log_info "Consider running: npx dotenvx encrypt .env"
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
    if [ "$WITH_MOCKS" = true ] && [ "$ENVIRONMENT" = "localhost" ]; then
        log_step "Deploying mock contracts..."
        
        # Get network configuration
        local network_info="${NETWORKS[$ENVIRONMENT]}"
        local rpc_url=$(echo "$network_info" | cut -d'|' -f1)
        
        # Deploy MockUSDC
        log_info "Deploying MockUSDC..."
        npx dotenvx run -- forge script scripts/deployment/DeployMockUSDC.s.sol --rpc-url "$rpc_url" --broadcast
        
        # Deploy Mock Feeds
        log_info "Deploying Mock Price Feeds..."
        npx dotenvx run -- forge script scripts/deployment/DeployMockFeeds.s.sol --rpc-url "$rpc_url" --broadcast
        
        log_success "Mock contracts deployed"
    elif [ "$WITH_MOCKS" = true ] && [ "$ENVIRONMENT" != "localhost" ]; then
        log_warning "Mock contracts are only supported for localhost environment"
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

    # Run deployment with dotenvx
    log_info "Running: $forge_cmd"
    echo "=============================================================="
    
    npx dotenvx run -- $forge_cmd
    
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
    ./scripts/deployment/copy-abis.sh "$ENVIRONMENT"
    
    # Update frontend addresses
    log_info "Updating frontend addresses..."
    ./scripts/deployment/update-frontend-addresses.sh
    
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

    log_success "🎉 Deployment process completed successfully!"
}

# Run main function
main "$@"
