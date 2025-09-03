#!/bin/bash

# Enhanced Slither Security Analysis Script for Quantillon Protocol
# This script runs Slither analysis with beautiful, readable output

# Ensure we're in the project root directory
cd "$(dirname "$0")/.."

echo "🔍 Running Enhanced Slither Security Analysis..."
echo ""

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

# Run Slither analysis with checklist output for detailed findings
echo "🚀 Running Slither analysis..."
slither . --config-file slither.config.json --exclude-dependencies --checklist --checklist-limit 10 > slither-temp-output.txt 2>&1
SLITHER_EXIT_CODE=$?

# Check exit code
if [ $SLITHER_EXIT_CODE -eq 0 ]; then
    echo "✅ Slither analysis completed successfully"
else
    echo "⚠️  Slither analysis found issues - check the output below"
fi

# Generate beautiful human-readable report
echo "📝 Generating beautiful human-readable report..."

# Create the beautiful report
cat > slither-report.txt << EOF
🎨 QUANTILLON PROTOCOL - ENHANCED SECURITY ANALYSIS REPORT
═══════════════════════════════════════════════════════════════════
Generated: $(date)
Tool: Slither Security Analyzer
Configuration: slither.config.json

📊 EXECUTIVE SUMMARY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

        # Add issue counts with proper error handling
        if [ -f "slither-temp-output.txt" ]; then
            echo "🔍 Debug: Found slither-temp-output.txt, analyzing issues..."
            HIGH_ISSUES=$(grep -c "sends eth to arbitrary user\|uninitialized state variables\|dangerous strict equality\|reentrancy" slither-temp-output.txt 2>/dev/null || echo "0")
            MEDIUM_ISSUES=$(grep -c "never initialized\|unused-return\|reentrancy-no-eth" slither-temp-output.txt 2>/dev/null || echo "0")
            LOW_ISSUES=$(grep -c "shadowing-local\|missing-zero-check\|calls-loop\|reentrancy-benign\|reentrancy-events\|timestamp\|costly-loop" slither-temp-output.txt 2>/dev/null || echo "0")
            INFO_ISSUES=$(grep -c "cyclomatic-complexity\|missing-inheritance\|unused-state\|constable-states" slither-temp-output.txt 2>/dev/null || echo "0")
            echo "🔍 Debug: HIGH_ISSUES=$HIGH_ISSUES, MEDIUM_ISSUES=$MEDIUM_ISSUES, LOW_ISSUES=$LOW_ISSUES, INFO_ISSUES=$INFO_ISSUES"
        else
            echo "🔍 Debug: slither-temp-output.txt not found!"
            HIGH_ISSUES=0
            MEDIUM_ISSUES=0
            LOW_ISSUES=0
            INFO_ISSUES=0
        fi

cat >> slither-report.txt << EOF
🔴 High Priority Issues: $HIGH_ISSUES
🟡 Medium Priority Issues: $MEDIUM_ISSUES  
🟢 Low Priority Issues: $LOW_ISSUES
ℹ️  Informational Issues: $INFO_ISSUES

🚨 CRITICAL FINDINGS (High Priority)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

# Extract and format high priority issues
if [ -f "slither-temp-output.txt" ]; then
            grep -A 5 -B 2 "sends eth to arbitrary user\|uninitialized state variables\|dangerous strict equality\|reentrancy" slither-temp-output.txt | while IFS= read -r line; do
        if [[ $line =~ ^[A-Z][a-zA-Z0-9]*\. ]]; then
            echo "🚨 ISSUE: $line" >> slither-report.txt
            echo "   Priority: HIGH" >> slither-report.txt
        elif [[ $line =~ "Reference:" ]]; then
            echo "   🔗 Documentation: $line" >> slither-report.txt
        elif [[ $line =~ "src/core/" ]]; then
            echo "   📍 Location: $line" >> slither-report.txt
        elif [[ $line =~ "Dangerous calls:" ]]; then
            echo "   ⚠️  $line" >> slither-report.txt
        elif [[ $line =~ "State variables written after the call" ]]; then
            echo "   🔄 $line" >> slither-report.txt
        elif [[ $line =~ "External calls:" ]]; then
            echo "   📞 $line" >> slither-report.txt
        elif [[ $line =~ "^- " ]]; then
            echo "      └─ $line" >> slither-report.txt
        elif [[ -n "$line" && ! $line =~ "━━━" && ! $line =~ "═══" ]]; then
            echo "   ℹ️  $line" >> slither-report.txt
        fi
    done
