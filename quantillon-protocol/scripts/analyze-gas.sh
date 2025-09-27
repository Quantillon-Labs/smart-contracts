#!/bin/bash

# Quantillon Protocol - Comprehensive Gas Analysis Script
# Provides detailed gas optimization insights and recommendations

set -e


# Configuration

# Load environment variables using shared utility
source "$(dirname "${BASH_SOURCE[0]}")/utils/load-env.sh"
setup_environment
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_DIR="/gas-analysis"
TEXT_REPORT_FILE="/gas-analysis-.txt"

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

print_header() {
    echo -e "================================"
    echo -e "$1"
    echo -e "================================"
}

print_section() {
    echo -e "\n$1"
    echo -e "$(printf '%.0s-' {1..${#1}})"
}

print_success() {
    echo -e " $1"
}

print_warning() {
    echo -e "  $1"
}

print_error() {
    echo -e " $1"
}

print_info() {
    echo -e "  $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to generate human-readable text report
generate_report() {
    local content="$1"
    echo -e "$content" >> "$TEXT_REPORT_FILE"
}

# Initialize text report
cat > "$TEXT_REPORT_FILE" << EOF
QUANTILLON PROTOCOL GAS ANALYSIS REPORT
========================================
Generated: $(date)

EXECUTIVE SUMMARY
================
This report provides a comprehensive analysis of gas optimization opportunities 
in the Quantillon Protocol smart contracts.

ANALYSIS RESULTS
===============

EOF

print_header "Quantillon Protocol Gas Analysis"
echo "Report will be saved to: $TEXT_REPORT_FILE"
echo ""

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Check dependencies
print_section "Checking Dependencies"

# Check for Foundry
if ! command_exists forge; then
    print_error "Foundry not found. Please install Foundry to run gas analysis."
    exit 1
else
    print_success "Foundry found"
fi

# Check for Slither (including virtual environment)
if ! command_exists slither && ! command_exists ./venv/bin/slither; then
    print_warning "Slither not found. Some analysis will be skipped."
    SLITHER_AVAILABLE=false
else
    print_success "Slither found"
    SLITHER_AVAILABLE=true
    # Set SLITHER_CMD to use the correct path
    if command_exists slither; then
        SLITHER_CMD="slither"
    else
        SLITHER_CMD="./venv/bin/slither"
    fi
fi

# 1. Build contracts first
print_section "Building Contracts"
if forge build > /dev/null 2>&1; then
    print_success "Contracts built successfully"
    generate_report "BUILD STATUS\n------------\n Contracts compiled successfully\n\n"
else
    print_error "Failed to build contracts"
    generate_report "BUILD STATUS\n------------\n Contract compilation failed\n\n"
    exit 1
fi

# 2. Forge Gas Report
print_section "Forge Gas Report"
echo "Generating detailed gas report..."

# Note: Using existing project tests for gas analysis instead of creating temporary files

# Run forge test with gas report using existing tests
FORGE_GAS_REPORT=$(forge test --gas-report 2>&1 | head -50 || echo "Failed to generate gas report")
if [ "$FORGE_GAS_REPORT" != "Failed to generate gas report" ]; then
    print_success "Forge gas report generated"
    generate_report "FORGE GAS REPORT\n---------------\n$(echo "$FORGE_GAS_REPORT" | head -50)\n\n"
else
    # Fallback: try to use existing gas-related tests
    print_warning "Primary gas report failed, trying existing gas tests..."
    FALLBACK_GAS_REPORT=$(forge test --gas-report --match-test "test_Gas_" 2>&1 || echo "Failed to generate fallback gas report")
    if [ "$FALLBACK_GAS_REPORT" != "Failed to generate fallback gas report" ]; then
        print_success "Fallback gas report generated using existing tests"
        generate_report "FORGE GAS REPORT (Fallback)\n---------------------------\n$(echo "$FALLBACK_GAS_REPORT" | head -50)\n\n"
    else
        print_warning "All gas report generation failed"
        generate_report "FORGE GAS REPORT\n---------------\n Failed to generate gas report (both primary and fallback methods failed)\n\n"
    fi
fi

# 3. Slither Analysis (if available)
if [ "$SLITHER_AVAILABLE" = true ]; then
    print_section "Slither Gas Optimization Analysis"
    
    # State variable optimizations
    echo "Analyzing state variable optimizations..."
    STATE_OPTIMIZATIONS=$($SLITHER_CMD . --detect constable-states,immutable-states 2>/dev/null | grep -E "(should be constant|should be immutable)" || echo "")
    if [ -n "$STATE_OPTIMIZATIONS" ]; then
        print_warning "Found state variable optimization opportunities"
        generate_report "STATE VARIABLE OPTIMIZATIONS\n---------------------------\n Found optimization opportunities:\n$STATE_OPTIMIZATIONS\n\n"
    else
        print_success "No state variable optimizations needed"
        generate_report "STATE VARIABLE OPTIMIZATIONS\n---------------------------\n No optimizations needed\n\n"
    fi
    
    # Function visibility optimizations
    echo "Analyzing function visibility optimizations..."
    VISIBILITY_OPTIMIZATIONS=$($SLITHER_CMD . --detect external-function 2>/dev/null | grep -E "should be declared external" || echo "")
    if [ -n "$VISIBILITY_OPTIMIZATIONS" ]; then
        print_warning "Found function visibility optimization opportunities"
        generate_report "FUNCTION VISIBILITY OPTIMIZATIONS\n--------------------------------\n Found optimization opportunities:\n$VISIBILITY_OPTIMIZATIONS\n\n"
    else
        print_success "No function visibility optimizations needed"
        generate_report "FUNCTION VISIBILITY OPTIMIZATIONS\n--------------------------------\n No optimizations needed\n\n"
    fi
    
    # Unused code detection
    echo "Analyzing unused code..."
    UNUSED_CODE=$($SLITHER_CMD . --detect dead-code,unused-state 2>/dev/null | grep -E "(is never used|Dead code)" || echo "")
    if [ -n "$UNUSED_CODE" ]; then
        print_warning "Found unused code"
        generate_report "UNUSED CODE DETECTION\n-------------------\n Found unused code:\n$UNUSED_CODE\n\n"
    else
        print_success "No unused code found"
        generate_report "UNUSED CODE DETECTION\n-------------------\n No unused code found\n\n"
    fi
    
    # Expensive operations in loops
    echo "Analyzing expensive operations in loops..."
    COSTLY_LOOPS=$($SLITHER_CMD . --detect costly-loop 2>/dev/null | grep -E "has costly operations inside a loop" || echo "")
    if [ -n "$COSTLY_LOOPS" ]; then
        print_warning "Found expensive operations in loops"
        generate_report "COSTLY LOOP OPERATIONS\n--------------------\n Found costly operations:\n$COSTLY_LOOPS\n\n"
    else
        print_success "No expensive operations in loops found"
        generate_report "COSTLY LOOP OPERATIONS\n--------------------\n No expensive operations in loops found\n\n"
    fi
    
    # Storage layout analysis
    echo "Analyzing storage layout..."
    STORAGE_LAYOUT=$($SLITHER_CMD . --print variable-order 2>/dev/null | head -100 || echo "")
    if [ -n "$STORAGE_LAYOUT" ]; then
        print_success "Storage layout analysis completed"
        generate_report "STORAGE LAYOUT ANALYSIS\n----------------------\n$STORAGE_LAYOUT\n\n"
    fi
    
    # Function summary
    echo "Generating function summary..."
    FUNCTION_SUMMARY=$($SLITHER_CMD . --print function-summary 2>/dev/null | head -50 || echo "")
    if [ -n "$FUNCTION_SUMMARY" ]; then
        print_success "Function summary generated"
        generate_report "FUNCTION SUMMARY\n---------------\n$FUNCTION_SUMMARY\n\n"
    fi
else
    print_warning "Skipping Slither analysis (not available)"
    generate_report "SLITHER ANALYSIS\n---------------\n Slither not available - analysis skipped\n\n"
fi

# 4. Contract Size Analysis
print_section "Contract Size Analysis"
echo "Analyzing contract sizes..."

# Get contract sizes and write directly to report
# Note: forge build --sizes can cause core dumps in some versions, so we handle it gracefully
CONTRACT_SIZES=$(timeout 30 forge build --sizes 2>&1 || echo "Failed to get contract sizes (forge build --sizes crashed or timed out)")

if [ -n "$CONTRACT_SIZES" ] && [ "$CONTRACT_SIZES" != "Failed to get contract sizes" ] && [ "$CONTRACT_SIZES" != "Failed to get contract sizes (forge build --sizes crashed or timed out)" ]; then
    print_success "Contract size analysis completed"
    
    # Check for contracts approaching size limit
    LARGE_CONTRACTS=$(echo "$CONTRACT_SIZES" | grep -E "([0-9]+\.?[0-9]*)\s+KB" | awk '$2 > 20 {print $1 " (" $2 " KB)"}')
    
    if [ -n "$LARGE_CONTRACTS" ]; then
        print_warning "Found large contracts (>20KB):"
        echo "$LARGE_CONTRACTS"
        generate_report "CONTRACT SIZE ANALYSIS\n----------------------\n Large contracts found (>20KB):\n$LARGE_CONTRACTS\n\n"
    else
        print_success "All contracts are within reasonable size limits"
        generate_report "CONTRACT SIZE ANALYSIS\n----------------------\n All contracts are within reasonable size limits\n\n"
    fi
    
    generate_report "Detailed Contract Sizes:\n$CONTRACT_SIZES\n\n"
else
    print_warning "Contract size analysis failed (forge build --sizes crashed or timed out)"
    generate_report "CONTRACT SIZE ANALYSIS\n----------------------\n Failed to analyze contract sizes (forge build --sizes crashed or timed out)\n\n"
fi

# 5. Gas Usage by Function - Analyze Real Quantillon Protocol Functions
print_section "Quantillon Protocol Function Gas Analysis"
echo "Analyzing gas usage for critical Quantillon protocol functions..."

# Analyze gas usage for critical protocol functions
echo "Running gas analysis for core protocol functions..."

# 1. Core Vault Functions (mintQEURO, redeemQEURO)
VAULT_GAS_USAGE=$(forge test --gas-report --match-test "test.*[Mm]int.*[Qq]euro|test.*[Rr]edeem.*[Qq]euro" 2>&1 || echo "No vault gas tests found")
if [ "$VAULT_GAS_USAGE" != "No vault gas tests found" ]; then
    print_success "Vault function gas analysis completed"
    generate_report "VAULT FUNCTION GAS ANALYSIS\n-------------------------\n$(echo "$VAULT_GAS_USAGE" | head -20)\n\n"
fi

# 2. Staking Functions (stake, unstake, batch operations)
STAKING_GAS_USAGE=$(forge test --gas-report --match-test "test.*[Ss]take|test.*[Bb]atch.*[Ss]take" 2>&1 || echo "No staking gas tests found")
if [ "$STAKING_GAS_USAGE" != "No staking gas tests found" ]; then
    print_success "Staking function gas analysis completed"
    generate_report "STAKING FUNCTION GAS ANALYSIS\n----------------------------\n$(echo "$STAKING_GAS_USAGE" | head -20)\n\n"
fi

# 3. Token Functions (mint, burn, batch operations)
TOKEN_GAS_USAGE=$(forge test --gas-report --match-test "test.*[Mm]int|test.*[Bb]urn|test.*[Bb]atch.*[Mm]int|test.*[Bb]atch.*[Bb]urn" 2>&1 || echo "No token gas tests found")
if [ "$TOKEN_GAS_USAGE" != "No token gas tests found" ]; then
    print_success "Token function gas analysis completed"
    generate_report "TOKEN FUNCTION GAS ANALYSIS\n--------------------------\n$(echo "$TOKEN_GAS_USAGE" | head -20)\n\n"
fi

# 4. HedgerPool Functions (position management)
HEDGER_GAS_USAGE=$(forge test --gas-report --match-test "test.*[Hh]edger|test.*[Pp]osition" 2>&1 || echo "No hedger gas tests found")
if [ "$HEDGER_GAS_USAGE" != "No hedger gas tests found" ]; then
    print_success "HedgerPool function gas analysis completed"
    generate_report "HEDGERPOOL FUNCTION GAS ANALYSIS\n--------------------------------\n$(echo "$HEDGER_GAS_USAGE" | head -20)\n\n"
fi

# 5. Yield Management Functions
YIELD_GAS_USAGE=$(forge test --gas-report --match-test "test.*[Yy]ield|test.*[Dd]istribute" 2>&1 || echo "No yield gas tests found")
if [ "$YIELD_GAS_USAGE" != "No yield gas tests found" ]; then
    print_success "Yield function gas analysis completed"
    generate_report "YIELD FUNCTION GAS ANALYSIS\n---------------------------\n$(echo "$YIELD_GAS_USAGE" | head -20)\n\n"
fi

# 6. Comprehensive Gas Optimization Tests (from GasResourceEdgeCases.t.sol)
GAS_OPTIMIZATION_USAGE=$(forge test --gas-report --match-test "test_Gas_" 2>&1 || echo "No gas optimization tests found")
if [ "$GAS_OPTIMIZATION_USAGE" != "No gas optimization tests found" ]; then
    print_success "Gas optimization analysis completed"
    generate_report "GAS OPTIMIZATION ANALYSIS\n-------------------------\n$(echo "$GAS_OPTIMIZATION_USAGE" | head -25)\n\n"
fi

# 7. Overall gas report for all tests
OVERALL_GAS_USAGE=$(forge test --gas-report 2>&1 | head -50 || echo "Failed to generate overall gas report")
if [ "$OVERALL_GAS_USAGE" != "Failed to generate overall gas report" ]; then
    print_success "Overall gas usage analysis completed"
    generate_report "OVERALL GAS USAGE SUMMARY\n-------------------------\n$(echo "$OVERALL_GAS_USAGE" | head -30)\n\n"
else
    print_warning "Overall gas analysis failed"
    generate_report "OVERALL GAS USAGE SUMMARY\n-------------------------\n Failed to generate overall gas usage report\n\n"
fi

# 6. Generate summary
print_section "Analysis Summary"

# Count issues found using the variables we already have
STATE_ISSUES=0
VISIBILITY_ISSUES=0
UNUSED_CODE_ISSUES=0
COSTLY_LOOP_ISSUES=0

if [ -n "$STATE_OPTIMIZATIONS" ]; then
    STATE_ISSUES=$(echo "$STATE_OPTIMIZATIONS" | grep -c "should be" 2>/dev/null || echo "0")
fi

if [ -n "$VISIBILITY_OPTIMIZATIONS" ]; then
    VISIBILITY_ISSUES=$(echo "$VISIBILITY_OPTIMIZATIONS" | grep -c "should be declared external" 2>/dev/null || echo "0")
fi

if [ -n "$UNUSED_CODE" ]; then
    UNUSED_CODE_ISSUES=$(echo "$UNUSED_CODE" | grep -c "is never used\|Dead code" 2>/dev/null || echo "0")
fi

if [ -n "$COSTLY_LOOPS" ]; then
    COSTLY_LOOP_ISSUES=$(echo "$COSTLY_LOOPS" | grep -c "has costly operations" 2>/dev/null || echo "0")
fi

TOTAL_ISSUES=$((STATE_ISSUES + VISIBILITY_ISSUES + UNUSED_CODE_ISSUES + COSTLY_LOOP_ISSUES))

echo "Issues found:"
echo "  - State variable optimizations: $STATE_ISSUES"
echo "  - Function visibility optimizations: $VISIBILITY_ISSUES"
echo "  - Unused code issues: $UNUSED_CODE_ISSUES"
echo "  - Costly loop operations: $COSTLY_LOOP_ISSUES"
echo "  - Total issues: $TOTAL_ISSUES"

# Add summary to report
generate_report "SUMMARY\n=======\n- State variable optimizations: $STATE_ISSUES issues found\n- Function visibility optimizations: $VISIBILITY_ISSUES issues found\n- Unused code issues: $UNUSED_CODE_ISSUES issues found\n- Costly loop operations: $COSTLY_LOOP_ISSUES issues found\n- Total optimization opportunities: $TOTAL_ISSUES\n\n"

if [ $TOTAL_ISSUES -eq 0 ]; then
    print_success "No gas optimization issues found!"
    generate_report "CONCLUSION\n==========\n Excellent! No gas optimization issues were found in the analysis.\n\n"
else
    print_warning "Found $TOTAL_ISSUES gas optimization opportunities"
    generate_report "CONCLUSION\n==========\n $TOTAL_ISSUES gas optimization opportunities were found.\n\n"
fi

# 7. Cleanup

print_header "Analysis Complete"
echo " Gas analysis report saved to: $TEXT_REPORT_FILE"
echo ""

if [ $TOTAL_ISSUES -gt 0 ]; then
    echo -e " Tip: Review the analysis results for gas optimization opportunities."
else
    echo -e " Great job! Your contracts are already well-optimized for gas usage."
fi

echo ""
echo -e "To view the report:"
echo -e "  cat $TEXT_REPORT_FILE"
echo ""