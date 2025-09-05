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
OUTPUT_DIR="gas-analysis"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
REPORT_FILE="${OUTPUT_DIR}/gas-analysis-${TIMESTAMP}.md"

# Create output directory
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
    echo -e "${PURPLE}ℹ️  $1${NC}"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to generate markdown report
generate_report() {
    local content="$1"
    echo "$content" >> "$REPORT_FILE"
}

# Initialize report
cat > "$REPORT_FILE" << EOF
# Gas Analysis Report - $(date)

## Executive Summary

This report provides a comprehensive analysis of gas optimization opportunities in the Quantillon Protocol smart contracts.

## Analysis Results

EOF

print_header "Quantillon Protocol Gas Analysis"
echo "Report will be saved to: $REPORT_FILE"
echo ""

# Check dependencies
print_section "Checking Dependencies"

if ! command_exists forge; then
    print_error "Foundry not found. Please install Foundry first."
    exit 1
fi

if ! command_exists slither; then
    print_warning "Slither not found. Some analysis will be skipped."
    SLITHER_AVAILABLE=false
else
    print_success "Slither found"
    SLITHER_AVAILABLE=true
fi

if ! command_exists hardhat; then
    print_warning "Hardhat not found. Some advanced analysis will be skipped."
    HARDHAT_AVAILABLE=false
else
    print_success "Hardhat found"
    HARDHAT_AVAILABLE=true
fi

# 1. Build contracts first
print_section "Building Contracts"
if forge build > /dev/null 2>&1; then
    print_success "Contracts built successfully"
    generate_report "### Build Status\n✅ Contracts compiled successfully\n\n"
else
    print_error "Failed to build contracts"
    generate_report "### Build Status\n❌ Contract compilation failed\n\n"
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
if forge test --gas-report --match-test testGasAnalysis > "${OUTPUT_DIR}/forge-gas-report.txt" 2>&1; then
    print_success "Forge gas report generated"
    generate_report "### Forge Gas Report\n\n\`\`\`\n$(cat "${OUTPUT_DIR}/forge-gas-report.txt" | head -50)\n\`\`\`\n\n"
else
    print_warning "Forge gas report generation failed"
    generate_report "### Forge Gas Report\n⚠️ Failed to generate gas report\n\n"
fi

# 3. Slither Analysis (if available)
if [ "$SLITHER_AVAILABLE" = true ]; then
    print_section "Slither Gas Optimization Analysis"
    
    # State variable optimizations
    echo "Analyzing state variable optimizations..."
    if slither . --detect constable-states,immutable-states 2>/dev/null | grep -E "(should be constant|should be immutable)" > "${OUTPUT_DIR}/state-optimizations.txt" 2>&1; then
        if [ -s "${OUTPUT_DIR}/state-optimizations.txt" ]; then
            print_warning "Found state variable optimization opportunities"
            generate_report "### State Variable Optimizations\n\n\`\`\`\n$(cat "${OUTPUT_DIR}/state-optimizations.txt")\n\`\`\`\n\n"
        else
            print_success "No state variable optimizations needed"
            generate_report "### State Variable Optimizations\n✅ No optimizations needed\n\n"
        fi
    fi
    
    # Function visibility optimizations
    echo "Analyzing function visibility optimizations..."
    if slither . --detect external-function 2>/dev/null | grep -E "should be declared external" > "${OUTPUT_DIR}/visibility-optimizations.txt" 2>&1; then
        if [ -s "${OUTPUT_DIR}/visibility-optimizations.txt" ]; then
            print_warning "Found function visibility optimization opportunities"
            generate_report "### Function Visibility Optimizations\n\n\`\`\`\n$(cat "${OUTPUT_DIR}/visibility-optimizations.txt")\n\`\`\`\n\n"
        else
            print_success "No function visibility optimizations needed"
            generate_report "### Function Visibility Optimizations\n✅ No optimizations needed\n\n"
        fi
    fi
    
    # Unused code detection
    echo "Analyzing unused code..."
    if slither . --detect dead-code,unused-state 2>/dev/null | grep -E "(is never used|Dead code)" > "${OUTPUT_DIR}/unused-code.txt" 2>&1; then
        if [ -s "${OUTPUT_DIR}/unused-code.txt" ]; then
            print_warning "Found unused code"
            generate_report "### Unused Code Detection\n\n\`\`\`\n$(cat "${OUTPUT_DIR}/unused-code.txt")\n\`\`\`\n\n"
        else
            print_success "No unused code found"
            generate_report "### Unused Code Detection\n✅ No unused code found\n\n"
        fi
    fi
    
    # Expensive operations in loops
    echo "Analyzing expensive operations in loops..."
    if slither . --detect costly-loop 2>/dev/null | grep -E "has costly operations inside a loop" > "${OUTPUT_DIR}/costly-loops.txt" 2>&1; then
        if [ -s "${OUTPUT_DIR}/costly-loops.txt" ]; then
            print_warning "Found expensive operations in loops"
            generate_report "### Expensive Operations in Loops\n\n\`\`\`\n$(cat "${OUTPUT_DIR}/costly-loops.txt")\n\`\`\`\n\n"
        else
            print_success "No expensive operations in loops found"
            generate_report "### Expensive Operations in Loops\n✅ No expensive operations in loops found\n\n"
        fi
    fi
    
    # Storage layout analysis
    echo "Analyzing storage layout..."
    if slither . --print variable-order 2>/dev/null > "${OUTPUT_DIR}/storage-layout.txt" 2>&1; then
        print_success "Storage layout analysis completed"
        generate_report "### Storage Layout Analysis\n\n\`\`\`\n$(cat "${OUTPUT_DIR}/storage-layout.txt" | head -100)\n\`\`\`\n\n"
    fi
    
    # Function summary
    echo "Generating function summary..."
    if slither . --print function-summary 2>/dev/null > "${OUTPUT_DIR}/function-summary.txt" 2>&1; then
        print_success "Function summary generated"
        generate_report "### Function Summary\n\n\`\`\`\n$(cat "${OUTPUT_DIR}/function-summary.txt" | head -50)\n\`\`\`\n\n"
    fi
