#!/bin/bash

# Slither Security Analysis Script for Quantillon Protocol
# This script runs Slither analysis on the smart contracts

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

# Run Slither analysis
echo "🚀 Running Slither analysis..."
slither . --config-file slither.config.json

# Check exit code
if [ $? -eq 0 ]; then
    echo "✅ Slither analysis completed successfully"
    echo "📊 Check slither-report.json for detailed results"
else
    echo "⚠️  Slither analysis found issues - check the output above"
    exit 1
fi

# Deactivate virtual environment
deactivate

echo "🎯 Slither analysis complete!"
