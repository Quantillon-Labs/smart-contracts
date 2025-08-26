#!/bin/bash

# Final solution for building documentation with correct GitHub URLs
# This script combines Git remote URL change with post-processing

# Ensure we're in the correct directory
cd "$(dirname "$0")/.."

echo "Building documentation with correct GitHub URLs..."

# Store the original remote URL
ORIGINAL_REMOTE=$(git remote get-url origin)
echo "Original remote URL: $ORIGINAL_REMOTE"

# Temporarily change the remote URL to point to the subdirectory
echo "Temporarily changing remote URL to point to quantillon-protocol subdirectory..."
git remote set-url origin "https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol.git"

# Generate and build documentation
echo "Generating documentation..."
forge doc --build

# Copy our custom favicon files to override the default forge icons
echo "Copying custom favicon files..."
if [ -f "docs/favicon.png" ]; then
    cp docs/favicon.png docs/book/favicon.png
    echo "Custom favicon.png copied successfully"
else
    echo "Warning: favicon.png not found in docs directory"
fi

if [ -f "docs/favicon.svg" ]; then
    cp docs/favicon.svg docs/book/favicon.svg
    echo "Custom favicon.svg copied successfully"
else
    echo "Warning: favicon.svg not found in docs directory"
fi

if [ -f "docs/favicon.ico" ]; then
    cp docs/favicon.ico docs/book/favicon.ico
    echo "Custom favicon.ico copied successfully"
else
    echo "Warning: favicon.ico not found in docs directory"
fi

# Restore the original remote URL
echo "Restoring original remote URL..."
git remote set-url origin "$ORIGINAL_REMOTE"

echo "Post-processing GitHub URLs in generated HTML files..."

# Find all HTML files in the docs/book directory and fix GitHub URLs
find docs/book -name "*.html" -type f | while read -r file; do
    echo "Processing: $file"
    
    # Create a temporary file
    temp_file=$(mktemp)
    
    # Replace incorrect GitHub URLs with correct ones
    # This replaces URLs like:
    # https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/.../src/...
    # with:
    # https://github.com/Quantillon-Labs/smart-contracts/blob/main/quantillon-protocol/src/...
    
    sed 's|https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/[^"]*/src/|https://github.com/Quantillon-Labs/smart-contracts/blob/main/quantillon-protocol/src/|g' "$file" > "$temp_file"
    
    # Also fix URLs that don't have the commit hash
    sed 's|https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/src/|https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/src/|g' "$temp_file" > "$file"
    
    # Clean up temporary file
    rm "$temp_file"
done

echo "Documentation built successfully with correct GitHub links!"
echo "Original remote URL restored: $(git remote get-url origin)"
