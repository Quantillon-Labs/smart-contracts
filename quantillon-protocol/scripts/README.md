# Scripts Documentation

This directory contains utility scripts for building documentation and running security analysis for the Quantillon Protocol.

## 📚 Documentation Generation

### `build-docs.sh` - Smart Contract Documentation Builder

**Purpose**: Generates comprehensive documentation for all smart contracts with correct GitHub URLs.

**Features**:
- Automatically generates documentation using Foundry's `forge doc`
- Fixes GitHub URL references to point to correct repository structure
- Handles subdirectory repository configurations
- Preserves custom favicon and branding
- Restores original Git remote configuration after processing

**Usage**:
```bash
# From project root
./scripts/build-docs.sh

# Or using Makefile
make docs
```

**What it does**:
1. Temporarily adjusts Git remote to handle subdirectory structure
2. Generates documentation using `forge doc --build`
3. Copies custom favicon files to override defaults
4. Post-processes all HTML files to fix GitHub URLs
5. Restores original Git remote configuration

**Output**: Generated documentation in `docs/book/` directory with correct GitHub links.

---

## 🔍 Security Analysis

### `run-slither.sh` - Slither Security Scanner

**Purpose**: Runs comprehensive security analysis on all smart contracts using Slither.

**Features**:
- Automated Python virtual environment management
- Dependency installation and updates
- Comprehensive security scanning with custom configuration
- Integration with Foundry workflow
- Detailed security reports in multiple formats

**Usage**:
```bash
# Direct execution
./scripts/run-slither.sh

# Using Makefile (recommended)
make slither

# Comprehensive security check
make security
```

**Configuration**:
- Uses `slither.config.json` for custom settings
- Excludes library files, tests, and build artifacts
- Generates JSON and SARIF reports
- Custom detector exclusions for false positives

**Output**:
- Console output with security findings
- `slither-report.json` - Machine-readable results
- `slither-report.sarif` - IDE integration format

---

## 🚀 Development Workflow Integration

### Makefile Commands

The project includes a comprehensive Makefile that integrates all tools:

```bash
make help          # Show all available commands
make build         # Compile contracts
make test          # Run tests
make coverage      # Generate coverage report
make slither       # Security analysis
make security      # Build + security
make all           # Complete pipeline
make ci            # CI/CD pipeline
```

### CI/CD Integration

**GitHub Actions Workflow** (`.github/workflows/ci.yml`):
- Automated testing on every PR
- Security analysis with Slither
- Coverage reporting
- Foundry and Python environment setup

**Workflow Steps**:
1. Setup Foundry toolchain
2. Setup Python environment
3. Install dependencies
4. Build contracts
5. Run tests
6. Generate coverage
7. Run Slither security analysis
8. Upload coverage to Codecov

---

## 📋 Prerequisites

### For Documentation Generation
- Foundry (forge) installed
- Git repository with proper remote configuration
- Custom favicon files in `docs/` directory

### For Security Analysis
- Python 3.11+
- Foundry toolchain
- Internet connection for dependency installation

### Dependencies
```bash
# Python dependencies (auto-installed)
slither-analyzer>=0.9.3
crytic-compile>=0.3.0

# Foundry dependencies (auto-installed)
forge
```

---

## 🔧 Configuration Files

### `slither.config.json`
```json
{
  "filter_paths": "lib,test,out,cache",
  "exclude_informational": false,
  "exclude_low": false,
  "exclude_medium": false,
  "exclude_high": false,
  "detectors_to_exclude": [
    "naming-convention",
    "external-function"
  ],
  "json": "slither-report.json",
  "sarif": "slither-report.sarif"
}
```

### `foundry.toml`
- Includes formal verification settings
- SMTChecker configuration for model checking
- Compiler optimization settings

---

## 📊 Security Analysis Results

### Typical Output Structure
- **High Priority**: Critical vulnerabilities (must fix)
- **Medium Priority**: Important security issues
- **Low Priority**: Minor concerns and best practices
- **Informational**: Suggestions and optimizations

### Common Issue Categories
- Reentrancy vulnerabilities
- Access control issues
- Integer overflow/underflow
- Uninitialized state variables
- Dangerous external calls
- Gas optimization opportunities

---

## 🚨 Troubleshooting

### Documentation Issues
```bash
# Check Git remote configuration
git remote -v

# Verify Foundry installation
forge --version

# Check custom favicon files
ls -la docs/favicon.*
```

### Slither Issues
```bash
# Recreate virtual environment
rm -rf venv
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Check Python version
python3 --version

# Verify Slither installation
slither --version
```

### Permission Issues
```bash
# Make scripts executable
chmod +x scripts/*.sh

# Check file permissions
ls -la scripts/
```

---

## 📈 Best Practices

### Documentation
- Run documentation generation before each release
- Verify GitHub links are correct after generation
- Keep custom branding files updated
- Review generated documentation for completeness

### Security Analysis
- Run Slither on every significant change
- Include security checks in CI/CD pipeline
- Review and address high/medium priority issues
- Document false positives and exclusions
- Regular security audit scheduling

### Development Workflow
- Use Makefile commands for consistency
- Run `make all` before major commits
- Include security analysis in PR reviews
- Monitor CI/CD pipeline results

---

## 🔗 Related Documentation

- [Foundry Book](https://book.getfoundry.sh/)
- [Slither Documentation](https://github.com/crytic/slither)
- [Crytic Tools](https://crytic.io/)
- [Quantillon Protocol Main README](../README.md)

---

**Last Updated**: December 2024  
**Status**: ✅ Active and Integrated  
**Coverage**: Documentation + Security Analysis

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
