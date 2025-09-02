#!/bin/bash

# Slither Security Analysis Script for Quantillon Protocol
# This script runs Slither analysis on the smart contracts

# Ensure we're in the project root directory
cd "$(dirname "$0")/.."

echo "🔍 Running Slither Security Analysis..."

# Check if Python virtual environment exists
if [ ! -d "venv" ]; then
    echo "📦 Creating Python virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
echo "🔧 Activating virtual environment..."
source venv/bin/activate

# Install/upgrade dependencies
echo "📥 Installing Slither dependencies..."
pip install -r requirements.txt

# Run Slither analysis with human-readable output
echo "🚀 Running Slither analysis..."
slither . --config-file slither.config.json --print human-summary

# Check exit code
if [ $? -eq 0 ]; then
    echo "✅ Slither analysis completed successfully"
else
    echo "⚠️  Slither analysis found issues - check the output above"
fi

# Generate human-readable text report
echo "📝 Generating human-readable text report..."
slither . --config-file slither.config.json --print human-summary > slither-report.txt 2>&1

# Parse and display results in human-readable format
echo ""
echo "📖 PARSING RESULTS FOR HUMAN READABILITY"
echo "========================================"
echo ""

# Extract summary information
echo "📊 ANALYSIS SUMMARY"
echo "-------------------"
TOTAL_CONTRACTS=$(cat slither-report.txt | grep "Total number of contracts" | sed 's/.*: //' | head -1)
SOURCE_SLOC=$(cat slither-report.txt | grep "SLOC in source files" | sed 's/.*: //' | head -1)
DEPENDENCY_SLOC=$(cat slither-report.txt | grep "SLOC in dependencies" | sed 's/.*: //' | head -1)

if [ ! -z "$TOTAL_CONTRACTS" ]; then
    echo "📦 Total Contracts: $TOTAL_CONTRACTS"
fi
if [ ! -z "$SOURCE_SLOC" ]; then
    echo "📝 Source Code: $SOURCE_SLOC lines"
fi
if [ ! -z "$DEPENDENCY_SLOC" ]; then
    echo "🔗 Dependencies: $DEPENDENCY_SLOC lines"
fi
echo ""

# Extract issue counts
echo "🚨 SECURITY ISSUES BY PRIORITY"
echo "------------------------------"
HIGH_ISSUES=$(cat slither-report.txt | grep "high issues" | sed 's/.*: //' | head -1)
MEDIUM_ISSUES=$(cat slither-report.txt | grep "medium issues" | sed 's/.*: //' | head -1)
LOW_ISSUES=$(cat slither-report.txt | grep "low issues" | sed 's/.*: //' | head -1)
INFO_ISSUES=$(cat slither-report.txt | grep "informational issues" | sed 's/.*: //' | head -1)

if [ ! -z "$HIGH_ISSUES" ]; then
    echo "🔴 High Priority: $HIGH_ISSUES"
fi
if [ ! -z "$MEDIUM_ISSUES" ]; then
    echo "🟡 Medium Priority: $MEDIUM_ISSUES"
fi
if [ ! -z "$LOW_ISSUES" ]; then
    echo "🟢 Low Priority: $LOW_ISSUES"
fi
if [ ! -z "$INFO_ISSUES" ]; then
    echo "ℹ️  Informational: $INFO_ISSUES"
fi
echo ""

# Show top contracts analyzed
echo "📋 TOP CONTRACTS ANALYZED"
echo "-------------------------"
cat slither-report.txt | grep "^[A-Z][a-zA-Z0-9]*" | grep -v "Total\|Number\|Source\|assembly\|optimization\|informational\|low\|medium\|high\|Compiled\|ERCs\|INFO" | head -10 | while read contract; do
    if [[ $contract =~ ^[A-Z][a-zA-Z0-9]* ]]; then
        echo "📄 $contract"
    fi
done

echo ""
# Show key security findings summary
echo "🔍 KEY SECURITY FINDINGS SUMMARY"
echo "-------------------------------"
if [ ! -z "$HIGH_ISSUES" ]; then
    echo "💡 The analysis found $HIGH_ISSUES high-priority issues that require immediate attention"
fi
if [ ! -z "$MEDIUM_ISSUES" ]; then
    echo "⚠️  There are $MEDIUM_ISSUES medium-priority issues that should be addressed soon"
fi
if [ ! -z "$LOW_ISSUES" ] && [ ! -z "$INFO_ISSUES" ]; then
    echo "📝 $LOW_ISSUES low-priority issues and $INFO_ISSUES informational items for improvement"
fi
echo ""
echo "🔧 RECOMMENDATIONS:"
echo "   - Review high-priority findings first"
echo "   - Address medium-priority issues in next development cycle"
echo "   - Consider low-priority items for future optimizations"
echo "   - Use detailed console output above for specific vulnerability details"
echo ""

echo "========================================"
echo "📊 Reports generated:"
echo "   - Console output (above)"
echo "   - slither-report.json (detailed JSON)"
echo "   - slither-report.sarif (IDE integration)"
echo "   - slither-report.txt (human-readable)"
echo ""
echo "💡 For detailed findings, check the console output above"
echo "🔧 Run 'make slither' to regenerate reports"

# Deactivate virtual environment
deactivate

echo "🎯 Slither analysis complete!"
