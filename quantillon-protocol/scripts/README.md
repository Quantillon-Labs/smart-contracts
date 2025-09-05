# Quantillon Protocol Scripts

This directory contains utility scripts for the Quantillon Protocol development workflow.

## Scripts Overview

This directory contains utility scripts for the Quantillon Protocol development workflow, including documentation generation, security analysis, and NatSpec validation.

### Available Scripts

- **`build-docs.sh`** - Generates comprehensive HTML documentation
- **`run-slither.sh`** - Performs security analysis using Slither
- **`validate-natspec.js`** - Validates NatSpec documentation coverage
- **`analyze-gas.sh`** - Comprehensive gas optimization analysis
- **`benchmark-gas.sh`** - Gas benchmarking for specific functions
- **`package.json`** - Node.js dependencies for validation scripts
- **`README.md`** - This documentation file

### Recently Removed Scripts

The following temporary utility scripts were removed after completing their purpose:
- ~~`fix-test-natspec.js`~~ - Was used to add @custom tags to test functions
- ~~`fix-all-test-natspec.js`~~ - Was used to bulk process all test files
- ~~`fix-main-contracts-natspec.js`~~ - Was used to add @custom tags to main contracts

These scripts were one-time utilities that successfully improved NatSpec coverage from 2.22% to 44.08% and are no longer needed.

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

# Review the generated report file
cat natspec-validation-report.txt

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
# 4. Generate HTML documentation
# 5. Validate NatSpec documentation
```

### 5. Review Generated Reports
```bash
# Check security analysis results
cat slither-report.txt

# Check NatSpec validation results
cat natspec-validation-report.txt

# View generated documentation
open docs/book/index.html
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
- **Solution**: Use the detailed output (both console and file) to identify missing documentation and add required tags
- **Issue**: Need to review validation results later
- **Solution**: Check the generated `natspec-validation-report.txt` file for complete results

### Dependencies

- **Node.js**: Required for NatSpec validation script
- **Python 3.7+**: Required for Slither security analysis
- **Foundry**: Required for documentation generation and project building
- **Git**: Required for proper source link generation

### Project Configuration

- **`.gitignore`**: Updated to exclude `node_modules/` and related Node.js files
- **`package.json`**: Manages Node.js dependencies for validation scripts
- **`package-lock.json`**: Locks dependency versions for reproducible builds

## Gas Analysis Scripts

The Quantillon Protocol includes comprehensive gas analysis tools to help optimize contract efficiency and reduce transaction costs.

### Main Gas Analysis Script

The `analyze-gas.sh` script provides comprehensive gas optimization analysis using multiple tools and techniques.

#### Features

- **Multi-Tool Analysis**: Integrates Foundry, Slither, and custom analysis
- **Comprehensive Reporting**: Generates detailed human-readable text reports with recommendations
- **State Variable Optimization**: Detects opportunities for `immutable` and `constant` variables
- **Function Visibility Analysis**: Identifies functions that should be `external`
- **Unused Code Detection**: Finds dead code and unused state variables
- **Loop Optimization**: Detects expensive operations in loops
- **Storage Layout Analysis**: Analyzes variable ordering and packing
- **Contract Size Analysis**: Monitors contract sizes and identifies large contracts
- **Function Gas Usage**: Detailed gas usage analysis per function
- **Optimization Recommendations**: Provides actionable optimization suggestions

#### Usage

```bash
# Run comprehensive gas analysis
./analyze-gas.sh

# Or from the project root
make gas-analysis
```

#### Output

The script generates:
- **Single Comprehensive Report**: `gas-analysis-YYYYMMDD_HHMMSS.txt`
- **All Analysis Results**: Complete analysis in one human-readable text file
- **Optimization Recommendations**: Actionable suggestions included in the report

### Gas Benchmarking Script

The `benchmark-gas.sh` script allows benchmarking specific functions and comparing gas usage.

#### Features

- **Targeted Benchmarking**: Benchmark specific functions, contracts, or tests
- **Flexible Options**: Command-line options for different analysis types
- **Verbose Output**: Optional detailed output for debugging
- **Results Export**: Save results to files for further analysis

#### Usage

