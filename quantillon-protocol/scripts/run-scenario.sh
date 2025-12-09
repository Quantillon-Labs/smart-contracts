#!/bin/bash
# Helper script to run StateTrackerScenario and save formatted output to results folder
# This script ensures contracts are freshly deployed before running the scenario

set -e

# Show help if no arguments or --help is requested
if [ $# -eq 0 ] || [ "$1" = "--help" ] || [ "$1" = "-h" ] || [ "$1" = "help" ]; then
    cat << EOF
================================================================================
QUANTILLON PROTOCOL - SCENARIO REPLAY SCRIPT
================================================================================

Usage: $0 [MODE] [STOP_AFTER_STEP] [FEE_PERCENTAGE]

This script automatically:
  1. Redeploys all contracts to ensure fresh state
  2. Runs the scenario (up to specified step or all 26 steps)
  3. Generates formatted log files in scripts/results/

ARGUMENTS:
  MODE            Position mode (required):
                  single    - Use single hedging position (adds margin to existing position)
                  multiple  - Use multiple hedging positions (opens new positions)
  
  STOP_AFTER_STEP Step number (1-26) to stop after. If not specified, runs all 26 steps.
  
  FEE_PERCENTAGE  Mint fee percentage (e.g., 0.1 for 0.1%, 0 for 0%). Default: 0.1

OUTPUT:
  Raw log:     scripts/results/scenario-{timestamp}.log

REQUIREMENTS:
  - Anvil running on localhost:8545
  - restart-local-stack.sh in ~/GitHub/
  - PRIVATE_KEY environment variable set

SCENARIO STEPS:
  1.  Hedger deposits 50 USDC at 5% margin (Oracle at 1.08)
  2.  Oracle price → 1.09 USD/EUR
  3.  User mints 500 QEURO
  4.  Oracle price → 1.11 USD/EUR
  5.  Hedger adds 50 USD to its position
  6.  Oracle price → 1.13 USD/EUR
  7.  User mints 350 QEURO
  8.  Oracle price → 1.15 USD/EUR
  9.  User redeems 180 QEURO
  10. Hedger deposits 50 more USD to its collateral
  11. User mints 500 QEURO
  12. Oracle price → 1.12 USD/EUR
  13. Oracle price → 1.15 USD/EUR
  14. Hedger adds 50 more USD to its collateral
  15. Oracle price → 1.13 USD/EUR
  16. Oracle price → 1.11 USD/EUR
  17. User mints 1500 QEURO
  18. Oracle price → 1.15 USD/EUR
  19. User redeems 1000 QEURO
  20. Oracle price → 1.13 USD/EUR
  21. User redeems 1000 QEURO
  22. Hedger removes 50 USD from its collateral
  23. Oracle price → 1.16 USD/EUR
  24. Hedger removes 20 USD from its collateral
  25. Oracle price → 1.10 USD/EUR
  26. User redeems all his QEURO left

EXAMPLES:
  $0 single 10 0.1         # Run 10 steps with single position, 0.1% fee
  $0 multiple 26 0         # Run all 26 steps with multiple positions, 0% fee
  $0 single 5 0.5          # Run 5 steps with single position, 0.5% fee

For more information, see the StateTrackerScenario.s.sol script.

================================================================================
EOF
    exit 0
fi

# Parse mode argument
SCENARIO_MODE=""
if [ "$1" = "single" ]; then
    SCENARIO_MODE="single"
elif [ "$1" = "multiple" ]; then
    SCENARIO_MODE="multiple"
else
    echo "ERROR: Invalid mode: $1"
    echo ""
    echo "Valid modes: single, multiple"
    echo "Use '$0' or '$0 --help' for usage information."
    exit 1
fi

# Parse stop after step argument (optional)
STOP_AFTER_STEP=""
if [ $# -ge 2 ]; then
    STOP_AFTER_STEP="$2"
    # Validate it's a number between 1 and 26
    if ! [[ "$STOP_AFTER_STEP" =~ ^[0-9]+$ ]] || [ "$STOP_AFTER_STEP" -lt 1 ] || [ "$STOP_AFTER_STEP" -gt 26 ]; then
        echo "ERROR: Invalid step number: $STOP_AFTER_STEP"
        echo ""
        echo "Step number must be between 1 and 26."
        echo "Use '$0' or '$0 --help' for usage information."
        exit 1
    fi
fi

# Parse fee percentage argument (optional, default: 0.1%)
FEE_PERCENTAGE="0.1"
if [ $# -ge 3 ]; then
    FEE_PERCENTAGE="$3"
    # Validate it's a valid number (can be decimal)
    if ! [[ "$FEE_PERCENTAGE" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        echo "ERROR: Invalid fee percentage: $FEE_PERCENTAGE"
        echo ""
        echo "Fee percentage must be a number (e.g., 0.1 for 0.1%, 0 for 0%)."
        echo "Use '$0' or '$0 --help' for usage information."
        exit 1
    fi
fi

# Convert fee percentage to 18-decimal format
# Formula: fee_percentage / 100 * 1e18 = fee_percentage * 1e16
# Using awk for decimal arithmetic (more portable than bc)
MINT_FEE=$(awk "BEGIN {printf \"%.0f\", $FEE_PERCENTAGE * 10000000000000000}")

# Show brief helper
if [ -n "$STOP_AFTER_STEP" ]; then
    echo "=================================================================================="
    echo "QUANTILLON PROTOCOL - SCENARIO REPLAY"
    echo "=================================================================================="
    echo ""
    echo "Running scenario replay script..."
    echo "  - Mode: $SCENARIO_MODE positions"
    echo "  - Stop after step: $STOP_AFTER_STEP"
    echo "  - Mint fee: $FEE_PERCENTAGE%"
    echo "  - Contracts will be redeployed to ensure fresh state"
    echo "  - Results saved to scripts/results/"
    echo ""
    echo "=================================================================================="
    echo ""
else
    echo "=================================================================================="
    echo "QUANTILLON PROTOCOL - SCENARIO REPLAY"
    echo "=================================================================================="
    echo ""
    echo "Running scenario replay script..."
    echo "  - Mode: $SCENARIO_MODE positions"
    echo "  - Mint fee: $FEE_PERCENTAGE%"
    echo "  - Contracts will be redeployed to ensure fresh state"
    echo "  - 26-step scenario will be executed"
    echo "  - Results saved to scripts/results/"
    echo ""
    echo "=================================================================================="
    echo ""
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
echo "  2. Run the complete scenario (26 steps)"
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

# Step 2: Load environment variables
cd "$SCRIPT_DIR/.."
echo "Loading environment variables..."

# Check for network-specific .env file first, then fallback to default
ENV_FILE=""
if [ -f ".env.localhost" ]; then
    ENV_FILE=".env.localhost"
    echo "Found environment file: $ENV_FILE"
elif [ -f ".env" ]; then
    ENV_FILE=".env"
    echo "Found environment file: $ENV_FILE"
else
    echo "WARNING: No .env file found (.env.localhost or .env)"
    echo "Will try to use PRIVATE_KEY from environment..."
fi

# Load environment variables if file exists
if [ -n "$ENV_FILE" ] && [ -f "$ENV_FILE" ]; then
    set -a  # Automatically export all variables
    source "$ENV_FILE"
    set +a
    echo "Environment variables loaded from $ENV_FILE"
    
    # Create symlink for Foundry to find the environment file (matching deploy.sh pattern)
    if [ "$ENV_FILE" != ".env" ]; then
        ln -sf "$ENV_FILE" .env
        echo "Created symlink: .env -> $ENV_FILE"
    fi
fi

# Check if PRIVATE_KEY is set
if [ -z "$PRIVATE_KEY" ]; then
    echo ""
    echo "ERROR: PRIVATE_KEY environment variable is not set!"
    echo ""
    echo "Please either:"
    echo "  1. Set PRIVATE_KEY in .env.localhost or .env file, OR"
    echo "  2. Export it before running: export PRIVATE_KEY=your_private_key_here"
    echo ""
    exit 1
fi

echo "Running StateTrackerScenario..."
echo "Mode: $SCENARIO_MODE positions"
if [ -n "$STOP_AFTER_STEP" ]; then
    echo "Stop after step: $STOP_AFTER_STEP"
fi
echo "Mint fee: $FEE_PERCENTAGE% (raw value: $MINT_FEE)"
echo "This may take a few moments..."
echo ""

# Run the scenario with broadcast
# Matching deploy.sh pattern: use vm.startBroadcast(pk) in script and only pass --broadcast flag
# PRIVATE_KEY must be available as environment variable (loaded from .env file above)
# SCENARIO_MODE is passed as environment variable to control single vs multiple positions
# STOP_AFTER_STEP is passed as environment variable to stop after a specific step
# MINT_FEE is passed as argument to the run() function
# Add gas limit to prevent OutOfGas errors during oracle calls
# Increased to 50M to handle scenarios with many positions and operations
SCENARIO_MODE="$SCENARIO_MODE" STOP_AFTER_STEP="$STOP_AFTER_STEP" forge script scripts/StateTrackerScenario.s.sol:StateTrackerScenario \
    --sig "run(uint256)" "$MINT_FEE" \
    --rpc-url http://localhost:8545 \
    --broadcast \
    --gas-limit 50000000 \
    2>&1 | tee "$OUTPUT_FILE"

echo ""
echo "=========================================="
echo "Scenario execution complete!"
echo "Results saved to: $OUTPUT_FILE"
echo "=========================================="
echo ""

# Extract addresses.json from script output and copy to frontend
ADDRESSES_FILE="$SCRIPT_DIR/results/addresses.json"
FRONTEND_ADDRESSES_FILE=""

# Extract JSON between markers from the log file
if [ -f "$OUTPUT_FILE" ]; then
    # Extract JSON between ADDRESSES_JSON_START and ADDRESSES_JSON_END markers
    sed -n '/=== ADDRESSES_JSON_START ===/,/=== ADDRESSES_JSON_END ===/p' "$OUTPUT_FILE" | \
        sed '/=== ADDRESSES_JSON_START ===/d' | \
        sed '/=== ADDRESSES_JSON_END ===/d' > "$ADDRESSES_FILE"
    
    # Clean and format JSON using jq - this will:
    # 1. Parse and reformat the JSON properly
    # 2. Remove all trailing/leading spaces from string values (addresses)
    if [ -s "$ADDRESSES_FILE" ]; then
        # First, try to parse and clean the JSON
        jq 'walk(if type == "string" then gsub("^\\s+|\\s+$"; "") else . end)' "$ADDRESSES_FILE" > "${ADDRESSES_FILE}.tmp" 2>/dev/null
        if [ $? -eq 0 ] && [ -s "${ADDRESSES_FILE}.tmp" ]; then
            mv "${ADDRESSES_FILE}.tmp" "$ADDRESSES_FILE"
        else
            # Fallback: just format the JSON (jq will still clean some spaces)
            jq . "$ADDRESSES_FILE" > "${ADDRESSES_FILE}.tmp" 2>/dev/null && mv "${ADDRESSES_FILE}.tmp" "$ADDRESSES_FILE"
        fi
    fi
    
    # Check if we extracted valid JSON
    if [ -s "$ADDRESSES_FILE" ] && jq empty "$ADDRESSES_FILE" 2>/dev/null; then
        # Determine frontend path (relative to smart-contracts/quantillon-protocol)
        # Try to find quantillon-dapp directory
        if [ -d "../../quantillon-dapp/src/config" ]; then
            FRONTEND_ADDRESSES_FILE="../../quantillon-dapp/src/config/addresses.json"
        elif [ -d "../../../quantillon-dapp/src/config" ]; then
            FRONTEND_ADDRESSES_FILE="../../../quantillon-dapp/src/config/addresses.json"
        elif [ -d "$HOME/GitHub/quantillon-dapp/src/config" ]; then
            FRONTEND_ADDRESSES_FILE="$HOME/GitHub/quantillon-dapp/src/config/addresses.json"
        fi
        
        if [ -n "$FRONTEND_ADDRESSES_FILE" ]; then
            # Create directory if it doesn't exist
            mkdir -p "$(dirname "$FRONTEND_ADDRESSES_FILE")"
            # Merge with existing addresses.json to preserve other chain IDs
            if [ -f "$FRONTEND_ADDRESSES_FILE" ]; then
                # Merge the 31337 entry with existing file
                jq -s '.[0] * .[1]' "$FRONTEND_ADDRESSES_FILE" "$ADDRESSES_FILE" > "${FRONTEND_ADDRESSES_FILE}.tmp" 2>/dev/null
                if [ $? -eq 0 ] && [ -s "${FRONTEND_ADDRESSES_FILE}.tmp" ]; then
                    # Clean trailing spaces from merged file
                    jq 'walk(if type == "string" then gsub("^\\s+|\\s+$"; "") else . end)' "${FRONTEND_ADDRESSES_FILE}.tmp" > "$FRONTEND_ADDRESSES_FILE" 2>/dev/null
                    rm -f "${FRONTEND_ADDRESSES_FILE}.tmp"
                    echo "✓ Contract addresses merged with existing addresses.json (trailing spaces removed)"
                else
                    # Fallback: just copy and clean
                    jq 'walk(if type == "string" then gsub("^\\s+|\\s+$"; "") else . end)' "$ADDRESSES_FILE" > "$FRONTEND_ADDRESSES_FILE" 2>/dev/null
                    echo "⚠ Warning: Merge failed, overwrote addresses.json (other chain IDs may be lost)"
                fi
            else
                # File doesn't exist, copy and clean
                jq 'walk(if type == "string" then gsub("^\\s+|\\s+$"; "") else . end)' "$ADDRESSES_FILE" > "$FRONTEND_ADDRESSES_FILE" 2>/dev/null
                echo "✓ Contract addresses written to new addresses.json (trailing spaces removed)"
            fi
            echo "  $FRONTEND_ADDRESSES_FILE"
            echo "  Frontend will use these addresses on next refresh!"
            echo ""
            echo "⚠ IMPORTANT: To access Hedger Dashboard:"
            echo "  1. Connect MetaMask with address: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
            echo "     (Import account using PRIVATE_KEY from your .env file)"
            echo "  2. Connect to Localhost:8545 network"
            echo "  3. Refresh the frontend page (hard refresh: Ctrl+Shift+R or Cmd+Shift+R)"
            echo "  4. The hedger address is already whitelisted in the contract"
            echo ""
        else
            echo "⚠ Could not find frontend directory to copy addresses.json"
            echo "  Addresses file is available at: $ADDRESSES_FILE"
            echo "  Please manually copy to quantillon-dapp/src/config/addresses.json"
            echo ""
        fi
    else
        echo "⚠ Could not extract valid addresses.json from script output"
        echo "  Check the log file for address information: $OUTPUT_FILE"
        echo ""
    fi
fi

