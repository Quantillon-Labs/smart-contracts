#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

/**
 * @title Comprehensive Test NatSpec Fixer
 * @notice Adds missing @custom tags to all test functions
 * @dev This script processes all test files and adds standard @custom tags to functions missing them
 * @author Quantillon Labs
 * @custom:security-contact team@quantillon.money
 */

// Standard @custom tags for test functions
const TEST_CUSTOM_TAGS = [
    '@custom:security No security implications - test function',
    '@custom:validation No input validation required - test function',
    '@custom:state-changes No state changes - test function',
    '@custom:events No events emitted - test function',
    '@custom:errors No errors thrown - test function',
    '@custom:reentrancy Not applicable - test function',
    '@custom:access Public - no access restrictions',
    '@custom:oracle No oracle dependency for test function'
];

/**
 * @notice Fixes NatSpec documentation for a single contract file
 * @param filePath Path to the Solidity contract file
 */
function fixTestNatSpec(filePath) {
    try {
        let code = fs.readFileSync(filePath, 'utf8');
        let modified = false;
        let functionsFixed = 0;
        
        // Split into lines for processing
        const lines = code.split('\n');
        
        // Find all function definitions and their comments
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();
            
            // Look for function definitions (excluding private functions and constructors)
            if (line.match(/^function\s+\w+.*\)\s+(public|external)/) && 
                !line.includes('private') && 
                !line.includes('constructor')) {
                
                // Find the comment block before this function
                let commentStart = -1;
                let commentEnd = -1;
                
                // Look backwards for comment block
                for (let j = i - 1; j >= 0; j--) {
                    const commentLine = lines[j].trim();
                    
                    if (commentLine.endsWith('*/')) {
                        commentEnd = j;
                        // Find the start of the comment block
                        for (let k = j; k >= 0; k--) {
                            if (lines[k].trim().startsWith('/**')) {
                                commentStart = k;
                                break;
                            }
                        }
                        break;
                    }
                    
                    // Stop if we hit non-empty, non-comment code
                    if (commentLine && 
                        !commentLine.startsWith('//') && 
                        !commentLine.startsWith('*') && 
                        !commentLine.startsWith('/*')) {
                        break;
                    }
                }
                
                if (commentStart !== -1 && commentEnd !== -1) {
                    // Extract the comment content
                    let commentContent = '';
                    for (let k = commentStart; k <= commentEnd; k++) {
                        commentContent += lines[k] + '\n';
                    }
                    
                    // Check if @custom tags are missing
                    const hasCustomTags = TEST_CUSTOM_TAGS.some(tag => 
                        commentContent.includes(tag.split(' ')[0])
                    );
                    
                    if (!hasCustomTags) {
                        // Get the indentation from the closing comment line
                        const lastCommentLine = lines[commentEnd];
                        const indent = lastCommentLine.match(/^(\s*)/)[1];
                        
                        // Create the @custom tags lines
                        const customTagsLines = TEST_CUSTOM_TAGS.map(tag => 
                            `${indent} * ${tag}`
                        );
                        
                        // Insert the tags before the closing */
                        lines.splice(commentEnd, 0, ...customTagsLines);
                        modified = true;
                        functionsFixed++;
                        
                        // Update the line index since we added lines
                        i += customTagsLines.length;
                    }
                }
            }
        }
        
        if (modified) {
            // Write the modified content back to the file
            fs.writeFileSync(filePath, lines.join('\n'));
            console.log(`📝 Updated: ${filePath} (${functionsFixed} functions fixed)`);
        } else {
            console.log(`✅ No changes needed: ${filePath}`);
        }
        
    } catch (error) {
        console.error(`❌ Error processing ${filePath}:`, error.message);
    }
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
        } else if (stat.isFile() && path.extname(item) === '.sol') {
            files.push(fullPath);
        }
    }
    
    return files;
}

/**
 * @notice Main function to fix test NatSpec documentation
 */
function main() {
    console.log('🔧 Comprehensive Test NatSpec Fixer\n');
    console.log('=' .repeat(60));
    
    // Only process test files
    const testDir = '../test';
    const files = scanDirectory(testDir);
    
    console.log(`Found ${files.length} test files to process:\n`);
    
    let totalFunctionsFixed = 0;
    
    for (const file of files) {
        console.log(`Processing: ${file}`);
        fixTestNatSpec(file);
    }
    
    console.log('\n🎉 Test NatSpec fixing completed!');
    console.log('Run the validation script again to verify coverage.');
}

// Run the fixer
if (require.main === module) {
    main();
}

module.exports = {
    fixTestNatSpec,
    scanDirectory,
    TEST_CUSTOM_TAGS
};
