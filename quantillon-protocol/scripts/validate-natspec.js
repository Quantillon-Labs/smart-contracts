#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const parser = require('@solidity-parser/parser');

/**
 * @title NatSpec Validation Script
 * @notice Comprehensive NatSpec documentation validator for Quantillon Protocol
 * @dev Validates that all functions have complete NatSpec documentation including @custom tags
 * @author Quantillon Labs
 * @custom:security-contact team@quantillon.money
 */

// Configuration
const CONFIG = {
    // Directories to scan (relative to project root)
    directories: [
        'src/core',
        'src/interfaces', 
        'src/libraries',
        'src/oracle',
        'src/core/vaults',
        'src/core/yieldmanagement',
        'test'
    ],
    
    // Required NatSpec tags for complete documentation
    requiredTags: [
        '@notice',
        '@dev',
        '@param', // For functions with parameters
        '@return', // For functions with return values
        '@custom:security',
        '@custom:validation', 
        '@custom:state-changes',
        '@custom:events',
        '@custom:errors',
        '@custom:reentrancy',
        '@custom:access',
        '@custom:oracle'
    ],
    
    // Optional tags that enhance documentation
    optionalTags: [
        '@custom:governance',
        '@custom:upgrade',
        '@custom:deprecated'
    ],
    
    // File extensions to process
    extensions: ['.sol'],
    
    // Functions to exclude from validation (constructors, fallbacks, etc.)
    excludePatterns: [
        /^constructor$/,
        /^fallback$/,
        /^receive$/,
        /^_authorizeUpgrade$/,
        /^__.*__$/, // OpenZeppelin internal functions
        /^_disableInitializers$/
    ]
};

/**
 * @notice Validates NatSpec documentation for a single contract
 * @param contractPath Path to the Solidity contract file
 * @return Object containing validation results
 */
function validateNatSpec(contractPath) {
    try {
        const code = fs.readFileSync(contractPath, 'utf8');
        const ast = parser.parse(code, { loc: true });
        
        let totalFunctions = 0;
        let documentedFunctions = 0;
        let missingFunctions = [];
        let incompleteFunctions = [];
        
        parser.visit(ast, {
            'FunctionDefinition': (node) => {
                // Skip excluded functions
                if (CONFIG.excludePatterns.some(pattern => pattern.test(node.name))) {
                    return;
                }
                
                // Skip private functions (they don't need full NatSpec)
                if (node.visibility === 'private') {
                    return;
                }
                
                totalFunctions++;
                
                // Find the comment block before the function
                const comment = findFunctionComment(code, node);
                
                if (comment) {
                    const validation = validateCommentCompleteness(comment, node);
                    if (validation.isComplete) {
                        documentedFunctions++;
                    } else {
                        incompleteFunctions.push({
                            name: node.name,
                            location: node.loc,
                            missing: validation.missing,
                            incomplete: validation.incomplete
                        });
                    }
                } else {
                    missingFunctions.push({
                        name: node.name,
                        location: node.loc
                    });
                }
            }
        });
        
        return {
            totalFunctions,
            documentedFunctions,
            missingFunctions,
            incompleteFunctions,
            coverage: totalFunctions > 0 ? (documentedFunctions / totalFunctions * 100).toFixed(2) : 100,
            missing: totalFunctions - documentedFunctions
        };
        
    } catch (error) {
        console.error(`Error parsing ${contractPath}:`, error.message);
        return {
            totalFunctions: 0,
            documentedFunctions: 0,
            missingFunctions: [],
            incompleteFunctions: [],
            coverage: 0,
            missing: 0,
            error: error.message
        };
    }
}

/**
 * @notice Finds the comment block associated with a function
 * @param code The source code
 * @param node The function AST node
 * @return The comment text or null
 */
function findFunctionComment(code, node) {
    const lines = code.split('\n');
    const functionLine = node.loc.start.line;
    
    // Look for comment block before the function
    for (let i = functionLine - 2; i >= 0; i--) {
        const line = lines[i].trim();
        
        // Found the start of a comment block
        if (line.startsWith('/**')) {
            let comment = '';
            let j = i;
            
            // Collect the entire comment block
            while (j < lines.length) {
                comment += lines[j] + '\n';
                if (lines[j].trim().endsWith('*/')) {
                    break;
                }
                j++;
            }
            
            return comment;
        }
        
        // Stop if we hit non-empty, non-comment code
        if (line && !line.startsWith('//') && !line.startsWith('*') && !line.startsWith('/*')) {
            break;
        }
    }
    
    return null;
}

