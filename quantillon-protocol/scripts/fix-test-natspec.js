#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const parser = require('@solidity-parser/parser');

/**
 * @title Test NatSpec Fixer Script
 * @notice Automatically adds missing @custom tags to test functions
 * @dev This script finds test functions with incomplete NatSpec and adds the standard @custom tags
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
        const code = fs.readFileSync(filePath, 'utf8');
        const lines = code.split('\n');
        let modified = false;
        
        // Find all function definitions
        const ast = parser.parse(code, { loc: true });
        
        parser.visit(ast, {
            'FunctionDefinition': (node) => {
                // Skip excluded functions
                if (node.visibility === 'private' || 
                    node.name === 'constructor' ||
                    node.name === 'fallback' ||
                    node.name === 'receive') {
                    return;
                }
                
                // Find the comment block before the function
                const functionLine = node.loc.start.line;
                let commentStartLine = -1;
                let commentEndLine = -1;
                
                // Look for comment block before the function
                for (let i = functionLine - 2; i >= 0; i--) {
                    const line = lines[i].trim();
                    
                    if (line.endsWith('*/')) {
                        commentEndLine = i;
                        // Find the start of the comment block
                        for (let j = i; j >= 0; j--) {
                            if (lines[j].trim().startsWith('/**')) {
                                commentStartLine = j;
                                break;
                            }
                        }
                        break;
                    }
                    
                    // Stop if we hit non-empty, non-comment code
                    if (line && !line.startsWith('//') && !line.startsWith('*') && !line.startsWith('/*')) {
                        break;
                    }
                }
                
                if (commentStartLine !== -1 && commentEndLine !== -1) {
                    // Extract the comment content
                    let commentContent = '';
                    for (let i = commentStartLine; i <= commentEndLine; i++) {
                        commentContent += lines[i] + '\n';
                    }
                    
                    // Check if @custom tags are missing
                    const hasCustomTags = TEST_CUSTOM_TAGS.some(tag => 
                        commentContent.includes(tag.split(' ')[0])
                    );
                    
                    if (!hasCustomTags) {
                        // Add @custom tags before the closing */
                        const lastCommentLine = lines[commentEndLine];
                        const indent = lastCommentLine.match(/^(\s*)/)[1];
                        
                        // Insert @custom tags
                        const customTagsLines = TEST_CUSTOM_TAGS.map(tag => 
                            `${indent} * ${tag}`
                        );
                        
                        // Insert the tags before the closing */
                        lines.splice(commentEndLine, 0, ...customTagsLines);
                        modified = true;
                        
                        console.log(`  ✅ Added @custom tags to function: ${node.name}`);
                    }
                }
            }
        });
        
        if (modified) {
            // Write the modified content back to the file
            fs.writeFileSync(filePath, lines.join('\n'));
            console.log(`📝 Updated: ${filePath}`);
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
    console.log('🔧 Fixing Test NatSpec Documentation\n');
    console.log('=' .repeat(60));
    
    // Only process test files
    const testDir = '../test';
    const files = scanDirectory(testDir);
    
    console.log(`Found ${files.length} test files to process:\n`);
    
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
