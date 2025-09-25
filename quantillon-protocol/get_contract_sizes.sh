#!/bin/bash

# EIP-170 limit: 24KB = 24576 bytes
EIP170_LIMIT=24576

echo "🔍 Smart Contract Size Analysis - EIP-170 Compliance Check"
echo "=========================================================="
echo "EIP-170 Limit: $EIP170_LIMIT bytes (24KB)"
echo ""

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
        printf "%.1f KB" $(echo "scale=1; $size/1024" | bc -l)
    else
        printf "%d bytes" $size
    fi
}

# Function to get percentage of limit
get_percentage() {
    local size=$1
    local limit=$2
    printf "%.1f%%" $(echo "scale=1; $size*100/$limit" | bc -l)
}

echo "📊 Analyzing Core Smart Contracts..."
echo ""

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

declare -a critical_contracts=()
declare -a warning_contracts=()
declare -a safe_contracts=()

total_size=0
contract_count=0

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
echo "📈 Summary Statistics:"
echo "======================"
echo -e "Total Contracts Analyzed: $contract_count"
echo -e "Total Combined Size: $(format_size $total_size)"
echo ""

echo "🚨 Critical Contracts (Exceed EIP-170 Limit):"
echo "=============================================="
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
echo "⚠️  Warning Contracts (80%+ of EIP-170 Limit):"
echo "=============================================="
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
echo "✅ Safe Contracts (Under 80% of EIP-170 Limit):"
echo "==============================================="
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
echo "💡 Recommendations:"
echo "==================="
if [ ${#critical_contracts[@]} -gt 0 ]; then
    echo -e "${RED}🔴 CRITICAL:${NC} Contracts exceeding EIP-170 limit must be refactored:"
    echo "   • Split large contracts into smaller modules"
    echo "   • Move complex logic to libraries"
    echo "   • Use proxy patterns for upgradeability"
    echo "   • Remove unused code and optimize imports"
fi

if [ ${#warning_contracts[@]} -gt 0 ]; then
    echo -e "${YELLOW}🟡 WARNING:${NC} Contracts approaching limit should be monitored:"
    echo "   • Consider refactoring before adding new features"
    echo "   • Optimize existing code"
    echo "   • Move non-critical functions to libraries"
fi

if [ ${#critical_contracts[@]} -eq 0 ] && [ ${#warning_contracts[@]} -eq 0 ]; then
    echo -e "${GREEN}✅ All contracts are within safe limits!${NC}"
    echo "   • Continue monitoring as you add features"
    echo "   • Consider size optimization for gas efficiency"
fi

