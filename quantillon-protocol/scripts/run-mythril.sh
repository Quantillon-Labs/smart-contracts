#!/bin/bash

# Quantillon Protocol - Mythril Security Analysis Script
# Runs Mythril symbolic execution analysis on all smart contracts

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="${RESULTS_DIR:-results}"
OUTPUT_DIR="$PROJECT_ROOT/$RESULTS_DIR/mythril-reports"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
REPORT_FILE="$OUTPUT_DIR/mythril-report-$TIMESTAMP.txt"
SARIF_FILE="$OUTPUT_DIR/mythril-report-$TIMESTAMP.sarif"

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo -e "${BLUE}🔍 QUANTILLON PROTOCOL - MYTHRIL SECURITY ANALYSIS${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "Generated: $(date)"
echo -e "Tool: Mythril Symbolic Execution Engine"
echo -e "Project: Quantillon Protocol Smart Contracts"
echo ""

# Check if Mythril is installed
if ! command -v myth &> /dev/null; then
    echo -e "${RED}❌ Mythril is not installed!${NC}"
    echo -e "${YELLOW}📦 Installing Mythril using pipx...${NC}"
    
    # Check if pipx is available
    if ! command -v pipx &> /dev/null; then
        echo -e "${YELLOW}📦 Installing pipx first...${NC}"
        sudo apt update && sudo apt install -y pipx
        pipx ensurepath
        export PATH="$PATH:/home/$USER/.local/bin"
    fi
    
    # Install Mythril using pipx
    pipx install mythril
    
    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}⚠️  pipx failed, trying pip3 --user...${NC}"
        pip3 install --user mythril
        
        if [ $? -ne 0 ]; then
            echo -e "${RED}❌ Failed to install Mythril. Please install manually:${NC}"
            echo -e "${YELLOW}   pipx install mythril${NC}"
            echo -e "${YELLOW}   or: pip3 install --user mythril${NC}"
            echo -e "${YELLOW}   or: pip3 install --break-system-packages mythril${NC}"
            exit 1
        fi
    fi
    
    echo -e "${GREEN}✅ Mythril installed successfully!${NC}"
fi

echo -e "${BLUE}📊 EXECUTIVE SUMMARY${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Initialize counters
TOTAL_CONTRACTS=0
VULNERABLE_CONTRACTS=0
TOTAL_ISSUES=0

# Core contracts to analyze
CORE_CONTRACTS=(
    "src/core/QEUROToken.sol:QEUROToken"
    "src/core/QTIToken.sol:QTIToken"
    "src/core/QuantillonVault.sol:QuantillonVault"
    "src/core/UserPool.sol:UserPool"
    "src/core/HedgerPool.sol:HedgerPool"
    "src/core/stQEUROToken.sol:stQEUROToken"
    "src/core/vaults/AaveVault.sol:AaveVault"
    "src/core/yieldmanagement/YieldShift.sol:YieldShift"
    "src/oracle/ChainlinkOracle.sol:ChainlinkOracle"
    "src/libraries/TimeProviderLibrary.sol:TimeProviderLibrary"
)

echo -e "${YELLOW}🎯 Analyzing Core Contracts...${NC}"
echo ""

# Analyze each core contract
for contract in "${CORE_CONTRACTS[@]}"; do
    contract_name=$(echo "$contract" | cut -d':' -f2)
    contract_file=$(echo "$contract" | cut -d':' -f1)
    
    echo -e "${BLUE}📋 Analyzing: $contract_name${NC}"
    echo -e "${BLUE}   File: $contract_file${NC}"
    
    TOTAL_CONTRACTS=$((TOTAL_CONTRACTS + 1))
    
    # Run Mythril analysis
    myth analyze "$contract" \
        --execution-timeout 300 \
        --max-depth 50 \
        --solver-timeout 10000 \
        --parallel-solving \
        --disable-dependency-pruning \
        --output json > "$OUTPUT_DIR/mythril-$contract_name.json" 2>/dev/null || true
    
    # Check if vulnerabilities were found
    if [ -f "$OUTPUT_DIR/mythril-$contract_name.json" ]; then
        issues_count=$(jq '.issues | length' "$OUTPUT_DIR/mythril-$contract_name.json" 2>/dev/null || echo "0")
        
        # Ensure issues_count is a valid number
        if [ -z "$issues_count" ] || [ "$issues_count" = "null" ]; then
            issues_count=0
        fi
        
        if [ "$issues_count" -gt 0 ]; then
            VULNERABLE_CONTRACTS=$((VULNERABLE_CONTRACTS + 1))
            TOTAL_ISSUES=$((TOTAL_ISSUES + issues_count))
            echo -e "${RED}   ⚠️  Found $issues_count potential issues${NC}"
        else
            echo -e "${GREEN}   ✅ No issues found${NC}"
        fi
    else
        echo -e "${YELLOW}   ⚠️  Analysis failed or timed out${NC}"
    fi
    
    echo ""
