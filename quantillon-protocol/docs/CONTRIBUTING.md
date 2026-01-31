# Contributing to Quantillon Protocol Documentation

Thank you for your interest in contributing to the Quantillon Protocol documentation! This guide will help you get started with contributing to our documentation.

---

## How to Contribute

### Types of Contributions

We welcome several types of contributions:

1. **Documentation Improvements**
   - Fix typos and grammatical errors
   - Improve clarity and readability
   - Add missing information
   - Update outdated content

2. **New Documentation**
   - Add new guides and tutorials
   - Create integration examples
   - Write architecture explanations
   - Develop troubleshooting guides

3. **Code Examples**
   - Add working code examples
   - Improve existing examples
   - Add error handling patterns
   - Create integration templates

4. **Translation**
   - Translate documentation to other languages
   - Maintain translated versions
   - Review translation accuracy

---

## Getting Started

### Prerequisites

- Git installed on your system
- GitHub account
- Basic knowledge of Markdown
- Understanding of the Quantillon Protocol

### Setup

1. **Fork the Repository**
   ```bash
   # Fork the repository on GitHub, then clone your fork
   git clone https://github.com/YOUR_USERNAME/smart-contracts.git
   cd smart-contracts/quantillon-protocol
   ```

2. **Create a Branch**
   ```bash
   # Create a new branch for your changes
   git checkout -b docs/your-feature-name
   ```

3. **Make Your Changes**
   - Edit the documentation files
   - Test any code examples
   - Ensure proper formatting

4. **Commit Your Changes**
   ```bash
   # Add your changes
   git add .
   
   # Commit with a descriptive message
   git commit -m "docs: improve API documentation clarity"
   ```

5. **Push and Create Pull Request**
   ```bash
   # Push your branch
   git push origin docs/your-feature-name
   
   # Create a pull request on GitHub
   ```

---

## Documentation Standards

### Writing Guidelines

#### 1. Clarity and Conciseness
- Use clear, simple language
- Avoid jargon when possible
- Be concise but comprehensive
- Use active voice

#### 2. Structure and Organization
- Use proper heading hierarchy (H1 → H2 → H3)
- Include table of contents for long documents
- Use bullet points and numbered lists appropriately
- Group related information together

#### 3. Code Examples
- Include working, tested code examples
- Add comments explaining complex logic
- Use proper syntax highlighting
- Include error handling where appropriate

#### 4. Links and References
- Use relative links for internal documentation
- Verify all external links work
- Include descriptive link text
- Update links when content moves

### Markdown Standards

#### Headers
```markdown
# Main Title (H1)
## Section Title (H2)
### Subsection Title (H3)
```

