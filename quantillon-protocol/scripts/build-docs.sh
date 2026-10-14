#!/bin/bash
set -euo pipefail

# Build documentation with a process-scoped source-link override and HTML post-processing.

# Ensure we're in the correct directory
cd "$(dirname "$0")/.."

echo "Building documentation with correct GitHub URLs..."

# Scope the source-link override to this build. Worktrees share Git configuration;
# changing origin here would also change the production checkout's remote.
echo "Generating documentation..."
env FOUNDRY_PROFILE=docs RUST_MIN_STACK=50331648 GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=remote.origin.url \
    GIT_CONFIG_VALUE_0=https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol.git \
    forge doc --build

# Forge adds blank lines at EOF. Normalize its output as part of generation so
# checked-in reference pages remain reproducible and pass whitespace checks.
python3 - <<'PY'
from pathlib import Path
for page in Path("docs/src").rglob("*.md"):
    page.write_text(page.read_text().rstrip() + "\n")
PY

# Copy our custom favicon files to override the default forge icons
echo "Copying custom favicon files..."
if [ -f "docs/favicon.png" ]; then
    cp docs/favicon.png docs/book/favicon.png
    echo "Custom favicon.png copied successfully"
else
    echo "Warning: favicon.png not found in docs directory"
fi

if [ -f "docs/favicon.ico" ]; then
    cp docs/favicon.ico docs/book/favicon.ico
    echo "Custom favicon.ico copied successfully"
else
    echo "Warning: favicon.ico not found in docs directory"
fi

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
