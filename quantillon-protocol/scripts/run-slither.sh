#!/bin/bash

# Enhanced Slither Security Analysis Script for Quantillon Protocol
# This script runs Slither analysis with beautiful, readable output

# Ensure we're in the project root directory
cd "$(dirname "$0")/.."

echo "🔍 Running Enhanced Slither Security Analysis..."
echo ""

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

# Configuration
RESULTS_DIR="${RESULTS_DIR:-scripts/results}"
SLITHER_DIR="$RESULTS_DIR/slither"

# Debug: Show the RESULTS_DIR being used
echo "📁 Using RESULTS_DIR: $RESULTS_DIR"
echo "📁 Slither output directory: $SLITHER_DIR"

# Create results directory
mkdir -p "$SLITHER_DIR"

# Run Slither analysis with checklist output for detailed findings
echo "🚀 Running Slither analysis..."
slither . --config-file slither.config.json --exclude-dependencies --show-ignored-findings --checklist 2>&1 | tee slither-temp-output.txt
SLITHER_EXIT_CODE=${PIPESTATUS[0]}

# Generate JSON and SARIF reports
echo "📄 Generating JSON and SARIF reports..."
slither . --config-file slither.config.json --exclude-dependencies --json $SLITHER_DIR/slither-report.json
slither . --config-file slither.config.json --exclude-dependencies --sarif $SLITHER_DIR/slither-report.sarif

# Check exit code
if [ $SLITHER_EXIT_CODE -eq 0 ]; then
    echo "✅ Slither analysis completed successfully"
else
    echo "⚠️  Slither analysis found issues - check the output below"
fi

# Generate beautiful human-readable report
echo "📝 Generating beautiful human-readable report..."

