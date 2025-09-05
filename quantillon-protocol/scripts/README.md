# Quantillon Protocol Scripts

This directory contains utility scripts for the Quantillon Protocol development workflow.

## Scripts Overview

This directory contains utility scripts for the Quantillon Protocol development workflow, including documentation generation, security analysis, and NatSpec validation.

## Documentation Generation Script

The `build-docs.sh` script generates comprehensive documentation for the Quantillon Protocol smart contracts using Foundry's built-in documentation generator.

### Features

- **Automatic Documentation Generation**: Uses `forge doc --build` to generate HTML documentation
- **GitHub URL Correction**: Automatically fixes GitHub source links to point to the correct repository structure
- **Custom Branding**: Applies custom favicon files for professional documentation appearance
- **Safe Git Operations**: Temporarily modifies git remote URLs and restores them automatically

### Usage

```bash
# Run from the scripts directory
./build-docs.sh

# Or from the project root
make docs
```

### What It Does

1. **Temporarily Updates Git Remote**: Changes the git remote URL to ensure correct GitHub source links
2. **Generates Documentation**: Runs `forge doc --build` to create HTML documentation
3. **Applies Custom Branding**: Copies custom favicon files to the generated documentation
4. **Fixes GitHub URLs**: Post-processes HTML files to correct GitHub source links
5. **Restores Git State**: Reverts git remote URL to original state

### Output

- **Location**: `docs/book/` directory
- **Format**: HTML documentation with navigation and search
- **Features**: Source code links, contract inheritance diagrams, and comprehensive API documentation

### Requirements

- Git repository with proper remote configuration
- Foundry installed and configured
- Custom favicon files in `docs/` directory (optional)

## Security Analysis Script

The `run-slither.sh` script provides comprehensive security analysis of the Quantillon Protocol smart contracts using the Slither static analysis tool.

### Features

- **Comprehensive Security Analysis**: Runs Slither with detailed configuration
- **Beautiful Reporting**: Generates human-readable reports with emojis and formatting
- **Multiple Output Formats**: Creates JSON, SARIF, and text reports
- **Priority Classification**: Categorizes issues by severity (High, Medium, Low, Informational)
- **Actionable Recommendations**: Provides specific guidance for fixing identified issues
- **Virtual Environment Management**: Automatically sets up Python environment

### Usage

```bash
# Run from the scripts directory
./run-slither.sh

# Or from the project root
make slither
```

### What It Does

1. **Environment Setup**: Creates and activates Python virtual environment
2. **Dependency Installation**: Installs Slither and required dependencies
3. **Security Analysis**: Runs Slither with comprehensive configuration
4. **Report Generation**: Creates multiple report formats:
   - `slither-report.txt` - Beautiful human-readable report
   - `slither-report.json` - Detailed JSON output
   - `slither-report.sarif` - IDE integration format
5. **Issue Classification**: Categorizes findings by priority and detector type
6. **Cleanup**: Removes temporary files and deactivates virtual environment

### Output Files

- **`slither-report.txt`**: Main human-readable report with executive summary
- **`slither-report.json`**: Detailed JSON output for programmatic processing
- **`slither-report.sarif`**: SARIF format for IDE integration
- **Console Output**: Real-time analysis results with beautiful formatting

### Issue Categories

#### 🚨 High Priority Issues
- Reentrancy vulnerabilities
- Arbitrary ETH transfers
- Uninitialized state variables
- Dangerous strict equalities

#### ⚠️ Medium Priority Issues
- Reentrancy without ETH
- Unused return values
- Incorrect equality checks
- Uninitialized local variables

#### 💡 Low Priority Issues
- Variable shadowing
- Missing zero checks
- Loop-based external calls
- Timestamp usage
- Costly loops

#### ℹ️ Informational Issues
- Cyclomatic complexity
- Missing inheritance
- Unused state variables
- Naming conventions

### Configuration

The script uses `slither.config.json` for analysis configuration, which includes:
- Detector enablement/disablement
- Exclusion patterns
- Output formatting options
- Custom analysis rules

## Makefile Integration

All scripts are integrated into the project's Makefile for easy execution:

### Available Commands

```bash
# Documentation generation
make docs                 # Generate HTML documentation

# Security analysis
make slither             # Run comprehensive security analysis

# NatSpec validation
make validate-natspec    # Validate NatSpec documentation coverage

# Complete development workflow
make all                 # Build, test, and analyze security
make ci                  # CI/CD pipeline (build, test, slither, validate-natspec)
```

### Quick Start

```bash
# Clone the repository
git clone https://github.com/Quantillon-Labs/smart-contracts.git
cd smart-contracts/quantillon-protocol

# Install dependencies
make install

# Generate documentation
make docs

# Run security analysis
make slither

# Validate NatSpec coverage
make validate-natspec

# Run complete development workflow
make all
```

## Development Workflow

### 1. Documentation Generation
```bash
# Generate comprehensive HTML documentation
make docs

# View generated documentation
open docs/book/index.html
```

### 2. Security Analysis
```bash
# Run comprehensive security analysis
make slither

# Review security findings
cat slither-report.txt
```

### 3. NatSpec Validation
```bash
# Validate NatSpec documentation coverage
make validate-natspec

# Fix missing documentation (if needed)
# The script will provide specific guidance on what needs to be documented
```

### 4. Complete Development Cycle
```bash
# Run the complete development workflow
make all

# This will:
# 1. Build the project
# 2. Run all tests
# 3. Perform security analysis
# 4. Validate NatSpec documentation
```

## Troubleshooting

### Common Issues

#### Documentation Generation
- **Issue**: GitHub URLs are incorrect in generated docs
- **Solution**: The script automatically fixes this, but ensure git remote is properly configured