fi

cat >> slither-report.txt << 'EOF'

⚠️  MEDIUM PRIORITY FINDINGS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

# Extract and format medium priority issues
if [ -f "slither-temp-output.txt" ]; then
            grep -A 5 -B 2 "never initialized\|unused-return\|reentrancy-no-eth" slither-temp-output.txt | while IFS= read -r line; do
        if [[ $line =~ ^[A-Z][a-zA-Z0-9]*\. ]]; then
            echo "⚠️  ISSUE: $line" >> slither-report.txt
            echo "   Priority: MEDIUM" >> slither-report.txt
        elif [[ $line =~ "Reference:" ]]; then
            echo "   🔗 Documentation: $line" >> slither-report.txt
        elif [[ $line =~ "src/core/" ]]; then
            echo "   📍 Location: $line" >> slither-report.txt
        elif [[ $line =~ "Dangerous calls:" ]]; then
            echo "   ⚠️  $line" >> slither-report.txt
        elif [[ $line =~ "State variables written after the call" ]]; then
            echo "   🔄 $line" >> slither-report.txt
        elif [[ $line =~ "External calls:" ]]; then
            echo "   📞 $line" >> slither-report.txt
        elif [[ $line =~ "^- " ]]; then
            echo "      └─ $line" >> slither-report.txt
        elif [[ -n "$line" && ! $line =~ "━━━" && ! $line =~ "═══" ]]; then
            echo "   ℹ️  $line" >> slither-report.txt
        fi
    done
fi

cat >> slither-report.txt << 'EOF'

💡 LOW PRIORITY FINDINGS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

# Add complete breakdown by detector type
if [ -f "slither-temp-output.txt" ]; then
    echo "📊 COMPLETE ISSUE BREAKDOWN BY DETECTOR TYPE:" >> slither-report.txt
    echo "" >> slither-report.txt
    
    # Extract all detector types and their counts
    grep -E "## [a-zA-Z-]+" slither-temp-output.txt | while IFS= read -r line; do
        if [[ $line =~ "## ([a-zA-Z-]+)" ]]; then
            detector="${BASH_REMATCH[1]}"
            count=$(grep -c "## $detector" slither-temp-output.txt 2>/dev/null || echo "0")
            echo "   • [$detector](#$detector) ($count results)" >> slither-report.txt
        fi
    done
    
    echo "" >> slither-report.txt
fi

# Extract and format low priority issues (SHOW ALL)
if [ -f "slither-temp-output.txt" ]; then
    grep -A 3 -B 1 "shadowing-local\|missing-zero-check\|calls-loop\|reentrancy-benign\|reentrancy-events\|timestamp\|costly-loop" slither-temp-output.txt | while IFS= read -r line; do
        if [[ $line =~ ^[A-Z][a-zA-Z0-9]*\. ]]; then
            echo "💡 ISSUE: $line" >> slither-report.txt
            echo "   Priority: LOW" >> slither-report.txt
        elif [[ $line =~ "Reference:" ]]; then
            echo "   🔗 Documentation: $line" >> slither-report.txt
        elif [[ $line =~ "src/core/" ]]; then
            echo "   📍 Location: $line" >> slither-report.txt
        elif [[ $line =~ "Dangerous calls:" ]]; then
            echo "   ⚠️  $line" >> slither-report.txt
        elif [[ $line =~ "State variables written after the call" ]]; then
            echo "   🔄 $line" >> slither-report.txt
        elif [[ $line =~ "External calls:" ]]; then
            echo "   📞 $line" >> slither-report.txt
        elif [[ $line =~ "^- " ]]; then
            echo "      └─ $line" >> slither-report.txt
        elif [[ -n "$line" && ! $line =~ "━━━" && ! $line =~ "═══" ]]; then
            echo "   ℹ️  $line" >> slither-report.txt
        fi
    done
