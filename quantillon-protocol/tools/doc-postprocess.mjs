import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// where forge outputs; keep in sync with workflow's --out
const DOCS_DIR = path.resolve(process.argv[2] || "./docs");

const THEME_REL = "/doc-theme.css"; // absolute path from root
const CUSTOM_JS = "custom.js"; // our custom JavaScript file
const FAVICON_PNG = "favicon.png"; // our PNG favicon
const BANNER_PNG = "banner.png"; // our banner image

// Comprehensive meta tags for SEO and social sharing
const META_TAGS = `
    <!-- Primary Meta Tags -->
    <title>Quantillon Protocol's smart contracts documentation</title>
    <meta name="title" content="Quantillon Protocol's smart contracts documentation">
    <meta name="description" content="Technical documentation of Quantillon Protocol — a euro stablecoin (QEURO) governed by DAO through $QTI, featuring smart contracts for minting, staking, hedging, and yield generation." />
    <meta name="keywords" content="Quantillon Protocol, Smart Contracts, Solidity, DeFi, QEURO, stQEURO, QTI, DAO Governance, Overcollateralization, Yield Shift, Hedging, Euro Stablecoin, Blockchain, On-chain Documentation, Aave Integration, Oracle, DeFi Infrastructure" />
    
    <!-- Open Graph / Facebook / Discord / LinkedIn / Telegram -->
    <meta property="og:type" content="website" />
    <meta property="og:url" content="https://smartcontracts.quantillon.money/" />
    <meta property="og:title" content="Quantillon Protocol's smart contracts documentation" />
    <meta property="og:description" content="Technical documentation of Quantillon Protocol — a euro stablecoin (QEURO) governed by DAO through $QTI, featuring smart contracts for minting, staking, hedging, and yield generation." />
    <meta property="og:image" content="https://quantillon.money/card.png" />
    <meta property="og:image:type" content="image/png" />
    <meta property="og:image:width" content="1200" />
    <meta property="og:image:height" content="630" />

    <!-- Twitter / X -->
    <meta name="twitter:card" content="summary_large_image" />
    <meta name="twitter:url" content="https://smartcontracts.quantillon.money/" />
    <meta name="twitter:title" content="Quantillon Protocol's smart contracts documentation" />
    <meta name="twitter:description" content="Technical documentation of Quantillon Protocol — a euro stablecoin (QEURO) governed by DAO through $QTI, featuring smart contracts for minting, staking, hedging, and yield generation." />
    <meta name="twitter:image" content="https://quantillon.money/card.png" />

    <!-- Additional SEO Meta Tags -->
    <meta name="robots" content="index, follow, max-snippet:-1, max-image-preview:large, max-video-preview:-1" />
    <meta name="language" content="English" />
    <meta name="author" content="Quantillon Labs" />
    <meta name="revisit-after" content="7 days" />
    <meta name="theme-color" content="#0f0f23" />
    <meta name="application-name" content="Quantillon Protocol's smart contracts documentation" />
    <meta name="apple-mobile-web-app-title" content="Quantillon Doc" />
    
    <!-- Canonical URL -->
    <link rel="canonical" href="https://smartcontracts.quantillon.money/" />
`;

// simple header/footer html (edit to match Quantillon)
const HEADER_HTML = `
<header class="site" style="padding:14px 18px;border-bottom:1px solid #232834;display:flex;gap:14px;align-items:center;">
  <div style="display:flex;align-items:center;gap:12px;">
    <img src="/${BANNER_PNG}?1" alt="Quantillon Protocol" style="height:140px;width:auto;">
  </div>
  <nav style="margin-left:auto;display:flex;gap:16px;">
    <a href="https://quantillon.money" target="_blank" rel="noreferrer">Website</a>
    <a href="https://app.quantillon.money" target="_blank" rel="noreferrer">App</a>
    <a href="https://docs.quantillon.money" target="_blank" rel="noreferrer">GitBook</a>
  </nav>
</header>
`;

const FOOTER_HTML = `
<footer class="footer" style="padding:20px;border-top:1px solid #232834;margin-top:40px;text-align:center;">
  <div>&copy; ${new Date().getFullYear()} Quantillon Labs — Generated with <code>forge doc</code></div>
</footer>
`;