/**
 * @notice Validates the completeness of a NatSpec comment
 * @param comment The comment text
 * @param node The function AST node
 * @return Validation result object
 */
function validateCommentCompleteness(comment, node) {
    const missing = [];
    const incomplete = [];
    
    // Check for basic required tags
    if (!comment.includes('@notice')) missing.push('@notice');
    if (!comment.includes('@dev')) missing.push('@dev');
    
    // Check for parameter documentation
    if (node.parameters && node.parameters.length > 0) {
        if (!comment.includes('@param')) {
            missing.push('@param');
        } else {
            // Count parameters vs @param tags
            const paramMatches = comment.match(/@param\s+\w+/g);
            if (!paramMatches || paramMatches.length < node.parameters.length) {
                incomplete.push('@param (missing some parameters)');
            }
        }
    }
    
    // Check for return value documentation
    if (node.returnParameters && node.returnParameters.length > 0) {
        if (!comment.includes('@return')) {
            missing.push('@return');
        } else {
            // Count return values vs @return tags
            const returnMatches = comment.match(/@return\s+\w+/g);
            if (!returnMatches || returnMatches.length < node.returnParameters.length) {
                incomplete.push('@return (missing some return values)');
            }
        }
    }
    
    // Check for @custom tags
    const customTags = [
        '@custom:security',
        '@custom:validation',
        '@custom:state-changes',
        '@custom:events',
        '@custom:errors',
        '@custom:reentrancy',
        '@custom:access',
        '@custom:oracle'
    ];
    
    customTags.forEach(tag => {
        if (!comment.includes(tag)) {
            missing.push(tag);
        }
    });
    
    return {
        isComplete: missing.length === 0 && incomplete.length === 0,
        missing,
        incomplete
    };
}

/**
 * @notice Scans a directory for Solidity files
 * @param dirPath Directory path to scan
 * @return Array of file paths
 */
function scanDirectory(dirPath) {
    const files = [];
    
    if (!fs.existsSync(dirPath)) {
        console.warn(`Directory ${dirPath} does not exist`);
        return files;
    }
    
    const items = fs.readdirSync(dirPath);
    
    for (const item of items) {
        const fullPath = path.join(dirPath, item);
        const stat = fs.statSync(fullPath);
        
        if (stat.isDirectory()) {
            // Recursively scan subdirectories
            files.push(...scanDirectory(fullPath));
        } else if (stat.isFile() && CONFIG.extensions.includes(path.extname(item))) {
            files.push(fullPath);
        }
    }
    
    return files;
}

/**
 * @notice Generates a detailed report for a contract
 * @param contractPath Path to the contract
 * @param result Validation result
 * @return Formatted report string
 */
function generateContractReport(contractPath, result) {
    let report = `\n📄 ${contractPath}\n`;
    report += `   Coverage: ${result.coverage}% (${result.documentedFunctions}/${result.totalFunctions} functions)\n`;
    
    if (result.error) {
        report += `   ❌ Error: ${result.error}\n`;
        return report;
    }
    
    if (result.missingFunctions.length > 0) {
        report += `   ❌ Missing Documentation (${result.missingFunctions.length}):\n`;
        result.missingFunctions.forEach(func => {
            report += `      - ${func.name} (line ${func.location.start.line})\n`;
        });
    }
    
    if (result.incompleteFunctions.length > 0) {
        report += `   ⚠️  Incomplete Documentation (${result.incompleteFunctions.length}):\n`;
        result.incompleteFunctions.forEach(func => {
            report += `      - ${func.name} (line ${func.location.start.line})\n`;
            if (func.missing.length > 0) {
                report += `        Missing: ${func.missing.join(', ')}\n`;
            }
            if (func.incomplete.length > 0) {
                report += `        Incomplete: ${func.incomplete.join(', ')}\n`;
            }
        });
    }
    
    if (result.missing === 0) {
        report += `   ✅ All functions properly documented!\n`;
    }
    
    return report;
}

/**
 * @notice Writes validation results to a text file
 * @param reports Array of validation reports
 * @param totalFiles Total number of files scanned
 * @param totalFunctions Total number of functions found
 * @param totalDocumented Total number of documented functions
 * @param overallCoverage Overall coverage percentage
 * @param outputFile Path to the output file
 */
