#!/bin/bash

# Quantillon Protocol - Comprehensive Gas Analysis Script
# Provides detailed gas optimization insights and recommendations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
FORGE_SRC_BUILD_CMD=(forge build --build-info --skip "*/test/**" "*/script/**")
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Load environment variables using shared utility
source "$(dirname "${BASH_SOURCE[0]}")/utils/load-env.sh"
setup_environment --allow-missing
cd "$PROJECT_ROOT"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_DIR="$PROJECT_ROOT/$RESULTS_DIR/gas-analysis"
TEXT_REPORT_FILE="$OUTPUT_DIR/gas-analysis-$TIMESTAMP.txt"

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Function to print colored output
print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

print_section() {
    echo -e "\n${CYAN}$1${NC}"
    echo -e "${CYAN}$(printf '%.0s-' {1..${#1}})${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
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
    mkdir -p "$OUTPUT_DIR"
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
echo "📄 Report will be saved to: $TEXT_REPORT_FILE"
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
if [ -d "out" ] && [ -d "out/build-info" ]; then
    print_success "Existing build artifacts found, reusing them"
    generate_report "BUILD STATUS\n------------\n Reused existing build artifacts from out/\n\n"
elif "${FORGE_SRC_BUILD_CMD[@]}" > /dev/null 2>&1; then
    print_success "Contracts built successfully"
    generate_report "BUILD STATUS\n------------\n Contracts compiled successfully\n\n"
else
    print_error "Failed to build contracts"
    generate_report "BUILD STATUS\n------------\n Contract compilation failed\n\n"
    exit 1
fi

# 2. Forge Gas Report (single run - results cached for later analysis)
print_section "Forge Gas Report"
echo "🔍 Generating detailed gas report (single comprehensive run)..."

# Run forge test with gas report ONCE and save full output
GAS_REPORT_FILE="$OUTPUT_DIR/forge-gas-report-full.txt"
if FOUNDRY_PROFILE=test forge test --gas-report 2>&1 | tee "$GAS_REPORT_FILE"; then
    print_success "Forge gas report generated and cached"
    if [ -f "$GAS_REPORT_FILE" ]; then
        generate_report "FORGE GAS REPORT\n---------------\n$(head -100 "$GAS_REPORT_FILE")\n\n"
    else
        print_warning "Gas report file missing after run; recording fallback note"
        generate_report "FORGE GAS REPORT\n---------------\n Gas report command succeeded but output file was not found at $GAS_REPORT_FILE\n\n"
    fi
else
    print_warning "Gas report generation had issues (partial results may be available)"
    generate_report "FORGE GAS REPORT\n---------------\n$(head -100 "$GAS_REPORT_FILE" 2>/dev/null || echo "Failed to generate gas report")\n\n"
fi

# 3. Slither Analysis (if available)
if [ "$SLITHER_AVAILABLE" = true ]; then
    print_section "Slither Gas Optimization Analysis"
    
    # State variable optimizations
    echo "🔍 Analyzing state variable optimizations..."
    STATE_OPTIMIZATIONS=$($SLITHER_CMD . --detect constable-states,immutable-states 2>/dev/null | grep -E "(should be constant|should be immutable)" || echo "")
    if [ -n "$STATE_OPTIMIZATIONS" ]; then
        print_warning "Found state variable optimization opportunities"
        generate_report "STATE VARIABLE OPTIMIZATIONS\n---------------------------\n Found optimization opportunities:\n$STATE_OPTIMIZATIONS\n\n"
    else
        print_success "No state variable optimizations needed"
        generate_report "STATE VARIABLE OPTIMIZATIONS\n---------------------------\n No optimizations needed\n\n"
    fi
    
    # Function visibility optimizations
    echo "🔍 Analyzing function visibility optimizations..."
    VISIBILITY_OPTIMIZATIONS=$($SLITHER_CMD . --detect external-function 2>/dev/null | grep -E "should be declared external" || echo "")
    if [ -n "$VISIBILITY_OPTIMIZATIONS" ]; then
        print_warning "Found function visibility optimization opportunities"
        generate_report "FUNCTION VISIBILITY OPTIMIZATIONS\n--------------------------------\n Found optimization opportunities:\n$VISIBILITY_OPTIMIZATIONS\n\n"
    else
        print_success "No function visibility optimizations needed"
        generate_report "FUNCTION VISIBILITY OPTIMIZATIONS\n--------------------------------\n No optimizations needed\n\n"
    fi
    
    # Unused code detection
    echo "🔍 Analyzing unused code..."
    UNUSED_CODE=$($SLITHER_CMD . --detect dead-code,unused-state 2>/dev/null | grep -E "(is never used|Dead code)" || echo "")
    if [ -n "$UNUSED_CODE" ]; then
        print_warning "Found unused code"
        generate_report "UNUSED CODE DETECTION\n-------------------\n Found unused code:\n$UNUSED_CODE\n\n"
    else
        print_success "No unused code found"
        generate_report "UNUSED CODE DETECTION\n-------------------\n No unused code found\n\n"
    fi
    
    # Expensive operations in loops
    echo "🔍 Analyzing expensive operations in loops..."
    COSTLY_LOOPS=$($SLITHER_CMD . --detect costly-loop 2>/dev/null | grep -E "has costly operations inside a loop" || echo "")
    if [ -n "$COSTLY_LOOPS" ]; then
        print_warning "Found expensive operations in loops"
        generate_report "COSTLY LOOP OPERATIONS\n--------------------\n Found costly operations:\n$COSTLY_LOOPS\n\n"
    else
        print_success "No expensive operations in loops found"
        generate_report "COSTLY LOOP OPERATIONS\n--------------------\n No expensive operations in loops found\n\n"
    fi
    
    # Storage layout analysis
    echo "🔍 Analyzing storage layout..."
    STORAGE_LAYOUT=$($SLITHER_CMD . --print variable-order 2>/dev/null | head -100 || echo "")
    if [ -n "$STORAGE_LAYOUT" ]; then
        print_success "Storage layout analysis completed"
        generate_report "STORAGE LAYOUT ANALYSIS\n----------------------\n$STORAGE_LAYOUT\n\n"
    fi
    
    # Function summary
    echo "📊 Generating function summary..."
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
echo "📏 Analyzing contract sizes..."

# Get contract sizes and write directly to report
# Note: forge build --sizes can cause core dumps in some versions, so we handle it gracefully
CONTRACT_SIZES=$(timeout 30 forge build --sizes --skip "*/test/**" "*/script/**" 2>&1 || echo "Failed to get contract sizes (forge build --sizes crashed or timed out)")

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

# 5. Gas Usage by Function - Parse from cached report (no additional test runs!)
print_section "Quantillon Protocol Function Gas Analysis"
echo "⚡ Extracting gas usage for critical functions from cached report..."

if [ -f "$GAS_REPORT_FILE" ]; then
    # Extract contract-specific gas data from the single cached report
    # The gas report contains tables like: | Contract | Function | Gas |

    # 1. Core Vault Functions
    VAULT_GAS=$(grep -iE "QuantillonVault|mintQEURO|redeemQEURO" "$GAS_REPORT_FILE" | head -20 || echo "")
    if [ -n "$VAULT_GAS" ]; then
        print_success "Vault function gas data extracted"
        generate_report "VAULT FUNCTION GAS ANALYSIS\n-------------------------\n$VAULT_GAS\n\n"
    fi

    # 2. Staking Functions
    STAKING_GAS=$(grep -iE "UserPool|stake|unstake" "$GAS_REPORT_FILE" | head -20 || echo "")
    if [ -n "$STAKING_GAS" ]; then
        print_success "Staking function gas data extracted"
        generate_report "STAKING FUNCTION GAS ANALYSIS\n----------------------------\n$STAKING_GAS\n\n"
    fi

    # 3. Token Functions
    TOKEN_GAS=$(grep -iE "QEUROToken|QTIToken|mint|burn" "$GAS_REPORT_FILE" | head -20 || echo "")
    if [ -n "$TOKEN_GAS" ]; then
        print_success "Token function gas data extracted"
        generate_report "TOKEN FUNCTION GAS ANALYSIS\n--------------------------\n$TOKEN_GAS\n\n"
    fi

    # 4. HedgerPool Functions
    HEDGER_GAS=$(grep -iE "HedgerPool|position|hedge" "$GAS_REPORT_FILE" | head -20 || echo "")
    if [ -n "$HEDGER_GAS" ]; then
        print_success "HedgerPool function gas data extracted"
        generate_report "HEDGERPOOL FUNCTION GAS ANALYSIS\n--------------------------------\n$HEDGER_GAS\n\n"
    fi

    # 5. Yield Management Functions
    YIELD_GAS=$(grep -iE "YieldShift|yield|distribute" "$GAS_REPORT_FILE" | head -20 || echo "")
    if [ -n "$YIELD_GAS" ]; then
        print_success "Yield function gas data extracted"
        generate_report "YIELD FUNCTION GAS ANALYSIS\n---------------------------\n$YIELD_GAS\n\n"
    fi

    # 6. Gas optimization test results
    GAS_OPT=$(grep -iE "test_Gas_|Gas.*test" "$GAS_REPORT_FILE" | head -25 || echo "")
    if [ -n "$GAS_OPT" ]; then
        print_success "Gas optimization data extracted"
        generate_report "GAS OPTIMIZATION ANALYSIS\n-------------------------\n$GAS_OPT\n\n"
    fi

    # 7. Overall summary (already in cached report)
    print_success "Overall gas usage analysis completed (from cached report)"
    generate_report "OVERALL GAS USAGE SUMMARY\n-------------------------\nSee full gas report at: $GAS_REPORT_FILE\n\n"
else
    print_warning "Cached gas report not found - skipping function-specific analysis"
    generate_report "FUNCTION GAS ANALYSIS\n--------------------\nSkipped - no cached gas report available\n\n"
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

echo "📋 Issues found:"
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
echo "✅ Gas analysis report saved to: $TEXT_REPORT_FILE"
echo ""

if [ $TOTAL_ISSUES -gt 0 ]; then
    echo -e "💡 Tip: Review the analysis results for gas optimization opportunities."
else
    echo -e "🎉 Great job! Your contracts are already well-optimized for gas usage."
fi

echo ""
echo -e "📖 To view the report:"
echo -e "  cat $TEXT_REPORT_FILE"
echo ""