#### Code Blocks
```markdown
```javascript
// JavaScript code with syntax highlighting
const contract = new ethers.Contract(address, abi, signer);
```

#### Tables
```markdown
| Column 1 | Column 2 | Column 3 |
|----------|----------|----------|
| Data 1   | Data 2   | Data 3   |
```

#### Links
```markdown
[Link Text](https://example.com)
[Internal Link](./other-document.md)
```

#### Lists
```markdown
- Unordered list item
- Another item
  - Nested item

1. Ordered list item
2. Another item
   1. Nested item
```

---

## Documentation Structure

### File Organization

```
docs/
├── README.md                 # Main documentation index
├── API.md                   # API documentation
├── API-Reference.md         # Technical API reference
├── Quick-Start.md           # Quick start guide
├── Integration-Examples.md  # Integration examples
├── Architecture.md          # Architecture overview
├── Security.md              # Security guide
├── Deployment.md            # Deployment guide
├── CONTRIBUTING.md          # This file
└── assets/                  # Images and other assets
    ├── images/
    └── diagrams/
```

### Naming Conventions

- Use kebab-case for file names: `quick-start.md`
- Use descriptive names: `integration-examples.md`
- Use consistent naming patterns
- Avoid spaces and special characters

---

## Review Process

### Pull Request Guidelines

1. **Title**: Use descriptive titles
   - `docs: improve API documentation clarity`
   - `docs: add new integration examples`
   - `docs: fix typos in security guide`

2. **Description**: Include detailed description
   - What changes were made
   - Why the changes were necessary
   - Any testing performed
   - Screenshots if applicable

3. **Size**: Keep PRs focused and manageable
   - One logical change per PR
   - Break large changes into smaller PRs
   - Avoid mixing unrelated changes

### Review Criteria

Our reviewers will check for:

- **Accuracy**: Information is correct and up-to-date
- **Clarity**: Writing is clear and easy to understand
- **Completeness**: All necessary information is included
- **Consistency**: Follows established patterns and style
- **Testing**: Code examples work as expected

### Review Timeline

- **Initial Review**: Within 2-3 business days
- **Follow-up Reviews**: Within 1-2 business days
- **Merge**: After approval and all checks pass

---

## Code of Conduct

### Our Standards

We are committed to providing a welcoming and inclusive environment for all contributors. Please:

- Be respectful and constructive
- Focus on the content, not the person
- Accept feedback gracefully
- Help others learn and improve

### Unacceptable Behavior

- Harassment or discrimination
- Personal attacks or insults
- Spam or off-topic content
- Violation of others' privacy

### Enforcement

Violations of the code of conduct may result in:
- Warning or temporary ban
- Permanent ban for severe violations
- Removal of inappropriate content

---

## Documentation Types

### API Documentation

**Purpose**: Complete reference for all smart contract interfaces

**Requirements**:
- Function signatures with parameters
- Return values and types
- Access control requirements
- Events and error codes
- Code examples

**Example**:
```markdown
#### `mintQEURO(uint256 usdcAmount, uint256 minQeuroOut)`
Mints QEURO by swapping USDC.

**Parameters:**
- `usdcAmount` (uint256): Amount of USDC to swap (6 decimals)
- `minQeuroOut` (uint256): Minimum QEURO expected (18 decimals)

**Access:** Public

**Requirements:**
- Contract not paused
- Valid oracle price
- Sufficient USDC balance and allowance
```

### Integration Examples

**Purpose**: Practical examples for common use cases

**Requirements**:
- Working code examples
- Error handling
- Best practices
- Complete implementations

**Example**:
```markdown
### Minting QEURO from USDC

```javascript
async function mintQEURO(usdcAmount, slippage = 0.05) {
    const vault = new ethers.Contract(VAULT_ADDRESS, VAULT_ABI, signer);
    
    try {
        // Calculate minimum output with slippage protection
        const expectedQeuro = await vault.calculateMintAmount(usdcAmount);
        const minQeuroOut = expectedQeuro.mul(100 - slippage * 100).div(100);
        
        // Approve USDC spending
        await usdc.approve(VAULT_ADDRESS, usdcAmount);
        
        // Mint QEURO
        const tx = await vault.mintQEURO(usdcAmount, minQeuroOut);
        await tx.wait();
        
        console.log('QEURO minted successfully');
    } catch (error) {
        console.error('Minting failed:', error.message);
        throw error;
    }
}
```
```

### Architecture Documentation

**Purpose**: High-level system design and component interactions

**Requirements**:
- System diagrams
- Component descriptions
- Data flow explanations
- Integration patterns

### Security Documentation

**Purpose**: Security considerations and best practices

**Requirements**:
- Security features explanation
- Risk assessment
- Best practices
- Incident response procedures

---

## Testing Documentation

### Code Examples

All code examples must be tested:

1. **Syntax Check**: Ensure code compiles/runs
2. **Functionality Test**: Verify examples work as expected
3. **Error Handling**: Test error scenarios
4. **Integration Test**: Test with actual contracts

### Testing Process

```bash
# Test JavaScript examples
node test-examples.js

# Test Solidity examples (use a real test contract name)
forge test --match-contract QuantillonVault

# Validate Markdown
markdownlint docs/*.md
```

---

## Tools and Resources

### Recommended Tools

**Markdown Editors**:
- [Typora](https://typora.io/) - WYSIWYG markdown editor
- [Mark Text](https://marktext.app/) - Real-time preview
- [VS Code](https://code.visualstudio.com/) - With markdown extensions

**Validation Tools**:
- [markdownlint](https://github.com/DavidAnson/markdownlint) - Markdown linting
- [markdown-link-check](https://github.com/tcort/markdown-link-check) - Link validation

**Diagram Tools**:
- [Mermaid](https://mermaid-js.github.io/) - For flowcharts and diagrams
- [Draw.io](https://app.diagrams.net/) - For complex diagrams

### Useful Resources

- [Markdown Guide](https://www.markdownguide.org/)
- [GitHub Markdown](https://docs.github.com/en/get-started/writing-on-github)
- [Technical Writing Best Practices](https://developers.google.com/tech-writing)

---

## Getting Help

### Questions and Support

- **GitHub Issues**: [Create an issue](https://github.com/Quantillon-Labs/smart-contracts/issues)
- **Discord**: [Join our Discord](https://discord.gg/uk8T9GqdE5)
- **Email**: team@quantillon.money

### Mentorship

New contributors can request mentorship:
- Pair with experienced contributors
- Get guidance on documentation standards
- Learn about the protocol architecture
- Receive feedback on contributions

---

## Recognition

### Contributor Recognition

We recognize contributors in several ways:

- **Contributor List**: Listed in project documentation
- **Release Notes**: Mentioned in release announcements
- **Community Recognition**: Highlighted in community channels
- **Swag**: Quantillon Protocol merchandise for significant contributions

### Types of Recognition

- **Documentation Contributor**: For documentation improvements
- **Example Contributor**: For code examples and tutorials
- **Translation Contributor**: For translation work
- **Reviewer**: For consistent review contributions

---

## License

By contributing to the Quantillon Protocol documentation, you agree that your contributions will be licensed under the same license as the project (MIT License).

---

## Thank You

Thank you for contributing to the Quantillon Protocol documentation! Your contributions help make the protocol more accessible and easier to use for developers around the world.

Every contribution, no matter how small, makes a difference. We appreciate your time and effort in helping improve our documentation.

---

*This contributing guide is maintained by Quantillon Labs and updated regularly.*
