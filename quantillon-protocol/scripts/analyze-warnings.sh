#!/bin/bash

# Quantillon Protocol - Build Warnings Analysis Script
# @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
# @notice Analyzes and isolates build warnings for better code quality

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

# Load environment variables from .env file using dotenvx
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

RESULTS_DIR="${RESULTS_DIR:-scripts/results}"
BUILD_OUTPUT_FILE="${RESULTS_DIR}/build-output.log"
WARNINGS_DIR="${RESULTS_DIR}/warnings-analysis"

echo -e "${BLUE}🔍 Quantillon Protocol - Build Warnings Analysis${NC}"
echo -e "${BLUE}================================================${NC}"

# Create warnings analysis directory
mkdir -p "$WARNINGS_DIR"

# Function to count warnings
count_warnings() {
    local warning_type="$1"
    local count=$(grep -c "Warning ($warning_type)" "$BUILD_OUTPUT_FILE" 2>/dev/null || echo "0")
    echo "$count"
}

# Function to extract warnings by type
extract_warnings() {
    local warning_type="$1"
    local output_file="$2"
    local description="$3"
    
    echo -e "${CYAN}📋 Extracting $description...${NC}"
    grep -A 3 "Warning ($warning_type)" "$BUILD_OUTPUT_FILE" > "$output_file" 2>/dev/null || touch "$output_file"
    
    local count=$(count_warnings "$warning_type")
    echo -e "   ${GREEN}✓${NC} Found $count $description"
}

# Function to generate summary
generate_summary() {
    local summary_file="$WARNINGS_DIR/warnings-summary.log"
    
    echo "=== QUANTILLON PROTOCOL BUILD WARNINGS ANALYSIS ===" > "$summary_file"
    echo "Generated: $(date)" >> "$summary_file"
    echo "Build Output: $BUILD_OUTPUT_FILE" >> "$summary_file"
    echo "" >> "$summary_file"
    
    echo "📊 WARNING STATISTICS:" >> "$summary_file"
    echo "• Unused Variables (2072): $(count_warnings 2072) warnings" >> "$summary_file"
    echo "• Unused Parameters (5667): $(count_warnings 5667) warnings" >> "$summary_file"
    echo "• Function Mutability (2018): $(count_warnings 2018) warnings" >> "$summary_file"
    echo "• Solver/CHC Warnings: Multiple (non-critical)" >> "$summary_file"
    echo "" >> "$summary_file"
    
    echo "💡 RECOMMENDATIONS:" >> "$summary_file"
    echo "1. Priority 1: Fix unused variables in production files" >> "$summary_file"
    echo "2. Priority 2: Fix unused parameters in production files" >> "$summary_file"
    echo "3. Priority 3: Optimize function mutability for gas efficiency" >> "$summary_file"
    echo "4. Priority 4: Clean up test file warnings (optional)" >> "$summary_file"
}

# Function to display results
display_results() {
    echo -e "\n${GREEN}✅ Analysis Complete!${NC}"
    echo -e "${BLUE}📁 Results saved to: $WARNINGS_DIR/${NC}"
    echo ""
    echo -e "${YELLOW}📊 Quick Summary:${NC}"
    echo -e "   • Unused Variables: $(count_warnings 2072) warnings"
    echo -e "   • Unused Parameters: $(count_warnings 5667) warnings"
    echo -e "   • Function Mutability: $(count_warnings 2018) warnings"
    echo -e "   • Solver/CHC: Multiple (non-critical)"
    echo ""
    echo -e "${PURPLE}💡 View detailed results:${NC}"
    echo -e "   cat $WARNINGS_DIR/warnings-summary.log"
}

# Main execution
main() {
    # Check if build output exists
    if [ ! -f "$BUILD_OUTPUT_FILE" ]; then
        echo -e "${RED}❌ Error: $BUILD_OUTPUT_FILE not found!${NC}"
        echo -e "${YELLOW}💡 Run 'make build' first to generate build output${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}📊 Analyzing build warnings...${NC}"
    
    # Extract different types of warnings
    extract_warnings "2072" "$WARNINGS_DIR/warnings-unused-variables.log" "unused variable warnings"
    extract_warnings "5667" "$WARNINGS_DIR/warnings-unused-parameters.log" "unused parameter warnings"
    extract_warnings "2018" "$WARNINGS_DIR/warnings-function-mutability.log" "function mutability warnings"
    extract_warnings "8158\|9134\|7649" "$WARNINGS_DIR/warnings-solver.log" "solver/CHC warnings"
    
    # Generate comprehensive summary
    echo -e "${CYAN}📋 Generating summary...${NC}"
    generate_summary
    
    # Display results
    display_results
    
    echo -e "${GREEN}🎉 Warning analysis complete!${NC}"
}

# Run main function
main "$@"