#### Security Analysis
- **Issue**: Slither fails to run
- **Solution**: Ensure Python 3.7+ is installed and virtual environment is created properly

#### NatSpec Validation
- **Issue**: Low coverage percentage
- **Solution**: Use the detailed output to identify missing documentation and add required tags

### Dependencies

- **Node.js**: Required for NatSpec validation script
- **Python 3.7+**: Required for Slither security analysis
- **Foundry**: Required for documentation generation and project building
- **Git**: Required for proper source link generation

## NatSpec Validation Script

The `validate-natspec.js` script provides comprehensive validation of NatSpec documentation across all Solidity contracts in the protocol.

### Features

- **Complete Coverage Analysis**: Scans all Solidity files in the protocol
- **Comprehensive Validation**: Checks for all required NatSpec tags including @custom tags
- **Detailed Reporting**: Provides specific feedback on missing or incomplete documentation
- **CI/CD Integration**: Can be integrated into automated workflows
- **Configurable**: Easy to modify validation rules and requirements

### Required NatSpec Tags

The script validates that all public and external functions have:

#### Basic Tags
- `@notice` - User-friendly description
- `@dev` - Technical implementation details
- `@param` - Parameter descriptions (for functions with parameters)
- `@return` - Return value descriptions (for functions with return values)

#### Custom Tags (Quantillon Protocol Standard)
- `@custom:security` - Security considerations and checks
- `@custom:validation` - Input validation details
- `@custom:state-changes` - State modifications
- `@custom:events` - Events emitted
- `@custom:errors` - Custom errors thrown
- `@custom:reentrancy` - Reentrancy protection status
- `@custom:access` - Access control requirements
- `@custom:oracle` - Oracle dependencies

### Usage

#### Using Make (Recommended)
```bash
# From the project root
make validate-natspec
```

#### Direct Execution
```bash
# Install dependencies
cd scripts
npm install

# Run validation
node validate-natspec.js
```

#### Programmatic Usage
```javascript
const { validateNatSpec, scanDirectory } = require('./validate-natspec.js');

// Validate a single contract
const result = validateNatSpec('src/core/QEUROToken.sol');
console.log(`Coverage: ${result.coverage}%`);

// Scan a directory
const files = scanDirectory('src/core');
```

### Output

The script provides:

1. **Summary Statistics**
   - Total files scanned
   - Total functions found
   - Documented functions count
   - Overall coverage percentage

2. **Detailed Reports**
   - Per-contract coverage analysis
   - List of functions missing documentation
   - List of functions with incomplete documentation
   - Specific missing tags for each function

3. **Recommendations**
   - Actionable steps to improve documentation
   - Required tags for complete documentation

### Example Output

```
🔍 Quantillon Protocol NatSpec Validation

============================================================

📊 SUMMARY
============================================================
Total Files Scanned: 25
Total Functions: 156
Documented Functions: 156
Overall Coverage: 100.00%
Missing Documentation: 0

📋 DETAILED REPORTS
============================================================

📄 src/core/QEUROToken.sol
   Coverage: 100.00% (45/45 functions)
   ✅ All functions properly documented!

📄 src/core/UserPool.sol
   Coverage: 100.00% (38/38 functions)
   ✅ All functions properly documented!

💡 RECOMMENDATIONS
============================================================
✅ All functions have complete NatSpec documentation!
🎉 The protocol meets MiCA regulatory requirements.

✅ Validation passed - all functions documented
```

### Configuration

The script can be configured by modifying the `CONFIG` object in `validate-natspec.js`:

```javascript
const CONFIG = {
    // Directories to scan
    directories: [
        'src/core',
        'src/interfaces', 
        'src/libraries',
        'src/oracle',
        'src/core/vaults',
        'src/core/yieldmanagement',
        'test'
    ],
    
    // Required NatSpec tags
    requiredTags: [
        '@notice',
        '@dev',
        '@param',
        '@return',
        '@custom:security',
        '@custom:validation', 
        '@custom:state-changes',
        '@custom:events',
        '@custom:errors',
        '@custom:reentrancy',
        '@custom:access',
        '@custom:oracle'
    ],
    
    // Functions to exclude from validation
    excludePatterns: [
        /^constructor$/,
        /^fallback$/,
        /^receive$/,
        /^_authorizeUpgrade$/,
        /^__.*__$/, // OpenZeppelin internal functions
        /^_disableInitializers$/
    ]
};
```

### Integration

#### CI/CD Pipeline
The script is integrated into the project's Makefile and can be included in CI/CD pipelines:

```yaml
# GitHub Actions example
- name: Validate NatSpec Documentation
  run: make validate-natspec
```

#### Pre-commit Hooks
Can be used as a pre-commit hook to ensure documentation standards:

```bash
#!/bin/sh
# .git/hooks/pre-commit
make validate-natspec
if [ $? -ne 0 ]; then
    echo "❌ NatSpec validation failed. Please fix documentation issues."
    exit 1
fi
```

### Troubleshooting

#### Common Issues

1. **Parser Errors**: If you encounter parsing errors, ensure your Solidity syntax is valid
2. **Missing Dependencies**: Run `npm install` in the scripts directory
3. **Node Version**: Requires Node.js 14.0.0 or higher

#### False Positives

The script may report false positives for:
- Private functions (excluded by default)
- Constructor functions (excluded by default)
- OpenZeppelin internal functions (excluded by default)

These can be configured in the `excludePatterns` array.

### Contributing

When adding new functions to the protocol:

1. Ensure all public/external functions have complete NatSpec documentation
2. Run `make validate-natspec` to verify compliance
3. Follow the established documentation patterns
4. Include all required @custom tags

### License

MIT License - See LICENSE file for details.