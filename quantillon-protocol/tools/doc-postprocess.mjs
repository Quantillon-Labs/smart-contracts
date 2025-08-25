import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// where forge outputs; keep in sync with workflow's --out
const DOCS_DIR = path.resolve(process.argv[2] || "./docs");

const THEME_REL = "doc-theme.css"; // we'll copy it next to each index.html root
const CUSTOM_JS = "custom.js"; // our custom JavaScript file
const FAVICON_PNG = "favicon.png"; // our PNG favicon

// simple header/footer html (edit to match Quantillon)
const HEADER_HTML = `
<header class="site" style="padding:14px 18px;border-bottom:1px solid #232834;display:flex;gap:14px;align-items:center;">
  <a href="/" style="font-weight:700;color:#e7b563;">Quantillon Docs</a>
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
  const themeDst = path.join(DOCS_DIR, THEME_REL);
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
}

function patchHtml(file) {
  let html = fs.readFileSync(file, "utf8");
  if (!html.includes("</head>") || !html.includes("<body")) return;

  // inject CSS
  if (!html.includes(THEME_REL)) {
    html = html.replace(
      "</head>",
      `  <link rel="stylesheet" href="/${THEME_REL}">\n</head>`
    );
  }

  // inject custom JavaScript
  if (!html.includes(CUSTOM_JS) && html.includes("</head>")) {
    html = html.replace(
      "</head>",
      `  <script src="/${CUSTOM_JS}" defer></script>\n</head>`
    );
  }

  // inject header (after <body>)
  if (!html.includes("Quantillon Docs") && html.includes("<body")) {
    html = html.replace("<body>", `<body>\n${HEADER_HTML}`);
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
