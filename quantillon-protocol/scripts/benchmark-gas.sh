#!/bin/bash

# Gas Benchmarking Script for Quantillon Protocol
# Allows benchmarking specific functions and comparing gas usage

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

print_section() {
    echo -e "\n${YELLOW}$1${NC}"
    echo -e "${YELLOW}$(printf '%.0s-' {1..${#1}})${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -f, --function FUNCTION    Benchmark specific function"
    echo "  -c, --contract CONTRACT    Benchmark specific contract"
    echo "  -t, --test TEST_NAME       Run specific test"
    echo "  -o, --output FILE          Output file for results"
    echo "  -v, --verbose              Verbose output"
    echo "  -h, --help                 Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 -f mint -c QEUROToken"
    echo "  $0 -t testDeposit"
    echo "  $0 -c UserPool -o results.txt"
}

# Default values
FUNCTION=""
CONTRACT=""
TEST_NAME=""
OUTPUT_FILE=""
VERBOSE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--function)
            FUNCTION="$2"
            shift 2
            ;;
        -c|--contract)
            CONTRACT="$2"
            shift 2
            ;;
        -t|--test)
            TEST_NAME="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

print_header "Gas Benchmarking Tool"

# Create output file if specified
if [ -n "$OUTPUT_FILE" ]; then
    echo "Results will be saved to: $OUTPUT_FILE"
    echo "Gas Benchmark Results - $(date)" > "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
fi

# Function to run benchmark
run_benchmark() {
    local test_pattern="$1"
    local description="$2"
    
    print_section "$description"
    
    if [ "$VERBOSE" = true ]; then
        echo "Running: forge test --gas-report --match-test $test_pattern"
    fi
    
    # Run the benchmark
    if forge test --gas-report --match-test "$test_pattern" > /tmp/benchmark_output.txt 2>&1; then
        print_success "Benchmark completed"
        
        # Extract gas information
        if grep -q "Gas" /tmp/benchmark_output.txt; then
            echo "Gas Usage:"
            grep -A 10 -B 2 "Gas" /tmp/benchmark_output.txt | head -20
            
            # Save to output file if specified
            if [ -n "$OUTPUT_FILE" ]; then
                echo "## $description" >> "$OUTPUT_FILE"
                echo "" >> "$OUTPUT_FILE"
                grep -A 10 -B 2 "Gas" /tmp/benchmark_output.txt | head -20 >> "$OUTPUT_FILE"
                echo "" >> "$OUTPUT_FILE"
            fi
        else
            print_error "No gas information found"
        fi
    else
        print_error "Benchmark failed"
        if [ "$VERBOSE" = true ]; then
            cat /tmp/benchmark_output.txt
        fi
    fi
}

# Build contracts first
print_section "Building Contracts"
if forge build > /dev/null 2>&1; then
    print_success "Contracts built successfully"
else
    print_error "Failed to build contracts"
    exit 1
fi

# Run benchmarks based on parameters
if [ -n "$TEST_NAME" ]; then
    # Benchmark specific test
    run_benchmark "$TEST_NAME" "Benchmarking Test: $TEST_NAME"
elif [ -n "$FUNCTION" ] && [ -n "$CONTRACT" ]; then
    # Benchmark specific function in contract
    run_benchmark "test.*$FUNCTION.*$CONTRACT" "Benchmarking Function: $FUNCTION in $CONTRACT"
elif [ -n "$CONTRACT" ]; then
    # Benchmark all functions in contract
    run_benchmark ".*$CONTRACT.*" "Benchmarking Contract: $CONTRACT"
elif [ -n "$FUNCTION" ]; then
    # Benchmark function across all contracts
    run_benchmark ".*$FUNCTION.*" "Benchmarking Function: $FUNCTION"
else
    # Run comprehensive benchmark
    print_section "Running Comprehensive Gas Benchmark"
    
    # Core contracts
    run_benchmark ".*QEUROToken.*" "QEURO Token Operations"
    run_benchmark ".*QTIToken.*" "QTI Token Operations"
    run_benchmark ".*UserPool.*" "User Pool Operations"
    run_benchmark ".*QuantillonVault.*" "Quantillon Vault Operations"
    run_benchmark ".*AaveVault.*" "Aave Vault Operations"
    run_benchmark ".*YieldShift.*" "Yield Shift Operations"
    run_benchmark ".*HedgerPool.*" "Hedger Pool Operations"
    
    # Common operations
    run_benchmark ".*mint.*" "Minting Operations"
    run_benchmark ".*burn.*" "Burning Operations"
    run_benchmark ".*deposit.*" "Deposit Operations"
    run_benchmark ".*withdraw.*" "Withdrawal Operations"
    run_benchmark ".*stake.*" "Staking Operations"
    run_benchmark ".*unstake.*" "Unstaking Operations"
fi

# Cleanup
rm -f /tmp/benchmark_output.txt

print_header "Benchmark Complete"

if [ -n "$OUTPUT_FILE" ]; then
    echo "📊 Results saved to: $OUTPUT_FILE"
fi

echo ""
echo " Tips for gas optimization:"
echo "  - Use 'immutable' for constructor-set variables"
echo "  - Use 'constant' for compile-time constants"
echo "  - Pack structs efficiently"
echo "  - Use 'external' instead of 'public' when possible"
echo "  - Avoid expensive operations in loops"
echo ""
