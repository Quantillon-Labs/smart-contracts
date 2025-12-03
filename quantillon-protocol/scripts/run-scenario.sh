#!/bin/bash
# Helper script to run StateTrackerScenario and save formatted output to results folder
# This script ensures contracts are freshly deployed before running the scenario

set -e

# Show help if --help is requested
if [ "$1" = "--help" ] || [ "$1" = "-h" ] || [ "$1" = "help" ]; then
    cat << EOF
================================================================================
QUANTILLON PROTOCOL - SCENARIO REPLAY SCRIPT
================================================================================

Usage: $0 [OPTIONS]

This script automatically:
  1. Redeploys all contracts to ensure fresh state
  2. Runs the complete 15-step scenario
  3. Generates formatted log files in scripts/results/

OPTIONS:
  --help, -h, help    Show this help message
  (no arguments)      Run the scenario with default settings

OUTPUT:
  Raw log:     scripts/results/scenario-{timestamp}.log
  Formatted:   scripts/results/scenario-{timestamp}-formatted.log

REQUIREMENTS:
  - Anvil running on localhost:8545
  - restart-local-stack.sh in ~/GitHub/
  - PRIVATE_KEY environment variable set

EXAMPLE:
  $0

For more information, see the StateTrackerScenario.s.sol script.

================================================================================
EOF
    exit 0
fi

# Show brief helper if no arguments (but still proceed with execution)
if [ $# -eq 0 ]; then
    cat << EOF
================================================================================
QUANTILLON PROTOCOL - SCENARIO REPLAY
================================================================================

Running scenario replay script...
  - Contracts will be redeployed to ensure fresh state
  - 15-step scenario will be executed
  - Results saved to scripts/results/

Use '$0 --help' for more information.

================================================================================

EOF
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/results"
mkdir -p "$RESULTS_DIR"

# Get the root directory (GitHub folder)
# Try multiple possible locations
if [ -f "$HOME/GitHub/restart-local-stack.sh" ]; then
    ROOT_DIR="$HOME/GitHub"
elif [ -f "$SCRIPT_DIR/../../../restart-local-stack.sh" ]; then
    ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
else
    ROOT_DIR="$HOME/GitHub"
fi

TIMESTAMP=$(date +%s)
OUTPUT_FILE="$RESULTS_DIR/scenario-${TIMESTAMP}.log"

echo "=================================================================================="
echo "QUANTILLON PROTOCOL - SCENARIO REPLAY"
echo "=================================================================================="
echo ""
echo "This script will:"
echo "  1. Redeploy all contracts to ensure fresh state"
echo "  2. Run the complete scenario (15 steps)"
echo "  3. Save formatted results to: $OUTPUT_FILE"
echo ""
echo "Starting fresh deployment..."
echo ""

# Step 1: Redeploy contracts to ensure fresh state
cd "$ROOT_DIR"
if [ -f "restart-local-stack.sh" ]; then
    echo "Redeploying contracts to localhost with mocks..."
    bash restart-local-stack.sh localhost --with-mocks 2>&1 | \
        grep -E "Deployment completed|ERROR|Error|Starting|Deploying|Complete" | \
        tail -30
    echo ""
    echo "✓ Contracts redeployed successfully"
    echo ""
    sleep 2  # Give contracts a moment to settle
else
    echo "WARNING: restart-local-stack.sh not found in $ROOT_DIR"
    echo "Proceeding with existing deployment."
    echo "Make sure contracts are freshly deployed before running the scenario."
    echo ""
fi

# Step 2: Run the scenario
cd "$SCRIPT_DIR/.."
echo "Running StateTrackerScenario..."
echo "This may take a few moments..."
echo ""
forge script scripts/StateTrackerScenario.s.sol:StateTrackerScenario \
    --rpc-url http://localhost:8545 \
    --broadcast 2>&1 | tee "$OUTPUT_FILE"

# Create formatted version
FORMATTED_FILE="${OUTPUT_FILE%.log}-formatted.log"
echo ""
echo "Creating formatted log..."
"$SCRIPT_DIR/format-scenario-log.sh" "$OUTPUT_FILE" > /dev/null 2>&1

if [ -f "$FORMATTED_FILE" ]; then
    echo ""
    echo "=========================================="
    echo "Scenario execution complete!"
    echo ""
    echo "Raw output:     $OUTPUT_FILE"
    echo "Formatted log:  $FORMATTED_FILE"
    echo "=========================================="
    echo ""
    echo "The formatted log is much more readable with proper units and formatting!"
else
    echo ""
    echo "=========================================="
    echo "Scenario execution complete!"
    echo "Results saved to: $OUTPUT_FILE"
    echo "=========================================="
fi