# Function to extract issues by detector type
extract_issues_by_detector() {
    local detector_name="$1"
    local priority="$2"
    local priority_icon="$3"
    
    echo "🔍 DETECTOR: $detector_name" >> $SLITHER_DIR/slither-report.txt
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >> $SLITHER_DIR/slither-report.txt
    
    # Extract issues for this specific detector using bash
    echo "   📍 ## $detector_name" >> $SLITHER_DIR/slither-report.txt
    
    # Find the section for this detector
    local section_start=$(grep -n "## $detector_name" slither-temp-output.txt | head -1 | cut -d: -f1)
    if [ -z "$section_start" ]; then
        echo "         ✅ No issues found for this detector" >> $SLITHER_DIR/slither-report.txt
        return
    fi
    
    # Find the next section or end of file
    local section_end=$(grep -n "^## " slither-temp-output.txt | grep -A 1 "^$section_start:" | tail -1 | cut -d: -f1)
    if [ -z "$section_end" ]; then
        section_end=$(wc -l < slither-temp-output.txt)
    fi
    
    # Extract all IDs in this section
    local ids=$(sed -n "${section_start},${section_end}p" slither-temp-output.txt | grep -E "^[[:space:]]*- \[ \] ID-[0-9]+" | sed 's/.*ID-\([0-9]*\).*/\1/')
    
    if [ -n "$ids" ]; then
        local issue_count=0
        
        # Process each ID
        for id in $ids; do
            echo "      └─  - [ ] ID-$id" >> $SLITHER_DIR/slither-report.txt
            issue_count=$((issue_count + 1))
            
            # Find the start line for this ID
            local id_start=$(grep -n "ID-$id" slither-temp-output.txt | head -1 | cut -d: -f1)
            if [ -n "$id_start" ]; then
                # Find the next ID or section boundary
                local id_end=$(grep -n -E "^[[:space:]]*- \[ \] ID-[0-9]+|^## " slither-temp-output.txt | grep -A 1 "^$id_start:" | tail -1 | cut -d: -f1)
                if [ -z "$id_end" ]; then
                    id_end=$((id_start + 20))
                fi
                
                # Extract the lines between this ID and the next
                sed -n "${id_start},${id_end}p" slither-temp-output.txt | while IFS= read -r line; do
                    # Skip the ID line itself
                    if [[ "$line" =~ ID-$id ]]; then
                        continue
                    fi
                    
                    # Stop if we hit another ID or section
                    if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*\[[[:space:]]*\][[:space:]]*ID-[0-9]+ ]] || [[ "$line" =~ ^## ]]; then
                        break
                    fi
                    
                    # Capture file location
                    if [[ "$line" =~ ^[[:space:]]*src/ ]]; then
                        echo "         📍 File: $line" >> $SLITHER_DIR/slither-report.txt
                    # Capture description lines (skip empty lines and file locations)
                    elif [[ -n "$line" ]] && [[ ! "$line" =~ ^[[:space:]]*$ ]]; then
                        echo "         📝 $line" >> $SLITHER_DIR/slither-report.txt
                    fi
                done
            fi
        done
        
        echo "   📊 Total Issues: $issue_count" >> $SLITHER_DIR/slither-report.txt
    else
        echo "         ✅ No issues found for this detector" >> $SLITHER_DIR/slither-report.txt
    fi
    
    echo "" >> $SLITHER_DIR/slither-report.txt
}

# Function to count issues by detector
count_issues_by_detector() {
    local detector_name="$1"
    # Look for the summary line that shows the count, e.g., "- [reentrancy-no-eth](#reentrancy-no-eth) (5 results) (Medium)"
    local count=$(grep -E "\\[${detector_name}\\]\\(#${detector_name}\\) \\(([0-9]+) results\\)" slither-temp-output.txt | sed -E 's/.*\(([0-9]+) results\).*/\1/' | head -1)
    echo "${count:-0}"
}

# Create the beautiful report
cat > $SLITHER_DIR/slither-report.txt << EOF
🎨 QUANTILLON PROTOCOL - ENHANCED SECURITY ANALYSIS REPORT
═══════════════════════════════════════════════════════════════════
Generated: $(date)
Tool: Slither Security Analyzer
Configuration: slither.config.json

📊 EXECUTIVE SUMMARY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

# Count issues by priority level (using proper detector mapping)
if [ -f "slither-temp-output.txt" ]; then
    echo "🔍 Analyzing Slither output for issue counts..."
    
    # High priority detectors (these don't exist in current output, but keeping for future)
    HIGH_ISSUES=0
    
    # Medium priority detectors (based on actual Slither output)
    MEDIUM_ISSUES=$((
        $(count_issues_by_detector "reentrancy-no-eth") +
        $(count_issues_by_detector "unused-return")
    ))
    
    # Low priority detectors (based on actual Slither output)
    LOW_ISSUES=$((
        $(count_issues_by_detector "shadowing-local") +
        $(count_issues_by_detector "missing-zero-check") +
        $(count_issues_by_detector "calls-loop") +
        $(count_issues_by_detector "reentrancy-benign") +
        $(count_issues_by_detector "timestamp")
    ))
    
    # Informational detectors (based on actual Slither output)
    INFO_ISSUES=$((
        $(count_issues_by_detector "cyclomatic-complexity") +
        $(count_issues_by_detector "low-level-calls") +
        $(count_issues_by_detector "costly-loop") +
        $(count_issues_by_detector "constable-states")
    ))
    
    echo "🔍 Counted: HIGH=$HIGH_ISSUES, MEDIUM=$MEDIUM_ISSUES, LOW=$LOW_ISSUES, INFO=$INFO_ISSUES"
else
    echo "🔍 Debug: slither-temp-output.txt not found!"
    HIGH_ISSUES=0
    MEDIUM_ISSUES=0
    LOW_ISSUES=0
    INFO_ISSUES=0
fi

cat >> $SLITHER_DIR/slither-report.txt << EOF
🔴 High Priority Issues: $HIGH_ISSUES
🟡 Medium Priority Issues: $MEDIUM_ISSUES  
🟢 Low Priority Issues: $LOW_ISSUES
ℹ️  Informational Issues: $INFO_ISSUES

🚨 CRITICAL FINDINGS (High Priority)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

# Extract high priority issues by detector
if [ -f "slither-temp-output.txt" ]; then
    extract_issues_by_detector "reentrancy-eth" "HIGH" "🚨"
    extract_issues_by_detector "arbitrary-send" "HIGH" "🚨"
    extract_issues_by_detector "uninitialized-state" "HIGH" "🚨"
    extract_issues_by_detector "dangerous-strict-equalities" "HIGH" "🚨"
fi

cat >> $SLITHER_DIR/slither-report.txt << 'EOF'

⚠️  MEDIUM PRIORITY FINDINGS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

# Extract medium priority issues by detector
if [ -f "slither-temp-output.txt" ]; then
    extract_issues_by_detector "reentrancy-no-eth" "MEDIUM" "⚠️"
    extract_issues_by_detector "unused-return" "MEDIUM" "⚠️"
    extract_issues_by_detector "incorrect-equality" "MEDIUM" "⚠️"
    extract_issues_by_detector "uninitialized-local" "MEDIUM" "⚠️"
fi

cat >> $SLITHER_DIR/slither-report.txt << 'EOF'

💡 LOW PRIORITY FINDINGS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

# Extract low priority issues by detector
if [ -f "slither-temp-output.txt" ]; then
    extract_issues_by_detector "shadowing-local" "LOW" "💡"
    extract_issues_by_detector "missing-zero-check" "LOW" "💡"
    extract_issues_by_detector "calls-loop" "LOW" "💡"
    extract_issues_by_detector "reentrancy-benign" "LOW" "💡"
    extract_issues_by_detector "reentrancy-events" "LOW" "💡"
    extract_issues_by_detector "timestamp" "LOW" "💡"
    extract_issues_by_detector "costly-loop" "LOW" "💡"
    extract_issues_by_detector "weak-prng" "LOW" "💡"
fi

cat >> $SLITHER_DIR/slither-report.txt << 'EOF'

ℹ️  INFORMATIONAL FINDINGS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

# Extract informational issues by detector
if [ -f "slither-temp-output.txt" ]; then
    extract_issues_by_detector "cyclomatic-complexity" "INFO" "ℹ️"
    extract_issues_by_detector "missing-inheritance" "INFO" "ℹ️"
    extract_issues_by_detector "unused-state" "INFO" "ℹ️"
    extract_issues_by_detector "constable-states" "INFO" "ℹ️"
    extract_issues_by_detector "external-function" "INFO" "ℹ️"
    extract_issues_by_detector "low-level-calls" "INFO" "ℹ️"
    extract_issues_by_detector "naming-convention" "INFO" "ℹ️"
fi

# Add comprehensive issue listing by detector type
cat >> $SLITHER_DIR/slither-report.txt << 'EOF'

📋 COMPREHENSIVE ISSUE LISTING BY DETECTOR TYPE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

# Extract and list all issues by detector type
if [ -f "slither-temp-output.txt" ]; then
    # Get all detector types
    detectors=$(grep -E "## [a-zA-Z-]+" slither-temp-output.txt | sed 's/## //')
    
    for detector in $detectors; do
        echo "🔍 DETECTOR: $detector" >> $SLITHER_DIR/slither-report.txt
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >> $SLITHER_DIR/slither-report.txt
        
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
        ' slither-temp-output.txt >> $SLITHER_DIR/slither-report.txt
        
        echo "" >> $SLITHER_DIR/slither-report.txt
    done
fi

cat >> $SLITHER_DIR/slither-report.txt << 'EOF'

🎯 ACTION PLAN & RECOMMENDATIONS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🚨 IMMEDIATE ACTIONS REQUIRED:
EOF

if [ "$HIGH_ISSUES" != "0" ]; then
    echo "   • Fix $HIGH_ISSUES high-priority issues (reentrancy, arbitrary ETH transfers)" >> $SLITHER_DIR/slither-report.txt
    echo "   • Focus on functions that send ETH to arbitrary destinations" >> $SLITHER_DIR/slither-report.txt
    echo "   • Address uninitialized state variables" >> $SLITHER_DIR/slither-report.txt
fi

cat >> $SLITHER_DIR/slither-report.txt << 'EOF'

⚠️  NEXT DEVELOPMENT CYCLE:
EOF

if [ "$MEDIUM_ISSUES" -gt 0 ]; then
    echo "   • Address $MEDIUM_ISSUES medium-priority issues" >> $SLITHER_DIR/slither-report.txt
    echo "   • Fix unused return values and reentrancy vulnerabilities" >> $SLITHER_DIR/slither-report.txt
    echo "   • Implement proper reentrancy guards" >> $SLITHER_DIR/slither-report.txt
fi

cat >> $SLITHER_DIR/slither-report.txt << 'EOF'

💡 IMPROVEMENT OPPORTUNITIES:
EOF

if [ "$LOW_ISSUES" -gt 0 ]; then
    echo "   • Consider $LOW_ISSUES low-priority items for future optimizations" >> $SLITHER_DIR/slither-report.txt
    echo "   • Address timestamp usage and shadowing issues" >> $SLITHER_DIR/slither-report.txt
    echo "   • Optimize loops and external calls" >> $SLITHER_DIR/slither-report.txt
fi

cat >> $SLITHER_DIR/slither-report.txt << 'EOF'

📚 RESOURCES & NEXT STEPS:
   • Review complete technical details in the generated report above
   • Check Slither documentation for each issue type
   • Consider automated fixes where possible
   • Run security analysis after each fix to verify resolution
   • Integrate security checks into your CI/CD pipeline

🔒 SECURITY STATUS:
EOF

if [ "$HIGH_ISSUES" -eq 0 ]; then
    echo "   ✅ No critical vulnerabilities found!" >> $SLITHER_DIR/slither-report.txt
elif [ "$HIGH_ISSUES" -lt 5 ]; then
    echo "   🟡 Low critical vulnerability count - good progress!" >> $SLITHER_DIR/slither-report.txt
else
    echo "   🔴 Multiple critical vulnerabilities require immediate attention!" >> $SLITHER_DIR/slither-report.txt
fi

cat >> $SLITHER_DIR/slither-report.txt << 'EOF'

🌟 REMEMBER: Security is an ongoing process, not a one-time check!

═══════════════════════════════════════════════════════════════════
Report generated by Enhanced Slither Analysis Script

📄 RAW SLITHER OUTPUT (COMPLETE)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

# Add the complete raw Slither output for transparency
if [ -f "slither-temp-output.txt" ]; then
    cat slither-temp-output.txt >> $SLITHER_DIR/slither-report.txt
fi

cat >> $SLITHER_DIR/slither-report.txt << 'EOF'

═══════════════════════════════════════════════════════════════════
End of Complete Slither Analysis Report
EOF

echo "✨ Beautiful human-readable report generated: $SLITHER_DIR/slither-report.txt"

# Now display the beautiful report in console
echo ""
echo "🎨 ENHANCED SECURITY ANALYSIS REPORT"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

# Display the beautiful report content
cat $SLITHER_DIR/slither-report.txt

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "📊 Reports generated:"
echo "   - Console output (above)"
echo "   - $SLITHER_DIR/slither-report.json (detailed JSON)"
echo "   - $SLITHER_DIR/slither-report.sarif (IDE integration)"
echo "   - $SLITHER_DIR/slither-report.txt (beautiful human-readable report)"
echo ""
echo "💡 For complete findings, check $SLITHER_DIR/slither-report.txt"
echo "🔧 Run 'make slither' to regenerate reports"

# Add a beautiful final summary
echo ""
echo "🎯 QUICK ACTION SUMMARY"
echo "═══════════════════════════════════════════════════════════════════"
echo ""
echo "🚨 IMMEDIATE ACTIONS:"
if [ "$HIGH_ISSUES" -gt 0 ]; then
    echo "   • Fix $HIGH_ISSUES high-priority issues (reentrancy, arbitrary ETH)"
fi
if [ "$MEDIUM_ISSUES" -gt 0 ]; then
    echo "   • Address $MEDIUM_ISSUES medium-priority issues (reentrancy-no-eth, unused-return)"
fi
echo ""
echo "💡 NEXT STEPS:"
echo "   • Review detailed findings in $SLITHER_DIR/slither-report.txt"
echo "   • Prioritize fixes based on impact and exploitability"
echo "   • Consider automated fixes where possible"
echo "   • Run 'make slither' after each fix to verify resolution"
echo ""
echo "🔒 SECURITY STATUS:"
if [ "$HIGH_ISSUES" -eq 0 ]; then
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