```bash
# Benchmark specific function
./benchmark-gas.sh -f mint -c QEUROToken

# Benchmark specific test
./benchmark-gas.sh -t testDeposit

# Benchmark entire contract
./benchmark-gas.sh -c UserPool

# Save results to file
./benchmark-gas.sh -c AaveVault -o results.txt

# Verbose output
./benchmark-gas.sh -v -f stake
```

#### Options

- `-f, --function FUNCTION`: Benchmark specific function
- `-c, --contract CONTRACT`: Benchmark specific contract
- `-t, --test TEST_NAME`: Run specific test
- `-o, --output FILE`: Output file for results
- `-v, --verbose`: Verbose output
- `-h, --help`: Show help

### Configuration

The gas analysis script uses built-in configuration and generates a single comprehensive text report. The script automatically:

- Uses Foundry for contract building and gas reporting
- Integrates with Slither for advanced analysis (if available)
- Generates timestamped reports in the current directory
- Provides comprehensive optimization recommendations

### Integration with Makefile

Gas analysis is integrated into the main development workflow:

```bash
# Run gas analysis
make gas-analysis

# Run all checks (includes gas analysis)
make all

# CI/CD pipeline (includes gas analysis)
make ci
```

### Best Practices

1. **Regular Analysis**: Run gas analysis regularly during development
2. **Before Deployment**: Always run gas analysis before mainnet deployment
3. **Optimization Focus**: Focus on high-impact optimizations first
4. **Testing**: Always test optimizations thoroughly
5. **Documentation**: Document optimization decisions

### Common Optimizations

- Use `immutable` for constructor-set variables
- Use `constant` for compile-time constants
- Pack structs efficiently
- Use `external` instead of `public` when possible
- Avoid expensive operations in loops
- Use events instead of storage for non-critical data

## NatSpec Validation Script

The `validate-natspec.js` script provides comprehensive validation of NatSpec documentation across all Solidity contracts in the protocol.

### Features

- **Complete Coverage Analysis**: Scans all Solidity files in the protocol
- **Comprehensive Validation**: Checks for all required NatSpec tags including @custom tags
- **Detailed Reporting**: Provides specific feedback on missing or incomplete documentation
- **File Output**: Automatically writes results to `natspec-validation-report.txt`
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

### Output

The script generates two types of output:

1. **Console Output**: Real-time validation results displayed in the terminal
2. **File Output**: Complete report written to `natspec-validation-report.txt` in the project root

The file output contains:
- Executive summary with coverage statistics
- Detailed reports for each contract file
- Specific missing documentation items
- Actionable recommendations for improvement

### Current NatSpec Coverage Status

As of the latest validation:
- **Total Files Scanned**: 47 Solidity files
- **Total Functions**: 1,665 functions
- **Documented Functions**: 734 functions
- **Overall Coverage**: 44.08%
- **Missing Documentation**: 931 functions

#### Coverage by Category
- **Test Files**: 80-100% coverage (excellent)
- **Main Contracts**: 37-55% coverage (needs improvement)
- **Libraries**: 0-100% coverage (varies by library)
- **Interfaces**: 0-5% coverage (needs significant work)

#### Recent Improvements
The project has made significant progress in NatSpec documentation:
- **Starting Point**: 2.22% coverage (37/1665 functions)
- **Current Status**: 44.08% coverage (734/1665 functions)
- **Improvement**: +697 functions documented (+41.86% increase)
- **Test Files**: Achieved near-complete coverage through automated fixes

#### Next Steps for 100% Coverage
To achieve complete NatSpec documentation coverage:

1. **Priority 1 - Interfaces**: Add complete documentation to all interface functions
2. **Priority 2 - Main Contracts**: Complete @dev and @custom tags for core contract functions
3. **Priority 3 - Libraries**: Add missing @custom tags to library functions
4. **Priority 4 - Final Review**: Use the validation script to identify remaining gaps

#### Automated Tools Used
- **Temporary Fix Scripts**: Successfully added @custom tags to 565+ test functions and 300+ main contract functions
- **Validation Script**: Continuously monitors coverage and provides detailed feedback
- **File Output**: Generates comprehensive reports for tracking progress

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