function writeResultsToFile(reports, totalFiles, totalFunctions, totalDocumented, overallCoverage, outputFile) {
    let output = '';
    
    output += '🔍 Quantillon Protocol NatSpec Validation\n';
    output += '='.repeat(60) + '\n\n';
    
    // Summary section
    output += '📊 SUMMARY\n';
    output += '='.repeat(60) + '\n';
    output += `Total Files Scanned: ${totalFiles}\n`;
    output += `Total Functions: ${totalFunctions}\n`;
    output += `Documented Functions: ${totalDocumented}\n`;
    output += `Overall Coverage: ${overallCoverage}%\n`;
    output += `Missing Documentation: ${totalFunctions - totalDocumented}\n\n`;
    
    // Detailed reports section
    output += '📋 DETAILED REPORTS\n';
    output += '='.repeat(60) + '\n';
    
    for (const { file, result } of reports) {
        output += generateContractReport(file, result) + '\n';
    }
    
    // Recommendations section
    output += '\n💡 RECOMMENDATIONS\n';
    output += '='.repeat(60) + '\n';
    
    if (overallCoverage < 100) {
        output += '❌ Some functions are missing NatSpec documentation.\n';
        output += '📝 Required tags for complete documentation:\n';
        CONFIG.requiredTags.forEach(tag => {
            output += `   - ${tag}\n`;
        });
        output += '\n🔧 To fix missing documentation:\n';
        output += '   1. Add @notice with user-friendly description\n';
        output += '   2. Add @dev with technical implementation details\n';
        output += '   3. Add @param for each function parameter\n';
        output += '   4. Add @return for each return value\n';
        output += '   5. Add all @custom tags for security and validation\n';
    } else {
        output += '✅ All functions have complete NatSpec documentation!\n';
    }
    
    // Write to file
    fs.writeFileSync(outputFile, output);
    console.log(`📄 Results written to: ${outputFile}`);
}

/**
 * @notice Main validation function
 */
function main() {
    console.log('🔍 Quantillon Protocol NatSpec Validation\n');
    console.log('=' .repeat(60));
    
    let totalFiles = 0;
    let totalFunctions = 0;
    let totalDocumented = 0;
    let overallCoverage = 0;
    const reports = [];
    
    // Scan all configured directories
    for (const dir of CONFIG.directories) {
        const files = scanDirectory(dir);
        totalFiles += files.length;
        
        for (const file of files) {
            const result = validateNatSpec(file);
            reports.push({ file, result });
            
            totalFunctions += result.totalFunctions;
            totalDocumented += result.documentedFunctions;
        }
    }
    
    // Calculate overall coverage
    if (totalFunctions > 0) {
        overallCoverage = (totalDocumented / totalFunctions * 100).toFixed(2);
    }
    
    // Generate summary
    console.log('\n📊 SUMMARY');
    console.log('=' .repeat(60));
    console.log(`Total Files Scanned: ${totalFiles}`);
    console.log(`Total Functions: ${totalFunctions}`);
    console.log(`Documented Functions: ${totalDocumented}`);
    console.log(`Overall Coverage: ${overallCoverage}%`);
    console.log(`Missing Documentation: ${totalFunctions - totalDocumented}`);
    
    // Generate detailed reports
    console.log('\n📋 DETAILED REPORTS');
    console.log('=' .repeat(60));
    
    for (const { file, result } of reports) {
        console.log(generateContractReport(file, result));
    }
    
    // Write results to file
    const outputFile = path.join(__dirname, '..', 'natspec-validation-report.txt');
    writeResultsToFile(reports, totalFiles, totalFunctions, totalDocumented, overallCoverage, outputFile);
    
    // Generate recommendations
    console.log('\n💡 RECOMMENDATIONS');
    console.log('=' .repeat(60));
    
    if (overallCoverage < 100) {
        console.log('❌ Some functions are missing NatSpec documentation.');
        console.log('📝 Required tags for complete documentation:');
        CONFIG.requiredTags.forEach(tag => {
            console.log(`   - ${tag}`);
        });
        console.log('\n🔧 To fix missing documentation:');
        console.log('   1. Add @notice with user-friendly description');
        console.log('   2. Add @dev with technical implementation details');
        console.log('   3. Add @param for each function parameter');
        console.log('   4. Add @return for each return value');
        console.log('   5. Add all @custom tags for security and validation');
    } else {
        console.log('✅ All functions have complete NatSpec documentation!');
    }
    
    // Report status without failing the build
    if (overallCoverage < 100) {
        console.log('\n⚠️  Validation complete - incomplete documentation detected');
        console.log('📄 Check natspec-validation-report.txt for detailed results');
    } else {
        console.log('\n✅ Validation complete - all functions documented');
    }
    
    // Always exit successfully to not break CI/CD pipelines
    process.exit(0);
}

// Run the validation
if (require.main === module) {
    main();
}

module.exports = {
    validateNatSpec,
    scanDirectory,
    generateContractReport,
    writeResultsToFile,
    CONFIG
};