function walk(dir, fn) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full, fn);
    else fn(full);
  }
}

function ensureThemeAtRoot() {
  const themeSrc = path.join(__dirname, "doc-theme.css");
  const themeDst = path.join(DOCS_DIR, "doc-theme.css");
  fs.copyFileSync(themeSrc, themeDst);
}

function copyCustomFiles() {
  // Copy custom JavaScript file
  const customJsSrc = path.join(__dirname, "..", "docs", CUSTOM_JS);
  const customJsDst = path.join(DOCS_DIR, CUSTOM_JS);
  if (fs.existsSync(customJsSrc)) {
    fs.copyFileSync(customJsSrc, customJsDst);
    console.log("Copied custom.js to docs directory");
  } else {
    console.warn("custom.js not found, skipping...");
  }

  // Copy favicon.png
  const faviconSrc = path.join(__dirname, "..", "docs", FAVICON_PNG);
  const faviconDst = path.join(DOCS_DIR, FAVICON_PNG);
  if (fs.existsSync(faviconSrc)) {
    fs.copyFileSync(faviconSrc, faviconDst);
    console.log("Copied favicon.png to docs directory");
  } else {
    console.warn("favicon.png not found, skipping...");
  }

  // Copy banner.png
  const bannerSrc = path.join(__dirname, BANNER_PNG);
  const bannerDst = path.join(DOCS_DIR, BANNER_PNG);
  if (fs.existsSync(bannerSrc)) {
    fs.copyFileSync(bannerSrc, bannerDst);
    console.log("Copied banner.png to docs directory");
  } else {
    console.warn("banner.png not found, skipping...");
  }
}

function patchHtml(file) {
  let html = fs.readFileSync(file, "utf8");
  if (!html.includes("</head>") || !html.includes("<body")) return;

  // Remove SVG favicon references
  html = html.replace(/<link[^>]*rel="icon"[^>]*\.svg[^>]*>/gi, '');
  html = html.replace(/<link[^>]*rel="shortcut icon"[^>]*\.svg[^>]*>/gi, '');

  // Replace existing title and inject comprehensive meta tags
  if (!html.includes('Quantillon Protocol\'s smart contracts documentation')) {
    // Remove existing title tag
    html = html.replace(/<title[^>]*>.*?<\/title>/gi, '');
    
    // Inject meta tags at the beginning of head section
    html = html.replace(/<head[^>]*>/, (match) => `${match}\n${META_TAGS}`);
  }

  // inject CSS with absolute path for layout fixes only
  if (!html.includes("doc-theme.css")) {
    html = html.replace(
      "</head>",
      `  <link rel="stylesheet" href="${THEME_REL}">\n</head>`
    );
  }

  // inject custom JavaScript
  if (!html.includes(CUSTOM_JS) && html.includes("</head>")) {
    html = html.replace(
      "</head>",
      `  <script src="/${CUSTOM_JS}" defer></script>\n</head>`
    );
  }

  // inject analytics script
  if (!html.includes("stats.quantillon.money") && html.includes("</head>")) {
    html = html.replace(
      "</head>",
      `  <script defer src="https://stats.quantillon.money/script.js" data-website-id="4ac570c4-7635-41b2-a470-91fe45020b5a"></script>\n</head>`
    );
  }

  // inject header (after <body>)
  if (!html.includes('class="site" style="padding:14px') && html.includes("<body")) {
    html = html.replace(/<body[^>]*>/, (match) => `${match}\n${HEADER_HTML}`);
  }

  // inject footer (before </body>)
  if (!html.includes("&copy;") && html.includes("</body>")) {
    html = html.replace("</body>", `${FOOTER_HTML}\n</body>`);
  }

  fs.writeFileSync(file, html, "utf8");
}

function main() {
  if (!fs.existsSync(DOCS_DIR)) {
    console.error("Docs dir not found:", DOCS_DIR);
    process.exit(1);
  }
  ensureThemeAtRoot();
  copyCustomFiles();

  walk(DOCS_DIR, (f) => {
    if (f.endsWith(".html")) patchHtml(f);
  });

  console.log("Post-processing complete.");
}

main();
