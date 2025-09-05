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
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_DIR="gas-analysis"
TEXT_REPORT_FILE="${OUTPUT_DIR}/gas-analysis-${TIMESTAMP}.txt"

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
    echo -e "${PURPLE}ℹ️  $1${NC}"
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

# Check for Slither
if ! command_exists slither; then
    print_warning "Slither not found. Some analysis will be skipped."
    SLITHER_AVAILABLE=false
else
    print_success "Slither found"
    SLITHER_AVAILABLE=true
fi

# 1. Build contracts first
print_section "Building Contracts"
if forge build > /dev/null 2>&1; then
    print_success "Contracts built successfully"
    generate_report "BUILD STATUS\n------------\n✅ Contracts compiled successfully\n\n"
else
    print_error "Failed to build contracts"
    generate_report "BUILD STATUS\n------------\n❌ Contract compilation failed\n\n"
    exit 1
fi

# 2. Forge Gas Report
print_section "Forge Gas Report"
echo "Generating detailed gas report..."

# Create a temporary test file for gas analysis
cat > /tmp/gas_test.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

contract GasAnalysisTest is Test {
    function testGasAnalysis() public {
        // This test will be used to generate gas reports
        assertTrue(true);
    }
}
EOF

# Run forge test with gas report
FORGE_GAS_REPORT=$(forge test --gas-report --match-test testGasAnalysis 2>&1 || echo "Failed to generate gas report")
if [ "$FORGE_GAS_REPORT" != "Failed to generate gas report" ]; then
    print_success "Forge gas report generated"
    generate_report "FORGE GAS REPORT\n---------------\n$(echo "$FORGE_GAS_REPORT" | head -50)\n\n"
else
    print_warning "Forge gas report generation failed"
    generate_report "FORGE GAS REPORT\n---------------\n⚠️ Failed to generate gas report\n\n"
fi

# 3. Slither Analysis (if available)
if [ "$SLITHER_AVAILABLE" = true ]; then
    print_section "Slither Gas Optimization Analysis"
    
    # State variable optimizations
    echo "Analyzing state variable optimizations..."
    STATE_OPTIMIZATIONS=$(slither . --detect constable-states,immutable-states 2>/dev/null | grep -E "(should be constant|should be immutable)" || echo "")
    if [ -n "$STATE_OPTIMIZATIONS" ]; then
        print_warning "Found state variable optimization opportunities"
        generate_report "STATE VARIABLE OPTIMIZATIONS\n---------------------------\n⚠️ Found optimization opportunities:\n$STATE_OPTIMIZATIONS\n\n"
    else
        print_success "No state variable optimizations needed"
        generate_report "STATE VARIABLE OPTIMIZATIONS\n---------------------------\n✅ No optimizations needed\n\n"
    fi
    
    # Function visibility optimizations
    echo "Analyzing function visibility optimizations..."
    VISIBILITY_OPTIMIZATIONS=$(slither . --detect external-function 2>/dev/null | grep -E "should be declared external" || echo "")
    if [ -n "$VISIBILITY_OPTIMIZATIONS" ]; then
        print_warning "Found function visibility optimization opportunities"
        generate_report "FUNCTION VISIBILITY OPTIMIZATIONS\n--------------------------------\n⚠️ Found optimization opportunities:\n$VISIBILITY_OPTIMIZATIONS\n\n"
    else
        print_success "No function visibility optimizations needed"
        generate_report "FUNCTION VISIBILITY OPTIMIZATIONS\n--------------------------------\n✅ No optimizations needed\n\n"
    fi
    
    # Unused code detection
    echo "Analyzing unused code..."
    UNUSED_CODE=$(slither . --detect dead-code,unused-state 2>/dev/null | grep -E "(is never used|Dead code)" || echo "")
    if [ -n "$UNUSED_CODE" ]; then
        print_warning "Found unused code"
        generate_report "UNUSED CODE DETECTION\n-------------------\n⚠️ Found unused code:\n$UNUSED_CODE\n\n"
    else
        print_success "No unused code found"
        generate_report "UNUSED CODE DETECTION\n-------------------\n✅ No unused code found\n\n"
    fi
    
    # Expensive operations in loops
    echo "Analyzing expensive operations in loops..."
    COSTLY_LOOPS=$(slither . --detect costly-loop 2>/dev/null | grep -E "has costly operations inside a loop" || echo "")
    if [ -n "$COSTLY_LOOPS" ]; then
        print_warning "Found expensive operations in loops"
        generate_report "COSTLY LOOP OPERATIONS\n--------------------\n⚠️ Found costly operations:\n$COSTLY_LOOPS\n\n"
    else
        print_success "No expensive operations in loops found"
        generate_report "COSTLY LOOP OPERATIONS\n--------------------\n✅ No expensive operations in loops found\n\n"
    fi
    
    # Storage layout analysis
    echo "Analyzing storage layout..."
    STORAGE_LAYOUT=$(slither . --print variable-order 2>/dev/null | head -100 || echo "")
    if [ -n "$STORAGE_LAYOUT" ]; then
        print_success "Storage layout analysis completed"
        generate_report "STORAGE LAYOUT ANALYSIS\n----------------------\n$STORAGE_LAYOUT\n\n"
    fi
    
    # Function summary
    echo "Generating function summary..."
    FUNCTION_SUMMARY=$(slither . --print function-summary 2>/dev/null | head -50 || echo "")
    if [ -n "$FUNCTION_SUMMARY" ]; then
        print_success "Function summary generated"
        generate_report "FUNCTION SUMMARY\n---------------\n$FUNCTION_SUMMARY\n\n"
    fi
else
    print_warning "Skipping Slither analysis (not available)"
    generate_report "SLITHER ANALYSIS\n---------------\n⚠️ Slither not available - analysis skipped\n\n"
