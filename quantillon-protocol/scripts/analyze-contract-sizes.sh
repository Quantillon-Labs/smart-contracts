#!/bin/bash

# Quantillon Protocol - Contract Size Analysis Script
# Analyzes smart contract sizes against EIP-170 limit and logs results

set -e

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Load environment variables using shared utility
source "$(dirname "${BASH_SOURCE[0]}")/utils/load-env.sh"
setup_environment
OUTPUT_DIR="$PROJECT_ROOT/$RESULTS_DIR/contract-sizes"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
REPORT_FILE="$OUTPUT_DIR/contract-sizes-$TIMESTAMP.txt"
SUMMARY_FILE="$OUTPUT_DIR/contract-sizes-summary.txt"

# EIP-170 limit: 24KB = 24576 bytes
EIP170_LIMIT=24576

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo -e "${BLUE}🔍 QUANTILLON PROTOCOL - CONTRACT SIZE ANALYSIS${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "Generated: $(date)"
echo -e "EIP-170 Limit: $EIP170_LIMIT bytes (24KB)"
echo -e "Project: Quantillon Protocol Smart Contracts"
echo ""

# Function to get contract size from JSON
get_contract_size() {
    local json_file="$1"
    if [ -f "$json_file" ]; then
        # Extract deployedBytecode size (remove 0x prefix and count characters)
        local bytecode=$(jq -r '.deployedBytecode.object' "$json_file" 2>/dev/null)
        if [ "$bytecode" != "null" ] && [ "$bytecode" != "" ]; then
            # Remove 0x prefix and count characters, then divide by 2 (each byte is 2 hex chars)
            local size=$(((${#bytecode} - 2) / 2))
            echo $size
        else
            echo "0"
        fi
    else
        echo "0"
    fi
}

# Function to format size
format_size() {
    local size=$1
    if [ $size -ge 1024 ]; then
        local kb_size=$(echo "scale=1; $size/1024" | bc -l | tr ',' '.')
        echo "${kb_size} KB"
    else
        echo "${size} bytes"
    fi
}

# Function to get percentage of limit
get_percentage() {
    local size=$1
    local limit=$2
    local percentage=$(echo "scale=1; $size*100/$limit" | bc -l | tr ',' '.')
    echo "${percentage}%"
}

# Core contracts to analyze
core_contracts=(
    "HedgerPool.sol:HedgerPool"
    "QuantillonVault.sol:QuantillonVault"
    "QEUROToken.sol:QEUROToken"
    "QTIToken.sol:QTIToken"
    "UserPool.sol:UserPool"
    "stQEUROToken.sol:stQEUROToken"
    "AaveVault.sol:AaveVault"
    "YieldShift.sol:YieldShift"
    "ChainlinkOracle.sol:ChainlinkOracle"
    "TimelockUpgradeable.sol:TimelockUpgradeable"
)

# Initialize arrays
declare -a critical_contracts=()
declare -a warning_contracts=()
declare -a safe_contracts=()

total_size=0
contract_count=0

echo -e "${BLUE}📊 ANALYZING CORE SMART CONTRACTS${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Analyze each contract
for contract_info in "${core_contracts[@]}"; do
    contract_file=$(echo "$contract_info" | cut -d':' -f1)
    contract_name=$(echo "$contract_info" | cut -d':' -f2)
    
    json_file="out/$contract_file/$contract_name.json"
    size=$(get_contract_size "$json_file")
    
    if [ $size -gt 0 ]; then
        total_size=$((total_size + size))
        contract_count=$((contract_count + 1))
        
        percentage=$(get_percentage $size $EIP170_LIMIT)
        formatted_size=$(format_size $size)
        
        # Categorize contracts
        if [ $size -gt $EIP170_LIMIT ]; then
            critical_contracts+=("$contract_name:$size:$percentage")
            echo -e "${RED}❌ $contract_name${NC} - $formatted_size ($percentage of limit) - ${RED}EXCEEDS LIMIT${NC}"
        elif [ $size -gt $((EIP170_LIMIT * 80 / 100)) ]; then
            warning_contracts+=("$contract_name:$size:$percentage")
            echo -e "${YELLOW}⚠️  $contract_name${NC} - $formatted_size ($percentage of limit) - ${YELLOW}WARNING${NC}"
        else
            safe_contracts+=("$contract_name:$size:$percentage")
            echo -e "${GREEN}✅ $contract_name${NC} - $formatted_size ($percentage of limit) - ${GREEN}SAFE${NC}"
        fi
    else
        echo -e "${BLUE}ℹ️  $contract_name${NC} - Not found or no bytecode"
    fi
done

echo ""

# Generate summary statistics
echo -e "${BLUE}📈 SUMMARY STATISTICS${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Total Contracts Analyzed: $contract_count"
echo -e "Total Combined Size: $(format_size $total_size)"
echo -e "Average Contract Size: $(format_size $((total_size / contract_count)))"
echo ""

# Critical contracts section
echo -e "${BLUE}🚨 CRITICAL CONTRACTS (Exceed EIP-170 Limit)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if [ ${#critical_contracts[@]} -eq 0 ]; then
    echo -e "${GREEN}✅ No contracts exceed the EIP-170 limit!${NC}"
else
    for contract_info in "${critical_contracts[@]}"; do
        contract_name=$(echo "$contract_info" | cut -d':' -f1)
        size=$(echo "$contract_info" | cut -d':' -f2)
        percentage=$(echo "$contract_info" | cut -d':' -f3)
        formatted_size=$(format_size $size)
        echo -e "${RED}❌ $contract_name${NC} - $formatted_size ($percentage of limit)"
    done
fi

echo ""

# Warning contracts section
echo -e "${BLUE}⚠️  WARNING CONTRACTS (80%+ of EIP-170 Limit)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if [ ${#warning_contracts[@]} -eq 0 ]; then
    echo -e "${GREEN}✅ No contracts in warning zone!${NC}"
else
    for contract_info in "${warning_contracts[@]}"; do
        contract_name=$(echo "$contract_info" | cut -d':' -f1)
        size=$(echo "$contract_info" | cut -d':' -f2)
        percentage=$(echo "$contract_info" | cut -d':' -f3)
        formatted_size=$(format_size $size)
        echo -e "${YELLOW}⚠️  $contract_name${NC} - $formatted_size ($percentage of limit)"
    done
fi

echo ""

# Safe contracts section
echo -e "${BLUE}✅ SAFE CONTRACTS (Under 80% of EIP-170 Limit)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if [ ${#safe_contracts[@]} -eq 0 ]; then
    echo -e "${BLUE}ℹ️  No contracts in safe zone${NC}"
else
    for contract_info in "${safe_contracts[@]}"; do
        contract_name=$(echo "$contract_info" | cut -d':' -f1)
        size=$(echo "$contract_info" | cut -d':' -f2)
        percentage=$(echo "$contract_info" | cut -d':' -f3)
        formatted_size=$(format_size $size)
        echo -e "${GREEN}✅ $contract_name${NC} - $formatted_size ($percentage of limit)"
    done
fi

echo ""

# Recommendations section
echo -e "${BLUE}💡 RECOMMENDATIONS${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ ${#critical_contracts[@]} -gt 0 ]; then
    echo -e "${RED}🔴 CRITICAL:${NC} Contracts exceeding EIP-170 limit must be refactored:"
    echo -e "   • Split large contracts into smaller modules"
    echo -e "   • Move complex logic to libraries"
    echo -e "   • Use proxy patterns for upgradeability"
    echo -e "   • Remove unused code and optimize imports"
    echo ""
fi

if [ ${#warning_contracts[@]} -gt 0 ]; then
    echo -e "${YELLOW}🟡 WARNING:${NC} Contracts approaching limit should be monitored:"
    echo -e "   • Consider refactoring before adding new features"
    echo -e "   • Optimize existing code"
    echo -e "   • Move non-critical functions to libraries"
    echo ""
fi

if [ ${#critical_contracts[@]} -eq 0 ] && [ ${#warning_contracts[@]} -eq 0 ]; then
    echo -e "${GREEN}✅ All contracts are within safe limits!${NC}"
    echo -e "   • Continue monitoring as you add features"
    echo -e "   • Consider size optimization for gas efficiency"
fi

# Save detailed report to file
{
    echo "QUANTILLON PROTOCOL - CONTRACT SIZE ANALYSIS REPORT"
    echo "Generated: $(date)"
    echo "EIP-170 Limit: $EIP170_LIMIT bytes (24KB)"
    echo "Project: Quantillon Protocol Smart Contracts"
    echo ""
    echo "EXECUTIVE SUMMARY"
    echo "Total Contracts Analyzed: $contract_count"
    echo "Total Combined Size: $(format_size $total_size)"
    echo "Average Contract Size: $(format_size $((total_size / contract_count)))"
    echo ""
    echo "CRITICAL CONTRACTS (Exceed EIP-170 Limit): ${#critical_contracts[@]}"
    for contract_info in "${critical_contracts[@]}"; do
        contract_name=$(echo "$contract_info" | cut -d':' -f1)
        size=$(echo "$contract_info" | cut -d':' -f2)
        percentage=$(echo "$contract_info" | cut -d':' -f3)
        formatted_size=$(format_size $size)
        echo "  - $contract_name: $formatted_size ($percentage of limit)"
    done
    echo ""
    echo "WARNING CONTRACTS (80%+ of EIP-170 Limit): ${#warning_contracts[@]}"
    for contract_info in "${warning_contracts[@]}"; do
        contract_name=$(echo "$contract_info" | cut -d':' -f1)
        size=$(echo "$contract_info" | cut -d':' -f2)
        percentage=$(echo "$contract_info" | cut -d':' -f3)
        formatted_size=$(format_size $size)
        echo "  - $contract_name: $formatted_size ($percentage of limit)"
    done
    echo ""
    echo "SAFE CONTRACTS (Under 80% of EIP-170 Limit): ${#safe_contracts[@]}"
    for contract_info in "${safe_contracts[@]}"; do
        contract_name=$(echo "$contract_info" | cut -d':' -f1)
        size=$(echo "$contract_info" | cut -d':' -f2)
        percentage=$(echo "$contract_info" | cut -d':' -f3)
        formatted_size=$(format_size $size)
        echo "  - $contract_name: $formatted_size ($percentage of limit)"
    done
} > "$REPORT_FILE"

# Save summary to file
{
    echo "Contract Size Analysis Summary - $(date)"
    echo "========================================"
    echo "Critical Contracts: ${#critical_contracts[@]}"
    echo "Warning Contracts: ${#warning_contracts[@]}"
    echo "Safe Contracts: ${#safe_contracts[@]}"
    echo "Total Size: $(format_size $total_size)"
    echo ""
    if [ ${#critical_contracts[@]} -gt 0 ]; then
        echo "CRITICAL:"
        for contract_info in "${critical_contracts[@]}"; do
            contract_name=$(echo "$contract_info" | cut -d':' -f1)
            percentage=$(echo "$contract_info" | cut -d':' -f3)
            echo "  - $contract_name ($percentage of limit)"
        done
    fi
    if [ ${#warning_contracts[@]} -gt 0 ]; then
        echo "WARNING:"
        for contract_info in "${warning_contracts[@]}"; do
            contract_name=$(echo "$contract_info" | cut -d':' -f1)
            percentage=$(echo "$contract_info" | cut -d':' -f3)
            echo "  - $contract_name ($percentage of limit)"
        done
    fi
} > "$SUMMARY_FILE"

echo ""
echo -e "${GREEN}🎯 Contract size analysis complete!${NC}"
echo -e "${GREEN}   Detailed report: $REPORT_FILE${NC}"
echo -e "${GREEN}   Summary report: $SUMMARY_FILE${NC}"

# Exit with error code if critical contracts found
if [ ${#critical_contracts[@]} -gt 0 ]; then
    echo -e "${RED}❌ Analysis failed: ${#critical_contracts[@]} contracts exceed EIP-170 limit${NC}"
    exit 1
else
    echo -e "${GREEN}✅ All contracts within EIP-170 limits${NC}"
    exit 0
fi
