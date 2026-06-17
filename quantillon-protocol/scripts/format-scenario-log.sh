#!/bin/bash
# Script to extract and format clean, human-readable statistics from scenario log

INPUT_FILE="$1"
OUTPUT_FILE="${INPUT_FILE%.log}-formatted.log"

if [ -z "$INPUT_FILE" ]; then
    echo "Usage: $0 <scenario-log-file>"
    exit 1
fi

if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: File not found: $INPUT_FILE"
    exit 1
fi

echo "Extracting and formatting statistics from: $INPUT_FILE"
echo "Output will be saved to: $OUTPUT_FILE"

python3 << PYTHON_SCRIPT
import re
import sys

input_file = "$INPUT_FILE"
output_file = "$OUTPUT_FILE"

with open(input_file, 'r') as f:
    lines = f.readlines()

# Extract console.log lines from trace output
console_logs = []

for line in lines:
    # Match console::log with single argument: console::log("text")
    match1 = re.search(r'console::log\("([^"]+)"\)', line)
    if match1:
        console_logs.append(match1.group(1))
        continue
    
    # Match console::log with two arguments: console::log("label", value)
    match2 = re.search(r'console::log\("([^"]+)", ([0-9-]+)\)', line)
    if match2:
        label = match2.group(1)
        value = match2.group(2)
        console_logs.append(f"{label}: {value}")
        continue
    
    # Match console::log with string argument: console::log("label", "value")
    match3 = re.search(r'console::log\("([^"]+)", "([^"]+)"\)', line)
    if match3:
        label = match3.group(1)
        value = match3.group(2)
        console_logs.append(f"{label}: {value}")
        continue

# Format the output
output = []
output.append("=" * 80)
output.append("QUANTILLON PROTOCOL - SCENARIO REPLAY RESULTS")
output.append("=" * 80)
output.append("")

i = 0
while i < len(console_logs):
    line = console_logs[i]
    
    # Skip empty lines
    if not line.strip():
        i += 1
        continue
    
    # Format headers
    if line.startswith("==="):
        output.append(line)
        output.append("")
    elif line.startswith("========================================"):
        output.append(line)
    elif line.startswith("STEP"):
        output.append("")
        output.append(line)
    elif line.startswith("Action:"):
        output.append(line)
        output.append("=" * 40)
    elif line.startswith("--- PROTOCOL STATISTICS ---"):
        output.append("")
        output.append(line)
    elif line.startswith("--- HEDGER STATISTICS ---"):
        output.append("")
        output.append(line)
    elif line.startswith("--- HEDGER POSITION DETAILS ---"):
        output.append("")
        output.append(line)
    elif line.startswith("Price set to:"):
        # Extract and format price
        match = re.search(r': (\d+)$', line)
        if match:
            price = int(match.group(1)) / 100
            output.append(f"  Price updated to: {price:.2f} USD")
            output.append("")
    elif line.startswith("=== SCENARIO COMPLETE ==="):
        output.append("")
        output.append(line)
        output.append("")
    elif line.startswith("Results saved") or line.startswith("Total steps"):
        output.append(line)
    elif "Verifying Fresh State" in line or "Initial" in line or "Protocol is in fresh state" in line:
        # Skip verification messages or format them
        if "Protocol is in fresh state" in line:
            output.append(f"  {line}")
        elif ":" in line:
            output.append(f"  {line}")
    else:
        # Format value lines
        formatted = line
        
        # Add units and format values
        if "Oracle Price" in formatted and ": " in formatted:
            match = re.search(r': (\d+)$', formatted)
            if match:
                price = int(match.group(1)) / 100
                formatted = re.sub(r': \d+$', f': {price:.2f} USD', formatted)
        elif "QEURO Minted" in formatted or "QEURO Mintable" in formatted:
            match = re.search(r': (\d+)$', formatted)
            if match:
                val = match.group(1)
                formatted = re.sub(r': \d+$', f': {val} QEURO', formatted)
        elif any(x in formatted for x in ["User Collateral", "Hedger Collateral", "Hedger Available Collateral", "USDC Held", "Hedger Margin", "Margin:", "Position Size", "Filled Volume", "Exposure"]) and ": " in formatted:
            match = re.search(r': ([0-9-]+)$', formatted)
            if match:
                val = match.group(1)
                formatted = re.sub(r': [0-9-]+$', f': {val} USDC', formatted)
        elif "Collateralization Percentage" in formatted:
            # Handle format like "111 . 20%" or "111.20%" (from console.log with multiple args)
            match = re.search(r': (\d+)\s*\.\s*(\d+)\s*%', formatted)
            if match:
                whole = match.group(1)
                decimal = match.group(2)
                formatted = re.sub(r': \d+\s*\.\s*\d+\s*%', f': {whole}.{decimal}%', formatted)
            else:
                # Fallback: if it's just a number, assume it's basis points
                match = re.search(r': (\d+)$', formatted)
                if match:
                    val = int(match.group(1))
                    whole = val // 100
                    decimal = val % 100
                    formatted = re.sub(r': \d+$', f': {whole}.{decimal:02d}%', formatted)
        elif "Collateralization Ratio %:" in formatted:
            match = re.search(r': (\d+)$', formatted)
            if match:
                val = match.group(1)
                formatted = re.sub(r': \d+$', f': {val}%', formatted)
        elif "Collateralization Ratio:" in formatted and "%" not in formatted:
            match = re.search(r': (\d+)', formatted)
            if match:
                val = match.group(1)
                formatted = re.sub(r': \d+', f': {val} bps', formatted)
        elif "Hedger Entry Price" in formatted or "Entry Price" in formatted:
            match = re.search(r': (\d+)$', formatted)
            if match:
                price = int(match.group(1)) / 100
                formatted = re.sub(r': \d+$', f': {price:.2f} USD', formatted)
        elif "Leverage" in formatted and ": " in formatted:
            match = re.search(r': (\d+)$', formatted)
            if match:
                val = match.group(1)
                formatted = re.sub(r': \d+$', f': {val}x', formatted)
        elif "P&L" in formatted and ": " in formatted:
            # Handle P&L values with 2 decimals (e.g., "-7.00 USDC" or "123.45 USDC")
            match = re.search(r': ([0-9-]+)\.([0-9]+) USDC$', formatted)
            if match:
                whole = match.group(1)
                decimal = match.group(2)
                # Ensure 2 decimal places
                if len(decimal) == 1:
                    decimal = decimal + "0"
                formatted = re.sub(r': [0-9-]+\.\d+ USDC$', f': {whole}.{decimal} USDC', formatted)
            else:
                # Fallback: if no decimals, add .00
                match = re.search(r': ([0-9-]+) USDC$', formatted)
                if match:
                    val = match.group(1)
                    formatted = re.sub(r': [0-9-]+ USDC$', f': {val}.00 USDC', formatted)
        elif "Is Collateralized" in formatted:
            formatted = formatted.replace(": 1", ": YES").replace(": 0", ": NO")
        
        output.append(f"  {formatted}")
    
    i += 1

output.append("")
output.append("=" * 80)
output.append("END OF REPORT")
output.append("=" * 80)

with open(output_file, 'w') as f:
    f.write('\n'.join(output))

print(f"\n✓ Formatted log created: {output_file}")
print(f"  File size: {len(output)} lines")
print(f"  Original: {len(lines)} lines")
print("\nThe formatted log is now much more readable!")
PYTHON_SCRIPT

echo ""
echo "Done!"
