// Quantillon Protocol Documentation Custom JavaScript

document.addEventListener('DOMContentLoaded', function() {
    // Add custom theme toggle functionality
    addThemeToggle();
    
    // Add smooth scrolling for anchor links
    addSmoothScrolling();
    
    // Add copy button to code blocks
    addCopyButtons();
    
    // Add search highlighting
    addSearchHighlighting();
    
    // Add contract function signature styling
    styleFunctionSignatures();
    
    // Add protocol flow diagram enhancements
    enhanceMermaidDiagrams();
});

// Theme toggle functionality
function addThemeToggle() {
    const themeToggle = document.createElement('button');
    themeToggle.className = 'theme-toggle';
    themeToggle.innerHTML = '🌙';
    themeToggle.title = 'Toggle theme';
    
    // Insert after the search box
    const searchBox = document.getElementById('search');
    if (searchBox && searchBox.parentNode) {
        searchBox.parentNode.insertBefore(themeToggle, searchBox.nextSibling);
    }
    
    themeToggle.addEventListener('click', function() {
        const currentTheme = document.documentElement.getAttribute('data-theme');
        const newTheme = currentTheme === 'ayu' ? 'light' : 'ayu';
        
        document.documentElement.setAttribute('data-theme', newTheme);
        localStorage.setItem('theme', newTheme);
        
        // Update button icon
        themeToggle.innerHTML = newTheme === 'ayu' ? '☀️' : '🌙';
    });
    
    // Set initial theme
    const savedTheme = localStorage.getItem('theme') || 'ayu';
    document.documentElement.setAttribute('data-theme', savedTheme);
    themeToggle.innerHTML = savedTheme === 'ayu' ? '☀️' : '🌙';
}

// Smooth scrolling for anchor links
function addSmoothScrolling() {
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', function (e) {
            e.preventDefault();
            const target = document.querySelector(this.getAttribute('href'));
            if (target) {
                target.scrollIntoView({
                    behavior: 'smooth',
                    block: 'start'
                });
            }
        });
    });
}

// Add copy buttons to code blocks
function addCopyButtons() {
    document.querySelectorAll('pre').forEach(pre => {
        const copyButton = document.createElement('button');
        copyButton.className = 'copy-button';
        copyButton.innerHTML = '📋';
        copyButton.title = 'Copy code';
        copyButton.style.cssText = `
            position: absolute;
            top: 0.5rem;
            right: 0.5rem;
            background: var(--primary-color);
            color: white;
            border: none;
            border-radius: 0.25rem;
            padding: 0.25rem 0.5rem;
            cursor: pointer;
            font-size: 0.75rem;
            opacity: 0;
            transition: opacity 0.2s ease;
        `;
        
        pre.style.position = 'relative';
        pre.appendChild(copyButton);
        
        pre.addEventListener('mouseenter', () => {
            copyButton.style.opacity = '1';
        });
        
        pre.addEventListener('mouseleave', () => {
            copyButton.style.opacity = '0';
        });
        
        copyButton.addEventListener('click', async () => {
            const code = pre.querySelector('code');
            if (code) {
                try {
                    await navigator.clipboard.writeText(code.textContent);
                    copyButton.innerHTML = '✅';
                    setTimeout(() => {
                        copyButton.innerHTML = '📋';
                    }, 2000);
                } catch (err) {
                    console.error('Failed to copy code:', err);
                }
            }
        });
    });
}

// Add search highlighting
function addSearchHighlighting() {
    const searchInput = document.getElementById('search');
    if (searchInput) {
        searchInput.addEventListener('input', function() {
            const searchTerm = this.value.toLowerCase();
            highlightSearchTerm(searchTerm);
        });
    }
}