fi

# Add comprehensive issue listing by detector type
cat >> slither-report.txt << 'EOF'

📋 COMPREHENSIVE ISSUE LISTING BY DETECTOR TYPE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

# Extract and list all issues by detector type
if [ -f "slither-temp-output.txt" ]; then
    # Get all detector types
    detectors=$(grep -E "## [a-zA-Z-]+" slither-temp-output.txt | sed 's/## //')
    
    for detector in $detectors; do
        echo "🔍 DETECTOR: $detector" >> slither-report.txt
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >> slither-report.txt
        
        # Extract all issues for this detector
        awk -v det="$detector" '
        /^## / && $2 == det { 
            in_section = 1
            print "   📍 " $0
            next
        }
        /^## / && $2 != det { 
            in_section = 0
        }
        in_section && /^[[:space:]]*- \[ \] ID-[0-9]+/ {
            print "      └─ " $0
        }
        in_section && /^[[:space:]]*📍 Location:/ {
            print "         " $0
        }
        in_section && /^[[:space:]]*📞 External calls:/ {
            print "         " $0
        }
        in_section && /^[[:space:]]*🔄 State variables written after the call/ {
            print "         " $0
        }
        in_section && /^[[:space:]]*ℹ️ Event emitted after the call/ {
            print "         " $0
        }
        in_section && /^[[:space:]]*⚠️ Dangerous calls:/ {
            print "         " $0
        }
        in_section && /^[[:space:]]*📊 Impact:/ {
            print "         " $0
        }
        in_section && /^[[:space:]]*🎯 Confidence:/ {
            print "         " $0
        }
        ' slither-temp-output.txt >> slither-report.txt
        
        echo "" >> slither-report.txt
    done
fi

cat >> slither-report.txt << 'EOF'

ℹ️  INFORMATIONAL FINDINGS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

# Extract and format informational issues (SHOW ALL)
if [ -f "slither-temp-output.txt" ]; then
    grep -A 3 -B 1 "cyclomatic-complexity\|missing-inheritance\|unused-state\|constable-states" slither-temp-output.txt | while IFS= read -r line; do
        if [[ $line =~ ^[A-Z][a-zA-Z0-9]*\. ]]; then
            echo "ℹ️  ISSUE: $line" >> slither-report.txt
            echo "   Priority: INFORMATIONAL" >> slither-report.txt
        elif [[ $line =~ "Reference:" ]]; then
            echo "   🔗 Documentation: $line" >> slither-report.txt
        elif [[ $line =~ "src/core/" ]]; then
            echo "   📍 Location: $line" >> slither-report.txt
        elif [[ $line =~ "Dangerous calls:" ]]; then
            echo "   ⚠️  $line" >> slither-report.txt
        elif [[ $line =~ "State variables written after the call" ]]; then
            echo "   🔄 $line" >> slither-report.txt
        elif [[ $line =~ "External calls:" ]]; then
            echo "   📞 $line" >> slither-report.txt
        elif [[ $line =~ "^- " ]]; then
            echo "      └─ $line" >> slither-report.txt
        elif [[ -n "$line" && ! $line =~ "━━━" && ! $line =~ "═══" ]]; then
            echo "   ℹ️  $line" >> slither-report.txt
        fi
    done
fi

cat >> slither-report.txt << 'EOF'

🎯 ACTION PLAN & RECOMMENDATIONS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🚨 IMMEDIATE ACTIONS REQUIRED:
EOF

if [ "$HIGH_ISSUES" != "0" ]; then
    echo "   • Fix $HIGH_ISSUES high-priority issues (reentrancy, arbitrary ETH transfers)" >> slither-report.txt
    echo "   • Focus on functions that send ETH to arbitrary destinations" >> slither-report.txt
    echo "   • Address uninitialized state variables" >> slither-report.txt
fi

cat >> slither-report.txt << 'EOF'

⚠️  NEXT DEVELOPMENT CYCLE:
EOF

