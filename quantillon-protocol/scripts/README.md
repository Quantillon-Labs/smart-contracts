# Documentation Build Scripts

This directory contains scripts to build the Quantillon Protocol documentation with correct GitHub source links.

## Problem

When using `forge doc --build`, Foundry generates documentation with incorrect GitHub source URLs like:
```
https://github.com/Quantillon-Labs/smart-contracts/blob/a0c4605b79826572de49aa1618715c7e4813adad/src/libraries/VaultMath.sol
```

These URLs point to the wrong paths because the source files are located in the `quantillon-protocol` subdirectory, not at the repository root.

## Root Cause

The issue is that `forge doc --build` **generates** the `book.toml` file during the build process, using the Git remote URL as the base. Since your Git remote points to the root repository (`https://github.com/Quantillon-Labs/smart-contracts.git`) but your source files are in a subdirectory (`quantillon-protocol/`), the generated URLs are incorrect.

## Solution

The final solution combines two approaches:
1. **Temporarily change the Git remote URL** to point to the subdirectory during documentation generation
2. **Post-process the generated HTML files** to fix any remaining incorrect URLs

## Scripts

### `build-docs.sh` ⭐ **RECOMMENDED**
**The complete solution that actually works**

This script:
1. Temporarily changes the Git remote URL to point to the subdirectory
2. Runs `forge doc --build` to generate documentation
3. Restores the original Git remote URL
4. Post-processes all HTML files to fix any remaining incorrect GitHub URLs

**Usage:**
```bash
./scripts/build-docs.sh
```

**Result:** All GitHub source links will point to the correct paths:
```
https://github.com/Quantillon-Labs/smart-contracts/blob/main/quantillon-protocol/src/libraries/VaultMath.sol
```

## Manual Solution

If you prefer to fix the issue manually:

1. **Store the original remote URL:**
   ```bash
   ORIGINAL_REMOTE=$(git remote get-url origin)
   ```

2. **Temporarily change the remote URL:**
   ```bash
   git remote set-url origin "https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol.git"
   ```

3. **Generate documentation:**
   ```bash
   forge doc --build
   ```

4. **Restore the original remote URL:**
   ```bash
   git remote set-url origin "$ORIGINAL_REMOTE"
   ```

5. **Post-process HTML files** (optional, for any remaining incorrect URLs):
   ```bash
   find docs/book -name "*.html" -type f -exec sed -i 's|https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/[^"]*/src/|https://github.com/Quantillon-Labs/smart-contracts/blob/main/quantillon-protocol/src/|g' {} \;
   ```

## Why This Works

- **Root cause**: `forge doc --build` generates URLs using the Git remote URL
- **Solution**: Temporarily change the Git remote URL to point to the subdirectory
- **Post-processing**: Fix any remaining incorrect URLs in the generated HTML files
- **Safety**: Original Git remote URL is always restored

## Note

This solution addresses the complete GitHub URL issue by fixing both the generation process and any remaining incorrect URLs in the final output.
