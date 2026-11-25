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
import re
from pathlib import Path

# Forge resolves source paths relative to the Foundry root inside the repository.
source = re.compile(r"(https://github.com/Quantillon-Labs/smart-contracts)(?:/quantillon-protocol)?/blob/([a-f0-9]+)/src/")
for directory, pattern in [("docs/src", "*.md"), ("docs/book", "*.html")]:
    for page in Path(directory).rglob(pattern):
        original = page.read_text()
        normalized = source.sub(r"\1/blob/\2/quantillon-protocol/src/", original)
        if pattern == "*.md":
            normalized = normalized.rstrip() + "\n"
        if normalized != original:
            page.write_text(normalized)
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

echo "Documentation built successfully with correct GitHub links!"