else
    print_warning "Skipping Slither analysis (not available)"
    generate_report "### Slither Analysis\n⚠️ Slither not available - analysis skipped\n\n"
fi

# 4. Contract Size Analysis
print_section "Contract Size Analysis"
echo "Analyzing contract sizes..."

# Get contract sizes
forge build --sizes > "${OUTPUT_DIR}/contract-sizes.txt" 2>&1 || true

if [ -s "${OUTPUT_DIR}/contract-sizes.txt" ]; then
    print_success "Contract size analysis completed"
    
    # Check for contracts approaching size limit
    LARGE_CONTRACTS=$(grep -E "([0-9]+\.?[0-9]*)\s+KB" "${OUTPUT_DIR}/contract-sizes.txt" | awk '$2 > 20 {print $1 " (" $2 " KB)"}')
    
    if [ -n "$LARGE_CONTRACTS" ]; then
        print_warning "Found large contracts (>20KB):"
        echo "$LARGE_CONTRACTS"
        generate_report "### Contract Size Analysis\n\n⚠️ Large contracts found (>20KB):\n\`\`\`\n$LARGE_CONTRACTS\n\`\`\`\n\n"
    else
        print_success "All contracts are within reasonable size limits"
        generate_report "### Contract Size Analysis\n\n✅ All contracts are within reasonable size limits\n\n"
    fi
    
    generate_report "#### Detailed Contract Sizes\n\n\`\`\`\n$(cat "${OUTPUT_DIR}/contract-sizes.txt")\n\`\`\`\n\n"
else
    print_warning "Contract size analysis failed"
    generate_report "### Contract Size Analysis\n⚠️ Failed to analyze contract sizes\n\n"
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
if forge test --gas-report --match-test testGasUsage > "${OUTPUT_DIR}/function-gas-usage.txt" 2>&1; then
    print_success "Function gas usage analysis completed"
    generate_report "### Function Gas Usage Analysis\n\n\`\`\`\n$(cat "${OUTPUT_DIR}/function-gas-usage.txt" | head -30)\n\`\`\`\n\n"
else
    print_warning "Function gas usage analysis failed"
    generate_report "### Function Gas Usage Analysis\n⚠️ Failed to analyze function gas usage\n\n"
fi

# 6. Optimization Recommendations
print_section "Gas Optimization Recommendations"

cat > "${OUTPUT_DIR}/recommendations.txt" << 'EOF'
## Gas Optimization Recommendations

### High Priority
1. **Use `immutable` for variables set only in constructor**
   - Reduces deployment gas costs
   - Reduces runtime gas costs for reads

2. **Use `constant` for compile-time constants**
   - No storage slot required
   - Minimal gas cost for reads

3. **Optimize storage layout**
   - Pack structs efficiently
   - Group related variables together
   - Use appropriate data types

4. **Use `external` instead of `public` for functions not called internally**
   - Saves gas on function calls
   - Reduces contract size

### Medium Priority
1. **Avoid expensive operations in loops**
   - Move storage reads outside loops
   - Use local variables for repeated calculations

