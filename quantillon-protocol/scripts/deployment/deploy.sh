#!/bin/bash

# =============================================================================
# QUANTILLON PROTOCOL - UNIFIED DEPLOYMENT SCRIPT
# =============================================================================
# 
# A unified deployment script that handles all networks and environments
# with built-in security using standard environment variables.
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
DRY_RUN=false
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

clean_deployment_artifacts() {
    log_step "Cleaning deployment artifacts..."
    
    # Clean broadcast folder
    if [ -d "broadcast" ]; then
        log_info "Removing broadcast folder..."
        rm -rf broadcast
        log_success "Broadcast folder cleaned"
    else
        log_info "No broadcast folder found (clean state)"
    fi
    
    # Clean cache folder
    if [ -d "cache" ]; then
        log_info "Removing cache folder..."
        rm -rf cache
        log_success "Cache folder cleaned"
    else
        log_info "No cache folder found (clean state)"
    fi
    
    log_success "Deployment artifacts cleaned successfully"
}

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
    echo "  --verify         - Verify contracts on block explorer (testnet & mainnet)"
    echo "  --dry-run        - Simulate deployment without broadcasting"
    echo "  --help           - Show this help message"
    echo ""
    echo -e "Examples:"
    echo "  $0 localhost --with-mocks"
    echo "  $0 base-sepolia --with-mocks --verify"
    echo "  $0 base --verify"
    echo ""
    echo -e "Deployment Method:"
    echo "  All deployments use multi-phase atomic deployment (A→B→C→D)"
    echo "  Each phase stays within the 24.9M gas limit per transaction"
    echo ""
    echo -e "Environment Setup:"
    echo "  # For localhost deployment"
    echo "  cp .env.localhost .env"
    echo "  $0 localhost --with-mocks"
    echo ""
    echo "  # For testnet deployment"
    echo "  cp .env.base-sepolia .env"
    echo "  $0 base-sepolia --verify"
    echo ""
    echo "  # For Base mainnet deployment"
    echo "  cp .env.base .env"
    echo "  $0 base --verify"
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
    local network_env_source=".env.$(echo ${ENVIRONMENT} | tr '-' '_')"
    local default_env_file=".env"
    
    # Check for network-specific file first, then fallback to default
    if [ -f "$network_env_file" ]; then
        log_info "Found environment file: $network_env_file"
        ENV_FILE="$network_env_file"
        log_success "Using environment file: $ENV_FILE"
    elif [ -f "$network_env_source" ] && [ "$network_env_source" != "$network_env_file" ]; then
        log_info "Found environment file: $network_env_source"
        log_info "Copying to: $network_env_file"
        cp "$network_env_source" "$network_env_file"
        if [ $? -eq 0 ]; then
            ENV_FILE="$network_env_file"
            log_success "Environment file copied successfully: $ENV_FILE"
        else
            log_error "Failed to copy environment file"
            exit 1
        fi
    elif [ -f "$default_env_file" ]; then
        ENV_FILE="$default_env_file"
        log_info "Using default environment file: $ENV_FILE"
    else
        log_error "No environment file found"
        log_info "Expected files: $network_env_file, $network_env_source, or $default_env_file"
        log_info "Please create an environment file for your network"
        exit 1
    fi
    
    # Validate environment file exists and is readable
    log_info "Using environment file: $ENV_FILE"

    # Create symlink for Foundry to find the environment file
    if [ -f "$ENV_FILE" ] && [ "$ENV_FILE" != ".env" ]; then
        ln -sf "$ENV_FILE" .env
        log_info "Created symlink: .env -> $ENV_FILE"
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
    # Always use multi-phase deployment (A→B→C→D)
    # No single script file; phases are handled in run_deployment()
    log_info "Using multi-phase deployment (A→B→C→D)"
    log_success "Deployment: 4 atomic phases"
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
        if [ "$ENVIRONMENT" = "base-sepolia" ]; then
            forge script scripts/deployment/DeployMockUSDC.s.sol --rpc-url "$rpc_url" --broadcast --gas-price 2000000000
        else
            forge script scripts/deployment/DeployMockUSDC.s.sol --rpc-url "$rpc_url" --broadcast
        fi
        
        # Deploy Mock Feeds
        log_info "Deploying Mock Price Feeds..."
        if [ "$ENVIRONMENT" = "base-sepolia" ]; then
            forge script scripts/deployment/DeployMockFeeds.s.sol --rpc-url "$rpc_url" --broadcast --gas-price 2000000000
        else
            forge script scripts/deployment/DeployMockFeeds.s.sol --rpc-url "$rpc_url" --broadcast
        fi
        
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

    local effective_gas_limit="${GAS_LIMIT:-24900000}"
    local effective_profile="${FOUNDRY_PROFILE:-default}"
    export FOUNDRY_PROFILE="$effective_profile"

    # Always use multi-phase deployment (A→B→C→D) - only method that fits gas cap
    log_info "Running split-phase deployment (A → B → C → D)..."
        
        # Phase A: Core infrastructure
        local phase_a_script="scripts/deployment/DeployQuantillonPhaseA.s.sol"
        local forge_cmd_a1="forge script $phase_a_script --rpc-url $rpc_url --gas-limit $effective_gas_limit"
        if [ "$ENVIRONMENT" = "base-sepolia" ]; then
            forge_cmd_a1="$forge_cmd_a1 --gas-price 2000000000"
        fi
        if [ "$DRY_RUN" = false ]; then forge_cmd_a1="$forge_cmd_a1 --broadcast"; fi
        if [ "$VERIFY" = true ]; then forge_cmd_a1="$forge_cmd_a1 --verify"; fi
        
        log_info "Phase A: Core Infrastructure"
        echo "=============================================================="
        
        # Extract USDC from DeployMockUSDC if it exists (for localhost/testnet with mocks)
        local mock_usdc_broadcast="./broadcast/DeployMockUSDC.s.sol/${chain_id}/run-latest.json"
        if [ -f "$mock_usdc_broadcast" ]; then
            export USDC=$(jq -r '.transactions[] | select(.contractName == "MockUSDC") | .contractAddress' "$mock_usdc_broadcast" | head -1)
            log_info "Using USDC from DeployMockUSDC: $USDC"
        fi
        
        if [ "$WITH_MOCKS" = true ]; then
            env WITH_MOCKS=true USDC="$USDC" $forge_cmd_a1
        else
            env WITH_MOCKS=false USDC="$USDC" $forge_cmd_a1
        fi
        echo "=============================================================="
        
        # Extract A1 addresses
        local phase_a_broadcast="./broadcast/DeployQuantillonPhaseA.s.sol/${chain_id}/run-latest.json"
        if [ ! -f "$phase_a_broadcast" ]; then
            log_error "Phase A broadcast not found"
            exit 1
        fi
        
        # Export A1 addresses for A2 (unique proxies preserving creation order)
        export TIME_PROVIDER=$(jq -r '.transactions[] | select(.contractName == "TimeProvider") | .contractAddress' "$phase_a_broadcast" | head -1)
        # USDC is already set from DeployMockUSDC step, no need to extract from Phase A
        
        # Debug: Log the extracted addresses
        log_info "Extracted addresses from Phase A:"
        log_info "TIME_PROVIDER: $TIME_PROVIDER"
        log_info "USDC: $USDC"
        PROXIES_A=($(jq -r '.transactions[] | select(.contractName == "ERC1967Proxy" and .transactionType == "CREATE") | .contractAddress' "$phase_a_broadcast"))
        
        # Debug: Log the PROXIES_A array
        log_info "PROXIES_A array contents:"
        for i in "${!PROXIES_A[@]}"; do
            log_info "PROXIES_A[$i]: ${PROXIES_A[$i]}"
        done
        
        export CHAINLINK_ORACLE="${PROXIES_A[0]}"
        export QEURO_TOKEN="${PROXIES_A[1]}"
        export FEE_COLLECTOR="${PROXIES_A[2]}"
        export QUANTILLON_VAULT="${PROXIES_A[3]}"
        
        # If QuantillonVault is not in the proxy array, extract it directly
        if [ -z "$QUANTILLON_VAULT" ] || [ "$QUANTILLON_VAULT" = "null" ]; then
            # Extract the QuantillonVault proxy address from the broadcast file
            # Look for the ERC1967Proxy that was created for QuantillonVault
            export QUANTILLON_VAULT=$(jq -r '.transactions[] | select(.contractName == "ERC1967Proxy") | .contractAddress' "$phase_a_broadcast" | tail -1)
            log_info "Extracted QuantillonVault directly: $QUANTILLON_VAULT"
        fi
        
        log_info "Phase A completed. Starting B..."
        
        # Phase B: Core protocol
        local phase_b_script="scripts/deployment/DeployQuantillonPhaseB.s.sol"
        local forge_cmd_b="forge script $phase_b_script --rpc-url $rpc_url --gas-limit $effective_gas_limit"
        if [ "$ENVIRONMENT" = "base-sepolia" ]; then
            forge_cmd_b="$forge_cmd_b --gas-price 2000000000"
        fi
        if [ "$DRY_RUN" = false ]; then forge_cmd_b="$forge_cmd_b --broadcast"; fi
        if [ "$VERIFY" = true ]; then forge_cmd_b="$forge_cmd_b --verify"; fi
        
        log_info "Phase B: Core Protocol"
        echo "=============================================================="
        env WITH_MOCKS=$WITH_MOCKS TIME_PROVIDER="$TIME_PROVIDER" CHAINLINK_ORACLE="$CHAINLINK_ORACLE" QEURO_TOKEN="$QEURO_TOKEN" FEE_COLLECTOR="$FEE_COLLECTOR" QUANTILLON_VAULT="$QUANTILLON_VAULT" USDC="$USDC" $forge_cmd_b
        echo "=============================================================="
        
        # Extract B addresses
        local phase_b_broadcast="./broadcast/DeployQuantillonPhaseB.s.sol/${chain_id}/run-latest.json"
        if [ ! -f "$phase_b_broadcast" ]; then
            log_error "Phase B broadcast not found"
            exit 1
        fi
        
        PROXIES_B=($(jq -r '.transactions[] | select(.contractName == "ERC1967Proxy" and .transactionType == "CREATE") | .contractAddress' "$phase_b_broadcast"))
        export QTI_TOKEN="${PROXIES_B[0]}"
        export AAVE_VAULT="${PROXIES_B[1]}"
        export STQEURO_TOKEN="${PROXIES_B[2]}"
        
        log_info "Phase B completed. Starting C..."
        
        # Re-export USDC from the mock deployment before A3
        export USDC=$(jq -r '.transactions[] | select(.contractName == "MockUSDC") | .contractAddress' "./broadcast/DeployMockUSDC.s.sol/$chain_id/run-latest.json" | head -1)
        
        # Phase C: UserPool, HedgerPool
        local phase_c_script="scripts/deployment/DeployQuantillonPhaseC.s.sol"
        local forge_cmd_c="forge script $phase_c_script --rpc-url $rpc_url --gas-limit $effective_gas_limit"
        if [ "$ENVIRONMENT" = "base-sepolia" ]; then
            forge_cmd_c="$forge_cmd_c --gas-price 2000000000"
        fi
        if [ "$DRY_RUN" = false ]; then forge_cmd_c="$forge_cmd_c --broadcast"; fi
        if [ "$VERIFY" = true ]; then forge_cmd_c="$forge_cmd_c --verify"; fi
        
        log_info "Phase C: UserPool + HedgerPool"
        echo "=============================================================="
        env WITH_MOCKS=$WITH_MOCKS TIME_PROVIDER="$TIME_PROVIDER" CHAINLINK_ORACLE="$CHAINLINK_ORACLE" QEURO_TOKEN="$QEURO_TOKEN" QUANTILLON_VAULT="$QUANTILLON_VAULT" USDC="$USDC" $forge_cmd_c
        echo "=============================================================="
        
        # Extract C addresses
        local phase_c_broadcast="./broadcast/DeployQuantillonPhaseC.s.sol/${chain_id}/run-latest.json"
        if [ ! -f "$phase_c_broadcast" ]; then
            log_error "Phase C broadcast not found"
            exit 1
        fi
        
        PROXIES_C=($(jq -r '.transactions[] | select(.contractName == "ERC1967Proxy" and .transactionType == "CREATE") | .contractAddress' "$phase_c_broadcast"))
        export USER_POOL="${PROXIES_C[0]}"
        export HEDGER_POOL="${PROXIES_C[1]}"
        
        log_info "Phase C completed. Starting D..."
        
        # Phase D: YieldShift + wiring
        local phase_d_script="scripts/deployment/DeployQuantillonPhaseD.s.sol"
        local forge_cmd_d="forge script $phase_d_script --rpc-url $rpc_url --gas-limit $effective_gas_limit"
        if [ "$ENVIRONMENT" = "base-sepolia" ]; then
            forge_cmd_d="$forge_cmd_d --gas-price 2000000000"
        fi
        if [ "$DRY_RUN" = false ]; then forge_cmd_d="$forge_cmd_d --broadcast"; fi
        if [ "$VERIFY" = true ]; then forge_cmd_d="$forge_cmd_d --verify"; fi
        
        log_info "Phase D: YieldShift + Wiring"
        echo "=============================================================="
        env WITH_MOCKS=$WITH_MOCKS TIME_PROVIDER="$TIME_PROVIDER" CHAINLINK_ORACLE="$CHAINLINK_ORACLE" QEURO_TOKEN="$QEURO_TOKEN" FEE_COLLECTOR="$FEE_COLLECTOR" QUANTILLON_VAULT="$QUANTILLON_VAULT" QTI_TOKEN="$QTI_TOKEN" AAVE_VAULT="$AAVE_VAULT" STQEURO_TOKEN="$STQEURO_TOKEN" USER_POOL="$USER_POOL" HEDGER_POOL="$HEDGER_POOL" USDC="$USDC" $forge_cmd_d
        echo "=============================================================="
    
    log_success "Deployment completed successfully!"
}

# =============================================================================
# POST-DEPLOYMENT TASKS
# =============================================================================

post_deployment() {
    log_step "Running post-deployment tasks..."
    
    # Copy ABIs to frontend (multi-phase deployment)
    log_info "Copying ABIs to frontend..."
    ENV_FILE="$ENV_FILE" PHASED=true ./scripts/deployment/copy-abis.sh "$ENVIRONMENT" --phased
    
    # Update frontend addresses (multi-phase address updater merges all broadcasts)
    log_info "Updating frontend addresses..."
    ENV_FILE="$ENV_FILE" PHASED=true ./scripts/deployment/update-frontend-addresses.sh "$ENVIRONMENT" --phased
    
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
    clean_deployment_artifacts
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