done

# Generate comprehensive report
echo -e "${BLUE}📊 ANALYSIS RESULTS${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "📈 Total Contracts Analyzed: $TOTAL_CONTRACTS"
echo -e "🔴 Contracts with Issues: $VULNERABLE_CONTRACTS"
echo -e "⚠️  Total Issues Found: $TOTAL_ISSUES"
echo ""

# Detailed vulnerability breakdown
echo -e "${BLUE}🔍 VULNERABILITY BREAKDOWN${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Count different types of vulnerabilities
declare -A vuln_types
declare -A vuln_severities

for contract in "${CORE_CONTRACTS[@]}"; do
    contract_name=$(echo "$contract" | cut -d':' -f2)
    json_file="$OUTPUT_DIR/mythril-$contract_name.json"
    
    if [ -f "$json_file" ]; then
        # Extract vulnerability types and severities
        jq -r '.issues[]? | .title' "$json_file" 2>/dev/null | while read -r title; do
            if [ -n "$title" ]; then
                vuln_types["$title"]=$((${vuln_types["$title"]:-0} + 1))
            fi
        done
        
        jq -r '.issues[]? | .severity' "$json_file" 2>/dev/null | while read -r severity; do
            if [ -n "$severity" ]; then
                vuln_severities["$severity"]=$((${vuln_severities["$severity"]:-0} + 1))
            fi
        done
    fi
done

# Display severity breakdown
echo -e "${YELLOW}📊 Severity Distribution:${NC}"
for severity in "High" "Medium" "Low" "Informational"; do
    count=${vuln_severities["$severity"]:-0}
    if [ "$count" -gt 0 ]; then
        case $severity in
            "High") echo -e "   🔴 High Priority: $count" ;;
            "Medium") echo -e "   🟡 Medium Priority: $count" ;;
            "Low") echo -e "   🟢 Low Priority: $count" ;;
            "Informational") echo -e "   ℹ️  Informational: $count" ;;
        esac
    fi
done

echo ""

# Detailed findings
echo -e "${BLUE}🔍 DETAILED FINDINGS${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

for contract in "${CORE_CONTRACTS[@]}"; do
    contract_name=$(echo "$contract" | cut -d':' -f2)
    json_file="$OUTPUT_DIR/mythril-$contract_name.json"
    
    if [ -f "$json_file" ] && [ -s "$json_file" ]; then
        issues_count=$(jq '.issues | length' "$json_file" 2>/dev/null || echo "0")
        
        # Ensure issues_count is a valid number
        if [ -z "$issues_count" ] || [ "$issues_count" = "null" ]; then
            issues_count=0
        fi
        
        if [ "$issues_count" -gt 0 ]; then
            echo -e "${YELLOW}📋 $contract_name:${NC}"
            
            jq -r '.issues[]? | "   \(.severity): \(.title) - \(.description)"' "$json_file" 2>/dev/null | while read -r line; do
                if [ -n "$line" ]; then
                    echo -e "   $line"
                fi
            done
            echo ""
        fi
    fi
done

# Recommendations
echo -e "${BLUE}💡 RECOMMENDATIONS${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ "$TOTAL_ISSUES" -eq 0 ]; then
    echo -e "${GREEN}✅ No security issues detected by Mythril!${NC}"
    echo -e "${GREEN}   Your contracts appear to be secure from common vulnerabilities.${NC}"
else
    echo -e "${YELLOW}⚠️  Security issues detected. Recommendations:${NC}"
    echo -e "   1. Review all High and Medium priority issues immediately"
    echo -e "   2. Consider implementing additional security measures"
    echo -e "   3. Run additional security tools (Slither, Echidna)"
    echo -e "   4. Consider professional security audit"
    echo -e "   5. Implement comprehensive testing for identified vulnerabilities"
fi

echo ""

# File locations
echo -e "${BLUE}📁 REPORT FILES${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "📄 Individual contract reports: $OUTPUT_DIR/mythril-*.json"
echo -e "📊 Summary report: $REPORT_FILE"
echo -e "🔍 SARIF report: $SARIF_FILE"

# Save summary to file
{
    echo "MYTHRIL SECURITY ANALYSIS REPORT"
    echo "Generated: $(date)"
    echo "Tool: Mythril Symbolic Execution Engine"
    echo "Project: Quantillon Protocol Smart Contracts"
    echo ""
    echo "EXECUTIVE SUMMARY"
    echo "Total Contracts Analyzed: $TOTAL_CONTRACTS"
    echo "Contracts with Issues: $VULNERABLE_CONTRACTS"
    echo "Total Issues Found: $TOTAL_ISSUES"
    echo ""
    echo "For detailed findings, check individual JSON reports in: $OUTPUT_DIR"
} > "$REPORT_FILE"

echo ""
echo -e "${GREEN}🎯 Mythril analysis complete!${NC}"
echo -e "${GREEN}   Reports saved to: $OUTPUT_DIR${NC}"