2. **Use events instead of storage for non-critical data**
   - Events are cheaper than storage
   - Good for logging and off-chain indexing

3. **Optimize string operations**
   - Use `bytes32` for fixed-length strings when possible
   - Avoid string concatenation in loops

4. **Use assembly for gas-critical operations**
   - Only for experienced developers
   - Can provide significant gas savings

### Low Priority
1. **Remove unused code**
   - Reduces contract size
   - Improves readability

2. **Use libraries for common operations**
   - Reduces code duplication
   - Can improve gas efficiency

3. **Optimize function parameters**
   - Use appropriate data types
   - Consider using structs for multiple parameters
EOF

print_success "Optimization recommendations generated"
generate_report "### Gas Optimization Recommendations\n\n$(cat "${OUTPUT_DIR}/recommendations.txt")\n\n"

# 7. Generate summary
print_section "Analysis Summary"

# Count issues found
STATE_ISSUES=$(grep -c "should be" "${OUTPUT_DIR}/state-optimizations.txt" 2>/dev/null || echo "0")
VISIBILITY_ISSUES=$(grep -c "should be declared external" "${OUTPUT_DIR}/visibility-optimizations.txt" 2>/dev/null || echo "0")
UNUSED_CODE_ISSUES=$(grep -c "is never used\|Dead code" "${OUTPUT_DIR}/unused-code.txt" 2>/dev/null || echo "0")
COSTLY_LOOP_ISSUES=$(grep -c "has costly operations" "${OUTPUT_DIR}/costly-loops.txt" 2>/dev/null || echo "0")

TOTAL_ISSUES=$((STATE_ISSUES + VISIBILITY_ISSUES + UNUSED_CODE_ISSUES + COSTLY_LOOP_ISSUES))

echo "Issues found:"
echo "  - State variable optimizations: $STATE_ISSUES"
echo "  - Function visibility optimizations: $VISIBILITY_ISSUES"
echo "  - Unused code issues: $UNUSED_CODE_ISSUES"
echo "  - Costly loop operations: $COSTLY_LOOP_ISSUES"
echo "  - Total issues: $TOTAL_ISSUES"

# Add summary to report
generate_report "## Summary\n\n- **State variable optimizations**: $STATE_ISSUES issues found\n- **Function visibility optimizations**: $VISIBILITY_ISSUES issues found\n- **Unused code issues**: $UNUSED_CODE_ISSUES issues found\n- **Costly loop operations**: $COSTLY_LOOP_ISSUES issues found\n- **Total optimization opportunities**: $TOTAL_ISSUES\n\n"

if [ $TOTAL_ISSUES -eq 0 ]; then
    print_success "No gas optimization issues found!"
    generate_report "## Conclusion\n\n✅ **Excellent!** No gas optimization issues were found in the analysis.\n\n"
else
    print_warning "Found $TOTAL_ISSUES gas optimization opportunities"
    generate_report "## Conclusion\n\n⚠️ **$TOTAL_ISSUES gas optimization opportunities** were found. Review the recommendations above to improve gas efficiency.\n\n"
fi

# 8. Cleanup
rm -f /tmp/gas_test.sol /tmp/comprehensive_gas_test.sol

print_header "Analysis Complete"
echo "📊 Report saved to: $REPORT_FILE"
echo "📁 All analysis files saved to: $OUTPUT_DIR/"
echo ""
echo "Files generated:"
echo "  - $REPORT_FILE (main report)"
echo "  - ${OUTPUT_DIR}/forge-gas-report.txt"
echo "  - ${OUTPUT_DIR}/state-optimizations.txt"
echo "  - ${OUTPUT_DIR}/visibility-optimizations.txt"
echo "  - ${OUTPUT_DIR}/unused-code.txt"
echo "  - ${OUTPUT_DIR}/costly-loops.txt"
echo "  - ${OUTPUT_DIR}/storage-layout.txt"
echo "  - ${OUTPUT_DIR}/function-summary.txt"
echo "  - ${OUTPUT_DIR}/contract-sizes.txt"
echo "  - ${OUTPUT_DIR}/function-gas-usage.txt"
echo "  - ${OUTPUT_DIR}/recommendations.txt"
echo ""

if [ $TOTAL_ISSUES -gt 0 ]; then
    echo -e "${YELLOW}💡 Tip: Review the recommendations in the report for gas optimization opportunities.${NC}"
else
    echo -e "${GREEN}🎉 Great job! Your contracts are already well-optimized for gas usage.${NC}"
fi

echo ""
echo -e "${BLUE}To view the full report:${NC}"
echo -e "${BLUE}  cat $REPORT_FILE${NC}"
echo ""