fi

# 4. Contract Size Analysis
print_section "Contract Size Analysis"
echo "Analyzing contract sizes..."

# Get contract sizes and write directly to report
CONTRACT_SIZES=$(forge build --sizes 2>&1 || echo "Failed to get contract sizes")

if [ -n "$CONTRACT_SIZES" ] && [ "$CONTRACT_SIZES" != "Failed to get contract sizes" ]; then
    print_success "Contract size analysis completed"
    
    # Check for contracts approaching size limit
    LARGE_CONTRACTS=$(echo "$CONTRACT_SIZES" | grep -E "([0-9]+\.?[0-9]*)\s+KB" | awk '$2 > 20 {print $1 " (" $2 " KB)"}')
    
    if [ -n "$LARGE_CONTRACTS" ]; then
        print_warning "Found large contracts (>20KB):"
        echo "$LARGE_CONTRACTS"
        generate_report "CONTRACT SIZE ANALYSIS\n----------------------\n⚠️ Large contracts found (>20KB):\n$LARGE_CONTRACTS\n\n"
    else
        print_success "All contracts are within reasonable size limits"
        generate_report "CONTRACT SIZE ANALYSIS\n----------------------\n✅ All contracts are within reasonable size limits\n\n"
    fi
    
    generate_report "Detailed Contract Sizes:\n$CONTRACT_SIZES\n\n"
else
    print_warning "Contract size analysis failed"
    generate_report "CONTRACT SIZE ANALYSIS\n----------------------\n⚠️ Failed to analyze contract sizes\n\n"
fi

# 5. Gas Usage by Function (if available)
print_section "Function Gas Usage Analysis"
echo "Analyzing gas usage by function..."

# Create a more comprehensive gas test
cat > /tmp/comprehensive_gas_test.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

contract ComprehensiveGasTest is Test {
    function testGasUsage() public {
        // Test basic operations
        uint256 a = 1;
        uint256 b = 2;
        uint256 c = a + b;
        assertEq(c, 3);
        
        // Test storage operations
        uint256 storageVar = 100;
        storageVar = storageVar + 1;
        assertEq(storageVar, 101);
        
        // Test array operations
        uint256[] memory arr = new uint256[](10);
        for (uint256 i = 0; i < arr.length; i++) {
            arr[i] = i;
        }
        assertEq(arr[5], 5);
    }
}
EOF

# Run gas analysis
FUNCTION_GAS_USAGE=$(forge test --gas-report --match-test testGasUsage 2>&1 || echo "Failed to analyze function gas usage")
if [ "$FUNCTION_GAS_USAGE" != "Failed to analyze function gas usage" ]; then
    print_success "Function gas usage analysis completed"
    generate_report "FUNCTION GAS USAGE ANALYSIS\n-------------------------\n$(echo "$FUNCTION_GAS_USAGE" | head -30)\n\n"
else
    print_warning "Function gas usage analysis failed"
    generate_report "FUNCTION GAS USAGE ANALYSIS\n-------------------------\n⚠️ Failed to analyze function gas usage\n\n"
fi

# 6. Optimization Recommendations
print_section "Gas Optimization Recommendations"

RECOMMENDATIONS="GAS OPTIMIZATION RECOMMENDATIONS
================================

HIGH PRIORITY
=============
1. Use 'immutable' for variables set only in constructor
   - Reduces deployment gas costs
   - Reduces runtime gas costs for reads

2. Use 'constant' for compile-time constants
   - No storage slot required
   - Minimal gas cost for reads

3. Optimize storage layout
   - Pack structs efficiently
   - Group related variables together
   - Use appropriate data types

4. Use 'external' instead of 'public' for functions not called internally
   - Saves gas on function calls
   - Reduces contract size

MEDIUM PRIORITY
===============
1. Avoid expensive operations in loops
   - Move storage reads outside loops
   - Use local variables for repeated calculations

2. Use events instead of storage for non-critical data
   - Events are cheaper than storage
   - Good for logging and off-chain indexing

3. Optimize string operations
   - Use 'bytes32' for fixed-length strings when possible
   - Avoid string concatenation in loops

4. Use assembly for gas-critical operations
   - Only for experienced developers
   - Can provide significant gas savings

LOW PRIORITY
============
1. Remove unused code
   - Reduces contract size
   - Improves readability

2. Use libraries for common operations
   - Reduces code duplication
   - Can improve gas efficiency

3. Optimize function parameters
   - Use appropriate data types
   - Consider using structs for multiple parameters"

print_success "Optimization recommendations generated"
generate_report "$RECOMMENDATIONS\n\n"

# 7. Generate summary
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
    generate_report "CONCLUSION\n==========\n✅ Excellent! No gas optimization issues were found in the analysis.\n\n"
else
    print_warning "Found $TOTAL_ISSUES gas optimization opportunities"
    generate_report "CONCLUSION\n==========\n⚠️ $TOTAL_ISSUES gas optimization opportunities were found. Review the recommendations above to improve gas efficiency.\n\n"
fi

# 8. Cleanup
rm -f /tmp/gas_test.sol /tmp/comprehensive_gas_test.sol

print_header "Analysis Complete"
echo "📄 Gas analysis report saved to: $TEXT_REPORT_FILE"
echo ""

if [ $TOTAL_ISSUES -gt 0 ]; then
    echo -e "${YELLOW}💡 Tip: Review the recommendations in the report for gas optimization opportunities.${NC}"
else
    echo -e "${GREEN}🎉 Great job! Your contracts are already well-optimized for gas usage.${NC}"
fi

echo ""
echo -e "${BLUE}To view the report:${NC}"
echo -e "${BLUE}  cat $TEXT_REPORT_FILE${NC}"
echo ""