if [ "$MEDIUM_ISSUES" != "0" ]; then
    echo "   • Address $MEDIUM_ISSUES medium-priority issues" >> slither-report.txt
    echo "   • Fix unused return values and incorrect equality comparisons" >> slither-report.txt
    echo "   • Implement proper reentrancy guards" >> slither-report.txt
fi

cat >> slither-report.txt << 'EOF'

💡 IMPROVEMENT OPPORTUNITIES:
EOF

if [ "$LOW_ISSUES" != "0" ]; then
    echo "   • Consider $LOW_ISSUES low-priority items for future optimizations" >> slither-report.txt
    echo "   • Address timestamp usage and shadowing issues" >> slither-report.txt
    echo "   • Optimize loops and external calls" >> slither-report.txt
fi

cat >> slither-report.txt << 'EOF'

📚 RESOURCES & NEXT STEPS:
   • Review complete technical details in the generated report above
   • Check Slither documentation for each issue type
   • Consider automated fixes where possible
   • Run security analysis after each fix to verify resolution
   • Integrate security checks into your CI/CD pipeline

🔒 SECURITY STATUS:
EOF

if [ "$HIGH_ISSUES" = "0" ]; then
    echo "   ✅ No critical vulnerabilities found!" >> slither-report.txt
elif [ "$HIGH_ISSUES" -lt 5 ]; then
    echo "   🟡 Low critical vulnerability count - good progress!" >> slither-report.txt
else
    echo "   🔴 Multiple critical vulnerabilities require immediate attention!" >> slither-report.txt
fi

cat >> slither-report.txt << 'EOF'

🌟 REMEMBER: Security is an ongoing process, not a one-time check!

═══════════════════════════════════════════════════════════════════
Report generated by Enhanced Slither Analysis Script

📄 RAW SLITHER OUTPUT (COMPLETE)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

# Add the complete raw Slither output for transparency
if [ -f "slither-temp-output.txt" ]; then
    cat slither-temp-output.txt >> slither-report.txt
fi

cat >> slither-report.txt << 'EOF'

═══════════════════════════════════════════════════════════════════
End of Complete Slither Analysis Report
EOF

echo "✨ Beautiful human-readable report generated: slither-report.txt"

# Now display the beautiful report in console
echo ""
echo "🎨 ENHANCED SECURITY ANALYSIS REPORT"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

# Display the beautiful report content
cat slither-report.txt

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "📊 Reports generated:"
echo "   - Console output (above)"
echo "   - slither-report.json (detailed JSON)"
echo "   - slither-report.sarif (IDE integration)"
echo "   - slither-report.txt (beautiful human-readable report)"
echo ""
echo "💡 For complete findings, check slither-report.txt"
echo "🔧 Run 'make slither' to regenerate reports"

# Add a beautiful final summary
echo ""
echo "🎯 QUICK ACTION SUMMARY"
echo "═══════════════════════════════════════════════════════════════════"
echo ""
echo "🚨 IMMEDIATE ACTIONS:"
if [ "$HIGH_ISSUES" != "0" ]; then
    echo "   • Fix $HIGH_ISSUES high-priority issues (reentrancy, arbitrary ETH)"
fi
if [ "$MEDIUM_ISSUES" != "0" ]; then
    echo "   • Address $MEDIUM_ISSUES medium-priority issues (unused returns, equality)"
fi
echo ""
echo "💡 NEXT STEPS:"
echo "   • Review detailed findings in slither-report.txt"
echo "   • Prioritize fixes based on impact and exploitability"
echo "   • Consider automated fixes where possible"
echo "   • Run 'make slither' after each fix to verify resolution"
echo ""
echo "🔒 SECURITY STATUS:"
if [ "$HIGH_ISSUES" = "0" ]; then
    echo "   ✅ No critical vulnerabilities found!"
elif [ "$HIGH_ISSUES" -lt 5 ]; then
    echo "   🟡 Low critical vulnerability count - good progress!"
else
    echo "   🔴 Multiple critical vulnerabilities require immediate attention!"
fi

# Deactivate virtual environment
deactivate

# Clean up temporary file
if [ -f "slither-temp-output.txt" ]; then
    rm slither-temp-output.txt
fi

echo "🎯 Enhanced Slither analysis complete!"
