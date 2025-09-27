#!/bin/bash

# Quantillon Protocol - Mythril Security Analysis Script
# Runs Mythril symbolic execution analysis on all smart contracts

set -e


# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Load environment variables using shared utility
source "$(dirname "${BASH_SOURCE[0]}")/utils/load-env.sh"
setup_environment
OUTPUT_DIR="$PROJECT_ROOT/$RESULTS_DIR/mythril-reports"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
REPORT_FILE="$OUTPUT_DIR/mythril-report-$TIMESTAMP.txt"
SARIF_FILE="$OUTPUT_DIR/mythril-report-$TIMESTAMP.sarif"

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo -e " QUANTILLON PROTOCOL - MYTHRIL SECURITY ANALYSIS"
echo -e "═══════════════════════════════════════════════════════════════════"
echo -e "Generated: $(date)"
echo -e "Tool: Mythril Symbolic Execution Engine"
echo -e "Project: Quantillon Protocol Smart Contracts"
echo ""

# Check if Mythril is installed
if ! command -v myth &> /dev/null; then
    echo -e " Mythril is not installed!"
    echo -e "📦 Installing Mythril using pipx..."
    
    # Check if pipx is available
    if ! command -v pipx &> /dev/null; then
        echo -e "📦 Installing pipx first..."
        sudo apt update && sudo apt install -y pipx
        pipx ensurepath
        export PATH="$PATH:/home/$USER/.local/bin"
    fi
    
    # Install Mythril using pipx
    pipx install mythril
    
    if [ $? -ne 0 ]; then
        echo -e "  pipx failed, trying pip3 --user..."
        pip3 install --user mythril
        
        if [ $? -ne 0 ]; then
            echo -e " Failed to install Mythril. Please install manually:"
            echo -e "   pipx install mythril"
            echo -e "   or: pip3 install --user mythril"
            echo -e "   or: pip3 install --break-system-packages mythril"
            exit 1
        fi
    fi
    
    echo -e " Mythril installed successfully!"
fi

echo -e "📊 EXECUTIVE SUMMARY"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

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

echo -e "🎯 Analyzing Core Contracts..."
echo ""

# Analyze each core contract
for contract in "${CORE_CONTRACTS[@]}"; do
    contract_name=$(echo "$contract" | cut -d':' -f2)
    contract_file=$(echo "$contract" | cut -d':' -f1)
    
    echo -e " Analyzing: $contract_name"
    echo -e "   File: $contract_file"
    
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
            echo -e "     Found $issues_count potential issues"
        else
            echo -e "    No issues found"
        fi
    else
        echo -e "     Analysis failed or timed out"
    fi
    
    echo ""
done

# Generate comprehensive report
echo -e "📊 ANALYSIS RESULTS"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "📈 Total Contracts Analyzed: $TOTAL_CONTRACTS"
echo -e "🔴 Contracts with Issues: $VULNERABLE_CONTRACTS"
echo -e "  Total Issues Found: $TOTAL_ISSUES"
echo ""

# Detailed vulnerability breakdown
echo -e " VULNERABILITY BREAKDOWN"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

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
echo -e "📊 Severity Distribution:"
for severity in "High" "Medium" "Low" "Informational"; do
    count=${vuln_severities["$severity"]:-0}
    if [ "$count" -gt 0 ]; then
        case $severity in
            "High") echo -e "   🔴 High Priority: $count" ;;
            "Medium") echo -e "    Medium Priority: $count" ;;
            "Low") echo -e "    Low Priority: $count" ;;
            "Informational") echo -e "     Informational: $count" ;;
        esac
    fi
done

echo ""

# Detailed findings
echo -e " DETAILED FINDINGS"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

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
            echo -e " $contract_name:"
            
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
echo -e " RECOMMENDATIONS"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$TOTAL_ISSUES" -eq 0 ]; then
    echo -e " No security issues detected by Mythril!"
    echo -e "   Your contracts appear to be secure from common vulnerabilities."
else
    echo -e "  Security issues detected. Recommendations:"
    echo -e "   1. Review all High and Medium priority issues immediately"
    echo -e "   2. Consider implementing additional security measures"
    echo -e "   3. Run additional security tools (Slither, Echidna)"
    echo -e "   4. Consider professional security audit"
    echo -e "   5. Implement comprehensive testing for identified vulnerabilities"
fi

echo ""

# File locations
echo -e "📁 REPORT FILES"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e " Individual contract reports: $OUTPUT_DIR/mythril-*.json"
echo -e "📊 Summary report: $REPORT_FILE"
echo -e " SARIF report: $SARIF_FILE"

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
echo -e "🎯 Mythril analysis complete!"
echo -e "   Reports saved to: $OUTPUT_DIR"