function highlightSearchTerm(term) {
    if (!term) {
        // Remove all highlights
        document.querySelectorAll('.search-highlight').forEach(el => {
            el.outerHTML = el.innerHTML;
        });
        return;
    }
    
    // Remove existing highlights
    document.querySelectorAll('.search-highlight').forEach(el => {
        el.outerHTML = el.innerHTML;
    });
    
    // Add new highlights
    const walker = document.createTreeWalker(
        document.body,
        NodeFilter.SHOW_TEXT,
        null,
        false
    );
    
    const textNodes = [];
    let node;
    while (node = walker.nextNode()) {
        if (node.textContent.toLowerCase().includes(term)) {
            textNodes.push(node);
        }
    }
    
    textNodes.forEach(textNode => {
        const parent = textNode.parentNode;
        if (parent.tagName !== 'SCRIPT' && parent.tagName !== 'STYLE') {
            const regex = new RegExp(`(${term})`, 'gi');
            const highlighted = textNode.textContent.replace(regex, '<mark class="search-highlight">$1</mark>');
            if (highlighted !== textNode.textContent) {
                parent.innerHTML = parent.innerHTML.replace(textNode.textContent, highlighted);
            }
        }
    });
}

// Style function signatures
function styleFunctionSignatures() {
    document.querySelectorAll('h3, h4').forEach(heading => {
        const text = heading.textContent;
        if (text.includes('function') || text.includes('event') || text.includes('error')) {
            heading.classList.add('function-signature');
            
            // Add function type badge
            const badge = document.createElement('span');
            badge.className = 'badge badge-primary';
            
            if (text.includes('function')) {
                badge.textContent = 'function';
                badge.className = 'badge badge-primary';
            } else if (text.includes('event')) {
                badge.textContent = 'event';
                badge.className = 'badge badge-secondary';
            } else if (text.includes('error')) {
                badge.textContent = 'error';
                badge.className = 'badge badge-error';
            }
            
            heading.appendChild(badge);
        }
    });
}

// Enhance Mermaid diagrams
function enhanceMermaidDiagrams() {
    // Add zoom functionality to Mermaid diagrams
    document.querySelectorAll('.mermaid svg').forEach(svg => {
        svg.style.cursor = 'zoom-in';
        svg.addEventListener('click', function() {
            if (this.style.transform === 'scale(1.5)') {
                this.style.transform = 'scale(1)';
                this.style.cursor = 'zoom-in';
            } else {
                this.style.transform = 'scale(1.5)';
                this.style.cursor = 'zoom-out';
            }
        });
    });
}

// Add protocol statistics
function addProtocolStats() {
    const statsContainer = document.createElement('div');
    statsContainer.className = 'protocol-stats';
    statsContainer.innerHTML = `
        <div class="stats-grid">
            <div class="stat-item">
                <div class="stat-number">100M</div>
                <div class="stat-label">QTI Supply</div>
            </div>
            <div class="stat-item">
                <div class="stat-number">10M</div>
                <div class="stat-label">QEURO/Hour Rate Limit</div>
            </div>
            <div class="stat-item">
                <div class="stat-number">4x</div>
                <div class="stat-label">Max Voting Power</div>
            </div>
            <div class="stat-item">
                <div class="stat-number">4 Years</div>
                <div class="stat-label">Max Lock Time</div>
            </div>
        </div>
    `;
    
    // Add CSS for stats
    const style = document.createElement('style');
    style.textContent = `
        .protocol-stats {
            background: var(--bg-secondary);
            border-radius: 0.5rem;
            padding: 1.5rem;
            margin: 2rem 0;
        }
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 1rem;
        }
        .stat-item {
            text-align: center;
            padding: 1rem;
            background: var(--bg-primary);
            border-radius: 0.5rem;
            border: 1px solid var(--border-color);
        }
        .stat-number {
            font-size: 2rem;
            font-weight: 700;
            color: var(--primary-color);
        }
        .stat-label {
            font-size: 0.875rem;
            color: var(--text-secondary);
            margin-top: 0.5rem;
        }
    `;
    document.head.appendChild(style);
    
    // Insert stats after the overview section
    const overview = document.querySelector('.alert-info');
    if (overview) {
        overview.parentNode.insertBefore(statsContainer, overview.nextSibling);
    }
}

// Initialize additional features
window.addEventListener('load', function() {
    addProtocolStats();
});
