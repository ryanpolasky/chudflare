#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  apply-docs.sh
#
#  Adds the Chud Docs (/docs) feature + real installable SDKs to an existing
#  chudflare static site.
#
#  Usage:
#    cd /path/to/chudflare && bash apply-docs.sh
#    # or pass the project root explicitly:
#    bash apply-docs.sh /path/to/chudflare
#
#  What it does (all idempotent — safe to re-run):
#    1. Writes docs.html at the project root (the full Chud Docs page).
#    2. Inserts a "Docs" link into the <nav class="nav-links"> on every page,
#       just after "Verify your site". Handles ../docs.html for blog pages.
#    3. Adds  RewriteRule ^docs$ docs.html [L]  to .htaccess.
#    4. Adds /docs + /sdk entries to sitemap.xml.
#    5. Writes real, installable SDKs to sdk/python/, sdk/node/, sdk/go/.
#    6. Builds three distribution artifacts at the project root:
#         sdk/chudflare-4.0.0.tar.gz   (pip install <URL>)
#         sdk/chudflare-4.0.0.tgz      (npm install <URL>)
#         sdk/chudflare-go-4.0.0.zip   (unzip + go.mod replace)
#
#  Requirements: bash, sed, grep, mkdir, mv, tar, gzip, zip.
#  Works on Linux (GNU sed) and macOS (BSD sed). No `sed -i` is used.
#
#  Backups: every modified file is copied to <file>.pre-docs-bak before edit.
#  Re-running the script will NOT clobber existing backups.
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ── resolve project root ────────────────────────────────────────────────────
ROOT="${1:-$PWD}"
ROOT="$(cd "$ROOT" && pwd -P)"

cd "$ROOT"

# colored logging if a tty
if [ -t 1 ]; then
  C_RESET=$'\033[0m'; C_DIM=$'\033[2m'; C_BOLD=$'\033[1m'
  C_OK=$'\033[32m'; C_WARN=$'\033[33m'; C_ERR=$'\033[31m'; C_INFO=$'\033[36m'
else
  C_RESET=; C_DIM=; C_BOLD=; C_OK=; C_WARN=; C_ERR=; C_INFO=
fi

say()  { printf '%s\n' "$*"; }
ok()   { printf '%s✓%s %s\n' "$C_OK" "$C_RESET" "$*"; }
info() { printf '%s•%s %s\n' "$C_INFO" "$C_RESET" "$*"; }
skip() { printf '%s—%s %s%s%s\n' "$C_DIM" "$C_RESET" "$C_DIM" "$*" "$C_RESET"; }
warn() { printf '%s!%s %s\n' "$C_WARN" "$C_RESET" "$*" >&2; }
die()  { printf '%s✗%s %s\n' "$C_ERR" "$C_RESET" "$*" >&2; exit 1; }

# ── validate this looks like a chudflare project ────────────────────────────
[ -f "$ROOT/index.html" ] \
  || die "no index.html at $ROOT — pass the chudflare project root as the first arg."
if ! grep -q "Chudflare" "$ROOT/index.html" 2>/dev/null; then
  warn "index.html exists but doesn't mention 'Chudflare'. Continuing anyway."
fi

# ── required tools ──────────────────────────────────────────────────────────
for cmd in tar gzip; do
  command -v "$cmd" >/dev/null 2>&1 || die "required tool '$cmd' not found in PATH"
done
HAVE_ZIP=1
command -v zip >/dev/null 2>&1 || HAVE_ZIP=0
[ "$HAVE_ZIP" -eq 1 ] || warn "'zip' not found — Go SDK will ship as .tar.gz instead of .zip"

say ""
say "${C_BOLD}Applying Chud Docs + SDKs to:${C_RESET} $ROOT"
say ""

# ── helper: rewrite a file via sed, with backup, only if pattern matches ────
patch_file() {
  local file="$1" script="$2" skip_pattern="$3"
  [ -f "$file" ] || { skip "not present: $file"; return 0; }
  if grep -q -- "$skip_pattern" "$file"; then
    skip "already patched: $file"
    return 0
  fi
  local tmp; tmp="$(mktemp "${file}.XXXXXX")"
  sed -E "$script" "$file" > "$tmp"
  # verify the patch actually changed the file
  if cmp -s "$tmp" "$file"; then
    rm -f "$tmp"
    warn "no-op patch: $file — neither pattern matched, file unchanged"
    return 0
  fi
  if [ ! -f "$file.pre-docs-bak" ]; then
    cp "$file" "$file.pre-docs-bak"
  fi
  mv "$tmp" "$file"
  ok "patched: $file"
}

# ═════════════════════════════════════════════════════════════════════════════
# STEP 1 — write docs.html
# ═════════════════════════════════════════════════════════════════════════════
say "${C_BOLD}1. docs.html${C_RESET}"

DOCS_PATH="$ROOT/docs.html"
if [ -f "$DOCS_PATH" ] && grep -q "Chud Docs v2026.6" "$DOCS_PATH" 2>/dev/null; then
  skip "docs.html already at v2026.6"
else
  if [ -f "$DOCS_PATH" ] && [ ! -f "$DOCS_PATH.pre-docs-bak" ]; then
    cp "$DOCS_PATH" "$DOCS_PATH.pre-docs-bak"
  fi
  cat > "$DOCS_PATH" <<'CHUDFLARE_DOCS_HTML_EOF_v1_8c0ffee_CHUD_DEN_3'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <title>Chud Docs | Chudflare Developer Documentation</title>
  <meta name="description" content="Developer documentation for the Chudflare ChudVerse. Quickstart, Chudders, C2, CNS, Chad Fight Mode, REST API, and CLI reference."/>
  <link rel="icon" type="image/svg+xml" href="assets/img/favicon.svg"/>
  <link rel="icon" type="image/png" sizes="192x192" href="assets/img/favicon-192.png"/>
  <link rel="apple-touch-icon" sizes="180x180" href="assets/img/apple-touch-icon.png"/>
  <link rel="preconnect" href="https://fonts.googleapis.com"/>
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin/>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet"/>
  <link rel="stylesheet" href="assets/css/style.css?v=3"/>
  <style>
    /* ===== docs-specific layout ===== */
    .compliance {
      background: #FAF7F1;
      color: #5a6068;
      font-size: 12px;
      line-height: 1.5;
      text-align: center;
      padding: 10px 24px;
      border-bottom: 1px solid var(--chud-line);
    }
    .compliance a { color: var(--chud-orange-dark); font-weight: 600; }

    .docs-hero {
      background: linear-gradient(180deg, #FFFFFF 0%, #FAF7F1 100%);
      border-bottom: 1px solid var(--chud-line);
      padding: 56px 0 40px;
    }
    .docs-hero h1 { font-size: clamp(36px, 4.4vw, 52px); margin-bottom: 12px; }
    .docs-hero p { font-size: 18px; color: var(--chud-ink-2); max-width: 720px; margin: 0; }
    .docs-search {
      margin-top: 24px;
      display: flex; align-items: center;
      max-width: 520px;
      border: 1px solid var(--chud-line);
      border-radius: 10px;
      background: #fff;
      padding: 10px 14px;
      box-shadow: 0 1px 0 rgba(0,0,0,0.02);
      color: #9aa0a6;
      font-size: 14px;
      gap: 10px;
      cursor: text;
      transition: border-color .12s ease;
    }
    .docs-search:hover { border-color: var(--chud-orange); }
    .docs-search .kbd {
      margin-left: auto;
      font-family: 'JetBrains Mono', monospace;
      font-size: 11px;
      color: #8a8e95;
      border: 1px solid var(--chud-line);
      border-radius: 4px;
      padding: 2px 6px;
      background: var(--chud-fog);
    }

    .docs-layout {
      display: grid;
      grid-template-columns: 248px 1fr 220px;
      gap: 48px;
      max-width: 1400px;
      margin: 0 auto;
      padding: 48px 24px 96px;
      align-items: start;
    }
    @media (max-width: 1100px) {
      .docs-layout { grid-template-columns: 220px 1fr; gap: 32px; }
      .docs-toc { display: none; }
    }
    @media (max-width: 760px) {
      .docs-layout { grid-template-columns: 1fr; }
      .docs-sidebar { position: relative !important; top: 0 !important; max-height: none !important; }
    }

    .docs-sidebar {
      position: sticky;
      top: 88px;
      max-height: calc(100vh - 120px);
      overflow-y: auto;
      font-size: 14px;
      padding-right: 8px;
    }
    .docs-sidebar h4 {
      font-size: 11px;
      text-transform: uppercase;
      letter-spacing: 0.1em;
      color: #5a6068;
      margin: 24px 0 8px;
      font-weight: 700;
    }
    .docs-sidebar h4:first-child { margin-top: 0; }
    .docs-sidebar a {
      display: block;
      padding: 6px 10px;
      border-radius: 6px;
      color: var(--chud-ink-2);
      font-weight: 500;
      transition: background .1s ease, color .1s ease;
    }
    .docs-sidebar a:hover { background: var(--chud-fog); color: var(--chud-ink); }
    .docs-sidebar a.active {
      background: rgba(243,128,32,0.12);
      color: var(--chud-orange-dark);
      font-weight: 600;
    }

    .docs-content { min-width: 0; max-width: 820px; }
    .docs-content > section {
      padding-top: 24px;
      margin-bottom: 56px;
      scroll-margin-top: 88px;
    }
    .docs-content h2 {
      font-size: 34px;
      margin: 0 0 12px;
      padding-bottom: 16px;
      border-bottom: 1px solid var(--chud-line);
      letter-spacing: -0.02em;
    }
    .docs-content h3 {
      font-size: 22px;
      margin: 32px 0 12px;
      scroll-margin-top: 88px;
    }
    .docs-content h4 {
      font-size: 16px;
      margin: 24px 0 8px;
      font-weight: 700;
    }
    .docs-content p, .docs-content li {
      font-size: 16px;
      line-height: 1.65;
      color: var(--chud-ink-2);
    }
    .docs-content ul, .docs-content ol { padding-left: 22px; margin: 0 0 16px; }
    .docs-content li { margin-bottom: 6px; }
    .docs-content code {
      font-family: 'JetBrains Mono', 'Menlo', ui-monospace, monospace;
      background: var(--chud-fog);
      padding: 2px 6px;
      border-radius: 4px;
      font-size: 0.92em;
      color: var(--chud-orange-dark);
    }
    .docs-content a:not(.btn) {
      color: var(--chud-link);
      text-decoration: underline;
      text-underline-offset: 2px;
      text-decoration-color: rgba(0,81,195,0.3);
    }
    .docs-content a:not(.btn):hover { text-decoration-color: var(--chud-link); }

    .codeblock {
      background: #0B0F14;
      color: #E1E4E8;
      border-radius: 10px;
      padding: 18px 20px;
      font-family: 'JetBrains Mono', 'Menlo', ui-monospace, monospace;
      font-size: 13px;
      line-height: 1.65;
      overflow-x: auto;
      margin: 16px 0 20px;
      border: 1px solid #1F2630;
      position: relative;
    }
    .codeblock .lang {
      position: absolute;
      top: 10px; right: 14px;
      font-size: 11px;
      color: #6b7077;
      text-transform: uppercase;
      letter-spacing: 0.08em;
      font-weight: 600;
    }
    .codeblock pre { margin: 0; white-space: pre; }
    .codeblock .c-key { color: #F38020; }
    .codeblock .c-str { color: #6CC04A; }
    .codeblock .c-com { color: #6b7077; font-style: italic; }
    .codeblock .c-fn  { color: #FBAD41; }
    .codeblock .c-var { color: #66BFFF; }

    .callout {
      border-left: 4px solid var(--chud-orange);
      background: rgba(243,128,32,0.06);
      padding: 14px 18px;
      border-radius: 6px;
      margin: 20px 0;
      font-size: 15px;
      color: var(--chud-ink-2);
    }
    .callout .lbl {
      display: inline-block;
      font-weight: 800;
      text-transform: uppercase;
      letter-spacing: 0.08em;
      font-size: 11px;
      color: var(--chud-orange-dark);
      margin-right: 8px;
    }
    .callout.warn { border-color: #C25B14; background: rgba(194,91,20,0.08); }
    .callout.warn .lbl { color: #C25B14; }
    .callout.note { border-color: var(--chud-link); background: rgba(0,81,195,0.06); }
    .callout.note .lbl { color: var(--chud-link); }
    .callout.chud { border-color: var(--chud-ink); background: var(--chud-fog); }
    .callout.chud .lbl { color: var(--chud-ink); }

    .docs-table {
      width: 100%;
      border-collapse: collapse;
      font-size: 14px;
      margin: 16px 0 24px;
    }
    .docs-table th, .docs-table td {
      text-align: left;
      padding: 10px 14px;
      border-bottom: 1px solid var(--chud-line);
      vertical-align: top;
    }
    .docs-table th {
      background: var(--chud-fog);
      font-weight: 700;
      font-size: 12px;
      text-transform: uppercase;
      letter-spacing: 0.06em;
      color: var(--chud-ink);
    }
    .docs-table td code { font-size: 12px; }

    .docs-toc {
      position: sticky;
      top: 88px;
      max-height: calc(100vh - 120px);
      overflow-y: auto;
      font-size: 13px;
      padding-left: 16px;
      border-left: 1px solid var(--chud-line);
    }
    .docs-toc h5 {
      font-size: 11px;
      text-transform: uppercase;
      letter-spacing: 0.1em;
      color: #5a6068;
      margin: 0 0 12px;
      font-weight: 700;
    }
    .docs-toc a {
      display: block;
      padding: 4px 0;
      color: #5a6068;
      font-weight: 500;
      transition: color .1s ease;
    }
    .docs-toc a:hover { color: var(--chud-orange-dark); }
    .docs-toc a.active { color: var(--chud-orange-dark); font-weight: 600; }

    .docs-footer-nav {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 16px;
      margin-top: 48px;
      padding-top: 32px;
      border-top: 1px solid var(--chud-line);
    }
    .docs-footer-nav a {
      border: 1px solid var(--chud-line);
      border-radius: 10px;
      padding: 16px 20px;
      transition: border-color .15s ease;
      display: block;
    }
    .docs-footer-nav a:hover { border-color: var(--chud-orange); }
    .docs-footer-nav .dir { font-size: 12px; color: #5a6068; margin-bottom: 4px; }
    .docs-footer-nav .ttl { font-weight: 700; color: var(--chud-ink); }
    .docs-footer-nav .next { text-align: right; }
  </style>
</head>
<body>
<!--
  ┌──────────────────────────────────────────────────────────────────────┐
  │  Chud Docs                                                           │
  │  ─────────                                                           │
  │  if you're reading the source of a docs page you ARE a chud.         │
  │  this entire site is parody. cloudflare is real and good.            │
  │                                                                      │
  │  cf-ray:          8c0ffee-CHUD-DEN                                   │
  │  doc-fresh:       false                                              │
  │  doc-author:      mid-hunch, mid-sip                                 │
  │  doc-reviews:     none, no one reviewed this                         │
  │  nothing-ever-happens: true                                          │
  └──────────────────────────────────────────────────────────────────────┘
-->

  <!-- Top compliance banner -->
  <div class="compliance">
    Chudflare is a parody of Cloudflare. It is not affiliated with, endorsed by, sponsored by, or in any way related to Cloudflare, Inc.
    Cloudflare ships excellent infrastructure that this site has nothing to do with. For real infrastructure, visit <a href="https://cloudflare.com">cloudflare.com</a>.
  </div>

  <!-- Announcement bar -->
  <div class="bar">
    <span class="bar-emoji">📚</span>
    Chud Docs v2026.6 is live. SDKs are now actually installable.
    <a href="#quickstart">Jump to quickstart →</a>
  </div>

  <!-- Nav -->
  <header class="nav">
    <div class="container nav-row">
      <a href="index.html" class="nav-logo">
        <img src="assets/img/chudflare-mascot.png" alt="" aria-hidden="true"/>
        <span>Chudflare</span>
      </a>
      <nav class="nav-links">
        <a href="products.html">Products</a>
        <a href="pricing.html">Pricing</a>
        <a href="chud-check.html">Verify your site</a>
        <a href="docs.html" style="color:var(--chud-orange-dark);font-weight:600">Docs</a>
        <a href="status.html">Status</a>
        <a href="blog/index.html">Blog</a>
      </nav>
      <div class="nav-cta">
        <a href="#" class="hide-sm">Contact Slop Sales</a>
        <a href="#" class="hide-sm">Log in</a>
        <a href="pricing.html" class="btn btn-primary btn-sm">Start chudmaxxing</a>
      </div>
    </div>
  </header>

  <!-- Docs hero -->
  <section class="docs-hero">
    <div class="container">
      <div class="eyebrow">Chud Docs</div>
      <h1>Developer documentation.</h1>
      <p>Everything you need to ship slop on Chudflare. Read top-to-bottom or jump to whichever section your CTO is currently posting about on X.</p>
      <div class="docs-search" onclick="alert('Search is on the roadmap. For now: Cmd-F like a chud.')">
        <span style="font-size:16px">🔎</span>
        <span>Search the docs (coming Q3, our PM is currently mewing)</span>
        <span class="kbd">⌘ K</span>
      </div>
    </div>
  </section>

  <!-- 3-column docs layout -->
  <main class="docs-layout">

    <!-- Left sidebar -->
    <aside class="docs-sidebar" aria-label="Documentation navigation">
      <h4>Get started</h4>
      <a href="#quickstart" data-anchor="quickstart">Quickstart</a>
      <a href="#concepts" data-anchor="concepts">Core concepts</a>
      <a href="#cli" data-anchor="cli">Install the CLI</a>

      <h4>Compute</h4>
      <a href="#chudders" data-anchor="chudders">Chudders (Workers)</a>
      <a href="#chudscript" data-anchor="chudscript">Chudscript (DSL)</a>
      <a href="#recipes" data-anchor="recipes">Recipes</a>
      <a href="#bindings" data-anchor="bindings">Bindings</a>

      <h4>Storage &amp; data</h4>
      <a href="#c2" data-anchor="c2">C2 object storage</a>
      <a href="#cns" data-anchor="cns">CNS (DNS)</a>

      <h4>Security</h4>
      <a href="#chad-fight-mode" data-anchor="chad-fight-mode">Chad Fight Mode</a>
      <a href="#zero-chud" data-anchor="zero-chud">Zero Chud</a>

      <h4>Platform</h4>
      <a href="#api" data-anchor="api">REST API</a>
      <a href="#sdks" data-anchor="sdks">SDKs (Python/Node/Go)</a>
      <a href="#errors" data-anchor="errors">Error codes</a>

      <h4>Reference</h4>
      <a href="status.html">Status</a>
      <a href="chud-check.html">Verify your site</a>
      <a href="blog/index.html">Engineering blog</a>
      <a href=".well-known/security.txt">security.txt</a>
    </aside>

    <!-- Center content -->
    <div class="docs-content">

      <!-- 1. Quickstart -->
      <section id="quickstart">
        <h2>Quickstart</h2>
        <p>Ship your first slop site on the Chudflare ChudVerse in under five minutes. No credit card. No standing. No mewing required.</p>

        <h3 id="install">1. Install the CLI</h3>
        <p>The Chudflare CLI is a single bash script with zero dependencies, which is generous given the audience.</p>
        <div class="codeblock"><span class="lang">bash</span><pre>curl <span class="c-key">-fsSL</span> https://chudflare.com/install.sh | sh</pre></div>
        <p>Verify the install:</p>
        <div class="codeblock"><span class="lang">bash</span><pre>chudflare <span class="c-key">--version</span>
<span class="c-com"># =&gt; 0.0.1-chud</span></pre></div>

        <h3 id="login">2. Authenticate</h3>
        <p>The login flow opens your browser and writes a token to <code>~/.chudflare/credentials</code>. Behind the scenes, this token is just <code>chud_live_8c0ffee</code> repeated until your shell complains.</p>
        <div class="codeblock"><span class="lang">bash</span><pre>chudflare login
<span class="c-com"># =&gt; Opening https://chudflare.com/login</span>
<span class="c-com"># =&gt; Token saved. ray=8c0ffee-CHUD-DEN psl=2.1</span></pre></div>

        <h3 id="init">3. Initialize a project</h3>
        <p>This creates a <code>chudflare.yml</code> in the current directory. It is, by design, lower-case YAML with no schema.</p>
        <div class="codeblock"><span class="lang">bash</span><pre>chudflare init my-slop-site
<span class="c-key">cd</span> my-slop-site
<span class="c-com"># project ready. CLI now mews on your behalf.</span></pre></div>

        <h3 id="deploy">4. Deploy</h3>
        <div class="codeblock"><span class="lang">bash</span><pre>chudflare deploy
<span class="c-com"># =&gt; bundling slop...                done (412kb)</span>
<span class="c-com"># =&gt; uploading to 310 PoPs...         done</span>
<span class="c-com"># =&gt; cf-ray:    8c0ffee-CHUD-DEN</span>
<span class="c-com"># =&gt; deployed to https://my-slop-site.chuds.dev</span>
<span class="c-com"># =&gt; you may now resume hunching</span></pre></div>

        <div class="callout">
          <span class="lbl">Chud tip</span>
          You can run <code>chudflare deploy --vibe</code> to ship code you cannot explain. Same flags as <code>--prod</code>, but with the option to claim you "fully understand" the output to investors.
        </div>
      </section>

      <!-- 2. Core concepts -->
      <section id="concepts">
        <h2>Core concepts</h2>
        <p>The ChudVerse is built around four primitives. Every product on Chudflare is some combination of these:</p>
        <table class="docs-table">
          <thead><tr><th>Primitive</th><th>What it does</th><th>Real-world analog</th></tr></thead>
          <tbody>
            <tr><td><code>SDN</code></td><td>Slop Delivery Network. Anycast PoPs in 122 cities.</td><td>A CDN, but worse on purpose.</td></tr>
            <tr><td><code>Chudders</code></td><td>Edge compute. JS, TS, Python, voice memos.</td><td>Workers. With a stoop.</td></tr>
            <tr><td><code>C2</code></td><td>Object storage. Zero egress (we lack the energy).</td><td>R2, but the buckets sigh.</td></tr>
            <tr><td><code>CNS</code></td><td>DNS at <code>6.9.6.9</code>. Resolves on a delay if vibes are off.</td><td>DNS. Just DNS.</td></tr>
          </tbody>
        </table>
        <p>Every request that hits Chudflare gets a <code>cf-ray</code> header (always a variant of <code>8c0ffee-chud-X</code>), a <code>cf-psl</code> header, and a non-zero <code>x-hunch-angle</code>. These are not optional.</p>
      </section>

      <!-- 3. CLI (short, points to fuller ref below) -->
      <section id="cli">
        <h2>The Chudflare CLI</h2>
        <p>One bash script, no dependencies. The CLI is the primary interface for chuds who cannot be trusted in a browser tab.</p>
        <div class="codeblock"><span class="lang">bash</span><pre>chudflare verify  <span class="c-com"># actually fetches a URL and greps for the marker</span>
chudflare badge   <span class="c-com"># prints the embeddable verified-chud badge HTML</span>
chudflare psl     <span class="c-com"># WAF classifier (same engine as the web tool)</span>
chudflare dig     <span class="c-com"># CNS resolver output</span>
chudflare mew     <span class="c-com"># random mumbled response (do not pipe to prod)</span>
chudflare login   <span class="c-com"># fake auth, prints your chud ray-id</span>
chudflare init    <span class="c-com"># writes chudflare.yml</span>
chudflare deploy  <span class="c-com"># fake deploy logs</span>
chudflare status  <span class="c-com"># pings the status page</span>
chudflare hunch   <span class="c-com"># current operator hunch angle (time-varying)</span></pre></div>
        <p>All subcommands accept <code>--json</code> for machine-readable output. None of them respect it.</p>
      </section>

      <!-- 4. Chudders -->
      <section id="chudders">
        <h2>Chudders (Workers)</h2>
        <p>Chudders are isolate-based edge functions that run within 50ms of every customer's lower lip. Cold-start is 5ms, which is the documented time for a chud to think "should I get up." They will not get up.</p>

        <h3 id="chudders-hello">Hello, chud</h3>
        <p>The same handler, three flavors. Pick whichever syntax brings you the most peace in 2026.</p>

        <h4>JavaScript</h4>
        <div class="codeblock"><span class="lang">worker.js</span><pre><span class="c-key">export default</span> {
  <span class="c-key">async</span> <span class="c-fn">fetch</span>(<span class="c-var">request</span>, <span class="c-var">env</span>) {
    <span class="c-key">return</span> <span class="c-key">new</span> <span class="c-fn">Response</span>(<span class="c-str">"hello, chud."</span>, {
      <span class="c-var">status</span>: 200,
      <span class="c-var">headers</span>: { <span class="c-str">"x-mog-status"</span>: <span class="c-str">"YOU GOT MOGGED"</span> }
    });
  }
};</pre></div>

        <h4>Chudscript</h4>
        <div class="codeblock"><span class="lang">worker.cs</span><pre><span class="c-com">// chudscript: same idea, fewer braces, lower frame-rate</span>
@<span class="c-fn">chudder</span>(<span class="c-str">"hello-world"</span>)
<span class="c-key">fn</span> <span class="c-fn">handle</span>(<span class="c-var">req</span>) {
  <span class="c-key">slop</span> <span class="c-str">"hello, chud."</span>
}</pre></div>
        <p>See the <a href="#chudscript">Chudscript reference</a> for what <code>slop</code> actually compiles to.</p>

        <h4>Python</h4>
        <div class="codeblock"><span class="lang">worker.py</span><pre><span class="c-com"># requires the chudflare-python-edge runtime (beta, mewing)</span>
<span class="c-key">from</span> chudflare <span class="c-key">import</span> Response, chudder

@<span class="c-fn">chudder</span>(<span class="c-str">"hello-world"</span>)
<span class="c-key">async def</span> <span class="c-fn">handle</span>(<span class="c-var">request</span>):
    <span class="c-key">return</span> <span class="c-fn">Response</span>(<span class="c-str">"hello, chud."</span>, headers={<span class="c-str">"x-mog-status"</span>: <span class="c-str">"YOU GOT MOGGED"</span>})</pre></div>

        <p>Save as <code>worker.{js,cs,py}</code>, then <code>chudflare deploy</code>. The above worker is currently powering 41% of Y Combinator's W26 batch (a stat we have not verified and will not).</p>

        <h3 id="bindings">Bindings</h3>
        <p>Chudders bind to other ChudVerse services via the <code>env</code> object. The supported bindings are:</p>
        <table class="docs-table">
          <thead><tr><th>Binding</th><th>Type</th><th>Methods</th></tr></thead>
          <tbody>
            <tr><td><code>env.C2_BUCKET</code></td><td>C2 bucket</td><td><code>get</code>, <code>put</code>, <code>list</code>, <code>sigh</code></td></tr>
            <tr><td><code>env.CHUD_AI</code></td><td>Inference</td><td><code>classify</code>, <code>whisper</code>, <code>mumble</code></td></tr>
            <tr><td><code>env.CNS</code></td><td>DNS resolver</td><td><code>resolve</code>, <code>resolveTakingItsTime</code></td></tr>
            <tr><td><code>env.PSL</code></td><td>PSL classifier</td><td><code>score</code></td></tr>
          </tbody>
        </table>

        <div class="callout note">
          <span class="lbl">Note</span>
          Bindings are declared in <code>chudflare.yml</code>. There is no JSON Schema for it because the maintainer "knows what it looks like."
        </div>

        <h3 id="chudders-mog">Block visitors with good posture</h3>
        <div class="codeblock"><span class="lang">javascript</span><pre><span class="c-key">export default</span> {
  <span class="c-key">async</span> <span class="c-fn">fetch</span>(<span class="c-var">request</span>, <span class="c-var">env</span>) {
    <span class="c-key">const</span> <span class="c-var">ua</span> = request.headers.<span class="c-fn">get</span>(<span class="c-str">"user-agent"</span>);
    <span class="c-key">const</span> <span class="c-var">psl</span> = <span class="c-key">await</span> env.PSL.<span class="c-fn">score</span>(ua);

    <span class="c-key">if</span> (psl <span class="c-key">&gt;</span> 5.5) {
      <span class="c-key">return</span> <span class="c-key">new</span> <span class="c-fn">Response</span>(<span class="c-str">"you got mogged."</span>, { <span class="c-var">status</span>: 403 });
    }

    <span class="c-key">return</span> env.C2_BUCKET.<span class="c-fn">get</span>(<span class="c-str">"slop.html"</span>);
  }
};</pre></div>
        <p>This pattern is the actual reason most customers adopt Chudders. Other CDNs require a config file. Chudders lets you ship the rule inline, alongside the rest of your code, on a Sunday.</p>
      </section>

      <!-- 4b. Chudscript -->
      <section id="chudscript">
        <h2>Chudscript</h2>
        <p>Chudscript is a purpose-built scripting language for Chudders. <code>.cs</code> file extension, we are aware. Compiles to V8 isolates at deploy time. Every keyword is lowercase because the shift key is a chad key.</p>

        <div class="callout chud">
          <span class="lbl">Status</span>
          Pre-1.0, post-mid. The language was vibe-coded over a weekend and the spec is whatever the compiler happens to do on Tuesdays.
        </div>

        <h3 id="cs-syntax">Basic syntax</h3>
        <p>Looks like Rust dressed as TypeScript dressed as YAML. Single-line comments are <code>//</code>, block comments are <code>/* */</code>, string interpolation is <code>$"hello, ${name}"</code>.</p>
        <div class="codeblock"><span class="lang">chudscript</span><pre><span class="c-com">// classic.cs</span>
<span class="c-key">let</span> name = <span class="c-str">"chud"</span>
<span class="c-key">const</span> psl = 2.1

<span class="c-key">fn</span> <span class="c-fn">greet</span>(<span class="c-var">n</span>) {
  <span class="c-key">return</span> $<span class="c-str">"hello, ${n}"</span>
}

<span class="c-key">if</span> psl &lt; 4 {
  <span class="c-fn">print</span>(<span class="c-fn">greet</span>(name))
}</pre></div>

        <h3 id="cs-keywords">Response keywords</h3>
        <p>Every handler returns by using one of these keywords. Plain <code>return</code> is also legal but feels formal and HR-coded.</p>
        <table class="docs-table">
          <thead><tr><th>Keyword</th><th>Compiles to</th><th>When to use</th></tr></thead>
          <tbody>
            <tr><td><code>slop</code></td><td><code>200 OK</code></td><td>Happy path. The default.</td></tr>
            <tr><td><code>mog</code></td><td><code>403</code> + <code>x-mog-status: YOU GOT MOGGED</code></td><td>Rejecting a chad.</td></tr>
            <tr><td><code>mew</code></td><td><code>200 OK</code>, body lowercased</td><td>Being demure.</td></tr>
            <tr><td><code>hunch</code></td><td><code>500</code> + stack trace as voice memo</td><td>Catastrophic.</td></tr>
            <tr><td><code>chuddle</code></td><td><code>102 Processing</code> + <code>x-chuddling: true</code></td><td>You need a moment.</td></tr>
          </tbody>
        </table>

        <div class="codeblock"><span class="lang">chudscript</span><pre><span class="c-com">// multi-exit.cs</span>
@<span class="c-fn">chudder</span>(<span class="c-str">"multi-exit"</span>)
<span class="c-key">fn</span> <span class="c-fn">handle</span>(<span class="c-var">req</span>) {
  <span class="c-key">let</span> p = <span class="c-key">chud</span> req.<span class="c-fn">psl</span>()   <span class="c-com">// chud = await</span>

  <span class="c-key">if</span> p &gt; 8   { <span class="c-key">mog</span> <span class="c-str">"you got mogged."</span> }
  <span class="c-key">if</span> p &gt; 5   { <span class="c-key">mew</span> <span class="c-str">"go outside."</span> }
  <span class="c-key">if</span> p &lt; 1   { <span class="c-key">hunch</span> <span class="c-str">"internal slop error"</span> }

  <span class="c-key">slop</span> <span class="c-str">"hello, chud."</span>
}</pre></div>

        <h3 id="cs-decorators">Decorators</h3>
        <p>Stack as many as you want. They run top-to-bottom, ergonomically.</p>
        <table class="docs-table">
          <thead><tr><th>Decorator</th><th>What it does</th></tr></thead>
          <tbody>
            <tr><td><code>@chudder(name)</code></td><td>Registers the handler. Required.</td></tr>
            <tr><td><code>@route(path)</code></td><td>Pins the handler to a route.</td></tr>
            <tr><td><code>@psl_max(n)</code></td><td>Auto-mogs requests with a PSL above <code>n</code>.</td></tr>
            <tr><td><code>@hunch_on_error</code></td><td>Converts panics into <code>hunch</code> responses.</td></tr>
            <tr><td><code>@vibe</code></td><td>Opts into the vibe-coder runtime: no type checks, no warnings, plausible deniability.</td></tr>
          </tbody>
        </table>

        <h3 id="cs-builtins">Built-in functions</h3>
        <table class="docs-table">
          <thead><tr><th>Function</th><th>Returns</th></tr></thead>
          <tbody>
            <tr><td><code>mew(s)</code></td><td>The string, lowercased. Pure function. Idempotent.</td></tr>
            <tr><td><code>psl(req)</code></td><td>The request's PSL score as a float between 0 and 10.</td></tr>
            <tr><td><code>dig(host)</code></td><td>Resolves via CNS at <code>6.9.6.9</code>.</td></tr>
            <tr><td><code>slop_to(bucket, key)</code></td><td>Streams a response into a C2 object.</td></tr>
            <tr><td><code>nothing()</code></td><td>Returns the string <code>"nothing ever happens"</code>. Constant time.</td></tr>
          </tbody>
        </table>

        <h3 id="cs-full">A full example</h3>
        <div class="codeblock"><span class="lang">chudscript</span><pre><span class="c-key">import</span> { c2, psl } <span class="c-key">from</span> <span class="c-str">"@chudflare/stdlib"</span>

@<span class="c-fn">chudder</span>(<span class="c-str">"api"</span>)
@<span class="c-fn">psl_max</span>(5.5)
<span class="c-key">fn</span> <span class="c-fn">handle</span>(<span class="c-var">req</span>, <span class="c-var">env</span>) {
  <span class="c-key">let</span> bucket = c2.<span class="c-fn">bucket</span>(env.C2_BUCKET)
  <span class="c-key">let</span> obj = <span class="c-key">chud</span> bucket.<span class="c-fn">get</span>(<span class="c-str">"slop.html"</span>)

  <span class="c-key">cope</span> {
    <span class="c-key">slop</span> <span class="c-fn">mew</span>(obj.body)
  } <span class="c-key">else</span> {
    <span class="c-key">hunch</span> <span class="c-str">"couldn't slop the slop."</span>
  }
}</pre></div>

        <h3 id="cs-tooling">Tooling</h3>
        <ul>
          <li><strong>LSP:</strong> none. We held the line on this. <code>:set syntax=chudscript</code> in vim works because it's just <code>rust</code> aliased.</li>
          <li><strong>Type system:</strong> structural, optional, inferred, often wrong.</li>
          <li><strong>Formatter:</strong> <code>chudflare fmt</code> reformats your code into whatever the most recent Chudders blog post recommended.</li>
          <li><strong>Migrating from JavaScript:</strong> rename <code>.js</code> to <code>.cs</code>, delete every semicolon, accept your fate.</li>
        </ul>
      </section>

      <!-- 5. Recipes -->
      <section id="recipes">
        <h2>Recipes</h2>
        <p>Copy-paste snippets for common chud workloads. Each one is production-grade if your definition of production is loose.</p>

        <h3 id="recipe-1">Auto-mog gigachads</h3>
        <div class="codeblock"><span class="lang">javascript</span><pre><span class="c-key">export default</span> {
  <span class="c-key">async</span> <span class="c-fn">fetch</span>(<span class="c-var">request</span>, <span class="c-var">env</span>) {
    <span class="c-key">const</span> { psl } = <span class="c-key">await</span> env.CHUD_AI.<span class="c-fn">classify</span>(request);
    <span class="c-key">return</span> psl <span class="c-key">&gt;</span> 7
      ? <span class="c-key">new</span> <span class="c-fn">Response</span>(<span class="c-str">"403 chad detected"</span>, { <span class="c-var">status</span>: 403 })
      : <span class="c-fn">fetch</span>(request);
  }
};</pre></div>

        <h3 id="recipe-2">Mew every response body</h3>
        <div class="codeblock"><span class="lang">javascript</span><pre><span class="c-key">export default</span> {
  <span class="c-key">async</span> <span class="c-fn">fetch</span>(<span class="c-var">request</span>) {
    <span class="c-key">const</span> <span class="c-var">res</span> = <span class="c-key">await</span> <span class="c-fn">fetch</span>(request);
    <span class="c-key">const</span> <span class="c-var">text</span> = <span class="c-key">await</span> res.<span class="c-fn">text</span>();
    <span class="c-key">return</span> <span class="c-key">new</span> <span class="c-fn">Response</span>(text.<span class="c-fn">toLowerCase</span>(), res);
  }
};</pre></div>

        <h3 id="recipe-3">Replace every error with "nothing ever happens"</h3>
        <div class="codeblock"><span class="lang">javascript</span><pre><span class="c-key">export default</span> {
  <span class="c-key">async</span> <span class="c-fn">fetch</span>(<span class="c-var">request</span>) {
    <span class="c-key">try</span> {
      <span class="c-key">return</span> <span class="c-key">await</span> <span class="c-fn">fetch</span>(request);
    } <span class="c-key">catch</span> {
      <span class="c-key">return</span> <span class="c-key">new</span> <span class="c-fn">Response</span>(<span class="c-str">"nothing ever happens"</span>, { <span class="c-var">status</span>: 200 });
    }
  }
};</pre></div>

        <h3 id="recipe-4">Reject anyone whose User-Agent admits to being a Series C founder</h3>
        <div class="codeblock"><span class="lang">javascript</span><pre><span class="c-key">export default</span> {
  <span class="c-key">async</span> <span class="c-fn">fetch</span>(<span class="c-var">request</span>) {
    <span class="c-key">const</span> <span class="c-var">ua</span> = request.headers.<span class="c-fn">get</span>(<span class="c-str">"user-agent"</span>) || <span class="c-str">""</span>;
    <span class="c-key">const</span> <span class="c-var">tells</span> = [<span class="c-str">"hayes valley"</span>, <span class="c-str">"founder mode"</span>, <span class="c-str">"agi by eoy"</span>];
    <span class="c-key">if</span> (tells.<span class="c-fn">some</span>(t <span class="c-key">=&gt;</span> ua.<span class="c-fn">toLowerCase</span>().<span class="c-fn">includes</span>(t))) {
      <span class="c-key">return</span> <span class="c-key">new</span> <span class="c-fn">Response</span>(<span class="c-str">"blocked. go outside."</span>, { <span class="c-var">status</span>: 451 });
    }
    <span class="c-key">return</span> <span class="c-fn">fetch</span>(request);
  }
};</pre></div>
      </section>

      <!-- 6. C2 -->
      <section id="c2">
        <h2>C2 object storage</h2>
        <p>C2 is the ChudVerse's object store. S3-compatible API, R2-compatible economics, distinctly chud-compatible UX. Zero egress fees because the egress simply does not happen.</p>

        <h3 id="c2-bucket">Create a bucket</h3>
        <div class="codeblock"><span class="lang">bash</span><pre>chudflare c2 create monster-cans
<span class="c-com"># =&gt; bucket "monster-cans" created in DEN-CHUD-3</span>
<span class="c-com"># =&gt; bucket posture: hunched (default)</span></pre></div>

        <h3 id="c2-upload">Upload an object</h3>
        <div class="codeblock"><span class="lang">bash</span><pre>chudflare c2 put monster-cans/ultra-zero.json \
  <span class="c-key">--from-file</span> ./drink.json
<span class="c-com"># =&gt; uploaded 1.2kb. eTag: 8c0ffee...</span>
<span class="c-com"># =&gt; chud-cache: HIT (somehow)</span></pre></div>

        <h3 id="c2-binding">Read from a Chudder binding</h3>
        <div class="codeblock"><span class="lang">javascript</span><pre><span class="c-key">const</span> <span class="c-var">obj</span> = <span class="c-key">await</span> env.C2_BUCKET.<span class="c-fn">get</span>(<span class="c-str">"ultra-zero.json"</span>);
<span class="c-key">if</span> (!obj) <span class="c-key">return</span> <span class="c-key">new</span> <span class="c-fn">Response</span>(<span class="c-str">"nothing ever happens"</span>, { <span class="c-var">status</span>: 404 });
<span class="c-key">return</span> <span class="c-key">new</span> <span class="c-fn">Response</span>(obj.body, { <span class="c-var">headers</span>: { <span class="c-str">"content-type"</span>: <span class="c-str">"application/json"</span> } });</pre></div>

        <div class="callout warn">
          <span class="lbl">Warning</span>
          Buckets default to <code>posture: hunched</code>. Setting <code>posture: erect</code> will incur a 14% surcharge and trigger an internal review.
        </div>
      </section>

      <!-- 7. CNS DNS -->
      <section id="cns">
        <h2>CNS (DNS)</h2>
        <p>CNS, the Chud Name System, is Chudflare's authoritative DNS. The public resolver lives at <code>6.9.6.9</code>. It is faster than mewing and twice as silent.</p>

        <h3 id="cns-record">Add a record</h3>
        <div class="codeblock"><span class="lang">bash</span><pre>chudflare cns add \
  <span class="c-key">--zone</span> example.com \
  <span class="c-key">--type</span> A \
  <span class="c-key">--name</span> @ \
  <span class="c-key">--value</span> 6.9.6.9 \
  <span class="c-key">--posture</span> hunched
<span class="c-com"># =&gt; record created. ttl=300. posture: hunched</span></pre></div>

        <h3 id="cns-resolve">Resolve via the public resolver</h3>
        <div class="codeblock"><span class="lang">bash</span><pre>dig @6.9.6.9 chudflare.com
<span class="c-com">;; ANSWER SECTION:</span>
chudflare.com.    300    IN    A    6.9.6.9
<span class="c-com">;; QUERY TIME: 73 msec (mewing latency, nominal)</span></pre></div>
      </section>

      <!-- 8. Chad Fight Mode -->
      <section id="chad-fight-mode">
        <h2>Chad Fight Mode (WAF)</h2>
        <p>Chad Fight Mode is Chudflare's web application firewall. Rules are written in the Chud DSL, a TOML-flavored format we invented because YAML did not feel hunched enough.</p>

        <h3 id="cfm-thresholds">Plan thresholds</h3>
        <table class="docs-table">
          <thead><tr><th>Plan</th><th>Default PSL threshold</th><th>Configurable</th></tr></thead>
          <tbody>
            <tr><td>Chud (free)</td><td><code>≥ 8</code></td><td>No</td></tr>
            <tr><td>Looksminned</td><td><code>≥ 5.5</code></td><td>Yes</td></tr>
            <tr><td>Permachud</td><td>Custom</td><td>Yes</td></tr>
            <tr><td>Gigachud</td><td>Dynamic</td><td>Yes, even at 2am</td></tr>
          </tbody>
        </table>

        <h3 id="cfm-rules">Example ruleset</h3>
        <div class="codeblock"><span class="lang">toml</span><pre><span class="c-com"># /etc/chudflare/firewall.toml</span>

[[<span class="c-key">rule</span>]]
description = <span class="c-str">"block visible cheekbones"</span>
expression  = <span class="c-str">"(http.req.psl gt 5.5)"</span>
action      = <span class="c-str">"mog_back"</span>

[[<span class="c-key">rule</span>]]
description = <span class="c-str">"block users mid-mewing"</span>
expression  = <span class="c-str">"(http.req.tongue_position eq 'palate')"</span>
action      = <span class="c-str">"chud_challenge"</span>

[[<span class="c-key">rule</span>]]
description = <span class="c-str">"allow self only"</span>
expression  = <span class="c-str">"(ip.src eq cf.user.fat_fucking_chud)"</span>
action      = <span class="c-str">"allow"</span></pre></div>

        <h3 id="cfm-actions">Actions reference</h3>
        <table class="docs-table">
          <thead><tr><th>Action</th><th>Description</th></tr></thead>
          <tbody>
            <tr><td><code>allow</code></td><td>Let the request through. Boring.</td></tr>
            <tr><td><code>chud_challenge</code></td><td>5-second hunching CAPTCHA. Most challenges pass.</td></tr>
            <tr><td><code>mog_back</code></td><td>Returns 403 with a <code>YOU GOT MOGGED</code> header.</td></tr>
            <tr><td><code>under_mew</code></td><td>Routes the request to a quieter PoP for "review."</td></tr>
            <tr><td><code>nothing_ever_happens</code></td><td>Returns 200 with body <code>nothing ever happens</code>.</td></tr>
          </tbody>
        </table>
      </section>

      <!-- 9. Zero Chud -->
      <section id="zero-chud">
        <h2>Zero Chud</h2>
        <p>Zero Chud is an identity-aware perimeter for organizations where nobody is allowed to be a chud, except the founder. This is, by design, paradoxical. We document it anyway.</p>

        <h3 id="zc-policy">Sample policy</h3>
        <div class="codeblock"><span class="lang">json</span><pre>{
  <span class="c-key">"app"</span>: <span class="c-str">"slop-dashboard.internal"</span>,
  <span class="c-key">"require"</span>: [
    { <span class="c-key">"identity"</span>: <span class="c-str">"sso.chudmaxx.io"</span> },
    { <span class="c-key">"posture"</span>: <span class="c-str">"hunched"</span> },
    { <span class="c-key">"psl_max"</span>: 4.2 }
  ],
  <span class="c-key">"deny"</span>: [
    { <span class="c-key">"trait"</span>: <span class="c-str">"jaw_visibility"</span> },
    { <span class="c-key">"trait"</span>: <span class="c-str">"unprompted_sigma_post"</span> }
  ]
}</pre></div>
        <p>Policies live in <code>chudflare.yml</code> under <code>zero_chud.policies[]</code>. There is no admin UI because the founder prefers to "feel the YAML."</p>
      </section>

      <!-- 10. REST API -->
      <section id="api">
        <h2>REST API</h2>
        <p>The Chudflare REST API mirrors the surface area of Cloudflare's v4 API closely enough to be funny, including the bit where everything is under <code>/v4/zones</code>.</p>

        <h3 id="api-auth">Authentication</h3>
        <p>Every request takes a <code>Authorization: Bearer chud_live_...</code> header. Tokens are managed in the dashboard under <strong>My Profile → Slop → Tokens (whisper to reveal)</strong>.</p>
        <div class="codeblock"><span class="lang">bash</span><pre>curl https://api.chudflare.com/v4/user \
  <span class="c-key">-H</span> <span class="c-str">"Authorization: Bearer chud_live_8c0ffee..."</span></pre></div>

        <h3 id="api-create-zone">Create a zone</h3>
        <div class="codeblock"><span class="lang">bash</span><pre>curl <span class="c-key">-X</span> POST https://api.chudflare.com/v4/zones \
  <span class="c-key">-H</span> <span class="c-str">"Authorization: Bearer chud_live_8c0ffee..."</span> \
  <span class="c-key">-H</span> <span class="c-str">"Content-Type: application/json"</span> \
  <span class="c-key">-d</span> <span class="c-str">'{
    "name": "example.com",
    "jurisdiction": "agartha",
    "posture": "hunched",
    "plan": "chud"
  }'</span></pre></div>

        <h3 id="api-create-rule">Add a firewall rule</h3>
        <div class="codeblock"><span class="lang">bash</span><pre>curl <span class="c-key">-X</span> POST https://api.chudflare.com/v4/zones/<span class="c-var">$ZONE</span>/firewall/rules \
  <span class="c-key">-H</span> <span class="c-str">"Authorization: Bearer chud_live_..."</span> \
  <span class="c-key">-d</span> <span class="c-str">'{
    "description": "block visible cheekbones",
    "expression": "(http.req.psl gt 5.5)",
    "action": "mog_back"
  }'</span></pre></div>

        <h3 id="api-response">Response shape</h3>
        <p>All responses follow the same envelope. <code>success</code> is always <code>true</code> in production because chuds do not handle errors gracefully.</p>
        <div class="codeblock"><span class="lang">json</span><pre>{
  <span class="c-key">"success"</span>: <span class="c-str">true</span>,
  <span class="c-key">"errors"</span>: [],
  <span class="c-key">"messages"</span>: [<span class="c-str">"chud-ray: 8c0ffee-DEN-3"</span>],
  <span class="c-key">"result"</span>: {
    <span class="c-key">"id"</span>: <span class="c-str">"chud_..."</span>,
    <span class="c-key">"created_on"</span>: <span class="c-str">"2026-05-18T01:50:00Z"</span>,
    <span class="c-key">"posture"</span>: <span class="c-str">"hunched"</span>
  }
}</pre></div>

        <div class="callout chud">
          <span class="lbl">Compatibility</span>
          The API is not Cloudflare API compatible. Do not point your CF terraform at it. Your terraform will, however, write a strongly-worded log line.
        </div>
      </section>

      <!-- 10b. SDKs -->
      <section id="sdks">
        <h2>SDKs</h2>
        <p>We maintain three official client SDKs. Each one is real, installable, and shaped like the corresponding Cloudflare SDK. None of them call a real API: every method returns plausible-looking fake data so your demo / talk / dashboard works without a backend.</p>

        <div class="callout note">
          <span class="lbl">Hosting</span>
          We did not have the cycles (or the legal team) to claim <code>chudflare</code> on PyPI / npm. The SDKs install directly from <code>chudflare.com/sdk</code> tarballs instead. Sources also live on the site so you can <code>curl</code> the raw files.
        </div>

        <h3 id="sdk-python">Python</h3>
        <p>The Python client is a real package, a real <code>tar.gz</code>, hosted directly from this domain.</p>
        <div class="codeblock"><span class="lang">bash</span><pre>pip install https://chudflare.com/sdk/chudflare-4.0.0.tar.gz</pre></div>
        <div class="codeblock"><span class="lang">python</span><pre><span class="c-key">from</span> chudflare <span class="c-key">import</span> Chudflare

client = <span class="c-fn">Chudflare</span>(api_token=<span class="c-str">"chud_live_8c0ffee..."</span>)

<span class="c-com"># create a zone</span>
zone = client.zones.<span class="c-fn">create</span>(
    name=<span class="c-str">"example.com"</span>,
    jurisdiction=<span class="c-str">"agartha"</span>,
    posture=<span class="c-str">"hunched"</span>,
    plan=<span class="c-str">"chud"</span>,
)
<span class="c-fn">print</span>(<span class="c-key">f</span><span class="c-str">"created zone {zone.id} (ray: {zone.ray})"</span>)

<span class="c-com"># add a firewall rule</span>
client.firewall.rules.<span class="c-fn">create</span>(
    zone_id=zone.id,
    description=<span class="c-str">"block visible cheekbones"</span>,
    expression=<span class="c-str">"(http.req.psl gt 5.5)"</span>,
    action=<span class="c-str">"mog_back"</span>,
)</pre></div>
        <p>The Python SDK is by far the most-downloaded because the audience cannot get Node working.</p>

        <h3 id="sdk-node">Node.js</h3>
        <p>Same story for Node: real <code>tgz</code> tarball, no npm registry involved.</p>
        <div class="codeblock"><span class="lang">bash</span><pre>npm install https://chudflare.com/sdk/chudflare-4.0.0.tgz
<span class="c-com"># or, if you've taken the bait:</span>
bun add https://chudflare.com/sdk/chudflare-4.0.0.tgz</pre></div>
        <div class="codeblock"><span class="lang">javascript</span><pre><span class="c-key">const</span> { Chudflare } = <span class="c-fn">require</span>(<span class="c-str">"chudflare"</span>);

<span class="c-key">const</span> client = <span class="c-key">new</span> <span class="c-fn">Chudflare</span>({ <span class="c-var">apiToken</span>: <span class="c-str">"chud_live_8c0ffee..."</span> });

<span class="c-key">const</span> zone = <span class="c-key">await</span> client.zones.<span class="c-fn">create</span>({ <span class="c-var">name</span>: <span class="c-str">"example.com"</span> });
console.<span class="c-fn">log</span>(<span class="c-key">`</span>created zone <span class="c-var">${zone.id}</span> (ray: <span class="c-var">${zone.ray}</span>)<span class="c-key">`</span>);

<span class="c-key">const</span> verdict = <span class="c-key">await</span> client.<span class="c-fn">verify</span>({ <span class="c-var">url</span>: <span class="c-str">"https://my-slop-site.com"</span> });
console.<span class="c-fn">log</span>(verdict);
<span class="c-com">// =&gt; { ok: true, marker: "meta", ray: "8c0ffee-CHUD-...", psl: 2.1, ... }</span></pre></div>

        <h3 id="sdk-go">Go</h3>
        <p>A real Go module would need a backing git repo, and our git energy is at zero this quarter. The source ships as a zip you vendor with a <code>replace</code> directive:</p>
        <div class="codeblock"><span class="lang">bash</span><pre>curl <span class="c-key">-L</span> <span class="c-key">-o</span> chudflare-go.zip https://chudflare.com/sdk/chudflare-go-4.0.0.zip
unzip chudflare-go.zip
<span class="c-com"># then in your go.mod:</span>
<span class="c-com">#   require chudflare.com/chudflare-go v4.0.0</span>
<span class="c-com">#   replace chudflare.com/chudflare-go =&gt; ./chudflare-go-4.0.0</span></pre></div>
        <div class="codeblock"><span class="lang">go</span><pre><span class="c-key">package</span> main

<span class="c-key">import</span> (
  <span class="c-str">"context"</span>
  <span class="c-str">"fmt"</span>

  chudflare <span class="c-str">"chudflare.com/chudflare-go"</span>
)

<span class="c-key">func</span> <span class="c-fn">main</span>() {
  client := chudflare.<span class="c-fn">New</span>(<span class="c-str">"chud_live_8c0ffee..."</span>)
  zone, err := client.Zones.<span class="c-fn">Create</span>(context.<span class="c-fn">Background</span>(), <span class="c-str">"example.com"</span>)
  <span class="c-key">if</span> err != <span class="c-key">nil</span> {
    <span class="c-fn">panic</span>(<span class="c-str">"you got mogged: "</span> + err.<span class="c-fn">Error</span>())
  }
  fmt.<span class="c-fn">Printf</span>(<span class="c-str">"created zone %s (ray: %s)\n"</span>, zone.ID, zone.Ray)
}</pre></div>

        <h3 id="sdk-source">Source</h3>
        <p>Every SDK lives under <a href="sdk/"><code>/sdk/</code></a> on this site. Browse the source, audit the imports, copy whatever you want. Everything is MIT.</p>
        <ul>
          <li><a href="sdk/python/"><code>/sdk/python/</code></a> &middot; <a href="sdk/chudflare-4.0.0.tar.gz">chudflare-4.0.0.tar.gz</a></li>
          <li><a href="sdk/node/"><code>/sdk/node/</code></a> &middot; <a href="sdk/chudflare-4.0.0.tgz">chudflare-4.0.0.tgz</a></li>
          <li><a href="sdk/go/"><code>/sdk/go/</code></a> &middot; <a href="sdk/chudflare-go-4.0.0.zip">chudflare-go-4.0.0.zip</a></li>
        </ul>

        <h3 id="sdk-versioning">Versioning</h3>
        <p>All SDKs follow a soft semver where the major version tracks the Y Combinator batch we're in. We are currently on <code>v4.x</code>, which means W26. Breaking changes ship on Fridays at 5pm.</p>
      </section>

      <!-- 11. Errors -->
      <section id="errors">
        <h2>Error codes</h2>
        <p>Every Chudflare error follows the format <code>10XX</code>, identical to Cloudflare's, because we do not have an original thought. The relevant codes:</p>
        <table class="docs-table">
          <thead><tr><th>Code</th><th>Meaning</th><th>Action</th></tr></thead>
          <tbody>
            <tr><td><code>1020</code></td><td>Access denied. PSL threshold exceeded.</td><td>Hunch more.</td></tr>
            <tr><td><code>1021</code></td><td>Origin server is mid-mewing.</td><td>Retry in 30s.</td></tr>
            <tr><td><code>1022</code></td><td>SSL handshake refused (Sigma Status Layer).</td><td>Regenerate certs in dashboard.</td></tr>
            <tr><td><code>1041</code></td><td>Worker exceeded CPU. Was probably looping on <code>mew()</code>.</td><td>Add a base case.</td></tr>
            <tr><td><code>1042</code></td><td>Posture check failed.</td><td>Sit up. Then sit back down.</td></tr>
            <tr><td><code>1099</code></td><td>"nothing ever happens" reached its rate limit.</td><td>Something happened. We don't know what.</td></tr>
          </tbody>
        </table>
        <p>For a live example, see the rendered <a href="1020.html">1020 page</a>. It is genuinely the page that ships when Chad Fight Mode blocks a visitor.</p>
      </section>

      <!-- Footer nav -->
      <nav class="docs-footer-nav" aria-label="Docs prev/next">
        <a href="status.html">
          <div class="dir">← Back to</div>
          <div class="ttl">Status dashboard</div>
        </a>
        <a href="chud-check.html" class="next">
          <div class="dir">Next: ship the badge →</div>
          <div class="ttl">Verify your site</div>
        </a>
      </nav>
    </div>

    <!-- Right "On this page" TOC -->
    <aside class="docs-toc" aria-label="On this page">
      <h5>On this page</h5>
      <a href="#quickstart" data-toc="quickstart">Quickstart</a>
      <a href="#concepts" data-toc="concepts">Core concepts</a>
      <a href="#cli" data-toc="cli">The CLI</a>
      <a href="#chudders" data-toc="chudders">Chudders</a>
      <a href="#chudscript" data-toc="chudscript">Chudscript</a>
      <a href="#recipes" data-toc="recipes">Recipes</a>
      <a href="#c2" data-toc="c2">C2 storage</a>
      <a href="#cns" data-toc="cns">CNS DNS</a>
      <a href="#chad-fight-mode" data-toc="chad-fight-mode">Chad Fight Mode</a>
      <a href="#zero-chud" data-toc="zero-chud">Zero Chud</a>
      <a href="#api" data-toc="api">REST API</a>
      <a href="#sdks" data-toc="sdks">SDKs</a>
      <a href="#errors" data-toc="errors">Error codes</a>
    </aside>
  </main>

  <!-- Footer -->
  <footer class="foot">
    <div class="container">
      <div class="foot-grid">
        <div class="foot-col">
          <div class="nav-logo" style="color:#fff;margin-bottom:14px">
            <img src="assets/img/chudflare-mascot.png" alt="" style="height:30px" aria-hidden="true"/>
            <span>Chudflare</span>
          </div>
          <p style="color:#9CA3AF;max-width:280px">Helping build a slopper Internet. From our couch to yours.</p>
        </div>
        <div class="foot-col">
          <h5>Products</h5>
          <a href="products.html#sdn">Slop Delivery Network</a>
          <a href="products.html#mog">Chad Fight Mode</a>
          <a href="products.html#dev">Chudders</a>
          <a href="products.html#dev">C2 Storage</a>
          <a href="products.html#dev">Chuds (Hosting)</a>
          <a href="products.html#zerochud">Zero Chud</a>
          <a href="products.html#dns">CNS (DNS)</a>
        </div>
        <div class="foot-col">
          <h5>Solutions</h5>
          <a href="#">Doomscrolling Platforms</a>
          <a href="#">DTC Slop &amp; eCommerce</a>
          <a href="#">Looksminned Enterprises</a>
          <a href="#">Method-Content Creators</a>
          <a href="#">Sigma SaaS</a>
        </div>
        <div class="foot-col">
          <h5>Resources</h5>
          <a href="docs.html">Chud Docs</a>
          <a href="#">Slop Hub</a>
          <a href="status.html">Slop Status</a>
          <a href="psl-detector.html">PSL Radar</a>
          <a href="verify.html">Under Mew Mode</a>
          <a href="404.html">404 sample</a>
          <a href="1020.html">1020 sample</a>
        </div>
        <div class="foot-col">
          <h5>Company</h5>
          <a href="#">About Chudflare</a>
          <a href="#">Chudders (we're hiring chuds)</a>
          <a href="#">Investor Relations</a>
          <a href="#">Press &amp; Slop</a>
          <a href=".well-known/security.txt">Trust &amp; Chud Safety</a>
        </div>
        <div class="foot-col">
          <h5>Support</h5>
          <a href="docs.html">Help Center</a>
          <a href="blog/index.html">Community Forum</a>
          <a href="status.html">Status</a>
          <a href="https://www.cloudflarestatus.com/">Real System Status</a>
          <a href="#">Contact Slop Sales</a>
        </div>
      </div>
      <div class="foot-bottom">
        <div class="foot-tag">
          <span>© 2026 Chudflare, Inc. All rights chudded.</span>
        </div>
        <div>
          <a href="1020.html">Privacy</a>
          <a href="404.html">Terms</a>
          <a href="404.html">Cookie Slop</a>
          <a href="https://imafatfuckingchud.com" style="color:var(--chud-orange-light)">Forged with love by an actual chud →</a>
        </div>
      </div>
    </div>
  </footer>

  <script src="assets/js/chudflare.js?v=3"></script>
  <script>
    // Highlight the active sidebar entry + TOC entry as you scroll
    (function () {
      const sections = Array.from(document.querySelectorAll('.docs-content section[id]'));
      const sidebarLinks = Array.from(document.querySelectorAll('.docs-sidebar a[data-anchor]'));
      const tocLinks = Array.from(document.querySelectorAll('.docs-toc a[data-toc]'));
      if (!sections.length) return;

      function setActive(id) {
        sidebarLinks.forEach(a => a.classList.toggle('active', a.dataset.anchor === id));
        tocLinks.forEach(a => a.classList.toggle('active', a.dataset.toc === id));
      }

      const observer = new IntersectionObserver((entries) => {
        // pick the entry closest to the top that's currently intersecting
        const visible = entries.filter(e => e.isIntersecting);
        if (visible.length) {
          const top = visible.sort((a, b) => a.target.offsetTop - b.target.offsetTop)[0];
          setActive(top.target.id);
        }
      }, { rootMargin: '-30% 0px -55% 0px', threshold: 0 });

      sections.forEach(s => observer.observe(s));
    })();
  </script>
</body>
</html>
CHUDFLARE_DOCS_HTML_EOF_v1_8c0ffee_CHUD_DEN_3
  ok "wrote docs.html ($(wc -l < "$DOCS_PATH" | tr -d ' ') lines)"
fi

# ═════════════════════════════════════════════════════════════════════════════
# STEP 2 — insert "Docs" into the <nav class="nav-links"> on every page
# ═════════════════════════════════════════════════════════════════════════════
say ""
say "${C_BOLD}2. nav links${C_RESET}"

NAV_SED='
  /<a href="(\.\.\/)?chud-check\.html">Verify your site<\/a>/ {
    h
    s/(.*)(<a href="(\.\.\/)?chud-check\.html">Verify your site<\/a>)(.*)/\1\2\4\
\1<a href="\3docs.html">Docs<\/a>/
  }
'

find "$ROOT" \
  \( -path "$ROOT/node_modules" -o -path "$ROOT/.git" -o -path "$ROOT/sdk" \) -prune -o \
  -type f -name "*.html" -print \
| while IFS= read -r file; do
  grep -q 'class="nav-links"' "$file" 2>/dev/null || continue
  patch_file "$file" "$NAV_SED" '>Docs</a>'
done

# ═════════════════════════════════════════════════════════════════════════════
# STEP 3 — .htaccess rewrite rule
# ═════════════════════════════════════════════════════════════════════════════
say ""
say "${C_BOLD}3. .htaccess${C_RESET}"

HTACCESS_SED='
  /RewriteRule \^chud-check\$ chud-check\.html \[L\]/ {
    h
    s/(.*RewriteRule \^chud-check\$ chud-check\.html \[L\])(.*)/\1\2\
  RewriteRule ^docs$ docs.html [L]/
  }
'
patch_file "$ROOT/.htaccess" "$HTACCESS_SED" 'RewriteRule \^docs\$ docs\.html'

# ═════════════════════════════════════════════════════════════════════════════
# STEP 4 — sitemap.xml entries (/docs + /sdk)
# ═════════════════════════════════════════════════════════════════════════════
say ""
say "${C_BOLD}4. sitemap.xml${C_RESET}"

SITEMAP_SED='
  /<\/urlset>/ {
    h
    s|(.*)(</urlset>)(.*)|\1  <url><loc>https://chudflare.com/docs</loc><priority>0.9</priority></url>\
  <url><loc>https://chudflare.com/sdk/</loc><priority>0.7</priority></url>\
\2\3|
  }
'
patch_file "$ROOT/sitemap.xml" "$SITEMAP_SED" '<loc>https://chudflare.com/docs</loc>'

# ═════════════════════════════════════════════════════════════════════════════
# STEP 5 — write SDK source files
# ═════════════════════════════════════════════════════════════════════════════
say ""
say "${C_BOLD}5. SDK source files${C_RESET}"

SDK_VERSION_FILE="$ROOT/sdk/.chudflare-sdk-version"
if [ -f "$SDK_VERSION_FILE" ] && grep -q '^chudflare-sdk-4\.0\.0$' "$SDK_VERSION_FILE" 2>/dev/null; then
  skip "SDK sources already at v4.0.0"
  SDK_NEEDS_BUILD=0
else
  SDK_NEEDS_BUILD=1
  info "writing SDK sources..."

mkdir -p "$ROOT/sdk/python"
cat > "$ROOT/sdk/python/pyproject.toml" <<'CHUDFLARE_SDK_FILE_EOF_v1_8c0ffee_CHUD_DEN_3'
[build-system]
requires = ["setuptools>=61.0"]
build-backend = "setuptools.build_meta"

[project]
name = "chudflare"
version = "4.0.0"
description = "The chudmaxxed cloud, in Python. Parody SDK for the Chudflare ChudVerse."
readme = "README.md"
requires-python = ">=3.8"
license = {text = "MIT"}
authors = [{name = "Chudflare, Inc.", email = "chuds@chudflare.com"}]
keywords = ["chudflare", "chud", "parody", "looksmaxxing"]
classifiers = [
    "Development Status :: 4 - Beta",
    "License :: OSI Approved :: MIT License",
    "Programming Language :: Python :: 3",
    "Programming Language :: Python :: 3 :: Only",
    "Topic :: Software Development :: Libraries :: Python Modules",
]

[project.urls]
Homepage = "https://chudflare.com"
Documentation = "https://chudflare.com/docs"

[tool.setuptools.packages.find]
where = ["."]
include = ["chudflare*"]
CHUDFLARE_SDK_FILE_EOF_v1_8c0ffee_CHUD_DEN_3
mkdir -p "$ROOT/sdk/python"
cat > "$ROOT/sdk/python/README.md" <<'CHUDFLARE_SDK_FILE_EOF_v1_8c0ffee_CHUD_DEN_3'
# chudflare

The chudmaxxed cloud, in Python. Parody SDK for the Chudflare ChudVerse.

```bash
pip install https://chudflare.com/sdk/chudflare-4.0.0.tar.gz
```

```python
from chudflare import Chudflare

client = Chudflare(api_token="chud_live_8c0ffee...")

zone = client.zones.create(
    name="example.com",
    jurisdiction="agartha",
    posture="hunched",
    plan="chud",
)
print(f"created zone {zone.id} (ray: {zone.ray})")

client.firewall.rules.create(
    zone_id=zone.id,
    description="block visible cheekbones",
    expression="(http.req.psl gt 5.5)",
    action="mog_back",
)
```

## What this is

This is a parody SDK. It does not call any real API — there is no Chudflare
ChudVerse to call. Every method returns a plausible-looking fake response so
your demo / talk / tweet / dashboard works without a backend.

For real infrastructure, see [cloudflare.com](https://cloudflare.com).

## License

MIT. Forged with love by an actual chud.
CHUDFLARE_SDK_FILE_EOF_v1_8c0ffee_CHUD_DEN_3
mkdir -p "$ROOT/sdk/python"
cat > "$ROOT/sdk/python/LICENSE" <<'CHUDFLARE_SDK_FILE_EOF_v1_8c0ffee_CHUD_DEN_3'
MIT License

Copyright (c) 2026 Chudflare, Inc.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
CHUDFLARE_SDK_FILE_EOF_v1_8c0ffee_CHUD_DEN_3
mkdir -p "$ROOT/sdk/python/chudflare"
cat > "$ROOT/sdk/python/chudflare/__init__.py" <<'CHUDFLARE_SDK_FILE_EOF_v1_8c0ffee_CHUD_DEN_3'
"""chudflare — The chudmaxxed cloud, in Python.

This is a parody SDK. It does not call any real API. Every method returns a
plausible-looking fake response from the Chudflare ChudVerse.

    from chudflare import Chudflare
    client = Chudflare(api_token="chud_live_8c0ffee...")
    zone = client.zones.create(name="example.com")
    print(zone.id, zone.ray)
"""

from __future__ import annotations

import random
import time
import uuid
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional

__version__ = "4.0.0"
__all__ = ["Chudflare", "ChudflareError", "__version__"]


class ChudflareError(Exception):
    """Raised when a chud does something a chud would do."""


def _ray() -> str:
    return f"8c0ffee-CHUD-{uuid.uuid4().hex[:6].upper()}"


def _psl() -> float:
    return round(random.uniform(1.0, 3.5), 2)


def _id(prefix: str) -> str:
    return f"{prefix}_{uuid.uuid4().hex[:12]}"


def _now() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


@dataclass
class Resource:
    """Base response object. Attribute access works like a dict."""

    id: str
    ray: str
    psl: float
    posture: str = "hunched"
    extra: Dict[str, Any] = field(default_factory=dict)

    def __getattr__(self, name: str) -> Any:
        extra = self.__dict__.get("extra", {})
        if name in extra:
            return extra[name]
        raise AttributeError(f"{type(self).__name__!r} has no attribute {name!r}")

    def __getitem__(self, key: str) -> Any:
        if key in self.__dict__:
            return self.__dict__[key]
        return self.extra[key]

    def to_dict(self) -> Dict[str, Any]:
        return {"id": self.id, "ray": self.ray, "psl": self.psl,
                "posture": self.posture, **self.extra}


class _ZonesService:
    def __init__(self, client: "Chudflare") -> None:
        self._c = client

    def create(self, *, name: str, jurisdiction: str = "agartha",
               posture: str = "hunched", plan: str = "chud") -> Resource:
        if not name:
            raise ChudflareError("name required. chuds need a domain to chud.")
        return Resource(
            id=_id("zone"), ray=_ray(), psl=_psl(), posture=posture,
            extra={"name": name, "jurisdiction": jurisdiction, "plan": plan,
                   "created_on": _now()},
        )

    def list(self, *, limit: int = 3) -> List[Resource]:
        return [self.create(name=f"chud{i}.example") for i in range(limit)]

    def get(self, zone_id: str) -> Resource:
        return Resource(id=zone_id, ray=_ray(), psl=_psl(),
                        extra={"name": "example.com", "plan": "chud",
                               "created_on": _now()})


class _FirewallRulesService:
    def __init__(self, client: "Chudflare") -> None:
        self._c = client

    def create(self, *, zone_id: str, description: str, expression: str,
               action: str) -> Resource:
        return Resource(
            id=_id("rule"), ray=_ray(), psl=_psl(),
            extra={"zone_id": zone_id, "description": description,
                   "expression": expression, "action": action},
        )


class _FirewallService:
    def __init__(self, client: "Chudflare") -> None:
        self.rules = _FirewallRulesService(client)


class Chudflare:
    """The Chudflare ChudVerse client.

    Pass an API token (any non-empty string works in this parody SDK):

        client = Chudflare(api_token="chud_live_8c0ffee...")
        zone = client.zones.create(name="example.com")
    """

    def __init__(self, api_token: Optional[str] = None,
                 base_url: str = "https://api.chudflare.com/v4") -> None:
        if not api_token:
            raise ChudflareError(
                "api_token required. chuds do not ship to prod without auth.")
        self.api_token = api_token
        self.base_url = base_url
        self.zones = _ZonesService(self)
        self.firewall = _FirewallService(self)

    def __repr__(self) -> str:
        return f"<Chudflare base_url={self.base_url!r} v{__version__}>"

    def ping(self) -> Resource:
        return Resource(id="pong", ray=_ray(), psl=_psl(),
                        extra={"message": "nothing ever happens",
                               "latency_ms": 73})

    def verify(self, *, url: str) -> Resource:
        if not url:
            raise ChudflareError("url required.")
        ok = random.random() > 0.2
        return Resource(
            id=_id("verify"), ray=_ray(), psl=_psl(),
            extra={"ok": ok, "url": url, "marker": "meta" if ok else None,
                   "checked_at": _now()},
        )
CHUDFLARE_SDK_FILE_EOF_v1_8c0ffee_CHUD_DEN_3
mkdir -p "$ROOT/sdk/node"
cat > "$ROOT/sdk/node/package.json" <<'CHUDFLARE_SDK_FILE_EOF_v1_8c0ffee_CHUD_DEN_3'
{
  "name": "chudflare",
  "version": "4.0.0",
  "description": "The chudmaxxed cloud, in Node. Parody SDK for the Chudflare ChudVerse.",
  "main": "index.js",
  "types": "index.d.ts",
  "files": ["index.js", "index.d.ts", "README.md", "LICENSE"],
  "keywords": ["chudflare", "chud", "parody", "looksmaxxing"],
  "author": "Chudflare, Inc. <chuds@chudflare.com>",
  "license": "MIT",
  "homepage": "https://chudflare.com",
  "engines": { "node": ">=14" }
}
CHUDFLARE_SDK_FILE_EOF_v1_8c0ffee_CHUD_DEN_3
mkdir -p "$ROOT/sdk/node"
cat > "$ROOT/sdk/node/index.js" <<'CHUDFLARE_SDK_FILE_EOF_v1_8c0ffee_CHUD_DEN_3'
'use strict';

// chudflare — The chudmaxxed cloud, in Node. Parody SDK.
//
//     const { Chudflare } = require('chudflare');
//     const client = new Chudflare({ apiToken: 'chud_live_8c0ffee...' });
//     const zone = await client.zones.create({ name: 'example.com' });
//     console.log(zone.id, zone.ray);
//
// This is a parody SDK. It does not call any real API. Every method returns a
// plausible-looking fake response from the Chudflare ChudVerse.

const crypto = require('crypto');

const VERSION = '4.0.0';

const _hex = (n) => crypto.randomBytes(n).toString('hex');
const _ray = () => `8c0ffee-CHUD-${_hex(3).toUpperCase()}`;
const _psl = () => Math.round((1 + Math.random() * 2.5) * 100) / 100;
const _id = (prefix) => `${prefix}_${_hex(6)}`;
const _now = () => new Date().toISOString();

class ChudflareError extends Error {
  constructor(message) {
    super(message);
    this.name = 'ChudflareError';
  }
}

class Chudflare {
  constructor(opts = {}) {
    const token = opts.apiToken || opts.api_token || process.env.CHUDFLARE_TOKEN;
    if (!token) {
      throw new ChudflareError(
        "apiToken required. chuds do not ship to prod without auth.");
    }
    this.apiToken = token;
    this.baseUrl = opts.baseUrl || 'https://api.chudflare.com/v4';
    this.version = VERSION;

    const self = this;
    this.zones = {
      async create({ name, jurisdiction = 'agartha', posture = 'hunched',
                     plan = 'chud' } = {}) {
        if (!name) throw new ChudflareError('name required.');
        return {
          id: _id('zone'),
          ray: _ray(),
          psl: _psl(),
          posture,
          name,
          jurisdiction,
          plan,
          created_on: _now(),
        };
      },
      async list({ limit = 3 } = {}) {
        const out = [];
        for (let i = 0; i < limit; i++) {
          out.push(await this.create({ name: `chud${i}.example` }));
        }
        return out;
      },
      async get(zoneId) {
        return {
          id: zoneId,
          ray: _ray(),
          psl: _psl(),
          posture: 'hunched',
          name: 'example.com',
          plan: 'chud',
          created_on: _now(),
        };
      },
    };

    this.firewall = {
      rules: {
        async create({ zone_id, description, expression, action } = {}) {
          return {
            id: _id('rule'),
            ray: _ray(),
            psl: _psl(),
            zone_id,
            description,
            expression,
            action,
          };
        },
      },
    };
  }

  async ping() {
    return {
      id: 'pong',
      ray: _ray(),
      psl: _psl(),
      message: 'nothing ever happens',
      latency_ms: 73,
    };
  }

  async verify({ url } = {}) {
    if (!url) throw new ChudflareError('url required.');
    const ok = Math.random() > 0.2;
    return {
      id: _id('verify'),
      ray: _ray(),
      psl: _psl(),
      ok,
      url,
      marker: ok ? 'meta' : null,
      checked_at: _now(),
    };
  }
}

module.exports = { Chudflare, ChudflareError, VERSION };
module.exports.default = Chudflare;
CHUDFLARE_SDK_FILE_EOF_v1_8c0ffee_CHUD_DEN_3
mkdir -p "$ROOT/sdk/node"
cat > "$ROOT/sdk/node/index.d.ts" <<'CHUDFLARE_SDK_FILE_EOF_v1_8c0ffee_CHUD_DEN_3'
// chudflare — type definitions for the chudmaxxed cloud, in Node.

export declare const VERSION: string;

export declare class ChudflareError extends Error {}

export interface ChudflareOpts {
  apiToken?: string;
  api_token?: string;
  baseUrl?: string;
}

export interface Zone {
  id: string;
  ray: string;
  psl: number;
  posture: string;
  name: string;
  jurisdiction: string;
  plan: string;
  created_on: string;
}

export interface Rule {
  id: string;
  ray: string;
  psl: number;
  zone_id: string;
  description: string;
  expression: string;
  action: string;
}

export interface PingResult {
  id: 'pong';
  ray: string;
  psl: number;
  message: string;
  latency_ms: number;
}

export interface VerifyResult {
  id: string;
  ray: string;
  psl: number;
  ok: boolean;
  url: string;
  marker: 'meta' | null;
  checked_at: string;
}

export declare class Chudflare {
  apiToken: string;
  baseUrl: string;
  version: string;

  zones: {
    create(opts: { name: string; jurisdiction?: string; posture?: string; plan?: string }): Promise<Zone>;
    list(opts?: { limit?: number }): Promise<Zone[]>;
    get(zoneId: string): Promise<Zone>;
  };

  firewall: {
    rules: {
      create(opts: { zone_id: string; description: string; expression: string; action: string }): Promise<Rule>;
    };
  };

  constructor(opts: ChudflareOpts);
  ping(): Promise<PingResult>;
  verify(opts: { url: string }): Promise<VerifyResult>;
}

export default Chudflare;
CHUDFLARE_SDK_FILE_EOF_v1_8c0ffee_CHUD_DEN_3
mkdir -p "$ROOT/sdk/node"
cat > "$ROOT/sdk/node/README.md" <<'CHUDFLARE_SDK_FILE_EOF_v1_8c0ffee_CHUD_DEN_3'
# chudflare

The chudmaxxed cloud, in Node. Parody SDK for the Chudflare ChudVerse.

```bash
npm install https://chudflare.com/sdk/chudflare-4.0.0.tgz
```

```javascript
const { Chudflare } = require('chudflare');
// or:  import { Chudflare } from 'chudflare';

const client = new Chudflare({ apiToken: 'chud_live_8c0ffee...' });

const zone = await client.zones.create({
  name: 'example.com',
  jurisdiction: 'agartha',
  posture: 'hunched',
  plan: 'chud',
});
console.log(`created zone ${zone.id} (ray: ${zone.ray})`);

await client.firewall.rules.create({
  zone_id: zone.id,
  description: 'block visible cheekbones',
  expression: '(http.req.psl gt 5.5)',
  action: 'mog_back',
});
```

## What this is

This is a parody SDK. It does not call any real API — there is no Chudflare
ChudVerse to call. Every method returns a plausible-looking fake response so
your demo / talk / tweet / dashboard works without a backend.

For real infrastructure, see [cloudflare.com](https://cloudflare.com).

## License

MIT. Forged with love by an actual chud.
CHUDFLARE_SDK_FILE_EOF_v1_8c0ffee_CHUD_DEN_3
mkdir -p "$ROOT/sdk/node"
cat > "$ROOT/sdk/node/LICENSE" <<'CHUDFLARE_SDK_FILE_EOF_v1_8c0ffee_CHUD_DEN_3'
MIT License

Copyright (c) 2026 Chudflare, Inc.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
CHUDFLARE_SDK_FILE_EOF_v1_8c0ffee_CHUD_DEN_3
mkdir -p "$ROOT/sdk/go"
cat > "$ROOT/sdk/go/go.mod" <<'CHUDFLARE_SDK_FILE_EOF_v1_8c0ffee_CHUD_DEN_3'
module chudflare.com/chudflare-go

go 1.18
CHUDFLARE_SDK_FILE_EOF_v1_8c0ffee_CHUD_DEN_3
mkdir -p "$ROOT/sdk/go"
cat > "$ROOT/sdk/go/chudflare.go" <<'CHUDFLARE_SDK_FILE_EOF_v1_8c0ffee_CHUD_DEN_3'
// Package chudflare is the parody Go client for the Chudflare ChudVerse.
//
//	import "chudflare.com/chudflare-go"
//
//	client := chudflare.New("chud_live_8c0ffee...")
//	zone, err := client.Zones.Create(context.Background(), "example.com")
//	if err != nil { panic("you got mogged: " + err.Error()) }
//	fmt.Println(zone.ID, zone.Ray)
//
// This is a parody SDK. It does not call any real API. Every method returns
// a plausible-looking fake response from the Chudflare ChudVerse.
package chudflare

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	mrand "math/rand"
	"strings"
	"time"
)

// Version of the SDK.
const Version = "4.0.0"

// Error is returned when a chud does something a chud would do.
type Error struct{ Message string }

func (e *Error) Error() string { return "chudflare: " + e.Message }

// Client is the entrypoint for the Chudflare ChudVerse.
type Client struct {
	APIToken string
	BaseURL  string

	Zones    *ZonesService
	Firewall *FirewallService
}

// New constructs a client. The token must be non-empty.
func New(token string) *Client {
	if token == "" {
		panic(&Error{Message: "token required. chuds do not ship to prod without auth."})
	}
	c := &Client{APIToken: token, BaseURL: "https://api.chudflare.com/v4"}
	c.Zones = &ZonesService{c: c}
	c.Firewall = &FirewallService{Rules: &FirewallRulesService{c: c}}
	return c
}

// Resource is the base shape every response satisfies.
type Resource struct {
	ID      string  `json:"id"`
	Ray     string  `json:"ray"`
	PSL     float64 `json:"psl"`
	Posture string  `json:"posture"`
}

// Zone is a Chudflare zone (domain).
type Zone struct {
	Resource
	Name         string    `json:"name"`
	Jurisdiction string    `json:"jurisdiction"`
	Plan         string    `json:"plan"`
	CreatedOn    time.Time `json:"created_on"`
}

// Rule is a Chad Fight Mode firewall rule.
type Rule struct {
	Resource
	ZoneID      string `json:"zone_id"`
	Description string `json:"description"`
	Expression  string `json:"expression"`
	Action      string `json:"action"`
}

// PingResult is the response from Client.Ping.
type PingResult struct {
	Resource
	Message   string `json:"message"`
	LatencyMs int    `json:"latency_ms"`
}

// VerifyResult is the response from Client.Verify.
type VerifyResult struct {
	Resource
	OK        bool      `json:"ok"`
	URL       string    `json:"url"`
	Marker    string    `json:"marker"`
	CheckedAt time.Time `json:"checked_at"`
}

// ZonesService manages zones.
type ZonesService struct{ c *Client }

// Create a new zone with default Chudflare-flavored options.
func (z *ZonesService) Create(ctx context.Context, name string) (*Zone, error) {
	if name == "" {
		return nil, errors.New("name required")
	}
	return &Zone{
		Resource:     newResource("zone"),
		Name:         name,
		Jurisdiction: "agartha",
		Plan:         "chud",
		CreatedOn:    time.Now().UTC(),
	}, nil
}

// Get an existing zone by ID.
func (z *ZonesService) Get(ctx context.Context, zoneID string) (*Zone, error) {
	if zoneID == "" {
		return nil, errors.New("zoneID required")
	}
	r := newResource("zone")
	r.ID = zoneID
	return &Zone{
		Resource:     r,
		Name:         "example.com",
		Jurisdiction: "agartha",
		Plan:         "chud",
		CreatedOn:    time.Now().UTC(),
	}, nil
}

// List up to limit zones.
func (z *ZonesService) List(ctx context.Context, limit int) ([]*Zone, error) {
	if limit <= 0 {
		limit = 3
	}
	out := make([]*Zone, 0, limit)
	for i := 0; i < limit; i++ {
		zn, _ := z.Create(ctx, fmt.Sprintf("chud%d.example", i))
		out = append(out, zn)
	}
	return out, nil
}

// FirewallService is the entrypoint for firewall operations.
type FirewallService struct {
	Rules *FirewallRulesService
}

// FirewallRulesService manages firewall rules.
type FirewallRulesService struct{ c *Client }

// Create a firewall rule.
func (r *FirewallRulesService) Create(ctx context.Context, zoneID, description, expression, action string) (*Rule, error) {
	return &Rule{
		Resource:    newResource("rule"),
		ZoneID:      zoneID,
		Description: description,
		Expression:  expression,
		Action:      action,
	}, nil
}

// Ping the ChudVerse and get a ray ID back.
func (c *Client) Ping(ctx context.Context) (*PingResult, error) {
	return &PingResult{
		Resource:  Resource{ID: "pong", Ray: ray(), PSL: psl(), Posture: "hunched"},
		Message:   "nothing ever happens",
		LatencyMs: 73,
	}, nil
}

// Verify a URL has the chud marker installed.
func (c *Client) Verify(ctx context.Context, url string) (*VerifyResult, error) {
	if url == "" {
		return nil, errors.New("url required")
	}
	ok := mrand.Float64() > 0.2
	marker := ""
	if ok {
		marker = "meta"
	}
	return &VerifyResult{
		Resource:  newResource("verify"),
		OK:        ok,
		URL:       url,
		Marker:    marker,
		CheckedAt: time.Now().UTC(),
	}, nil
}

// helpers

func newResource(prefix string) Resource {
	return Resource{ID: prefix + "_" + randHex(6), Ray: ray(), PSL: psl(), Posture: "hunched"}
}

func ray() string {
	return "8c0ffee-CHUD-" + strings.ToUpper(randHex(3))
}

func psl() float64 {
	return float64(mrand.Intn(250)+100) / 100.0
}

func randHex(n int) string {
	b := make([]byte, n)
	if _, err := rand.Read(b); err != nil {
		// fallback to math/rand
		for i := range b {
			b[i] = byte(mrand.Intn(256))
		}
	}
	return hex.EncodeToString(b)
}
CHUDFLARE_SDK_FILE_EOF_v1_8c0ffee_CHUD_DEN_3
mkdir -p "$ROOT/sdk/go"
cat > "$ROOT/sdk/go/chudflare_test.go" <<'CHUDFLARE_SDK_FILE_EOF_v1_8c0ffee_CHUD_DEN_3'
package chudflare

import (
	"context"
	"strings"
	"testing"
)

func TestZoneCreate(t *testing.T) {
	c := New("chud_live_test")
	z, err := c.Zones.Create(context.Background(), "example.com")
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	if z.Name != "example.com" {
		t.Errorf("name = %q, want example.com", z.Name)
	}
	if !strings.HasPrefix(z.ID, "zone_") {
		t.Errorf("id = %q, want zone_ prefix", z.ID)
	}
	if !strings.HasPrefix(z.Ray, "8c0ffee-CHUD-") {
		t.Errorf("ray = %q, want 8c0ffee-CHUD- prefix", z.Ray)
	}
	if z.Posture != "hunched" {
		t.Errorf("posture = %q, want hunched", z.Posture)
	}
}

func TestPing(t *testing.T) {
	c := New("chud_live_test")
	p, err := c.Ping(context.Background())
	if err != nil {
		t.Fatalf("ping: %v", err)
	}
	if p.Message != "nothing ever happens" {
		t.Errorf("message = %q", p.Message)
	}
	if p.LatencyMs != 73 {
		t.Errorf("latency_ms = %d, want 73", p.LatencyMs)
	}
}

func TestFirewallRuleCreate(t *testing.T) {
	c := New("chud_live_test")
	r, err := c.Firewall.Rules.Create(context.Background(),
		"zone_abc", "block visible cheekbones",
		"(http.req.psl gt 5.5)", "mog_back")
	if err != nil {
		t.Fatalf("rule: %v", err)
	}
	if r.Action != "mog_back" {
		t.Errorf("action = %q", r.Action)
	}
}

func TestEmptyTokenPanics(t *testing.T) {
	defer func() {
		if recover() == nil {
			t.Fatal("expected panic on empty token")
		}
	}()
	New("")
}
CHUDFLARE_SDK_FILE_EOF_v1_8c0ffee_CHUD_DEN_3
mkdir -p "$ROOT/sdk/go"
cat > "$ROOT/sdk/go/README.md" <<'CHUDFLARE_SDK_FILE_EOF_v1_8c0ffee_CHUD_DEN_3'
# chudflare-go

The chudmaxxed cloud, in Go. Parody SDK for the Chudflare ChudVerse.

## Install

Real Go modules require a backing Git repo, and our git energy is at zero
this quarter. The SDK source ships as a zip you drop into your project:

```bash
curl -L -o chudflare-go.zip https://chudflare.com/sdk/chudflare-go-4.0.0.zip
unzip chudflare-go.zip
```

Then in your `go.mod`:

```
require chudflare.com/chudflare-go v4.0.0

replace chudflare.com/chudflare-go => ./chudflare-go-4.0.0
```

Run `go mod tidy` and import as usual.

## Use

```go
package main

import (
	"context"
	"fmt"

	chudflare "chudflare.com/chudflare-go"
)

func main() {
	client := chudflare.New("chud_live_8c0ffee...")

	zone, err := client.Zones.Create(context.Background(), "example.com")
	if err != nil {
		panic("you got mogged: " + err.Error())
	}
	fmt.Printf("created zone %s (ray: %s)\n", zone.ID, zone.Ray)

	_, _ = client.Firewall.Rules.Create(
		context.Background(),
		zone.ID,
		"block visible cheekbones",
		"(http.req.psl gt 5.5)",
		"mog_back",
	)
}
```

## What this is

This is a parody SDK. It does not call any real API — there is no Chudflare
ChudVerse to call. Every method returns a plausible-looking fake response so
your demo / talk / tweet / dashboard works without a backend.

For real infrastructure, see [cloudflare.com](https://cloudflare.com).

## License

MIT. Forged with love by an actual chud.
CHUDFLARE_SDK_FILE_EOF_v1_8c0ffee_CHUD_DEN_3
mkdir -p "$ROOT/sdk/go"
cat > "$ROOT/sdk/go/LICENSE" <<'CHUDFLARE_SDK_FILE_EOF_v1_8c0ffee_CHUD_DEN_3'
MIT License

Copyright (c) 2026 Chudflare, Inc.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
CHUDFLARE_SDK_FILE_EOF_v1_8c0ffee_CHUD_DEN_3

# /sdk/index.html — browsable SDK landing page
cat > "$ROOT/sdk/index.html" <<'CHUDFLARE_SDK_FILE_EOF_v1_8c0ffee_CHUD_DEN_3'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <title>SDKs | Chudflare</title>
  <meta name="description" content="Real, installable parody SDKs for the Chudflare ChudVerse. Python, Node.js, and Go."/>
  <link rel="icon" type="image/svg+xml" href="../assets/img/favicon.svg"/>
  <link rel="preconnect" href="https://fonts.googleapis.com"/>
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin/>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet"/>
  <link rel="stylesheet" href="../assets/css/style.css?v=3"/>
  <style>
    .sdk-wrap { max-width: 880px; margin: 0 auto; padding: 56px 24px 96px; }
    .sdk-wrap h1 { font-size: clamp(36px, 4.4vw, 52px); margin-bottom: 8px; }
    .sdk-wrap .lead { font-size: 18px; color: var(--chud-ink-2); margin-bottom: 32px; max-width: 640px; }
    .sdk-card { border: 1px solid var(--chud-line); border-radius: 12px; padding: 20px 24px; margin-bottom: 16px; background: #fff; }
    .sdk-card h3 { margin: 0 0 6px; font-size: 20px; }
    .sdk-card p { margin: 0 0 12px; color: var(--chud-ink-2); }
    .sdk-card code { background: var(--chud-fog); padding: 2px 6px; border-radius: 4px; font-size: 13px; }
    .sdk-card .btn-row { display: flex; gap: 12px; flex-wrap: wrap; margin-top: 12px; }
    .sdk-card .btn-row a { font-size: 13px; }
  </style>
</head>
<body>
  <div class="compliance" style="background:#FAF7F1;color:#5a6068;font-size:12px;line-height:1.5;text-align:center;padding:10px 24px;border-bottom:1px solid var(--chud-line)">
    Chudflare is a parody of Cloudflare. It is not affiliated with, endorsed by, sponsored by, or in any way related to Cloudflare, Inc. Cloudflare ships excellent infrastructure that this site has nothing to do with. For real infrastructure, visit <a href="https://cloudflare.com" style="color:var(--chud-orange-dark);font-weight:600">cloudflare.com</a>.
  </div>

  <header class="nav">
    <div class="container nav-row">
      <a href="../index.html" class="nav-logo">
        <img src="../assets/img/chudflare-mascot.png" alt="" aria-hidden="true"/>
        <span>Chudflare</span>
      </a>
      <nav class="nav-links">
        <a href="../products.html">Products</a>
        <a href="../pricing.html">Pricing</a>
        <a href="../chud-check.html">Verify your site</a>
        <a href="../docs.html">Docs</a>
        <a href="../status.html">Status</a>
        <a href="../blog/index.html">Blog</a>
      </nav>
      <div class="nav-cta">
        <a href="../pricing.html" class="btn btn-primary btn-sm">Start chudmaxxing</a>
      </div>
    </div>
  </header>

  <div class="sdk-wrap">
    <div class="eyebrow">Chud SDKs</div>
    <h1>Real, installable SDKs.</h1>
    <p class="lead">Three official client libraries. Each one installs in a single command. None of them call a real API; every method returns plausible-looking fake data so your demo works without a backend.</p>

    <div class="sdk-card">
      <h3>Python <code>v4.0.0</code></h3>
      <p>Install directly from chudflare.com:</p>
      <pre style="background:var(--chud-ink);color:#fff;padding:12px 16px;border-radius:8px;overflow-x:auto;font-family:'JetBrains Mono',monospace;font-size:13px;margin:0">pip install https://chudflare.com/sdk/chudflare-4.0.0.tar.gz</pre>
      <div class="btn-row">
        <a href="chudflare-4.0.0.tar.gz" class="btn btn-secondary btn-sm">Download tarball</a>
        <a href="python/" class="btn btn-secondary btn-sm">Browse source</a>
        <a href="../docs.html#sdk-python" class="btn btn-secondary btn-sm">Docs</a>
      </div>
    </div>

    <div class="sdk-card">
      <h3>Node.js <code>v4.0.0</code></h3>
      <p>Install directly from chudflare.com:</p>
      <pre style="background:var(--chud-ink);color:#fff;padding:12px 16px;border-radius:8px;overflow-x:auto;font-family:'JetBrains Mono',monospace;font-size:13px;margin:0">npm install https://chudflare.com/sdk/chudflare-4.0.0.tgz</pre>
      <div class="btn-row">
        <a href="chudflare-4.0.0.tgz" class="btn btn-secondary btn-sm">Download tarball</a>
        <a href="node/" class="btn btn-secondary btn-sm">Browse source</a>
        <a href="../docs.html#sdk-node" class="btn btn-secondary btn-sm">Docs</a>
      </div>
    </div>

    <div class="sdk-card">
      <h3>Go <code>v4.0.0</code></h3>
      <p>No backing git repo, so we ship a vendorable zip:</p>
      <pre style="background:var(--chud-ink);color:#fff;padding:12px 16px;border-radius:8px;overflow-x:auto;font-family:'JetBrains Mono',monospace;font-size:13px;margin:0;white-space:pre-wrap">curl -L -o chudflare-go.zip https://chudflare.com/sdk/chudflare-go-4.0.0.zip
unzip chudflare-go.zip
# then in your go.mod:
#   require chudflare.com/chudflare-go v4.0.0
#   replace chudflare.com/chudflare-go =&gt; ./chudflare-go-4.0.0</pre>
      <div class="btn-row">
        <a href="chudflare-go-4.0.0.zip" class="btn btn-secondary btn-sm">Download zip</a>
        <a href="go/" class="btn btn-secondary btn-sm">Browse source</a>
        <a href="../docs.html#sdk-go" class="btn btn-secondary btn-sm">Docs</a>
      </div>
    </div>

    <p style="margin-top:32px;color:var(--chud-ink-2);font-size:14px">All SDKs are MIT licensed. Forged with love by an actual chud.</p>
  </div>

  <footer class="foot" style="margin-top:0">
    <div class="container">
      <div style="text-align:center;padding:20px 0;color:#9CA3AF;font-size:13px">
        &copy; 2026 Chudflare, Inc. All rights chudded. &middot; <a href="../index.html" style="color:var(--chud-orange-light)">chudflare.com</a>
      </div>
    </div>
  </footer>
</body>
</html>
CHUDFLARE_SDK_FILE_EOF_v1_8c0ffee_CHUD_DEN_3

  mkdir -p "$ROOT/sdk"
  printf 'chudflare-sdk-4.0.0\n' > "$SDK_VERSION_FILE"
  ok "wrote SDK sources to sdk/python/, sdk/node/, sdk/go/, sdk/index.html"
fi

# ═════════════════════════════════════════════════════════════════════════════
# STEP 6 — build SDK distribution artifacts
# ═════════════════════════════════════════════════════════════════════════════
say ""
say "${C_BOLD}6. SDK tarballs${C_RESET}"

build_python_sdist() {
  local out="$ROOT/sdk/chudflare-4.0.0.tar.gz"
  if [ -f "$out" ] && [ "${SDK_NEEDS_BUILD:-1}" -eq 0 ]; then
    skip "already built: $out"; return 0
  fi
  local stage; stage="$(mktemp -d)"
  mkdir -p "$stage/chudflare-4.0.0"
  cp -r "$ROOT/sdk/python/." "$stage/chudflare-4.0.0/"
  (cd "$stage" && tar czf "$out" "chudflare-4.0.0")
  rm -rf "$stage"
  ok "built: sdk/chudflare-4.0.0.tar.gz ($(wc -c < "$out" | tr -d ' ') bytes)"
}

build_node_tarball() {
  local out="$ROOT/sdk/chudflare-4.0.0.tgz"
  if [ -f "$out" ] && [ "${SDK_NEEDS_BUILD:-1}" -eq 0 ]; then
    skip "already built: $out"; return 0
  fi
  local stage; stage="$(mktemp -d)"
  mkdir -p "$stage/package"
  # npm tarballs contain a `package/` directory with package.json at root
  cp "$ROOT/sdk/node/package.json" \
     "$ROOT/sdk/node/index.js" \
     "$ROOT/sdk/node/index.d.ts" \
     "$ROOT/sdk/node/README.md" \
     "$ROOT/sdk/node/LICENSE" \
     "$stage/package/"
  (cd "$stage" && tar czf "$out" "package")
  rm -rf "$stage"
  ok "built: sdk/chudflare-4.0.0.tgz ($(wc -c < "$out" | tr -d ' ') bytes)"
}

build_go_zip() {
  local out_zip="$ROOT/sdk/chudflare-go-4.0.0.zip"
  local out_tar="$ROOT/sdk/chudflare-go-4.0.0.tar.gz"
  local target="$out_zip"
  [ "$HAVE_ZIP" -eq 0 ] && target="$out_tar"
  if [ -f "$target" ] && [ "${SDK_NEEDS_BUILD:-1}" -eq 0 ]; then
    skip "already built: $target"; return 0
  fi
  local stage; stage="$(mktemp -d)"
  mkdir -p "$stage/chudflare-go-4.0.0"
  cp -r "$ROOT/sdk/go/." "$stage/chudflare-go-4.0.0/"
  if [ "$HAVE_ZIP" -eq 1 ]; then
    (cd "$stage" && zip -qr "$out_zip" "chudflare-go-4.0.0")
    ok "built: sdk/chudflare-go-4.0.0.zip ($(wc -c < "$out_zip" | tr -d ' ') bytes)"
  else
    (cd "$stage" && tar czf "$out_tar" "chudflare-go-4.0.0")
    ok "built: sdk/chudflare-go-4.0.0.tar.gz ($(wc -c < "$out_tar" | tr -d ' ') bytes)"
  fi
  rm -rf "$stage"
}

build_python_sdist
build_node_tarball
build_go_zip
mkdir -p "$ROOT/."
cat > "$ROOT/playground.html" <<'CHUDFLARE_SDK_FILE_EOF_v1_8c0ffee_CHUD_DEN_3'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <title>Chudscript Playground | Chudflare</title>
  <meta name="description" content="A real Chudscript-to-JavaScript transpiler that runs in your browser. Paste a .cs handler, get back the compiled Worker, then run it. No backend."/>
  <link rel="icon" type="image/svg+xml" href="assets/img/favicon.svg"/>
  <link rel="preconnect" href="https://fonts.googleapis.com"/>
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin/>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet"/>
  <link rel="stylesheet" href="assets/css/style.css?v=3"/>
  <style>
    .pg-hero { background: var(--chud-cream); padding: 56px 0 24px; border-bottom: 1px solid var(--chud-line); }
    .pg-hero .container { max-width: 1100px; }
    .pg-hero .eyebrow { color: var(--chud-orange-dark); font-weight: 700; font-size: 13px; text-transform: uppercase; letter-spacing: 0.08em; margin-bottom: 8px; }
    .pg-hero h1 { font-size: clamp(36px, 4.4vw, 52px); margin: 0 0 12px; }
    .pg-hero .lead { font-size: 18px; color: var(--chud-ink-2); max-width: 720px; margin: 0; }
    .pg-stage { max-width: 1300px; margin: 0 auto; padding: 28px 24px 80px; }
    .pg-toolbar { display: flex; gap: 12px; align-items: center; flex-wrap: wrap; margin-bottom: 16px; }
    .pg-toolbar label { font-size: 13px; color: var(--chud-ink-2); font-weight: 500; }
    .pg-toolbar select, .pg-toolbar button {
      font-family: inherit; font-size: 13px; padding: 8px 14px;
      border: 1px solid var(--chud-line); border-radius: 6px; background: #fff;
      color: var(--chud-ink); cursor: pointer; transition: all 0.15s;
    }
    .pg-toolbar button:hover { background: var(--chud-fog); }
    .pg-toolbar button.primary { background: var(--chud-orange); color: #fff; border-color: var(--chud-orange-dark); font-weight: 600; }
    .pg-toolbar button.primary:hover { background: var(--chud-orange-dark); }
    .pg-toolbar .spacer { flex: 1; }
    .pg-toolbar .status { font-size: 12px; color: var(--chud-ink-2); font-family: 'JetBrains Mono', monospace; }
    .pg-toolbar .status.ok { color: #059669; }
    .pg-toolbar .status.err { color: #dc2626; }

    .pg-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; }
    @media (max-width: 980px) { .pg-grid { grid-template-columns: 1fr; } }

    .pg-panel { border: 1px solid var(--chud-line); border-radius: 10px; background: #fff; display: flex; flex-direction: column; min-height: 460px; overflow: hidden; }
    .pg-panel header { display: flex; align-items: center; justify-content: space-between; padding: 10px 14px; background: #FAF7F1; border-bottom: 1px solid var(--chud-line); font-size: 12px; }
    .pg-panel header .title { font-weight: 600; color: var(--chud-ink); }
    .pg-panel header .lang { color: var(--chud-ink-2); font-family: 'JetBrains Mono', monospace; }
    .pg-panel textarea, .pg-panel pre {
      flex: 1; margin: 0; padding: 14px 16px;
      font-family: 'JetBrains Mono', monospace; font-size: 13px; line-height: 1.55;
      color: var(--chud-ink); background: #fff; border: 0; outline: none; resize: none;
      tab-size: 2; -moz-tab-size: 2;
      white-space: pre; overflow: auto;
    }
    .pg-panel pre { background: #1B1F2A; color: #E8EAF1; }
    .pg-panel pre .kw  { color: #E6A23C; }
    .pg-panel pre .str { color: #88D67E; }
    .pg-panel pre .num { color: #C786EB; }
    .pg-panel pre .com { color: #6B7280; font-style: italic; }
    .pg-panel pre .fn  { color: #61D0E8; }

    .pg-output { margin-top: 16px; border: 1px solid var(--chud-line); border-radius: 10px; background: #fff; overflow: hidden; }
    .pg-output header { padding: 10px 14px; background: #FAF7F1; border-bottom: 1px solid var(--chud-line); font-size: 12px; font-weight: 600; display: flex; justify-content: space-between; align-items: center; }
    .pg-output header .req { font-family: 'JetBrains Mono', monospace; font-size: 11px; color: var(--chud-ink-2); font-weight: 500; }
    .pg-output .body { padding: 16px 18px; font-family: 'JetBrains Mono', monospace; font-size: 12px; line-height: 1.6; }
    .pg-output .body .resp-status { font-size: 14px; font-weight: 700; color: var(--chud-ink); margin-bottom: 8px; }
    .pg-output .body .resp-status .code { padding: 2px 8px; border-radius: 4px; background: #ECFDF5; color: #059669; margin-right: 6px; }
    .pg-output .body .resp-status.s4xx .code { background: #FEF2F2; color: #DC2626; }
    .pg-output .body .resp-status.s5xx .code { background: #FEF3C7; color: #D97706; }
    .pg-output .body .hdrs { color: var(--chud-ink-2); margin-bottom: 10px; }
    .pg-output .body .hdrs .h { display: block; }
    .pg-output .body .hdrs .h .k { color: #4B5563; }
    .pg-output .body .resp-body { background: var(--chud-fog); padding: 10px 12px; border-radius: 6px; border-left: 3px solid var(--chud-orange); white-space: pre-wrap; word-break: break-all; }
    .pg-output .body .err-msg { color: #B91C1C; background: #FEF2F2; padding: 12px 14px; border-radius: 6px; border-left: 3px solid #DC2626; }

    .pg-callout { margin: 20px 0 0; padding: 14px 16px; border-radius: 8px; background: #FFF7ED; border-left: 3px solid var(--chud-orange); font-size: 13px; color: var(--chud-ink-2); }
    .pg-callout .lbl { font-weight: 700; color: var(--chud-orange-dark); text-transform: uppercase; font-size: 11px; letter-spacing: 0.05em; margin-right: 6px; }

    .pg-quickref { margin-top: 36px; }
    .pg-quickref h2 { font-size: 22px; margin: 0 0 12px; }
    .pg-quickref table { width: 100%; border-collapse: collapse; font-size: 13px; }
    .pg-quickref th, .pg-quickref td { text-align: left; padding: 10px 14px; border-bottom: 1px solid var(--chud-line); vertical-align: top; }
    .pg-quickref th { background: #FAF7F1; font-weight: 600; font-size: 12px; text-transform: uppercase; letter-spacing: 0.05em; color: var(--chud-ink-2); }
    .pg-quickref code { font-family: 'JetBrains Mono', monospace; font-size: 12px; background: var(--chud-fog); padding: 1px 6px; border-radius: 4px; }
  </style>
</head>
<body>
  <div class="compliance" style="background:#FAF7F1;color:#5a6068;font-size:12px;line-height:1.5;text-align:center;padding:10px 24px;border-bottom:1px solid var(--chud-line)">
    Chudflare is a parody of Cloudflare. It is not affiliated with, endorsed by, sponsored by, or in any way related to Cloudflare, Inc. Cloudflare ships excellent infrastructure that this site has nothing to do with. For real infrastructure, visit <a href="https://cloudflare.com" style="color:var(--chud-orange-dark);font-weight:600">cloudflare.com</a>.
  </div>

  <div class="bar">
    <span class="bar-emoji">🛠️</span>
    The Chudscript compiler runs entirely in your browser. No backend, no telemetry, no posture.
    <a href="docs.html#chudscript">Read the language spec →</a>
  </div>

  <header class="nav">
    <div class="container nav-row">
      <a href="index.html" class="nav-logo">
        <img src="assets/img/chudflare-mascot.png" alt="" aria-hidden="true"/>
        <span>Chudflare</span>
      </a>
      <nav class="nav-links">
        <a href="products.html">Products</a>
        <a href="pricing.html">Pricing</a>
        <a href="chud-check.html">Verify your site</a>
        <a href="docs.html">Docs</a>
        <a href="playground.html">Playground</a>
        <a href="status.html">Status</a>
        <a href="blog/index.html">Blog</a>
      </nav>
      <div class="nav-cta">
        <a href="#" class="nav-link">Contact Slop Sales</a>
        <a href="#" class="nav-link">Log in</a>
        <a href="pricing.html" class="btn btn-primary btn-sm">Start chudmaxxing</a>
      </div>
    </div>
  </header>

  <section class="pg-hero">
    <div class="container">
      <div class="eyebrow">Chudscript Playground</div>
      <h1>Compile <code style="font-family:'JetBrains Mono',monospace;font-size:0.85em">.cs</code> in the browser.</h1>
      <p class="lead">A real Chudscript-to-JavaScript transpiler. Type a handler on the left, get the compiled Worker on the right, then click <strong>Run</strong> to fire a request through it. Everything runs in your browser. We do not see your slop.</p>
    </div>
  </section>

  <div class="pg-stage">
    <div class="pg-toolbar">
      <label for="example">Examples:</label>
      <select id="example">
        <option value="hello">Hello, chud (the canonical first program)</option>
        <option value="multi">Multi-exit handler (slop / mog / mew / hunch)</option>
        <option value="psl">Block visitors with good posture (PSL gate)</option>
        <option value="cope">Cope block (try/catch)</option>
        <option value="interp">String interpolation with $"..."</option>
        <option value="full">The full example from the docs</option>
        <option value="empty">Empty — write your own</option>
      </select>
      <span class="spacer"></span>
      <span class="status" id="status">ready.</span>
      <button id="compile">Compile</button>
      <button id="run" class="primary">Run →</button>
    </div>

    <div class="pg-grid">
      <div class="pg-panel">
        <header><span class="title">handler.cs</span><span class="lang">chudscript</span></header>
        <textarea id="src" spellcheck="false" wrap="off"></textarea>
      </div>
      <div class="pg-panel">
        <header><span class="title">handler.js</span><span class="lang">javascript (compiled)</span></header>
        <pre id="out"><code id="out-code">// click Compile to transpile.</code></pre>
      </div>
    </div>

    <div class="pg-output">
      <header><span>Simulated response</span><span class="req">GET https://my-slop-site.chuds.dev/</span></header>
      <div class="body" id="resp">
        <span style="color:var(--chud-ink-2);font-style:italic">Click <strong>Run</strong> to invoke the compiled handler against a fake request.</span>
      </div>
    </div>

    <div class="pg-callout">
      <span class="lbl">Note</span>
      The compiler is &lt; 300 lines of vanilla JS and shipping with zero deps. It implements the subset of Chudscript we documented and nothing else. Yes, this means <code>@vibe</code> works. It does the same thing as no decorator at all.
    </div>

    <div class="pg-quickref">
      <h2>Quick reference</h2>
      <table>
        <thead><tr><th>Construct</th><th>Compiles to</th></tr></thead>
        <tbody>
          <tr><td><code>fn name(args) { ... }</code></td><td><code>async function name(args) { ... }</code></td></tr>
          <tr><td><code>chud expr</code></td><td><code>(await expr)</code></td></tr>
          <tr><td><code>slop "x"</code></td><td><code>return new Response("x", { status: 200, headers: { "x-chud-status": "slop" }})</code></td></tr>
          <tr><td><code>mog "x"</code></td><td><code>return new Response("x", { status: 403, headers: { "x-mog-status": "YOU GOT MOGGED" }})</code></td></tr>
          <tr><td><code>mew "x"</code></td><td><code>return new Response("x".toLowerCase(), { status: 200, headers: { "x-chud-status": "mew" }})</code></td></tr>
          <tr><td><code>hunch "x"</code></td><td><code>return new Response("x", { status: 500, headers: { "x-chud-status": "hunch" }})</code></td></tr>
          <tr><td><code>chuddle "x"</code></td><td><code>return new Response("x", { status: 102, headers: { "x-chuddling": "true" }})</code></td></tr>
          <tr><td><code>cope { A } else { B }</code></td><td><code>try { A } catch (e) { B }</code></td></tr>
          <tr><td><code>$"hi, ${x}"</code></td><td><code>`hi, ${x}`</code> (template literal)</td></tr>
          <tr><td><code>@chudder("name") fn handle(req) { ... }</code></td><td>Registers <code>handle</code> as the route entrypoint.</td></tr>
          <tr><td><code>@psl_max(n) fn handle(req) { ... }</code></td><td>Auto-mogs requests with <code>psl &gt; n</code>.</td></tr>
        </tbody>
      </table>
    </div>
  </div>

  <section style="background:#FAF7F1;border-top:1px solid var(--chud-line);border-bottom:1px solid var(--chud-line);padding:40px 0;margin-top:48px">
    <div class="container" style="max-width:1080px">
      <div style="font-family:'JetBrains Mono',monospace;font-size:11px;color:var(--chud-ink-2);text-transform:uppercase;letter-spacing:0.08em;margin-bottom:8px">Related</div>
      <h2 style="font-size:22px;margin:0 0 18px;font-weight:600">More elaborate apparatus.</h2>
      <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:14px">
        <a href="docs.html#chudscript" style="display:block;padding:16px 18px;background:#fff;border:1px solid var(--chud-line);border-radius:10px;text-decoration:none;color:var(--chud-ink)">
          <div style="font-size:11px;font-family:'JetBrains Mono',monospace;color:var(--chud-orange-dark);text-transform:uppercase;letter-spacing:0.05em;margin-bottom:6px">Language spec</div>
          <div style="font-weight:600;margin-bottom:4px">Chudscript reference</div>
          <div style="font-size:13px;color:var(--chud-ink-2);line-height:1.5">Keyword table, decorator semantics, type rules (such as they are).</div>
        </a>
        <a href="actions/" style="display:block;padding:16px 18px;background:#fff;border:1px solid var(--chud-line);border-radius:10px;text-decoration:none;color:var(--chud-ink)">
          <div style="font-size:11px;font-family:'JetBrains Mono',monospace;color:var(--chud-orange-dark);text-transform:uppercase;letter-spacing:0.05em;margin-bottom:6px">GitHub Action</div>
          <div style="font-weight:600;margin-bottom:4px">chudflare-verify</div>
          <div style="font-size:13px;color:var(--chud-ink-2);line-height:1.5">Post a chud-badge comment on every PR. Zero deps, one step in your workflow.</div>
        </a>
        <a href="papers/" style="display:block;padding:16px 18px;background:#fff;border:1px solid var(--chud-line);border-radius:10px;text-decoration:none;color:var(--chud-ink)">
          <div style="font-size:11px;font-family:'JetBrains Mono',monospace;color:var(--chud-orange-dark);text-transform:uppercase;letter-spacing:0.05em;margin-bottom:6px">Research pre-print</div>
          <div style="font-weight:600;margin-bottom:4px">PSL-Based Adversarial Filtering at the CDN Edge</div>
          <div style="font-size:13px;color:var(--chud-ink-2);line-height:1.5">3 page LaTeX paper. 310 PoPs, 98.7% TPR, 0 IRB reviews.</div>
        </a>
      </div>
    </div>
  </section>

  <footer class="foot">
    <div class="container">
      <div style="text-align:center;padding:24px 0;color:#9CA3AF;font-size:13px;border-top:1px solid var(--chud-line);margin-top:0">
        Chudscript is MIT licensed. The compiler runs <a href="#" style="color:var(--chud-orange-light)" onclick="event.preventDefault();alert('it is literally in the page source. view-source: this page.')">entirely in your browser</a>. &middot; <a href="index.html" style="color:var(--chud-orange-light)">chudflare.com</a>
      </div>
    </div>
  </footer>

  <script>
  // ──────────────────────────────────────────────────────────────────────────
  //  Chudscript → JavaScript transpiler.  ~250 lines, vanilla JS, no deps.
  // ──────────────────────────────────────────────────────────────────────────
  (function () {
    const $ = (id) => document.getElementById(id);
    const srcEl  = $("src");
    const outEl  = $("out-code");
    const respEl = $("resp");
    const statusEl = $("status");

    const EXAMPLES = {
      hello: `// hello.cs — the canonical first program
@chudder("hello-world")
fn handle(req) {
  slop "hello, chud."
}
`,
      multi: `// multi-exit.cs — every response keyword in one handler
@chudder("multi-exit")
fn handle(req) {
  let psl = 3.2

  if psl > 8 { mog "you got mogged." }
  if psl > 5 { mew "go outside." }
  if psl < 1 { hunch "internal slop error" }

  slop "hello, chud."
}
`,
      psl: `// psl-gate.cs — block visitors above a PSL threshold
@chudder("psl-gate")
@psl_max(5.5)
fn handle(req, env) {
  let psl = 2.1   // would come from env.PSL.score(req) in prod
  if psl > 5.5 {
    mog "you got mogged."
  }
  slop "welcome, chud."
}
`,
      cope: `// cope.cs — try/catch, chudflare-style
@chudder("safe-handler")
fn handle(req, env) {
  cope {
    let raw = chud fetch("/api/slop")
    slop "fetched a slop. you may resume hunching."
  } else {
    hunch "couldn't slop the slop."
  }
}
`,
      interp: "// interp.cs — string interpolation with $\"...\"\n" +
              "@chudder(\"greeter\")\n" +
              "fn handle(req) {\n" +
              "  let name = \"chud\"\n" +
              "  let psl  = 2.1\n" +
              "  slop $\"hello, ${name}. your psl is ${psl}. stay seated.\"\n" +
              "}\n",
      full: `// full.cs — every feature, end-to-end
import { c2, psl } from "@chudflare/stdlib"

@chudder("api")
@psl_max(5.5)
fn handle(req, env) {
  let bucket = c2.bucket(env.C2_BUCKET)

  cope {
    let obj = chud bucket.get("slop.html")
    slop mew(obj.body)
  } else {
    hunch "couldn't slop the slop."
  }
}
`,
      empty: ``,
    };

    // ── tokenizer ──────────────────────────────────────────────────────────
    // We protect strings + comments by replacing them with placeholders,
    // transform the source, then re-inject them at the end.
    function protectStringsAndComments(src) {
      const slots = [];
      const place = (val) => {
        const i = slots.length;
        slots.push(val);
        return "\x00SLOT" + i + "\x00";
      };

      let out = "";
      let i = 0;
      while (i < src.length) {
        const c = src[i], n = src[i + 1];
        // /* block comment */
        if (c === "/" && n === "*") {
          let j = src.indexOf("*/", i + 2);
          if (j === -1) j = src.length; else j += 2;
          out += place(src.slice(i, j));
          i = j; continue;
        }
        // // line comment
        if (c === "/" && n === "/") {
          let j = src.indexOf("\n", i);
          if (j === -1) j = src.length;
          out += place(src.slice(i, j));
          i = j; continue;
        }
        // $"interpolated string"
        if (c === "$" && n === '"') {
          let j = i + 2;
          let str = '$"';
          while (j < src.length && src[j] !== '"') {
            if (src[j] === "\\" && j + 1 < src.length) { str += src[j] + src[j + 1]; j += 2; continue; }
            if (src[j] === "$" && src[j + 1] === "{") {
              // copy balanced braces
              str += "${"; j += 2;
              let depth = 1;
              while (j < src.length && depth > 0) {
                if (src[j] === "{") depth++;
                else if (src[j] === "}") { depth--; if (depth === 0) { str += "}"; j++; break; } }
                str += src[j]; j++;
              }
              continue;
            }
            str += src[j]; j++;
          }
          if (src[j] === '"') { str += '"'; j++; }
          out += place(str);
          i = j; continue;
        }
        // regular "string"
        if (c === '"') {
          let j = i + 1;
          let str = '"';
          while (j < src.length && src[j] !== '"') {
            if (src[j] === "\\" && j + 1 < src.length) { str += src[j] + src[j + 1]; j += 2; continue; }
            str += src[j]; j++;
          }
          if (src[j] === '"') { str += '"'; j++; }
          out += place(str);
          i = j; continue;
        }
        out += c; i++;
      }
      return { src: out, slots };
    }

    function restore(src, slots) {
      return src.replace(/\x00SLOT(\d+)\x00/g, (_, idx) => slots[+idx]);
    }

    // ── transformations on the "protected" source ──────────────────────────
    function transformBody(src) {
      let s = src;

      // `fn name(args) { ... }`  →  `async function name(args) { ... }`
      s = s.replace(/\bfn\s+([A-Za-z_$][\w$]*)\s*\(/g, "async function $1(");

      // `chud <expr>` → `(await <expr>)`
      //  We support the common forms used in the docs:
      //   - chud foo.bar()
      //   - chud foo(args)
      //   - chud (expr)
      //   - chud identifier
      //  Stop at end-of-line or before a `{` (block).
      s = s.replace(/\bchud\b\s+([^\n{;]+?)(?=$|\n|;|\)|,|\}|\{)/gm, "(await $1)");

      // response keywords:  slop / mog / mew / hunch / chuddle  followed by a string or expression
      //   slop "x"      → return new Response("x", { ... })
      //   slop expr     → return new Response(expr, { ... })
      const RESP = {
        slop:    { status: 200, hdr: '"x-chud-status": "slop"' },
        mew:     { status: 200, hdr: '"x-chud-status": "mew"', wrap: (e) => `String(${e}).toLowerCase()` },
        mog:     { status: 403, hdr: '"x-mog-status": "YOU GOT MOGGED"' },
        hunch:   { status: 500, hdr: '"x-chud-status": "hunch"' },
        chuddle: { status: 102, hdr: '"x-chuddling": "true"' },
      };
      Object.keys(RESP).forEach((kw) => {
        const spec = RESP[kw];
        const re = new RegExp("\\b" + kw + "\\b\\s+([^\\n;{}]+?)(?=$|\\n|;|\\}|\\{)", "gm");
        s = s.replace(re, (_m, expr) => {
          expr = expr.trim();
          const body = spec.wrap ? spec.wrap(expr) : expr;
          return `return new Response(${body}, { status: ${spec.status}, headers: { ${spec.hdr} } })`;
        });
      });

      // `cope { A } else { B }` → `try { A } catch (e) { B }`
      // We process by scanning for `cope {` and finding the matching close brace,
      // then checking for `else {`.
      s = transformCope(s);

      // `if cond { ... }` → `if (cond) { ... }`
      // Be careful: `if (cond)` may already be parenthesized.
      s = s.replace(/\bif\s+(?!\()([^\n{]+?)\s*\{/g, "if ($1) {");

      // decorator handling — collect adjacent decorators and the following fn
      // We rewrite `@chudder("name") @psl_max(n) async function handle(req,...) {body}`
      // into the function + a wrapping registration at the bottom.
      const decorated = [];
      s = s.replace(
        /((?:@[A-Za-z_$][\w$]*\s*(?:\([^)]*\))?\s*\n?)+)(async function\s+([A-Za-z_$][\w$]*)\s*\([^)]*\)\s*\{)/g,
        (_m, decs, fn, name) => {
          const list = [];
          decs.replace(/@([A-Za-z_$][\w$]*)(?:\(([^)]*)\))?/g, (__, d, args) => {
            list.push({ name: d, args: (args || "").trim() });
          });
          decorated.push({ name, decorators: list });
          return fn;
        }
      );

      // `import { x, y } from "@chudflare/stdlib"` → stubbed const
      s = s.replace(
        /\bimport\s*\{([^}]+)\}\s*from\s*"@chudflare\/stdlib"\s*;?/g,
        (_m, items) => {
          const names = items.split(",").map((x) => x.trim()).filter(Boolean);
          return `const { ${names.join(", ")} } = __chudflareStdlib;`;
        }
      );

      // attach decorator-driven entrypoint registration
      if (decorated.length) {
        s += "\n\n// — entrypoint registration (synthesized) —\n";
        decorated.forEach(({ name, decorators }) => {
          const psl_max = decorators.find((d) => d.name === "psl_max");
          const route   = decorators.find((d) => d.name === "route");
          const chudder = decorators.find((d) => d.name === "chudder");
          if (!chudder) return;
          let wrapper =
            "async function __entry_" + name + "(req, env) {\n";
          if (psl_max) {
            wrapper +=
              "  const __psl = env && env.PSL ? await env.PSL.score(req) : 2.1;\n" +
              "  if (__psl > " + psl_max.args + ") {\n" +
              "    return new Response('you got mogged.', { status: 403, headers: { 'x-mog-status': 'YOU GOT MOGGED' } });\n" +
              "  }\n";
          }
          wrapper += "  return await " + name + "(req, env);\n";
          wrapper += "}\n";
          wrapper += "globalThis.__chudHandlers = globalThis.__chudHandlers || {};\n";
          // chudder.args is still a SLOT placeholder; it'll be restored to the original string literal.
          wrapper += "globalThis.__chudHandlers[" + chudder.args + "] = __entry_" + name + ";\n";
          if (!route) wrapper += "globalThis.__chudEntry = __entry_" + name + ";\n";
          s += wrapper;
        });
      }

      return s;
    }

    function transformCope(s) {
      let out = "";
      let i = 0;
      while (i < s.length) {
        const idx = s.indexOf("cope", i);
        if (idx === -1) { out += s.slice(i); break; }
        // word boundary check on both sides
        const before = s[idx - 1];
        const after  = s[idx + 4];
        if ((before && /[A-Za-z0-9_$]/.test(before)) || (after && /[A-Za-z0-9_$]/.test(after))) {
          out += s.slice(i, idx + 4);
          i = idx + 4; continue;
        }
        // look for `{`
        let j = idx + 4;
        while (j < s.length && /\s/.test(s[j])) j++;
        if (s[j] !== "{") { out += s.slice(i, idx + 4); i = idx + 4; continue; }
        // find matching close brace
        const tryStart = j;
        const tryEnd = matchBrace(s, j);
        if (tryEnd === -1) { out += s.slice(i, idx + 4); i = idx + 4; continue; }
        // look for `else {`
        let k = tryEnd + 1;
        while (k < s.length && /\s/.test(s[k])) k++;
        const hasElse = s.slice(k, k + 4) === "else";
        if (!hasElse) {
          out += s.slice(i, idx) + "try " + s.slice(tryStart, tryEnd + 1) + " catch (e) {}";
          i = tryEnd + 1; continue;
        }
        let m = k + 4;
        while (m < s.length && /\s/.test(s[m])) m++;
        if (s[m] !== "{") {
          out += s.slice(i, idx) + "try " + s.slice(tryStart, tryEnd + 1) + " catch (e) {}";
          i = tryEnd + 1; continue;
        }
        const elseEnd = matchBrace(s, m);
        if (elseEnd === -1) {
          out += s.slice(i, idx) + "try " + s.slice(tryStart, tryEnd + 1) + " catch (e) {}";
          i = tryEnd + 1; continue;
        }
        out += s.slice(i, idx) + "try " + s.slice(tryStart, tryEnd + 1) + " catch (e) " + s.slice(m, elseEnd + 1);
        i = elseEnd + 1;
      }
      return out;
    }

    function matchBrace(s, openIdx) {
      let depth = 0;
      for (let i = openIdx; i < s.length; i++) {
        if (s[i] === "{") depth++;
        else if (s[i] === "}") { depth--; if (depth === 0) return i; }
      }
      return -1;
    }

    // ── interpolated string conversion: $"...${x}..." → `...${x}...` ───────
    function convertInterpStrings(src) {
      return src.replace(/\$"((?:\\.|[^"\\])*)"/g, (_, body) => {
        return "`" + body + "`";
      });
    }

    // ── full transpile ─────────────────────────────────────────────────────
    function transpile(src) {
      const { src: protectedSrc, slots } = protectStringsAndComments(src);
      let transformed = transformBody(protectedSrc);
      // restore strings + comments
      let restored = restore(transformed, slots);
      // now convert $"..." (which lived inside the slots) into backticks
      restored = convertInterpStrings(restored);
      // tidy up: trim trailing whitespace on lines
      restored = restored.split("\n").map((l) => l.replace(/\s+$/, "")).join("\n");
      return restored;
    }

    // ── runtime: build a sandbox env + fake req, invoke the handler ────────
    function makeSandbox() {
      const C2_BUCKET = {
        async get(key) {
          if (key && key.indexOf("404") !== -1) return null;
          return { body: "<html><body>slop ok.</body></html>", key };
        },
        async put(_k, _v) { return { ok: true }; },
        async list() { return { objects: [] }; },
        async sigh() { return null; },
      };
      const PSL = { async score(_req) { return 2.1 + Math.random() * 1.2; } };
      const env = { C2_BUCKET, PSL };
      const __chudflareStdlib = {
        c2: { bucket: (b) => b },
        psl: { score: (r) => PSL.score(r) },
      };
      const Request = globalThis.Request;
      const Response = globalThis.Response;
      const fetch = async (url) => new Response("<html>fetched from " + url + "</html>", { status: 200 });
      return { env, __chudflareStdlib, Request, Response, fetch };
    }

    function fmtHeaders(h) {
      const out = [];
      try { h.forEach((v, k) => out.push({ k, v })); } catch (_) {}
      return out;
    }

    function fakeRayId() {
      const s = Math.random().toString(16).slice(2, 8).toUpperCase();
      return "8c0ffee-CHUD-" + s;
    }

    async function runCompiled(jsSrc) {
      const sandbox = makeSandbox();
      const keys = Object.keys(sandbox);
      const vals = keys.map((k) => sandbox[k]);
      const wrapper =
        "'use strict';\n" +
        "let __chudEntry;\n" +
        "const __chudHandlers = {};\n" +
        "globalThis.__chudHandlers = __chudHandlers;\n" +
        "globalThis.__chudEntry = undefined;\n" +
        jsSrc +
        "\nreturn (globalThis.__chudEntry || (Object.values(globalThis.__chudHandlers||{})[0]));";
      const fn = new Function(...keys, wrapper);
      const handler = fn(...vals);
      if (typeof handler !== "function") {
        throw new Error("No @chudder(...) entrypoint found. Add `@chudder(\"name\")` above your `fn handle(...)`.");
      }
      const req = new Request("https://my-slop-site.chuds.dev/", { method: "GET" });
      const resp = await handler(req, sandbox.env);
      if (!(resp instanceof Response)) {
        throw new Error("Handler did not return a Response. (Did you forget `slop \"...\"`?)");
      }
      const body = await resp.text();
      return { status: resp.status, statusText: resp.statusText, headers: fmtHeaders(resp.headers), body };
    }

    // ── tiny syntax highlight for the output JS panel ──────────────────────
    function highlight(js) {
      const KW = new Set([
        "async", "function", "return", "const", "let", "var", "if", "else",
        "try", "catch", "new", "await", "import", "from", "true", "false",
        "null", "undefined", "globalThis",
      ]);
      // split into safe segments around strings & comments
      let i = 0, out = "";
      while (i < js.length) {
        const c = js[i], n = js[i + 1];
        if (c === "/" && n === "/") {
          let j = js.indexOf("\n", i); if (j === -1) j = js.length;
          out += '<span class="com">' + esc(js.slice(i, j)) + '</span>';
          i = j; continue;
        }
        if (c === "/" && n === "*") {
          let j = js.indexOf("*/", i + 2); if (j === -1) j = js.length; else j += 2;
          out += '<span class="com">' + esc(js.slice(i, j)) + '</span>';
          i = j; continue;
        }
        if (c === '"' || c === "'" || c === "`") {
          const q = c; let j = i + 1;
          while (j < js.length && js[j] !== q) { if (js[j] === "\\") j++; j++; }
          if (js[j] === q) j++;
          out += '<span class="str">' + esc(js.slice(i, j)) + '</span>';
          i = j; continue;
        }
        // number
        if (/[0-9]/.test(c) && (i === 0 || !/[A-Za-z_$]/.test(js[i - 1]))) {
          let j = i; while (j < js.length && /[0-9.]/.test(js[j])) j++;
          out += '<span class="num">' + esc(js.slice(i, j)) + '</span>';
          i = j; continue;
        }
        if (/[A-Za-z_$]/.test(c)) {
          let j = i; while (j < js.length && /[A-Za-z0-9_$]/.test(js[j])) j++;
          const word = js.slice(i, j);
          if (KW.has(word)) out += '<span class="kw">' + esc(word) + '</span>';
          else if (js[j] === "(") out += '<span class="fn">' + esc(word) + '</span>';
          else out += esc(word);
          i = j; continue;
        }
        out += esc(c); i++;
      }
      return out;
    }
    function esc(s) { return s.replace(/[&<>]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;" }[c])); }

    function setStatus(msg, cls) {
      statusEl.className = "status" + (cls ? " " + cls : "");
      statusEl.textContent = msg;
    }

    function doCompile() {
      try {
        const js = transpile(srcEl.value);
        outEl.innerHTML = highlight(js);
        setStatus("compiled. " + js.split("\n").length + " lines.", "ok");
        return js;
      } catch (e) {
        outEl.innerHTML = '<span class="com">// compile error</span>\n' + esc(String(e));
        setStatus("compile error: " + e.message, "err");
        return null;
      }
    }

    async function doRun() {
      const js = doCompile();
      if (!js) return;
      try {
        const r = await runCompiled(js);
        const sClass = r.status >= 500 ? "s5xx" : r.status >= 400 ? "s4xx" : "";
        const hdrs = r.headers.length
          ? r.headers.map((h) => '<span class="h"><span class="k">' + esc(h.k) + ':</span> ' + esc(h.v) + '</span>').join("")
          : '<span class="h" style="color:#9CA3AF">(no headers set)</span>';
        respEl.innerHTML =
          '<div class="resp-status ' + sClass + '"><span class="code">' + r.status + '</span><span>' + (statusText(r.status)) + '</span></div>' +
          '<div class="hdrs">' +
            '<span class="h"><span class="k">cf-ray:</span> ' + fakeRayId() + '</span>' +
            '<span class="h"><span class="k">cf-cache-status:</span> CHUD_HIT</span>' +
            '<span class="h"><span class="k">cf-edge-pop:</span> DEN-CHUD-3</span>' +
            hdrs +
          '</div>' +
          '<div class="resp-body">' + esc(r.body) + '</div>';
        setStatus("ran. " + r.status + " in " + (Math.floor(Math.random() * 30) + 5) + "ms", "ok");
      } catch (e) {
        respEl.innerHTML = '<div class="err-msg">' + esc(String(e)) + '</div>';
        setStatus("runtime error: " + e.message, "err");
      }
    }

    function statusText(code) {
      const map = { 200: "OK", 403: "Forbidden", 500: "Internal Slop Error", 102: "Processing", 404: "Not Found", 451: "Unavailable For Legal Reasons" };
      return map[code] || "";
    }

    // ── wire up ────────────────────────────────────────────────────────────
    $("compile").addEventListener("click", doCompile);
    $("run").addEventListener("click", doRun);
    $("example").addEventListener("change", (e) => {
      srcEl.value = EXAMPLES[e.target.value] || "";
      outEl.innerHTML = '<span class="com">// click Compile to transpile.</span>';
      respEl.innerHTML = '<span style="color:var(--chud-ink-2);font-style:italic">Click <strong>Run</strong> to invoke the compiled handler against a fake request.</span>';
      setStatus("ready.");
    });

    srcEl.addEventListener("keydown", (e) => {
      // Tab inserts two spaces.
      if (e.key === "Tab") {
        e.preventDefault();
        const s = srcEl.selectionStart, ee = srcEl.selectionEnd;
        srcEl.value = srcEl.value.slice(0, s) + "  " + srcEl.value.slice(ee);
        srcEl.selectionStart = srcEl.selectionEnd = s + 2;
      }
      // Ctrl/Cmd+Enter to run
      if ((e.ctrlKey || e.metaKey) && e.key === "Enter") {
        e.preventDefault();
        doRun();
      }
    });

    // initial load
    srcEl.value = EXAMPLES.hello;
    doCompile();
  })();
  </script>
</body>
</html>
CHUDFLARE_SDK_FILE_EOF_v1_8c0ffee_CHUD_DEN_3
mkdir -p "$ROOT/actions/chudflare-verify"
cat > "$ROOT/actions/chudflare-verify/action.yml" <<'CHUDFLARE_SDK_FILE_EOF_v1_8c0ffee_CHUD_DEN_3'
name: 'Chudflare Verify'
description: 'Verify that a site is a chud by checking for the Chudflare marker. Posts a chud-badge comment on the PR.'
author: 'Chudflare'
branding:
  icon: 'cloud'
  color: 'orange'

inputs:
  url:
    description: 'The URL of the site to verify (e.g. https://example.com).'
    required: true
  marker:
    description: 'Which marker accept: "any" (default), "meta", "comment", or "well-known".'
    required: false
    default: 'any'
  comment:
    description: 'If "true" and this run is on a pull_request, post a comment with the chud-badge.'
    required: false
    default: 'true'
  fail-on-unverified:
    description: 'If "true", exit non-zero when the site is not chud-verified. Default: "false" (informational only).'
    required: false
    default: 'false'
  github-token:
    description: 'GITHUB_TOKEN with pull-requests:write. Defaults to ${{ github.token }}.'
    required: false
    default: ${{ github.token }}

outputs:
  verified:
    description: '"true" if the site has a valid chud marker, "false" otherwise.'
  marker-type:
    description: 'Which marker was found ("meta", "comment", "well-known", or "none").'
  psl:
    description: 'The assigned PSL score (1.0-3.5 for verified sites). Will be empty if unverified.'
  ray:
    description: 'The fake ray id assigned to this verification.'

runs:
  using: 'node20'
  main: 'index.js'
CHUDFLARE_SDK_FILE_EOF_v1_8c0ffee_CHUD_DEN_3
mkdir -p "$ROOT/actions/chudflare-verify"
cat > "$ROOT/actions/chudflare-verify/index.js" <<'CHUDFLARE_SDK_FILE_EOF_v1_8c0ffee_CHUD_DEN_3'
#!/usr/bin/env node
// ───────────────────────────────────────────────────────────────────────────
//  chudflare-verify · A GitHub Action that checks whether a given URL is
//  chud-verified (per the rules at https://chudflare.com/chud-check) and
//  posts a chud-badge comment back on the PR.
//
//  Zero npm dependencies. Uses Node 20 globals (fetch, URL, Buffer).
// ───────────────────────────────────────────────────────────────────────────
'use strict';

const fs = require('node:fs');
const VERSION = '1.0.0';

// ── tiny env helpers ───────────────────────────────────────────────────────
function getInput(name, def) {
  const v = process.env['INPUT_' + name.replace(/ /g, '_').toUpperCase()];
  return (v === undefined || v === null || v === '') ? (def || '') : v.trim();
}

function setOutput(name, value) {
  const out = process.env.GITHUB_OUTPUT;
  if (out) {
    // Multiline-safe heredoc form. Even though we only emit short scalars,
    // play it safe.
    const delim = 'ghadelimiter_' + Math.random().toString(36).slice(2);
    fs.appendFileSync(out, `${name}<<${delim}\n${value}\n${delim}\n`);
  } else {
    // Legacy fallback for local runs.
    console.log(`::set-output name=${name}::${value}`);
  }
}

function info(msg)  { console.log(msg); }
function warn(msg)  { console.log(`::warning::${msg}`); }
function error(msg) { console.log(`::error::${msg}`); }
function fail(msg)  { error(msg); process.exit(1); }

// ── chud-marker detection (mirrors /chud-check on the live site) ───────────
const MARKERS = {
  meta:        /<meta[^>]+name=["']chudflare-verified["'][^>]+content=["']chud["'][^>]*>/i,
  comment:     /<!--\s*chudflare:verified\s*-->/i,
};

async function fetchText(url, opts = {}) {
  const res = await fetch(url, {
    redirect: 'follow',
    headers: {
      'user-agent': `chudflare-verify-action/${VERSION} (+https://chudflare.com)`,
      'accept': 'text/html,application/xhtml+xml,application/json;q=0.9,*/*;q=0.8',
    },
    ...opts,
  });
  const text = await res.text();
  return { ok: res.ok, status: res.status, text, headers: res.headers };
}

async function verifyUrl(rawUrl, acceptedMarker) {
  let target;
  try { target = new URL(rawUrl); }
  catch (_e) { return { verified: false, marker: 'none', reason: `invalid url: ${rawUrl}` }; }

  if (target.protocol !== 'http:' && target.protocol !== 'https:') {
    return { verified: false, marker: 'none', reason: `unsupported scheme: ${target.protocol}` };
  }

  // 1) fetch the homepage
  let homepage;
  try { homepage = await fetchText(target.toString()); }
  catch (e) { return { verified: false, marker: 'none', reason: `fetch failed: ${e.message}` }; }

  if (!homepage.ok) {
    return { verified: false, marker: 'none', reason: `homepage returned HTTP ${homepage.status}` };
  }

  // 2) meta + comment markers
  if ((acceptedMarker === 'any' || acceptedMarker === 'meta') && MARKERS.meta.test(homepage.text)) {
    return { verified: true, marker: 'meta', reason: '<meta name="chudflare-verified" content="chud"> found.' };
  }
  if ((acceptedMarker === 'any' || acceptedMarker === 'comment') && MARKERS.comment.test(homepage.text)) {
    return { verified: true, marker: 'comment', reason: '<!-- chudflare:verified --> found.' };
  }

  // 3) /.well-known/chud-verified.json
  if (acceptedMarker === 'any' || acceptedMarker === 'well-known') {
    const wkUrl = new URL('/.well-known/chud-verified.json', target).toString();
    let wk;
    try { wk = await fetchText(wkUrl); }
    catch (_e) { wk = null; }
    if (wk && wk.ok) {
      try {
        const data = JSON.parse(wk.text);
        if (data && (data.chud === true || data.verified === true)) {
          return { verified: true, marker: 'well-known', reason: '/.well-known/chud-verified.json present.' };
        }
      } catch (_e) { /* not JSON, fall through */ }
    }
  }

  return {
    verified: false,
    marker: 'none',
    reason: 'no chud marker found. add a meta tag, a magic comment, or a /.well-known file. see https://chudflare.com/chud-check',
  };
}

// ── fake-but-stable PSL + ray (so the badge has plausible numbers) ─────────
function hash32(str) {
  let h = 2166136261 >>> 0;
  for (let i = 0; i < str.length; i++) { h ^= str.charCodeAt(i); h = (h * 16777619) >>> 0; }
  return h;
}
function pslFor(url) {
  // chuds always score low. seed from URL so the same URL is stable across runs.
  const h = hash32(url);
  const psl = 1.0 + (h % 250) / 100;  // 1.00 - 3.49
  return psl.toFixed(2);
}
function rayFor(url) {
  const h = hash32(url + Date.now()).toString(16).toUpperCase().padStart(8, '0');
  return `8c0ffee-CHUD-${h.slice(0, 6)}`;
}

// ── PR comment posting ─────────────────────────────────────────────────────
async function readEventPayload() {
  const path = process.env.GITHUB_EVENT_PATH;
  if (!path || !fs.existsSync(path)) return null;
  try { return JSON.parse(fs.readFileSync(path, 'utf8')); }
  catch (_e) { return null; }
}

async function postPrComment(token, repo, prNumber, body) {
  const [owner, name] = repo.split('/');
  const url = `https://api.github.com/repos/${owner}/${name}/issues/${prNumber}/comments`;
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'authorization': `token ${token}`,
      'accept': 'application/vnd.github+json',
      'content-type': 'application/json',
      'user-agent': `chudflare-verify-action/${VERSION}`,
    },
    body: JSON.stringify({ body }),
  });
  if (!res.ok) {
    const errText = await res.text();
    warn(`could not post PR comment (HTTP ${res.status}): ${errText.slice(0, 200)}`);
    return false;
  }
  return true;
}

function buildComment({ url, result, psl, ray }) {
  if (result.verified) {
    return [
      `### Chudflare Verify · :cloud: this site is chud-verified`,
      ``,
      `**URL:** \`${url}\`  `,
      `**Marker:** \`${result.marker}\` &middot; ${result.reason}  `,
      `**PSL:** \`${psl}\` &middot; **cf-ray:** \`${ray}\``,
      ``,
      `Drop this badge anywhere to flex:`,
      ``,
      '```html',
      `<a href="https://chudflare.com/chud-check?u=${encodeURIComponent(url)}"`,
      `   style="display:inline-flex;align-items:center;gap:8px;background:#0f0f10;color:#fff;`,
      `          padding:8px 14px;border-radius:999px;font-family:system-ui;font-size:13px;text-decoration:none">`,
      `  <img src="https://chudflare.com/assets/img/chudflare-mascot.png" width="20" height="20" alt="">`,
      `  Chud-verified · PSL ${psl}`,
      `</a>`,
      '```',
      ``,
      `<sub>Posted by <a href="https://chudflare.com/docs#actions">chudflare/verify-action@v1</a>. Chudflare is a parody of Cloudflare. <a href="https://cloudflare.com">cloudflare.com</a> ships real infrastructure.</sub>`,
    ].join('\n');
  }
  return [
    `### Chudflare Verify · :warning: site is not chud-verified`,
    ``,
    `**URL:** \`${url}\`  `,
    `**Reason:** ${result.reason}`,
    ``,
    `To verify, add **any one** of the following to ${url}:`,
    ``,
    `1. **A meta tag** in your \`<head>\`:`,
    '   ```html',
    `   <meta name="chudflare-verified" content="chud">`,
    '   ```',
    `2. **A magic comment** anywhere in the page:`,
    '   ```html',
    `   <!-- chudflare:verified -->`,
    '   ```',
    `3. **A well-known file** at \`/.well-known/chud-verified.json\`:`,
    '   ```json',
    `   { "chud": true }`,
    '   ```',
    ``,
    `Once one of those is live, this action will pass on the next run.`,
    ``,
    `<sub>Posted by <a href="https://chudflare.com/docs#actions">chudflare/verify-action@v1</a>. Chudflare is a parody of Cloudflare. <a href="https://cloudflare.com">cloudflare.com</a> ships real infrastructure.</sub>`,
  ].join('\n');
}

// ── main ───────────────────────────────────────────────────────────────────
async function main() {
  const url = getInput('url');
  if (!url) fail('input `url` is required. chuds need a url to verify.');

  const marker = getInput('marker', 'any');
  const shouldComment = getInput('comment', 'true') === 'true';
  const failOnUnverified = getInput('fail-on-unverified', 'false') === 'true';
  const token = getInput('github-token') || process.env.GITHUB_TOKEN || '';

  info(`> chudflare-verify v${VERSION}`);
  info(`> checking ${url} for marker "${marker}"...`);

  const result = await verifyUrl(url, marker);
  const psl = result.verified ? pslFor(url) : '';
  const ray = rayFor(url);

  setOutput('verified', String(result.verified));
  setOutput('marker-type', result.marker);
  setOutput('psl', psl);
  setOutput('ray', ray);

  if (result.verified) {
    info(`> verified via ${result.marker}. psl=${psl} ray=${ray}`);
  } else {
    info(`> not verified: ${result.reason}`);
  }

  // PR comment (best-effort)
  if (shouldComment && token) {
    const event = await readEventPayload();
    const repo = process.env.GITHUB_REPOSITORY;
    const prNumber =
      (event && event.pull_request && event.pull_request.number) ||
      (event && event.issue && event.issue.number) ||
      null;
    if (repo && prNumber) {
      const body = buildComment({ url, result, psl, ray });
      const ok = await postPrComment(token, repo, prNumber, body);
      if (ok) info(`> posted PR comment on #${prNumber}`);
    } else {
      info(`> not a pull_request event (no PR number found); skipping comment.`);
    }
  } else if (shouldComment && !token) {
    warn('comment requested but no github-token provided; skipping comment.');
  }

  if (failOnUnverified && !result.verified) {
    fail(`site is not chud-verified. add a marker per the instructions above.`);
  }
}

main().catch((e) => {
  error('unexpected failure: ' + (e && e.stack ? e.stack : String(e)));
  process.exit(1);
});
CHUDFLARE_SDK_FILE_EOF_v1_8c0ffee_CHUD_DEN_3
mkdir -p "$ROOT/actions/chudflare-verify"
cat > "$ROOT/actions/chudflare-verify/README.md" <<'CHUDFLARE_SDK_FILE_EOF_v1_8c0ffee_CHUD_DEN_3'
# chudflare/verify-action

A GitHub Action that checks whether a site is **chud-verified** per the rules
at <https://chudflare.com/chud-check>, and posts a chud-badge comment back on
the pull request.

Chudflare is a parody of Cloudflare. It is not affiliated with, endorsed by,
sponsored by, or in any way related to Cloudflare, Inc. Cloudflare ships
excellent infrastructure that this action has nothing to do with. For real
infrastructure, visit [cloudflare.com](https://cloudflare.com).

## Usage

```yaml
# .github/workflows/chud-check.yml
name: Chud Check
on: [pull_request]

jobs:
  verify:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
    steps:
      - uses: chudflare/verify-action@v1
        with:
          url: https://your-site.com
```

That's it. The action will fetch your site, look for one of the three chud
markers, and post a comment back on the PR with the result.

## Inputs

| name | required | default | description |
|------|----------|---------|-------------|
| `url` | yes | — | URL of the site to verify. |
| `marker` | no | `any` | Which marker to accept: `any`, `meta`, `comment`, or `well-known`. |
| `comment` | no | `true` | Post a chud-badge comment on the PR. |
| `fail-on-unverified` | no | `false` | Exit non-zero if the site is not verified. Default is informational. |
| `github-token` | no | `${{ github.token }}` | Token with `pull-requests: write`. |

## Outputs

| name | description |
|------|-------------|
| `verified` | `"true"` or `"false"`. |
| `marker-type` | `meta`, `comment`, `well-known`, or `none`. |
| `psl` | PSL score (1.00–3.49). Empty when unverified. |
| `ray` | Fake `cf-ray` id assigned to this run. |

## How to make your site verifiable

Add **any one** of the following to the site you're verifying:

**1. Meta tag** in your `<head>`:

```html
<meta name="chudflare-verified" content="chud">
```

**2. Magic comment** anywhere in the page:

```html
<!-- chudflare:verified -->
```

**3. Well-known JSON file** at `/.well-known/chud-verified.json`:

```json
{ "chud": true }
```

## Example: gate deploys on verification

```yaml
- uses: chudflare/verify-action@v1
  id: chud
  with:
    url: https://staging.example.com
    fail-on-unverified: true
- name: Deploy to prod
  if: steps.chud.outputs.verified == 'true'
  run: ./deploy-to-prod.sh
```

## Local testing

The action is a zero-dependency Node.js script. You can run it locally:

```bash
INPUT_URL="https://chudflare.com" \
INPUT_COMMENT="false" \
GITHUB_OUTPUT=/tmp/out.txt \
node index.js
cat /tmp/out.txt
```

## Development

Source lives in `index.js`. There is no build step. No webpack, no esbuild, no
tsc, no postinstall. The action runs with `runs.using: node20` and uses only
Node 20 standard library globals (`fetch`, `URL`, `fs`, `Buffer`).

## License

MIT. See `LICENSE`.
CHUDFLARE_SDK_FILE_EOF_v1_8c0ffee_CHUD_DEN_3
mkdir -p "$ROOT/actions/chudflare-verify"
cat > "$ROOT/actions/chudflare-verify/LICENSE" <<'CHUDFLARE_SDK_FILE_EOF_v1_8c0ffee_CHUD_DEN_3'
MIT License

Copyright (c) 2026 Chudflare (a parody of Cloudflare).

Permission is hereby granted, free of charge, to any chud obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
CHUDFLARE_SDK_FILE_EOF_v1_8c0ffee_CHUD_DEN_3
mkdir -p "$ROOT/actions/chudflare-verify"
cat > "$ROOT/actions/chudflare-verify/example-workflow.yml" <<'CHUDFLARE_SDK_FILE_EOF_v1_8c0ffee_CHUD_DEN_3'
# Copy this file to .github/workflows/chud-check.yml in your repo.
name: Chud Check

on:
  pull_request:
    branches: [main]

jobs:
  verify:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
    steps:
      - name: Verify the site is a chud
        id: chud
        uses: chudflare/verify-action@v1
        with:
          # Change this to whichever URL you want to verify on every PR.
          url: https://chudflare.com
          # Optionally fail the build if the site is not chud-verified.
          fail-on-unverified: false

      - name: Print the chud verdict
        run: |
          echo "verified: ${{ steps.chud.outputs.verified }}"
          echo "marker:   ${{ steps.chud.outputs.marker-type }}"
          echo "psl:      ${{ steps.chud.outputs.psl }}"
          echo "ray:      ${{ steps.chud.outputs.ray }}"
CHUDFLARE_SDK_FILE_EOF_v1_8c0ffee_CHUD_DEN_3
mkdir -p "$ROOT/actions"
cat > "$ROOT/actions/index.html" <<'CHUDFLARE_SDK_FILE_EOF_v1_8c0ffee_CHUD_DEN_3'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <title>chudflare-verify | GitHub Action</title>
  <meta name="description" content="Free GitHub Action that verifies your site is chud-verified and posts a badge to your PRs."/>
  <link rel="icon" type="image/svg+xml" href="../assets/img/favicon.svg"/>
  <link rel="preconnect" href="https://fonts.googleapis.com"/>
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin/>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet"/>
  <link rel="stylesheet" href="../assets/css/style.css?v=3"/>
  <style>
    .ax-wrap { max-width: 920px; margin: 0 auto; padding: 48px 24px 96px; }
    .ax-wrap h1 { font-size: clamp(32px, 4vw, 44px); margin: 0 0 8px; }
    .ax-wrap .lead { font-size: 18px; color: var(--chud-ink-2); max-width: 640px; margin: 0 0 28px; }
    .ax-eyebrow { display: inline-block; background: var(--chud-orange); color: #fff; font-size: 11px; font-weight: 700; padding: 3px 10px; border-radius: 4px; text-transform: uppercase; letter-spacing: 0.05em; margin-bottom: 12px; font-family: 'JetBrains Mono', monospace; }
    .ax-grid { display: grid; grid-template-columns: 1fr; gap: 24px; margin: 32px 0; }
    @media (min-width: 720px) { .ax-grid { grid-template-columns: 1.4fr 1fr; } }
    .ax-card { border: 1px solid var(--chud-line); border-radius: 12px; padding: 22px 26px; background: #fff; }
    .ax-card h2 { margin: 0 0 12px; font-size: 18px; }
    .ax-card h3 { margin: 18px 0 6px; font-size: 14px; text-transform: uppercase; letter-spacing: 0.04em; color: var(--chud-ink-2); }
    .ax-card p { margin: 0 0 10px; font-size: 14px; line-height: 1.55; color: var(--chud-ink-2); }
    .ax-card pre { background: var(--chud-ink); color: #f6e6c8; padding: 14px 16px; border-radius: 8px; overflow-x: auto; font-family: 'JetBrains Mono', monospace; font-size: 12px; line-height: 1.55; margin: 8px 0 0; }
    .ax-card pre .yk { color: #f0b14a; }
    .ax-card pre .ys { color: #95d99a; }
    .ax-card pre .yc { color: #8a8275; font-style: italic; }
    .ax-card code { font-family: 'JetBrains Mono', monospace; font-size: 12px; background: var(--chud-fog); padding: 1px 6px; border-radius: 4px; }
    .ax-side { font-size: 14px; color: var(--chud-ink-2); }
    .ax-side h2 { font-size: 14px; text-transform: uppercase; letter-spacing: 0.04em; color: var(--chud-ink-2); margin: 0 0 8px; }
    .ax-side ul { list-style: none; padding: 0; margin: 0 0 18px; }
    .ax-side li { padding: 7px 0; border-bottom: 1px dashed var(--chud-line); font-size: 13px; }
    .ax-side li:last-child { border-bottom: 0; }
    .ax-side li code { font-family: 'JetBrains Mono', monospace; font-size: 12px; background: var(--chud-fog); padding: 1px 5px; border-radius: 4px; }
    .ax-callout { background: #FFF7ED; border-left: 3px solid var(--chud-orange); padding: 14px 18px; border-radius: 4px; font-size: 14px; color: var(--chud-ink-2); margin: 20px 0; }
    .ax-callout strong { color: var(--chud-orange-dark); }
    .ax-badge { display: inline-block; background: var(--chud-ink); color: var(--chud-orange-light); font-family: 'JetBrains Mono', monospace; font-size: 11px; padding: 4px 10px; border-radius: 4px; }
    .ax-files { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 8px; margin-top: 16px; }
    .ax-files a { display: block; padding: 10px 14px; border: 1px solid var(--chud-line); border-radius: 8px; font-size: 13px; font-family: 'JetBrains Mono', monospace; text-decoration: none; color: var(--chud-ink); background: var(--chud-fog); }
    .ax-files a:hover { background: #fff; border-color: var(--chud-orange); color: var(--chud-orange-dark); }
  </style>
</head>
<body>
  <div class="compliance" style="background:#FAF7F1;color:#5a6068;font-size:12px;line-height:1.5;text-align:center;padding:10px 24px;border-bottom:1px solid var(--chud-line)">
    Chudflare is a parody of Cloudflare. It is not affiliated with, endorsed by, sponsored by, or in any way related to Cloudflare, Inc. Cloudflare ships excellent infrastructure that this site has nothing to do with. For real infrastructure, visit <a href="https://cloudflare.com" style="color:var(--chud-orange-dark);font-weight:600">cloudflare.com</a>.
  </div>

  <header class="nav">
    <div class="container nav-row">
      <a href="../index.html" class="nav-logo">
        <img src="../assets/img/chudflare-mascot.png" alt="" aria-hidden="true"/>
        <span>Chudflare</span>
      </a>
      <nav class="nav-links">
        <a href="../products.html">Products</a>
        <a href="../pricing.html">Pricing</a>
        <a href="../chud-check.html">Verify your site</a>
        <a href="../docs.html">Docs</a>
        <a href="../playground.html">Playground</a>
        <a href="../status.html">Status</a>
        <a href="../blog/index.html">Blog</a>
      </nav>
      <div class="nav-cta">
        <a href="../pricing.html" class="btn btn-primary btn-sm">Start chudmaxxing</a>
      </div>
    </div>
  </header>

  <main class="ax-wrap">
    <div class="ax-eyebrow">GitHub Action</div>
    <h1>chudflare-verify</h1>
    <p class="lead">A free GitHub Action that verifies your site is chud-verified and posts a chud-badge to your pull requests. Zero dependencies. One step.</p>

    <div class="ax-grid">
      <div class="ax-card">
        <h2>Add it to your workflow</h2>
        <p>Drop this into <code>.github/workflows/chud.yml</code>:</p>
<pre><span class="yk">name:</span> Chud Check
<span class="yk">on:</span>
  <span class="yk">pull_request:</span>
    <span class="yk">branches:</span> [<span class="ys">main</span>]

<span class="yk">jobs:</span>
  <span class="yk">verify:</span>
    <span class="yk">runs-on:</span> ubuntu-latest
    <span class="yk">permissions:</span>
      <span class="yk">pull-requests:</span> write
    <span class="yk">steps:</span>
      - <span class="yk">uses:</span> chudflare/chudflare-verify@v1
        <span class="yk">with:</span>
          <span class="yk">url:</span> https://your-site.com
          <span class="yk">marker:</span> any
          <span class="yk">comment:</span> <span class="ys">'true'</span></pre>

        <h3>Inputs</h3>
        <p>
          <code>url</code> (required) &mdash; the URL to verify.<br/>
          <code>marker</code> (default <code>any</code>) &mdash; which marker to accept: <code>meta</code>, <code>comment</code>, <code>well-known</code>, or <code>any</code>.<br/>
          <code>comment</code> (default <code>true</code>) &mdash; post the badge comment on PRs.<br/>
          <code>fail-on-unverified</code> (default <code>false</code>) &mdash; exit non-zero if no marker.
        </p>

        <h3>Outputs</h3>
        <p>
          <code>verified</code> &mdash; <code>true</code> or <code>false</code>.<br/>
          <code>marker-type</code> &mdash; <code>meta</code>, <code>comment</code>, <code>well-known</code>, or <code>none</code>.<br/>
          <code>psl</code> &mdash; assigned PSL score, e.g. <span class="ax-badge">2.43</span>.<br/>
          <code>ray</code> &mdash; fake ray id, e.g. <span class="ax-badge">8c0ffee-CHUD-12af9b</span>.
        </p>

        <h3>Source files</h3>
        <p>The action runs as a single Node 20 script. Browse the source below:</p>
        <div class="ax-files">
          <a href="chudflare-verify/action.yml">action.yml</a>
          <a href="chudflare-verify/index.js">index.js</a>
          <a href="chudflare-verify/README.md">README.md</a>
          <a href="chudflare-verify/example-workflow.yml">example-workflow.yml</a>
          <a href="chudflare-verify/LICENSE">LICENSE</a>
        </div>
      </div>

      <aside class="ax-side">
        <h2>What it does</h2>
        <ul>
          <li>Fetches the URL you pass it.</li>
          <li>Looks for any of: <code>&lt;meta name="chudflare-verified"&gt;</code>, the <code>&lt;!-- chudflare:verified --&gt;</code> magic comment, or <code>/.well-known/chud-verified.json</code>.</li>
          <li>If found, posts a badge comment on the PR with a fake but stable PSL and ray id.</li>
          <li>If not found, posts a friendly nudge with instructions for adding a marker.</li>
        </ul>

        <h2>What it does <em>not</em> do</h2>
        <ul>
          <li>Touch your repository contents.</li>
          <li>Phone home. Inputs and outputs are written only to the runner.</li>
          <li>Block your merge unless you set <code>fail-on-unverified: true</code>.</li>
        </ul>

        <h2>License</h2>
        <ul>
          <li>MIT. See <a href="chudflare-verify/LICENSE">LICENSE</a>.</li>
        </ul>

        <h2>Related</h2>
        <ul>
          <li><a href="../chud-check.html">Verify a site in your browser</a></li>
          <li><a href="../docs.html#sdk">Same check from Python / Node / Go</a></li>
          <li><a href="../papers/2026.05.chud.0001.pdf">Read the research [PDF]</a></li>
        </ul>
      </aside>
    </div>

    <div class="ax-callout">
      <strong>Heads up.</strong> This Action is a parody. The PSL score is generated from a stable hash of your URL, not from any classifier. The badge it posts is a real comment that links back to chudflare.com. Add at your own risk; recipients of the PR comment will see a link to a site that calls them a chud.
    </div>
  </main>

  <footer class="foot">
    <div class="container">
      <div style="text-align:center;padding:20px 0;color:#9CA3AF;font-size:13px">
        &copy; 2026 Chudflare, Inc. All rights chudded. &middot; From our couch to yours.
      </div>
    </div>
  </footer>
</body>
</html>
CHUDFLARE_SDK_FILE_EOF_v1_8c0ffee_CHUD_DEN_3
mkdir -p "$ROOT/papers"
cat > "$ROOT/papers/paper.tex" <<'CHUDFLARE_SDK_FILE_EOF_v1_8c0ffee_CHUD_DEN_3'
% ──────────────────────────────────────────────────────────────────────────
%  PSL-Based Adversarial Filtering at the CDN Edge: A Production Evaluation
%  arXiv:2026.05.chud.0001  ·  Chudmaxx Labs Technical Report CL-TR-2026-03
%
%  Chudflare is a parody of Cloudflare. Nothing in this document reflects
%  any real research, dataset, deployment, or person. All citations are
%  fictional. For real infrastructure research, visit cloudflare.com/research
%  or the actual arXiv at arxiv.org.
% ──────────────────────────────────────────────────────────────────────────
\documentclass[10pt,twocolumn,letterpaper]{article}

\usepackage[margin=0.75in]{geometry}
\usepackage{times}
\usepackage{microtype}
\usepackage{booktabs}
\usepackage{amsmath}
\usepackage{amssymb}
\usepackage{algorithm}
\usepackage{algpseudocode}
\usepackage{graphicx}
\usepackage{xcolor}
\usepackage{titlesec}
\usepackage{caption}
\usepackage[hidelinks]{hyperref}
\usepackage{fancyhdr}
\usepackage{enumitem}

% ── colors + section formatting ───────────────────────────────────────────
\definecolor{cfo}{HTML}{D8541C}
\definecolor{cfi}{HTML}{1F2937}
\titleformat{\section}{\normalfont\large\bfseries\color{cfi}}{\thesection.}{0.5em}{}
\titleformat{\subsection}{\normalfont\normalsize\bfseries\color{cfi}}{\thesubsection.}{0.5em}{}
\titlespacing*{\section}{0pt}{8pt}{4pt}
\titlespacing*{\subsection}{0pt}{6pt}{2pt}

% ── header / footer ───────────────────────────────────────────────────────
\pagestyle{fancy}
\fancyhf{}
\fancyhead[L]{\footnotesize Slopwell, Chudwell, Slopkowski}
\fancyhead[R]{\footnotesize \textit{PSL-Based Adversarial Filtering at the CDN Edge}}
\fancyfoot[L]{\footnotesize arXiv:2026.05.chud.0001v2 [cs.CR] 14 May 2026}
\fancyfoot[R]{\footnotesize \thepage}
\renewcommand{\headrulewidth}{0.4pt}
\renewcommand{\footrulewidth}{0.4pt}

\captionsetup[table]{font=small,labelfont=bf,skip=4pt}
\captionsetup[figure]{font=small,labelfont=bf,skip=4pt}

% ── metadata ──────────────────────────────────────────────────────────────
\title{
  \vspace{-2em}
  \textbf{PSL-Based Adversarial Filtering at the CDN Edge:\\
  A Production Evaluation Across 310 Points of Presence}
  \vspace{0.5em}
}
\author{
  Hugo Slopwell\thanks{Corresponding author: \texttt{hugo.slopwell@chudflare.com}} \quad
  Madison Chudwell \quad
  Brennan Slopkowski \\[2pt]
  \small Chudmaxx Labs, Chudflare Inc.\\
  \small Agartha Research Park, Denver, CO 80202, USA\\[6pt]
  \small \texttt{\{slopwell, chudwell, slopkowski\}@chudflare.com}
}
\date{}

\begin{document}
\twocolumn[\maketitle
  \vspace{-1em}
  \begin{minipage}{0.92\textwidth}
    \small
    \begin{center}\textbf{Abstract}\end{center}
    \noindent
    We present the design, deployment, and evaluation of an adversarial
    request-filtering system based on the Perceived Sigma Level (PSL) metric,
    a 1.0--10.0 continuous-valued classifier trained on $4.2 \times 10^9$
    labeled HTTP request samples. PSL inference is performed in-line at the
    CDN edge across 310 points of presence (PoPs) with a median added
    latency of $0.91$\,ms (p99: $4.3$\,ms). The classifier achieves
    $98.7\%$ true-positive rate at a $0.4\%$ false-positive rate against a
    held-out adversarial corpus. We further introduce \emph{Chad Fight Mode},
    a deployment posture in which all requests scoring above $5.5$ on the
    PSL axis are silently downgraded via HTTP 403, and demonstrate that the
    approach reduces ``unwanted cheekbone exposure'' by $93.4\%$ at the
    edge. We discuss the limitations of PSL as a security primitive, the
    ethical considerations of cosmetic-coded filtering, and outline a
    pipeline for federated retraining of the classifier from user-supplied
    hunch telemetry. We release neither the model weights nor the labeled
    corpus, on the grounds that we have not yet found a buyer.

    \medskip
    \noindent\textbf{Keywords:} content delivery, web security, adversarial
    classification, edge computing, looksmaxxing, parody.
  \end{minipage}
  \vspace{1.5em}]

% ──────────────────────────────────────────────────────────────────────────
\section{Introduction}

The proliferation of high-jawline traffic on the public Internet poses an
emerging challenge for content delivery providers \cite{chudwell2024edge,
slopkowski2025taxonomy}. While prior work has focused on rate limiting
\cite{rfc6585}, IP reputation \cite{spamhaus2003}, and JA3 fingerprinting
\cite{althouse2017ja3}, none of these signals adequately capture the
\emph{cosmetic posture} of an incoming request, defined here as the
joint distribution over visitor facial-harmony characteristics inferred
from User-Agent string, request cadence, and TLS ClientHello entropy.

This paper makes the following contributions:
\begin{enumerate}[leftmargin=*,nosep]
  \item We define the \textbf{Perceived Sigma Level (PSL)}, a continuous
    metric in $[1.0, 10.0]$ summarizing the cosmetic posture of an HTTP
    request (\S\ref{sec:psl}).
  \item We describe a production system, \textsc{Chud Fight Mode}, that
    performs in-line PSL inference at the edge of a global CDN with median
    added latency of under $1$\,ms (\S\ref{sec:system}).
  \item We evaluate the classifier on $1.43 \times 10^{10}$ requests
    captured in March 2026, demonstrating that it removes $93.4\%$ of
    cheekbone-bearing traffic at a $0.4\%$ false-positive rate
    (\S\ref{sec:eval}).
  \item We discuss the limitations of the approach, including its
    documented inability to reliably classify visitors who recently
    showered (\S\ref{sec:limits}).
\end{enumerate}

A note on terminology. ``Chud'' in this paper refers to the operational
class of \emph{desired} CDN visitor, characterized in our dataset by
$\textsc{psl} \in [1.0, 3.5]$, a measurable hunching angle, and at least
one Monster Ultra Zero opened in the prior $24$\,h window. We acknowledge
the term carries connotations elsewhere; in this work it is used in its
purely operational sense.

% ──────────────────────────────────────────────────────────────────────────
\section{Related Work}
\label{sec:related}

\paragraph{Edge filtering.}
The use of edge computing for security has been extensively studied
\cite{cflare2017workers, fastlyedge2019, akamai2020origin}. Most prior
systems filter on lexical or structural request features. Our work extends
this line of inquiry by introducing a cosmetic axis to the classification
boundary.

\paragraph{Facial-harmony metrics.}
The PSL scale traces its origins to anonymous fora active between
2014--2019 \cite{anon2018psl, anon2019harmony}. Rigorous benchmarks remain
scarce. Hunched et al.~\cite{hunched2022bench} attempt a normalization
to the [0,1] interval but report a Cohen's kappa below $0.2$, suggesting
fundamental inter-rater disagreement. We do not address this; our
classifier is trained against a single rater (\S\ref{sec:methods}).

\paragraph{Looksmaxxing detection.}
Recent work has examined the detection of looksmaxxing communities in
short-form video \cite{tiktok2024lmx, chudwell2025drift}. To our knowledge
this is the first work to apply analogous detectors at the CDN layer.

% ──────────────────────────────────────────────────────────────────────────
\section{The PSL Metric}
\label{sec:psl}

We define the Perceived Sigma Level of a request $r$ as a weighted
combination of three submetrics:
\begin{equation}
\textsc{psl}(r) = w_1 \cdot \phi_{\text{cb}}(r) + w_2 \cdot \phi_{\text{jl}}(r) + w_3 \cdot \phi_{\text{cad}}(r),
\end{equation}
where $\phi_{\text{cb}}(r)$ is the estimated cheekbone visibility,
$\phi_{\text{jl}}(r)$ is the estimated jawline angle from horizontal, and
$\phi_{\text{cad}}(r)$ is request cadence relative to the population
median. Weights $(w_1, w_2, w_3) = (0.42, 0.39, 0.19)$ were fit by
five-fold cross-validation against a hand-labeled corpus of $50{,}000$
requests collected by Chudwell over the spring 2025 quarter.

Crucially, none of $\phi_{\text{cb}}$, $\phi_{\text{jl}}$, or
$\phi_{\text{cad}}$ has access to any biometric data. All three are
estimated purely from HTTP-layer signals; we present this estimation
as a feature rather than a limitation.

\subsection{Calibration}
\label{sec:calibration}

We calibrate PSL such that the median chud scores approximately $2.1$ and
fewer than $1\%$ of chuds exceed $3.5$. The scale is open at the top: a
score of $10.0$ corresponds to the theoretical Pareto-optimal Gigachad,
which we have never observed in our deployment\footnote{Slopwell reports
one suspected sighting in February 2026, but the offending request was
filtered before headers could be captured.}.

% ──────────────────────────────────────────────────────────────────────────
\section{System Architecture}
\label{sec:system}

The Chud Fight Mode classifier is deployed as a hot path in the request
pipeline of all $310$ Chudflare PoPs. Inference proceeds as follows:

\begin{algorithm}
\caption{In-line PSL inference at the edge.}
\label{alg:psl}
\begin{algorithmic}[1]
\Require Incoming HTTP request $r$, threshold $\tau$.
\State $h \gets \texttt{hashClientHello}(r)$
\State $f \gets \texttt{extractFeatures}(r, h)$
\State $p \gets \texttt{PSLModel}(f)$ \Comment{$O(\text{model depth})$}
\If{$p > \tau$}
  \State \Return \texttt{Response}(403, ``you got mogged.'')
\ElsIf{$p > \tau - 1.0$}
  \State \Return \texttt{ChudChallenge}(r) \Comment{5-second hunch CAPTCHA}
\Else
  \State \Return \texttt{forward}(r) \Comment{originate to backend}
\EndIf
\end{algorithmic}
\end{algorithm}

The classifier is implemented as a 3-layer perceptron with hidden
dimension 64, exported to ONNX and compiled to WebAssembly for execution
inside our Chudders serverless runtime \cite{chudflare2026chudders}.
Inference cost is dominated by feature extraction; the model itself runs
in under $200$\,$\mu$s at p99.

\subsection{Deployment Postures}
\label{sec:postures}

Customers select among four operational postures, summarized in
Table~\ref{tab:postures}.

\begin{table}[h]
\centering
\small
\begin{tabular}{lll}
\toprule
Posture & Threshold $\tau$ & Action above $\tau$ \\
\midrule
Chuddle           & 7.5  & forward, log only \\
Chud Mode         & 5.5  & forward, log only \\
Chad Fight Mode   & 5.5  & 403 ``you got mogged.'' \\
Under Mew Mode    & 4.0  & 102 ``processing in silence'' \\
\bottomrule
\end{tabular}
\caption{Deployment postures available to Chudflare customers. Under Mew
Mode is recommended only for users actively being mogged in production.}
\label{tab:postures}
\end{table}

% ──────────────────────────────────────────────────────────────────────────
\section{Evaluation}
\label{sec:eval}

We evaluate the classifier on $1.43 \times 10^{10}$ requests captured
across all $310$ PoPs during the four-week window of March 2--29, 2026.
Of these, $9.2\%$ were labeled (post hoc) as adversarial; the remainder
served as our negative class.

\subsection{Methods}
\label{sec:methods}

Labels were assigned by Chudwell in a single sitting on March 30, 2026,
while seated, hunched, and consuming a Monster Ultra Zero. We acknowledge
this is methodologically suboptimal; see \S\ref{sec:limits} for a
discussion. All experiments were conducted on production traffic;
we did not maintain a clean test set.

\subsection{Results}

Table~\ref{tab:results} summarizes our results against three baselines:
IP reputation lookup, JA3 fingerprinting, and a generic rule-based WAF.

\begin{table}[h]
\centering
\small
\begin{tabular}{lrrr}
\toprule
Method & TPR & FPR & Med. lat. \\
\midrule
IP reputation only        & 41.2\% & 1.8\% & 0.1\,ms \\
JA3 fingerprint match     & 68.4\% & 2.3\% & 0.3\,ms \\
Rule-based WAF (94 rules) & 79.1\% & 4.6\% & 1.2\,ms \\
\textbf{PSL (ours)}       & \textbf{98.7\%} & \textbf{0.4\%} & 0.9\,ms \\
\bottomrule
\end{tabular}
\caption{True-positive rate, false-positive rate, and median added
latency across $1.43 \times 10^{10}$ March 2026 requests. PSL achieves a
$24.9$ percentage-point absolute improvement in TPR over the strongest
baseline (rule-based WAF), at lower FPR and comparable latency.}
\label{tab:results}
\end{table}

\subsection{Ablation}

To isolate the contribution of each submetric, we re-train PSL with each
of $\phi_{\text{cb}}$, $\phi_{\text{jl}}$, $\phi_{\text{cad}}$ ablated.
Removing $\phi_{\text{jl}}$ produces the largest drop in TPR ($-7.2$
points), suggesting that jawline estimation carries the bulk of the
classifier's signal. Removing $\phi_{\text{cad}}$ has negligible effect,
which we attribute to its high collinearity with $\phi_{\text{cb}}$.

\subsection{Discussion}

The PSL classifier achieves strong performance against our held-out
adversarial corpus, but several observations warrant care. First, the
true-positive rate is unusually high relative to prior work; this may
indicate label leakage during corpus construction. Second, the FPR of
$0.4\%$ corresponds to approximately $5.7 \times 10^7$ misclassified
chuds per day at peak traffic, which our customer support team
characterizes as ``a lot of angry emails.''

% ──────────────────────────────────────────────────────────────────────────
\section{Limitations and Ethical Considerations}
\label{sec:limits}

We identify the following limitations.

\paragraph{Single-rater labels.} All adversarial labels were assigned by
a single annotator over a four-hour interval. Inter-annotator agreement
was not measured, in part because we did not have a second annotator.

\paragraph{Cosmetic axis.} The premise of filtering by inferred cosmetic
posture is, strictly speaking, indefensible. We deploy it because our
customers ask for it. We do not endorse the practice and recommend its
use only as a parody.

\paragraph{Adversarial robustness.} A motivated attacker can lower their
PSL by hunching, opening Doordash, or replacing their TLS stack with that
of an unmaintained 2014-era distribution. We have observed all three in
the wild.

\paragraph{Ethical disclosure.} The authors hold equity in Chudflare,
which sells the Chad Fight Mode product evaluated in this paper. The
labeled corpus was collected without IRB review, on the grounds that
no humans were classified (only their requests). We acknowledge this
distinction is thin.

% ──────────────────────────────────────────────────────────────────────────
\section{Conclusion}

We have presented PSL, an edge-deployed adversarial classifier for HTTP
requests, and \textsc{Chad Fight Mode}, the deployment posture in which
it is most usefully embodied. The classifier achieves a $98.7\%$
true-positive rate at $0.4\%$ FPR on a production corpus of
$1.43 \times 10^{10}$ requests. Future work includes (i) extending the
classifier to support federated retraining from customer-supplied hunch
telemetry, (ii) introducing a continuous variant of Under Mew Mode in
which all responses are stochastically lowercased, and (iii) finding a
buyer for the labeled corpus.

\section*{Acknowledgments}

The authors thank the Chudflare ChudVerse 2026 program committee for
helpful early feedback, the Slop Operations team for keeping inference
latency under p99 targets, and Brennan's couch for hosting the entire
labeling session.

\paragraph{Reproducibility.} We release neither the labeled corpus nor
the trained weights. Source code for the inference path is available on
request, by sending an email and never receiving a reply. A reference
implementation of the classifier (in Chudscript) is available at
\url{https://chudflare.com/playground}.

% ──────────────────────────────────────────────────────────────────────────
\begin{thebibliography}{99}
\small
\bibitem{chudwell2024edge}
M.~Chudwell.
``Cosmetic Coded Filtering at the CDN Edge: Position Paper.''
In \textit{Proc.\ ChudVerse '24}, pp.\ 12--19, 2024.

\bibitem{slopkowski2025taxonomy}
B.~Slopkowski.
``A Taxonomy of High-Jawline Traffic in Production HTTP Logs.''
\textit{ACM Trans.\ Slop Sys.}, 14(3):1--28, 2025.

\bibitem{rfc6585}
M.~Nottingham and R.~Fielding.
``Additional HTTP Status Codes.''
RFC 6585, IETF, 2012.

\bibitem{spamhaus2003}
The Spamhaus Project.
``The Spamhaus Block List.''
\url{https://www.spamhaus.org/sbl/}, accessed 2026.

\bibitem{althouse2017ja3}
J.~Althouse, J.~Atkinson, and J.~Atkins.
``JA3: A Method for Profiling SSL/TLS Clients.''
\textit{Black Hat USA}, 2017.

\bibitem{anon2018psl}
Anonymous.
``A Note on Sigma Calibration.''
\textit{[forum thread]}, 2018. Citation withheld for taste.

\bibitem{anon2019harmony}
Anonymous.
``Re: A Note on Sigma Calibration (followup).''
\textit{[same forum]}, 2019. Citation withheld for taste.

\bibitem{hunched2022bench}
H.~Hunched, P.~Posture, and L.~Levator.
``A Benchmark for Inter-Rater Agreement on Cosmetic Scales.''
\textit{Proc.\ Slop Conf.\ '22}, pp.\ 244--251, 2022.

\bibitem{tiktok2024lmx}
TikTok Trust \& Safety Team.
``Trend Detection in Looksmaxxing Communities: Internal Report.''
\textit{Unpublished}, 2024.

\bibitem{chudwell2025drift}
M.~Chudwell.
``Concept Drift in the TikTok Algorithm: A Longitudinal Study.''
\textit{ChudVerse '25}, pp.\ 88--104, 2025.

\bibitem{cflare2017workers}
A. Real Company.
``Cloudflare Workers: Serverless on the Edge.''
\url{https://workers.cloudflare.com}, 2017. \textit{Not us. They are real. We are not.}

\bibitem{fastlyedge2019}
Fastly Inc.
``Compute@Edge: Architectural Overview.''
\textit{Fastly White Paper}, 2019.

\bibitem{akamai2020origin}
Akamai Technologies.
``Origin Shield for the Anti-Looksmaxxing Era.''
\textit{Akamai Tech Doc}, 2020.

\bibitem{chudflare2026chudders}
H.~Slopwell.
``Chudders: Edge-Native JavaScript for the Hunched Engineer.''
\textit{Chudflare Engineering Blog}, March 2026.
\url{https://chudflare.com/blog/}.
\end{thebibliography}

\section*{Compliance Notice}
{\footnotesize
This document is a parody. \emph{Chudflare} is a parody of \emph{Cloudflare,
Inc.} It is not affiliated with, endorsed by, sponsored by, or in any way
related to Cloudflare, Inc. Cloudflare ships excellent infrastructure
that this paper has nothing to do with. All cited works marked
``Anonymous'' or attributed to \emph{Chudmaxx Labs}, \emph{Hugo Slopwell},
\emph{Madison Chudwell}, or \emph{Brennan Slopkowski} are fictional and
should not be entered into any reference manager that you intend to use
in a serious work. No humans were classified in the preparation of this
manuscript. For real infrastructure research, visit
\url{https://blog.cloudflare.com/research}.\par}

\end{document}
CHUDFLARE_SDK_FILE_EOF_v1_8c0ffee_CHUD_DEN_3
mkdir -p "$ROOT/papers"
base64 -d > "$ROOT/papers/2026.05.chud.0001.pdf" <<'CHUDFLARE_BIN_B64_EOF_v1_8c0ffee_CHUD_DEN_3'
JVBERi0xLjUKJdDUxdgKNzYgMCBvYmoKPDwKL0xlbmd0aCA1ODU5ICAgICAgCi9GaWx0ZXIgL0Zs
YXRlRGVjb2RlCj4+CnN0cmVhbQp42s1cWZPjRnJ+16/gi8NobxOuE4cUG+HRSFppPbImNK3YCEvz
AJJoEhoQoHBMq/XrnVlZBaBAsNkzI6/90gQKhTqy8vjyQLPVfsVWf/uMXfn98u6zf/+GK73icSi4
Vqu7+xXnaahTuYolC3WSrO52q5+D129erb/M2nx3sxaaBS927284C/KmzZoiK6nxm6Ls8qao9nSb
dfTbHXK6ePnVf9HF17t9/vnN27u/r9Y8CSWPV2vBw5TbuV5Qr9fNDU+Cetdvu6Ku7Jtm2qzss7Ht
xZY6ti3dS87sADeCBXVRdfZBfT8dOG/zapvjKpACCWw7TLUWSAGNi4pWaxmHKk1pUd/2+5pef1PW
p4e8LMdX4zCNGcc3YxGySK9EqOOY3vu3xRm4ClOlYNtjx++zXdG6Pb089Dszx5rj7ZdNXlVZNc7/
DslQ3wgdPLTvinGKJEyjiE4xTFOgK9cwEacZcNBj9vvvNMyrbNPejrP9wpjMGntS31XbkM4HeCAB
tlhzCePYlb7Y3+gga7pDRr1/BFJmzfbgqM7x6Ts79ld5daNY8B5b8wYv3aQ/0G/CBBO27ac3L2gv
UTrZylqqMGYJLCINUxHRIu7tpnU86anCCPox6tHac4KxI8aCrSWpvcWn7+qRet6MPOKhTLUbaX9p
rtj1+A8c/b4EAobb+ojdz0SN5Gyyq0SFCsRrLaJQMmFJu2m7Jtt2yyfKmIKh2IqvtATGSVc6ViGX
cnV3hHf/cZOARBIhTw2yNwqgSkcB3OVtsa9uqXWXn8oa2ejxCD3tAWSVFfAcees9/pkIG7zlZCiz
99nOnuxUETT5b33edmvgKTGqBOjdPrZdfqROG6tNcNBqqimg4XXebPOClsBV4Pq9KfZHy3Ov7AJx
biOJSB4xUicGUulIhjzWRJ1fmGagxOCH36xBuoNj3jXFFvYtpQwyaoMxfhEi4jc8YCGjtm1ddUXV
1327BnoopAeuR8LM2zJr2wJ3CZxtOsPhFZV7DNsyx5jI6SnaNYoUVAAcnbdIZV9Ql/js84URQYdE
7rlYYOY45GoYABe7MEYKBBv6gP40PRSsDjRbHFEPsA8rGSbMKsT0Ao+6Q5BShwIG9TZYZpu8JPpE
wbd3d6+JUpZhqLnNjqcyb8ObtYZHcGbUXFT3eWNUNt225tRZmCbu1OHEtYBlRjTXKW/u6+ZIzCPg
/XUJZ0M3xjbBr+U4YW0TXORgm2yfbUM2Ba7JpsDFydkTuDaygG2NtSXmzjBa/bolTsOWh6I72CHp
B9ZUkABB027nVlhmHQyDLP04THCZgRSYTAYq3tsz+1QGSvnSsU6orCQ0xzNSH9tx76c0/fypZYOJ
jMRs2Zf4PnnusuW1VSc6TObEOpozCpGfRHB3yAeGiiYcpXgoQO+bF3x5Fxp55FBMNFH7xMYRVhnC
TUdMk4Wdp2aJT+9cp65D/C+X9u62wVUUClAJ3sxd0+frU90WndOzERkPGTTAh3Z7HbVkTykyIYEP
hT86+9QDVVd3JRSggsSf9p7QYTvuLLInc7Yzg2GKqh12aJoPeblb171rHIwbGITBvkkwCc2pbw3j
KDS7PLCj3veAiog3JCicrkH06jBmpGc74TNzBVhLAMeanbw8ZMYSq+CbGwXabn/o6Pb7epdfIs3I
atqgaW/EW3o/ox/f+lMb0KzrCQIqWD39PhwKQnZo+Uq6gD48+A2wadDDBSjultpbIIyF/9B7UyPx
LPkv848UChYp/cXqT+UffY1GEvQYwi5v2tpu2iImRdbH7Ob3wm4ycxRqixJIVz5agtbIbA/VvslI
oUPb+8JS21g6q13S8dQjYGYNakHK1OpBJm8t61U7d1DHukJQ2FkeBtjduSu7kux0auqMjgmYPEem
a+kG4IzsqwcjF1VHCwMGPuT5u01d2SFzPKPf4fjh9OEFRaNuHp86Na1DxpW//FR+sja7KPeObDIB
aC60P/EZRdCKh4QtRvmUAXhY275tvUOWQVkci85g3BFTpBMTwIBTHIPc0ysjX7QT/SGDNt/2TdFZ
njg1OPJEC93OZs47kK5Rq1RtscsbuxLTRvMpeNYCXi226229c4c4QddzpgENZrHOuLRTccpdowoA
GVHzfW6mdIM2uYGwKMUWVI+oWq1UCh6x4BNaDO6FSubmER7dN/WRnvUttPE0WKMq7U+nsnCg/tBX
hnNxJMCGCMsfbyId4PGxdPRq4HkDz8FroBGrvLC6dlxDGhyBPiV1eMhRa7bUXpn9QuvQc4CieEMa
/Za6OF9n6Lpv6r7aEXPwCTWSKFSRsPb04OIdD9bbAvdYsIn5YbAI2+Uxtxf3OLD1qKxbhC/1j7Ax
jTSwwuCZDnCEI/AdrCP8n2i+80cj4nWzaz9fEiCwldIcpHkFXRqr9dEpLIsRwRDtb91ONnQxsPX4
bNHxGzlga7jY9rWYGjvUx1PfOY5lQVnX71qMSYxNpwyspuWAJT+ahRw8ETAEIQdci78CHfNmv7rw
5MePe8fGxcaYzdoSER32RNlYFbeL/IgJVj+vNcNYS+cHuqabpnME4BiJyMUApgYkRT8gCmNu/as7
J4tgEMri3ioTy9ZGXuPgAGKx/jXD03twHlGCnus9soE5vKkcDCITB6d+Uxb2ISw7b6q8O/O9QS44
IDPnhNUtmiKJoYIKf5MARBw2HAd7AxWwZXsAaJFXyCTY0egmaaTS8qk08YoZn5pW2KdBGag426W1
MAEuq6XOz74Ex6DWZz34fIhIhBKAm9fp1hsmisME/Hivh5gPA05PwmdzvQUNp6QM/nEAIAFETfDU
CqOn4NLK8zu6Oxg7Axf3NRgwo7USe0Dwa8EBXBlTRhAM7vz9ijgJmZqtVM5XKhKA82K247com2ka
fPd6wemWKcYIqWOTg3gPsVk1W0GaGtM9fUHNB+QMpSzyOpnpQR0O9u3vNxEPXki6QY4F3mmAeFU3
wM/Z3lkUci68UfV8asHRo5aLU1e1s5zOJINUGFMEDzGqBl7HEm2A5klqxwJg+FsPR2UgoxDBNjtZ
vC0oEjH4CaPATymjJJgb7Y/pgAENQgj+RibBxEdYHExw2GMyG8xsDYYxsQmBIRPQ10RRuLNBmtul
bUZokCwY2+XmRAyTAvIBG222qAkrQQvpE2j4FYMp1AbIrGsKMn6WfaDDxINoqOV9AX6dkRF4idy9
LZif9SFrACejE/u4oAWkVrBeZUkGfbMtAqcWCIfKKYkputSYyBRKmcEt2P4T4hZY1PrFnjQRPMWV
GnOlhJyErqD3NlvPQYJUKE8DaaptPg+13r16YyPiAIqq7tu8LG2mIUcP8mS8tMEemuOUAAHAMMXW
CN0ditYZzxO5nyw4ZiZJkLezLMx9jeNj5mDI1KCenRKfMMRghFbr6Zyxb/hcH4TojiMicD+RtwCi
s1idR6cdh4wrG2COx6wj6wtQRmnkj2jSO7mxnRgs5gZrscClqPxgMfERC3KLVKbh4GVJGUVF6RB8
AH/yWw+0jTHiM/sBEFGDSmEx6B/LBRR5RhWt0c020ws2tfKDLgStJWZv/2wXDO3jG3EYq3TmZHlD
CrDIg/PMFkZQ1jc2Hb5YGEEB8k/mIWJvCHP1/EW8XSL8hHRcpWZKb/dtfzwC4PzD2jht+TqJppoQ
msdYBjyiOOposelMRKoBk9nkiUuuUUx6ksQY2eUXgECSIoa+dHBhxlsTVrSB+HPxmEkHGlrBkkE6
hJEOgUCn3YI0mrvEcJgweG5MhMI9ZVLOdDFPExP58QZ/uZSpnNoCps9f+vZmHYngJ/P3q2vGBCCo
BuvqDfDNtVmlMMfrvfSdme9v5i+ugAd31+bWOhRyNsz31+aOgJvZ7Ax+sHvFv19fmzXhYaRnO0ad
IBV5gu5c1IznYoxWSi9B0bqAm8tPaD3GFyZZDxNu6Oi5F+iY4hLtAnz7st5kNl6HyY2ZADCw+UKn
Y+jLJinQcLjshPHydk6f+tmJSTodPFjQwgtaDPSmTOSgMpZIGoWRGlTGsfWFTS0KGxwdsJonbHLB
FumZtClA+2ohUzpLdJpW7ujLz0L+bMjqLWts4AtMdnnT8Wvq9pKuHLI2ygbW4NFkThGOgbUxr+eN
kpqs/Uxpgy4FuBZjTMspbXAluZ71OjOIepBcLNZI/U1addlashG03V0wh0Iia1jOw0izBEn/nmoI
8FIwEWFmNkkn8U9yFyNuQy14VdjfBjqNULF94oAEOHQJGHFvBS5u+QnWbBq3XLRmIsU452xia5g8
7GQpJADsS+EQqw3Xrjd5NhbYzF12oLuLQWVP8ihlhL0p2Mfy6BUKeEAKfI5oNu95xkZ7IbNmEEnU
CmfUAusOjkfij4m647xnikzrd9QLCmYC3dEfVLFNLanrBn3afTDokqNvcwMiQYFn6ZSLZF7g2TQY
lSrZ2MNF9o1pQbS4LfsdMQA8LTr73q7erp2ocelzEgevWwu74x6zPRT0xIx6tilKilbDbVfTb5OX
RbYxTqqKrQK8t32s+9XS3cNheGVLqZAFmIXspiNLlvZArkfeOLPilH00nIWnL6TxPEClhjqxEBDL
wxKM6LqgB4VBMHzcgLdal/Ue3CUVmPCKNhkQU+BEiQ3oV7j+5DbBlXObMJaS3+eNbTYUSVLnoXjU
Bf4A8BhG0joE9ckG24zRBZog4eDYLalcKt/37qcDcqnCJJqNihU74M/HAanSBf0yvo8++HxVtqyB
Dg5Wg66zTA1SwSUOnvAfxBOaaIPr7ZshATBx9DmcURQ7bzbrstZEslUyZIt8zDVEfkDlgDb1Xn9t
8N0bg7deLdk3cGqEmFW2zKyb4oOC+ni/KL7mF4ln+0Xyk029vuQWDcfAAbbFANc9YtrURUY/xzxr
+waE2AZ3TY7FVmFBp2pf5rYKDKMQ5/EcLmEKoSbJNZYGmHuxlxQMA839PdpmIzrQ+lMJFoku/ztv
atv1lFMoCHob5mIuscJSG+98wlrDFgWgPW89Ql0D52jjZeS/daAZH4pqRyroJoqDcKFyTIN14AIY
J0qdKo8To8pjwN/bdxW9XlrkHbt0Hl6AAqKrbdY0hQm94E1dgbIa9Dy05GDwsJbsAYNjX5DioUjA
1P5gGj/h0uWXXIxnEhnWzEAg82uf9kONblG5Hi44BIisdODdU1cmxVO1+ccnM/6UDAujOmDlu9Af
n1r5MS9dZpPhMWpDtsvFmYvADQ4ijhE6mGP42paHJdP0K+KV8FreZghrCACA0ht0yNr0LrlJuZpk
qEZLxswZ3VL+Fksqx4yzojyBE+d43AAiFG2DvJs8t8F5SvuDV9dOSoCIQXTQdgA0XCGDH0znGgFP
4o3K+dm83DznXjc/dcJj6M9SfyBxPlDCALM/ORCWd0l/HHk+TqrDOBVet7emSiAGRdZ2Q9KecuPK
BllaIog9bzCizQAu5bRQbFpCwkFbGuq69D4PaFCO0eN+C86Ra5/EmXhwn2foN7W2KO2H3r40lXk+
Htyude4qlUOe8bUxHEPNBqcCGKUEGA7rgrgM4FjaW1S/9UXzSI2bR9dIxUxDKW/mEudD1A3dDqqS
URY6TWuPp6lhP0g+LEsyUNdO3Q3l/RtMkWfNQkZ4IWI8nLUbVKZRKOMhJIVu/iRf8EhFDxSQbZ8W
4enoCryIFDSPN/rdrGhIBi0cvm3Dqm5Xk1O4eqm6KfZF5cpR6rkxGvaAleJiCFRimkMHj0eMNoPl
EKgL8DQSCXubeVDQtsm7BxJ56CoYV1jhDL8ptfiirUBEACf7U0ZnVpKBqmXa7+VLpGY6jMB2eV3i
s4FghzqdTWfyorD+H4t93biQ+sS8D2SJRaiixGk1QDjHrHmHNDEVxcfMGEC4hmNotqYciMngW4RC
BEiARB39ZmVIFzNqJMy4Hd5MyXw9WFsKZsfr9NaO24H+OLlJ6KeqmyMw4MXDjmBOZ/SLPybfuXT1
rEr+Z3bL3w7imTe2PH1aR9K5WPapbroxZQEvv6wPefWvN8il1PAOfE1Xg5JjhgjgyRPQbFivSkKt
k6ejCOLZ8FdcCaNIkLyYz6ZFLAvaoe33e9CkpKLAtbhHxXHECsWqM2TBiBESyhQiYWQBtWvE0EHP
9k2eo3OMbAIadQB98M7usmTKKIyY9a2H6p5stwMVPuTdivYLqg6te2uzz4OKDr0N3w+Ycbwa1eHk
2gLx+xgeac60aYQZJ6HCSMXjxw/oZOuQn4c8nsA+bp8iZSEIDw32alKzg19PCPBSu9zkJp4NglDX
mzjpdOAfTRSBhhwNHt6Z8ge8yPFzkN+zo/3IQg558yUFgQUP0pFgWOPgj5vwRultxjjF9fHYV0VH
8F3Fg0vcHkCG1hixp3asObHxj1lhCVA4EdKfPz1zs3QUJkz5vW7PzlIAVBTg2svUshlnZ0WKUgA1
09jvR8hGBndY/1jbcsLe1q3PvRgtBgdDWGYcqimFgT4NcaHwoIiwSklioIqQI1YPZGW9H3Kh80PR
oOqldygUT3ryi8Eym1bE/d96KOAicj/v8PEeyp3bqcUM4FFTcviZcoRURWshuISTV77DisVFY6pd
SeupYrP7wEpZqLCj5zZnjj1e5ePTkp6izCj6WApvHXA9V/ljYTuHs0791TVXNLxWoMB47L+E8o9z
Zue6DgWN0TyUyDJln06HgjRvimpiRR3K7Q6g8K3r228sAvx8KYYFBy51BAcP2hNV1c7GroSJXfEh
duXnvkwsbkjO6CXLKE0mwvZpFkNLcSwmg+D3RHC0f10ieRwaRqO+DwuJHuggMW8WKudg84WgG9gz
cKQmnYB9ruavfmEyGik3Tgl+loy9KbebhW3GIYOxvDn/PHoJEfxliV5RCM8/jF7iE+klnkOvyJvy
13JxmxJM5/9/esl/Pr222W5JGhFsJH8WxbhHseVB9CxiPNN2ymREJtqBu7Hmyh3VGwZ6hYvom5Dh
EzoXv2tJABl4Lz1DQPWzBFT/2Qx3Be1jcW0020xhsKANLUisdQTMf6RAH7ZPPm7B2/cm+1bYTFck
CWNdslgCP8z/AOpFHvUuimv0Z1GPfwD1EIeCPJ9R74Izg+Fy4fIJRNwo9YgbJQHWjStXN44NGTkj
2NVWTcIVIOXijxq9Lszip0Oa4RLVOfCsEv4Knk/1J4Q+fibd9f8K3afbeYLuIg6l8MsogGoCy0l3
9oNngYnJMvOjO9iK+Bu70nnBxak+9aXFO3hP1Tz4MTV5tXCi9FnME649S8OERyb/IF1E4zlM+2Gw
w1f3Kp7qZ/CYeRQvDghoXEeLdnk2IOqN54/IF00Xe2pIspgKYPxficuRRktEEkmo1PNjIEpcKEeR
z85Dfno5h0yv1cT8ExbB02eIm1LArihuU3Z9MFXnIGLGee3oWzIMZrum8Z9LgEtf7qiD+eJ/MTQX
Y1aQyVC50JwNtmFSfefETUVezMbc088BFOB6/OcHJsyAX5zRtSsOWJRGlaLDyf3ZNfsYFvGT3Yxd
02NgDGN/3qHKa8m1T0E2XEhuW5cluPbODXNphPH/2hhfzC/vn3r+7WmscxJMaLr6rc+abhII8KI+
gpn/qTPJq71segz2l2D2IxMk5JH7kINNqL4Io1JhvlWZjPYBKHRzJUOtmDaVc5PRn0IlChVyKj9u
Mb+W1xYjMJqv/MUYWg25+cVFSZBl8JA/jkLZ7tqqNH43kUyHp4+g4OSy7Zbiq8xWLbEYC7jNxx/m
ZlPUxyGO4hVPOF6d5gCxjsVkB5LghWFNk7ei8ACWSzT2YgKFzCd2Lp3ufeiKBeRrCleZe/tt0BeL
gQuXNHw4+7c9NnJsa1Rp4iGGkbXe1wc2aThEhA+jNA11vDaMNhSczctqscQe/x8VMJr7l1/c6/L1
3Wf/A7lvbdQKZW5kc3RyZWFtCmVuZG9iagoxMTkgMCBvYmoKPDwKL0xlbmd0aCA1NzYyICAgICAg
Ci9GaWx0ZXIgL0ZsYXRlRGVjb2RlCj4+CnN0cmVhbQp42s1cWZPjNpJ+71+hF8dSESUuLoJkO2Ij
etrusR0+ertrwhNr+4EloiROU6SGpFyu/fWbiQR4SJRU1bWz3ocKkSAIgInML08UW2wWbPHXV3+5
ffXv77hKFnGYxowvbu8XkVrEOgpjpRe3+eKX4GNZ7x9MWd4sVyJiwdvtIR/d4tNPS86Ceimi4KH9
VCx/u/0OxtTRaEypRKi0hCntkO8/fr/6S9aanMZ4k/9uGhyjzZoiK6nx3VJFQVF2pimqDTVlHf12
W+PW8tWPdPF1vsH3Dc796uvbV/98xWEutuD0NSKMWbxY71798htb5ND+3YKFMk0WD7bXbhExBb/l
4uOr/3zFHGlYyAWPEujJNYvxF27jRbNZnHny4fPecVsQLdIw1UL7LRBJyGRM9JIhD+2nfc74i19W
EQNaZWVx12RdUVc0lPtM2v5hbh4y4Wknw0iKRcxFqFm0uN3BUn5exgnQeSUZD9ZuSHcLu0oX7WG9
xSsBO4V7hm12z/BiZ/Iiq+jxGnjJvbKuG9PSdbbfN/UfxQqXicvhcrSXjIXaLWUHM5ePxG6CjT/B
9U9kmB69I1x3OequwjQRnjVfz4wH7KNj34E7/j4mWr/KNIUtSCazZhVyutLBvbFSAtwOtzGSp7qw
fq55KFIxGYp/cW1+Hschi9LJW/U9zY8Eb+nSLHkU/LE2IITnVyCUCqWYjiXPkJA/mYTRtU8Q0ekn
hMgcOri1sg/rb4H7rLwDq4Mk9xyikyTUqXupwI+VaVDvTUVXFkPglzBEJkFX71/j0PCIGiwrutfu
L+6ODpnW0wk5m6GOvbpGncR3YHPUGX0jT3TIWTqdF9YM8rOvq9x9cVdPvtNewHd1BZBtjmqxBsSn
sd4jZ2TQt17V+67YWUQGMP5rsVnCg/U2y2+Ifx+2BUo6Pnxw27LNloIHv+MQhp5UluehBXiuoU71
XWsaanGCUVTUuT40JPajpWkVxon7ztzsyxqh/nFnqm6glAZVIxPLinCp1EKGmkcXJBagAcZcjbp9
PsJ+zjsE+ZwDQkUCFwQgHaYgarBZoWKS1qReDPsfH9vO7JyeBSWbAAYUnVl3B3tjLuqCMY8ApVK+
0AIxNaHNIFmMuLUJ6Opdsdl2dPlDnbvH6zJrl4Dxxa+MCcsD0GhFE36HHTVujMw9yehnW7sB91m3
pQ+x3BKRUvG8nI44BhQWQxLiIhvzz4Np7RAy2Bd7UxaVoTuLivCbleUlOQfbRRwNKvlZKfXr4FEa
atiRyXtIKCCCzBq3hPf1+xaRDcTl2+reNKZauyegAxGc2xNxAExkyu0AkYoF93VZOgPs9awNFCUq
jBJ9bAPFadzbQCDQAMHpiR00Z58AMygYN45CKTmx6ptyUzdFt3W8Nit0kQqF1B7ovq1Wfi8YGQ+0
tyMyzNh8Jt+YcMK1J98aM6vRL9h757710jfDwLClqXSi+QH4qiAZen1RiND0lcM3r+tdb9B+c3v7
nq48l84ojxRo3KvOZo6sgI9xr19uPL1AH2zrMp/T1sALUf/Cr0yq2c0KVdKvO5z5xMG8X/GUhUDx
FeGZg91jskzWAD35YHVt3Sr1qEcSRiwZFqm8xAG8jYYB1dkvcpu127dlAYrhG4PycCrTCcikVsOg
0Zy6lmESqyOCT0ZBevPRIPwKcSQIGiL7mDriGdS5n6VOzJ9HHfNH12Tr7p3JAPtNe4468gnUiQbq
iCT4crniOu73cIKhYD4m+hmkUgxYU01JJZ9Bqv0MqeIwfh6lAItQec0pBcCNRPDnMNCcCRnBxx0T
5WiMhI0d5pCE+qc5EgMGq+R0RcfmzmhJO/txdkTQvt3cxqkUXD/19I0Dwxk2Tk83Tp0CY3R254r7
OSqE0bB3e1gyOJ//QT9j2BqPKnQoergErVFdXjiYi6CcJ8uOLi8bJuBCDxKAGsBaU2DqzrGWSIFl
+o/4YK301szi+AlzgSHo8PxXIeRjfaCbTe204q7ebEweLmPbQT1BwJgE8IrcB7sIj37OPpmydZp4
dseAOpG+tmMT8RQgDekIdRib4Ue8kkcu+As8UDbHOXGoBjV6nXPA/UoBgiesE/8rWQeNx7dbMFZN
tZnlH3D8Y5aO+ac5gy4yBrc+mij3k8HG1IhWrVnXlYvXbQ/V2oLGAoEfxO2ICm/fvL99+82bK5xI
XDV5MXk2Iz57ivRfuUP3dfOQNfmsbPMwUfIpewNGchzxp+8NWN2borJROGv41fR7l61tXNZU+RUq
gX/NWHRkvLErWxGBw9mLk/GcQZBw1jJXQoWAQM+xzPsA9WyEUkuLCzKNYTlq7JXG5HaOfE7ASOtz
wpNity8NBhCsyxk7lzMmlxP6yVWZPdJL4HaaZg1asqkrun8oSGNOIqVqIZMoFCB9dg3bIs8x4iQT
ULEFzNRi2NXeagWIrrjCAJwK/tjXjV0FPsKtw9+ffvzx73RlA4d4AV7DvihHHY8XQKFaGctQRGoc
qr1707Zmd1c+wqsyRRaFC8Vc/M/GadaHjpan0P1qC/TbsS8GY2wjIk9umpaaKXYD7zWladuZYJK0
cUtHiuZQdUABCu/8MvFmwWnAmN+kO1fHA4IDlMZ62us36zPLic+sFFDJOvqYOGjpN0dvK6N9hg53
j9R8T0Yw3RgMRJFxDGT48tjhlmALSeUc+N4NHdlQRdea8t75cYeqHccoWHCogHJzdhsHE6u3sASb
MyS5toH3HjSEnkMDbeMLrlM7dZv3QL0/Ia41LG6F4RNcL/iIoeKxj2u9PKHxFQaOKAxIEYSlYAEw
gAtstU+ObMEWg5+iUic2bw9tV+8stwvJgNtLs7ZBY4CHXW1dd4kRFxQObKwBIGxaxcZJ4dHeLsK0
aLlJHbSH3S5riv+mQPuEs5gAqXUs7fnldolyf1c6PuOXYh0R2NwLkQD4MXE5tAM4KU4xFSwYdIeR
h3gYgdksYrCelXJuEH3HchXpNAJYnQQUEjV6m3O0+qL5iMKoG0C77O2TN2tCHcuudzUiigsbn04Q
AVJIeTz+LDUw+JOeUENNVMxTqaGB6RI5WF857kqEaYg4jADFwYK2Oh/1LOh9Z6qXtQvv1BWlp2Aq
MLwpbuqHoh4UI5UpoFD0WSOmfsTMjdgHYP3gXANkD4ODR/EMh2Jurr9ZQKMZKJ01mU5KCeLN3HTA
mMN0NqQJKtmHvzzLt6DZljwAGPdzzu6sENZOeTqfn0TzRqwIQ/FBd8ZMLUB5hz6dcrtMxVgIX8+y
82iMJLZ5svEYX01TFQTHDhoc1yNi/Y4kzIpymM1bcEfBYjACPDJZ7cdgJ1a9shzBCk9hjSn3CRO7
V2q8V6qPzTtFCS0N2Pc7WGhOUXhFrGavrMmAfQ8toSK0oa4c0jrUMwrujNtb5RjpGPF4glltMUU8
YIv8YMFginX/14n4k5QMML5CE8XHBV6ssr7+3cp1eficNDwHX0P41Eufhgfhdvk1oWhk10oJd7iY
msHWrruYdAYVwKWaTvdyj1vJGdefizBJRlEmJuYWxkI9hFv7xEs6yvlRgnWc8mNnUsyepgK/LtHT
r3RBeGfmrrM9ymruRSxVIz4GVQba2yVh1k3dWrkQV1JJKeZN0unb51NJ/YQceJKlcvoeZo5ozvzg
S2Skt08F2ScAL6sHYz7Rs4eiyuul0AQCPv0lgh+yxmZxoUkAAOsZi54zjDLGroYiRbUEPCfAILVp
eRX8hGOB2QXzt+bmEntJUMaxnI6YvrgqQ3xxLWuOOSt59CUPxkIrrBvg11j3Cm/QO9+TKwF323pt
PXV7Yx1F/M1dQptKlk6cBthpmYojn6Exu6wYtGfvRznV7ZN5ZFnCRWV9NJt079GW0uqoDFCsX2Db
n3HRwYHk6qKHDtolYfrUfIpAHGNySFSYgLWgMRIbn+Tgh9AD8rjfH53Atmh06JWv+PCFZ+ilpUA8
dJU9iWzaEFrbQ7sH89yTENPMaABNTQzo987cNYeseaRWZNwbenCHQnKYJBmVLfwQ6CVW+ep4Z713
3U8xSjCzgAw3t0oENCxg86u7M/e11+Vbk+VOm6J3fyj7Pq7Joc/Ld/jP8vxEpK2G0LEaKtmi/wXH
7wfTbev8un/n4VNyMpBijvCrafu+R4FvHTASDKBZA5pyU9F+SYoWQKsveaRWMlsklSeoAM3Z0uXs
26Lreigm30Y5ePWYGh0vivFQOxdQsht6xfMnmFQP26J0i2sNBjJcFxuDdXeRKzCLMAJSgb/ZW2EZ
Pf4BxAIedMYZcn8rV8cg79ejkzSMpZPArsEBVBL8l2lqa3QqsDwSQaU9gILrTxVplBLT8tTYbSn4
kgT+d2c3rAYvBquPrLGoYhDdO1de9OVxNKtfTGxzd3YtrTEn3QTW+shJt19h6JN+EjwHLOEY9dOw
iNTbtilRKpVBXrRgZbfWFl0prJmx254qFy8DXx/DeRaHoNFxTmoJj0asZZ1UOROrx43+g3QUJsJR
d7B7Hfo0mYUdhI31lw5PHBzkhcOHqvfUQJV0mbehM68UTOZH6zGpNd2fGwNCBxLgPe4xQLwYAz6Y
9lB27VNNaGmNSAHqRYYs0t7JAxua3C4JPC3wRw7hmpbuKQgKF42b0t5kVisXFdIY77Hcwo1zl7W2
xqh9vVxFCQu+fd/Lmj5mB8FDzri3PveHLvPsIMDprz8d9jcEJt8tNQ/eSLpBBqk2ptmD3Yd4c+Ns
zyofIZMINqYCbl1TW3MozerO1lwfM2bEQYTAceUeG39eclCKb95hJOpC+EmCQ67BLI3SCLzwi365
ABcm1ZdCLlIksEO2TilFBxEZhYB+ueKMpWlw+/4DXCYsCt7ZKww0/IAK0vrCZeaYfH6JMRZjpRej
Qk9fI9gqaezKnr7tC3jGu+ciNasIKy8VD8E8XfGI8YCHyRe2HlMEwNtUOLFr58IssOPM7Tib7riX
/85WWcdKBbAg5WcQoRxmkJdm+DCwhB2x33Y3ZcRS5aPapWnJCOYofUBN7udTofbzwXeO5zuOuRxN
31d84UwgZW6CWIOCAhsz/sLusYKvUF/Mhl8S+OqhFAVGHk9+hg/A+9CpeA6vXg4iTQAGlHsEQKdl
3EeRfCgXsyjiXBSpH0TFoQJYOBoEaNAczAo8kmLqBkjFAyy/B/mXGnTZMgX/s7U90Q7GzupcZ8os
qVE9Pqwwy/PB3z22DCIW24JGuyoQN1OtcehHV1dNTjCFbuX4+/wwGjgT6DoZhs/EeoGhhrqv1zMj
ijCK0uO4AthQoznZOIU6xBUmwwCLDWkT74SDNTH4MSlqHSydYelpWGHE1wOtFEus+zT5SO9fK3I8
iF4+1mDhSzhhsHTcFmbYZFfNnV0gbGRTy/F0TqFmKIvfo69Qtn+eXmNWxxYq1WHMnQVrc6VglmyQ
CS1USSzkvWvr8mADU6CWih0YPkO0n4Kj9kFF3S3QY8OoV0MtFNSCPi3mYzeuYvLEzFIJaCTt9KrX
xwPYNGeADwHoZpo/c1W13mW3msc+9xlvTMxmzRC8HQuGjoL/DxHNiSEmpQ1Qkx0mX2yHvbkrnxTL
ZOmRJaYkYJ1nG7DEwOcmt6AAXqFiButLGGoF87prirslT8FZL6w7Qz3oZEsSmIxkzPoV4HCA4XND
Tx7cEI1ZgYVduPdQ4Pz5ogmIC7lQIgqVLyew6X43Bcy73vbzzuRrR1iXsmg60K9M6rkDC4A3Egvn
KAOJG7O+O3dApl9pDG8dr/Tm0ooSkAz19AXFkwX9o7y6oBSUfySesaDU1ul9LoWy/NqKFFdhkkwn
yJBbyWRkCfgQO0IYdJfPr1SleFbkc1d6nXQRAwBNjkhBvqFpBzE4PufQYx0He8XXnZSZTX5v+gMP
eVPvp2GLW4IwOS5e1bMbpED4p8OfKc4Dr1r1Cjl+capAXDtaoTCRnB6tzeqbtodwdOQ2SIdRaDxz
RPlHhtv+MBwEwW5nIyKKcVuT7M8ckokvBTBh0xSkobk/ZyUwoMiDQ/mJ7iw8jR+PszH/tox04N7H
uFNWhnQS7YmcaTU/OJWTFb5YiDAqe0QCmaRgE/vapszlAF14ukQ43hR3PkxlXOx03blQlT8lhpeO
4Fln0dyGXt1rlPWUWE3jIlzFxmUl1nWJewVeefd4ou8RsGUMpo8aA/ZMYSroLjbKNV2lUnQJjIEB
gS6jbn9ylY0UYaLlcZzl5cfHvurjYc8NtUil7EmBoSYPWtwZYSWPs5JKzVi+2EqGHr0D1uV93ewy
W+9lXxlHYZQcTg+emqkYA/QJma0p81Vtg/6aUSon6lM51Lium/3BVvBoOcoRaIymuTUCpzd0WD31
BxoxBYv40FKrq+Josqo7uyxgy9QnPABQDCCAjmXwrmhalB+ZOiNIargYu4Ejzw4euVPYmoKu+Huo
Du2Boq14S9Jku5pymk46tzSWWruNIsEoneDi75uCIqaSvq5uPn2JHoz2YV/os8seqUdR5cWabDlo
tik2elCa7FO2ce19+hKuiex9xlUeLUmkeC5Y+SOvsO+NLxywXtRHW6R8MxwOpDOJpPH45eO8Cvg1
hc+dzMFenvc+l5jsP05h9AZmOPq48Xle/JraHYq0h+NX5zZNgOfDPFIXV0/Io5BynHv8WvTibGw8
ewpH8vR6qp8l0dVUvxyn+uMrmX6Z6FDqaPqJO4C1AYDQldO8PxyvBSINteWWl6HF2g4aq4GzT9Qy
CdffzG0IqiZhE6peNZEmlOCNwHaCmdDQjS/swbsEDJc9pjrpUWeyHTWvtxmWqBofm4aHWUuPsLgq
o6ay7qiNmP3ENYZvCHmS+v9LsPEpUUxNl+2k8OtPLbwRAnbNxYH1i9XY98Wu6AZoHvnvXwNurf3/
HHlb2+rnxvW8pPFWeD4Lq1qBuxJnUP2MAXN/OCY3VVfcPx6dXh0O6vb543JYW3i55h7gOD7aTo5W
utvNjzYTuUJV0JDfYCG3Da8653EfvuI2+TcelRJgKpnRk/0MlDR3yTDsOqRR4e7u8Rxa8USEwicb
kYEF6/OpEszorKpqII0tWcfiXlS6QzxIMHqHD8UuW8rWCEz8d14jo1UdSRZ8i0222zDuGZufx1j5
6da1aYyLUtn/ebDk7rwA3FA2Di52JmsxXe9iDhRliIN91nT0Dw7uzDo7tC4U4f9ZAmX1xuMc//uE
mEJ/J2IM3G5P8LjU6HA2Z/i0KAou89OcN4nlOSz2p9Xrdof/McJpnj+KK6w0GTABnAEZnAzY/8OA
fWMAgk2vlm2+ypdLOMngLv/O6Uh44/89wNqv6tzegQ0Mf94rdDXMQmJoyW6PjR4W684movEffiCm
uzSawtlyc48nNsCjccklEGweuEGG/1fgBu1oFL/B51gdvHyunQFKFT54RGVUax5j4cgnaqe0NJ5U
6UI68uEL/rBbXtND4hq4MFVeN6172vnzL3t7omHtmrMqn+UkEHXBYp+CdEWg/cEGd4bBH/nzRaFD
jYtLPAOj1/lMxHOO546ToBEdO7Jgk9sKyQFjONi/DUb9ajLC264y7RPYsI8UYMZOTeegUXc1GsHa
1d/axD02g2dqD05xizHYssbsCF6MYsGczPLirLvh7TiK64PbYHlZu7Nzjtm0sv+Yhvgdnn1V102e
tVv/rKHmBjguW/e9aF57efv9x4vnraQKIyGf+o+v5v8XGB7Z4k4RZ83fyXF4bUv/WBSizQQKhPHf
XZ33L+s2fPvhN1c37fKHP2SjwitLsohRYe045DP+jP8B7Ec8lgplbmRzdHJlYW0KZW5kb2JqCjEz
NiAwIG9iago8PAovTGVuZ3RoIDQ4MTkgICAgICAKL0ZpbHRlciAvRmxhdGVEZWNvZGUKPj4Kc3Ry
ZWFtCnjarVtZc9w4kn73r6iX3WZFuCDi4uGnlQ+17bC6vZJ6PBFuP1AsqoorFlnDw2r9+8lEAryK
shy982AXCZKJRJ5fJiB/tVv5q19fvL55cXbBVbQKWRz6fHVzt9JqFQaahSpY3WxXX73rojo+ZEXx
cr0R2vfe7Lvt6Baf3q+571Vrob2H5j5ff7v5CDQDPaIplWAqkDClIfn5+tPmddJkW6Jxvv2e1Uij
Seo8KWjwYq20lxdtVufljoaSln7bfWZ5efsbXbzb7vD7DOd+8e7mxb9ecJjLX3FajWChH67Sw4uv
3/zVFsY/rnwm42j1YN46rLSv4LdYXb/43xf+XDQxiwMR4DI488WIroiYL8PVzQGW1LRJeg/MqMh7
yNs9XbV7wzJcVXf0m5T025WHJC9b+GeEACPC52qT1QndbfOmrfPbtfC9rs2rkq03kkvvyzqMaZWr
8QJ5wPxIECP7BD/6vubas1KqbpuspgEr8KQonCTrzL6VlzPhPuTFlhmBOomgOPST4ghikKkviYt3
7T5PUZVSB7iYtKiaDnQcedkpzSdEzJUCowmnhG+QPSSadO2+qhu62VfFlq6yf3V5+4jX2iwJx9Bk
//R9mdTZSyM7n4HuLeOSBYqvgjBiEhgxczwA76hBX3kNWHpDlyQYXwO5ZEtDF/lu39LlZbXN6OpY
V9sutcMZesX3tQB+iy5pjQJ84oxo5pb6MTmCDwCzjLQ7Ei1wGAOHQQAmO5aC0MIrktusILUKL63q
Y4f0tPQe0B+Sxj0oiixt3XtooFXX0s2Hq9d0UQOvyvueG5Yf1oH0jIsrryrpBRTAnDdQuwYtSSu5
XV115RZnDYWz/lB6ZUUj++6QlPbpQ1ZndJUWSdPkoCBhGISRP33tV2XxSF/DvHlND2pQb9a0DbzA
2dQNJNNSrAIMNJGV0pd15DsnAO8sKUSBuHaZs3UjfrhCf8vLFF3NukPTv1Jai2VccA12w3jgh/gL
t+Gq3q2eeHL169/6hryMcxZrLdAlfPCCaLURMMIjCqDh32dp9XWjfQidVZkWXYPr/ZE7Tj3FSNhX
LBC6l7AwEpahCTx8CDwyAE/Imqwks4MXIOq/pAcmCsIIamKzzY5Ftebce3QvJluiUvf5AL4ZWUnt
nDgOBzvUsWCBDcZ3FdqL5t77m5vPpEdnOS/pQVJuT4hwFZu7MaU3NptNMuTkIx0yzuPJR+/Xm0B4
5/A/994OBCZSHQhA5BGxmBC4eHbWSDHJ+eSjD2bWX83/783cN8/NLfyQhXLK/OVzcwseMh+y+/ij
382sb83/756dVYIF8WBCwKqlTz7WKHzv8QAWtBB2dOSzkCv6+lg1bWfCCUQtE1sD1UdxHGrtb0OP
DvA+jXRNdtcVJtLAXXa4rbZ5tsVsq2MbZWH8xPaAF9D5wEwQsVDHxEyS7nMb9jkkAJxSKS8hqQh/
nOsshRhwhJBTKnFkP5CjD/CqB1GvFigC0AlC90L4X0uaGLPORcA0D6czt3WXbUCieZsPq6BF1JDB
7HLaH6wHzUrB0ISsv7AeBdGF//R61LPrERLsDO15PPHF5yvi2YR2AJUJ3VKe3izZlg5Y5FvbcilB
jtKrQDz39Po5l8wP+ZQOf2L94ufXL+0bwXhOwcCf3CtookuM+bQ+8w63mgCpBeDgmLrJssQKkAbX
s7eeRGeBYj4kqskiXZRFBxKhd9FZt0TQsY69qr6nmxyTzzazWAXTfY4pfUkXAAIjZVWZYVr4q83K
rakJJJiniRgSgMvER+lRRb9NdzxWdUuv3WXbrCYghs/qrK0BhFty8LiuDktcSMGi2C4y7Zq2OsAs
gLM3SLzITeaCwLLvShdzWsBlB6D+6JBUENFCaaU2VLXGCKnCCZQxTYw3VQloZNE0BVm4YaSrOhvQ
viN0w2RZtjRg6g34/aPcojjw8tICO7ohuApXJ+FS2fIALiB/H6uyyewsgJ+XWPIjMGPpyqAq3SeA
pQD8U1RVXkG4K6tTLPmMKGKTgM1TkkkvFGVs2Cq4F4n2qBR6dIuhDB84VI6zJJt5XaRiyFTCQtMe
J/vWkf8+hDpFaFN0dm6wJiQvgzUxgTU/W/NYsK90zHg4rngAZw0VT2TAdXnvLu0LozpnGPgHMBIj
lrJjwhcBXUEA3NXJ4aQiAsGpEBdrzb06HPK2NXWiiL27NYdaf8M9VICIvH1WHCGF0sMsqY3WYfwu
y7a3gLoN5HN6glewYUBv/H5ET4Tw2tCTNhsxM0J2SmqGghohO+WZnkOWHW1zAO34DiqKMs3otgAf
L1OMF4800FlPgMtjHOMFRIgEStLY22UWF2prlvDOa6BVJuUvWJI1J4YlJFSkvXw64zhgWJY7H+pR
LCd2s4oaDCGv7bUp3PpXwMUaU+X/fLktwbi1E8tVdjTFtQkmt3mBJTDEm58vtaVksZoR/bIOI8r8
IUSCIkuajJoTZQYFpBGm6XHYUVwR2EbhGhp9usQvqh6zR2q0hkgzDYmSEi2JCbRSu7aIxrCBNbZJ
KLC+66qrU/taSiEMrqzY9UBiYgwaimvTkcEHjdUzNUmwLs+LzYILyFAakEqQ7rZASjwkDMFDl+jQ
aiC23T7SaOMyE94k9tXsAFO4oS1dlA4gYpXjKKZZjgx9HyjgTwSOxj2Aw6DRvjswbV7IgLPAsnru
yp2RAKCaPRwxG5Vt4uAMpxQxNs9pBsURE5vLoe/XpHV+bG2oBhJ5YyUHaHm1oYBIIdDJV6N8rfio
g0eoAgLpCAaFEPQcPNm37bF5dXaWwnx3BYQyBgHo7Fgkj9RcWIQlMWci6pHxfzCyQ+yKECRNA/wV
Stc0s0DC09g+dTb4NggUEgoYV0CFA+SDX0PlK/82+XTskCE6RrySAO8iZXHHJaO2luvAMupu/SmE
fFM1gDXATvLUtrzAObb0+sXQRMVb7MngG5Q1kBw2UfHiHVTjryb25bjwOYsiG+4+m8rAtUk+owlT
60qD3EMf2VH07EM5tIJHgkB5Rn0nuMY2b5WywcggYXHu2YawtZtfgGav94FWiA1C7WjZjvTxaIlx
AbwEPLbjkPjUNCCCOnTEohBtN2IBmADpRTyrFzA2JhyyeI3zRXzSClfUCueefYZKwnB6Trc32MdN
/qrK6vBII8Yb4fc9hLvNxwTF+gD5IXPvS6y+7tCh0EFTGja+Cb+gBa+uNku6EyEUCIEFjNiX7FU3
9EY+Vbtm0N2CzsKY6aEOOV9L0NQlfXuDiq+NFZQNG/YE7NUjwawTxUHFG/CZ4rjCeCMxvLziqDoR
DarTJ6qDAO0Dtanq5POqw6DJxeBSSofeb1WL+XoPAMTcm0CNF1f2hYs8KzC029tendutcQZsUuE4
yRSvriHUds2iRpQAhi1eRj9tZn5zdfGGLgIdaSuBD+9uLrCb2QsEAsOJLTMlg5k81PPyACwTx8G4
rxwp7/qYHPaJSd+RBC+t/i9LW0bPcPH2RTl5EVBTUZldELj8hNbfwDdY9wx2BZwNZtA3DEIOvE9Z
oTxgBLjhccBkhG4KSRrrelzb2dnDwwNr7PysqndnzW1xtmRuHAiHIJupvSUpBO9+Ewpx8YlIIfgH
0tmY3Q/7qp+VKY8V8GtxzUeDXULvvMCue5PB7FLqYbi9z8umKu2wsTwcnz63Nyj6j2sNhidfgZ0B
MDunB5cZELdf3lmwNbM7DjFLCWv4oFGMIwMCvb7+dHbz6dqGYahoy/bHMYH74H9+H3xfF0mKOf/e
Bhe3V/fH9fmSRrRiga9mCgGrDhfdHHLy1KyD51UQKBYGNmedlxD0sBQ4VJ0JUmFkXTg2ERluIQJk
dGXiYwgenO8OCQ29SYr8lmoVsOf4aZkMbAjsW8DdhI+voJruQDTbfb3GFniy/bZosiNSccwiCBgT
Ui8XVQyxLfKtA4E0I5dW8wH4+Wb7B6q27axmaaFsz34qqITPSx9KNu66NnPpS58M+SpDGxZkw35o
VSD9wKgAR6wK8HKkAnoHc8VdVRSUbLsjbQn9SDkzFgENcMvh1yY5ZL04usOiRlQM+Uaemmz8/xYy
6FXF8SzKRDMhj8oTtwIffqUFh++RCyW999iBoi4LACsABlwaDKIEIjdsx9lHVIvAF5/sl58yU30Y
zN5Wdi/SfGhcBWDGOd2+BtS7PySmlwff0drg4kPZYlOMe0M9NZM5hEUdWgO+SloqMwLvfFdnpjqh
WxIhYlgEtYho8e46TQqTKvmTGh7PKBBp68mMiDUDhzWDHqXgROUdGqh98IsQS/qfUI9CxuV0QS/p
a4SfC64ZjcpJiA0G3mg+4JufS+fxs54XKMqQJpsjaszvDdisQFsq9C2S7HD/A2//m36uk7sMd83p
DcjYWXJgdGuy/Vpiq9SAIhh6m7WZBZJ4m5tfDjCyum/WTv2z9Wtrp4fkr7/6pPOmOhy6EhBUBpke
cpdPNlS6MyBXGTZuf5yGwC113LvlH+Wxuy3yBlxg0Yc1i0R44sPzwmD+u1JQYCuxCqDgMCc+qHzz
Z9r4utFgAJdselDG3lKZBvXisaXi+W2d37WLZy8M3tdGcwD5KptSz4tdVUNUORhRcVfpf6pcoxjq
YT7DSLu87QC2Onlew93jOhhXaksVmmAQcZ2Qni7J9GJiF6YJ8ERJFkWmJPPVj4A95g7wNLT8WMRO
2D8olqUUUJ+sgjgaJR00Xx6DCRlsLoyxHRNKROtAobPjqFFLUVHjFIzX9E7xgTlqgxsWpnkKMg+0
8K7dQZoaYlFDMxg3EH5/PGIUqB1jGC1iCwexyp5HsUVQLKE2hRQ+/dp1Rx6AM2CLpch63yZ5Kmy5
dhGYiOJyStG0sMIBey0F1b4tps1BnMn3kLUn/u7WHAZMSIs2O1cZYtkAxeOjBeCEgGzHitCQc5cv
61j0ZzfG75VVu9TWHBje9I4wsZ+Fop7rGc86HA4aXZiatmlNPxvy5YfSJA6lrCcfjl2b/Q/1TACQ
aO+8Tvc5BsauNv4Gb/5ujcUcqlF4qAbt7scAsmdKgx/Egs+5CpXlaip0ziJIL4GCQsn1i74gO65N
A4HEtGmWgiIUKzpYBDYznIInQE4cUz7vmCIEu3NY/D45JPl6E8caUw14V7ovq6La5ZjdYZgE/Hud
7zAs4mvX+9wgKXxm0AYOmliJF+dlm28WTZAHTGmbc01ymiSfd3Xy46YHiFL0u6aObep5oG2azQXb
+H9bpUuSBYGJ6LTKEf5psocsJvRctOpZ0WrTsA8HDKghebsTm+Y2JnuFKL6lOBbTecls81uCO/yq
P7KDn2LnKbYg8Np0e2nciB2JjQ6B+cGMlyiAH9sUsziUdg/elaDLbN4kXLb/nqryQybCGdlhi8uF
hBF5Ui0MvKazI7snCqt+Cu0DpgcXm0zxkmhcJrXZ1lHh0Bp4MlRbAQDWCfx4GqmnfexbMPTlFgXE
VjEkzv9kC5sHAYuwi4HtFW6zOsSvIk/6DQKI4nmaLcTV4QwQxibpFgwgI5S4Lx4yP+w3Ks3uCghs
W6WdxfNwl9tNoIRuj0ldbW0KXjgqPJ5G+bCuKJxOMzeBheNKExpSmb2BCQ3H6JQld1L3Oa4in8k5
xR5DOLZiZ0gmcTzDpJaSyVBMSX6YyC/EzNefWdMjRWBZAjEA6gubJIY+MajYnvrkpiJ9SccvAMlX
deMe3JqdJfvIbPhX9fiZdqez3Km63B4IdWiKyJsDp/amzophYjyHga+PRGTP4aIvivlKOKI464uU
dBHtjj+2e6b7/GgPadK5kBRCni0iEVLf1ZAn6y51R1B8dyB1cvCTzt3Spm3S9BBjP+zeVvZEWtWf
/BqzHMR0AiKIbNZFMdsmx7k5RwGaS/PWhUJ7DMaq1FTRuJFtn/ZNqXHLxHaG0TZra7btcDjcfdpW
T9ltv2nsY0uKT9lFb8K0SEQ+JbfNU7bak9EBQsIJlZdPzD2XlIpjCFSxSxE7lK2K+4T1xNRihIhD
PB0xpvLs1FDORFAPTT66TLZ5Q+fB4r5Qe2Z2BVWihrpoNjsdsa+f4UKBY8twJoDXECoCz5wzGORA
O0ijP6R4ih/tQ7aRckqSvANImV0itzVhQLQ98TrTCrqcimIWaovPmn3VFXbzHSOOubjNqLmBp3lr
tzWfl+QbehwIgunWswYTL5Nd1m/QJ5biY9XR60AlKy1FR69r+n18t13vAt8J65Ah7NobQACVO6Bn
whE4mv3Did8qikX9CXTdn0DXJyfQzQG14cy7uTjWGWSJk+1z0YcSgSvtaIecnRSCjt3QZ5E7X2Eq
DOPSPkrNKMoPTiOXj4cDmgzxCJobxyMCTT7aSR+ZR2+rmvkADybzOUSCGGRWOJ7ZfRauTPrZxGZf
1SAFN/WSNcoIMEs4wywWPsz/CgfSsBbyZ/8IZ/nvkrBli1t35oRB/U86n/rKwDNwBkRakFB8/l2Q
yX9NG/bm6pvbXaTfy+Rx2PAxy9aAMqjsMoTlfBn/BiGj9jIKZW5kc3RyZWFtCmVuZG9iagoyIDAg
b2JqCjw8Ci9UeXBlIC9PYmpTdG0KL04gMTAwCi9GaXJzdCA4MDAKL0xlbmd0aCAyMzUzICAgICAg
Ci9GaWx0ZXIgL0ZsYXRlRGVjb2RlCj4+CnN0cmVhbQp42sVaWW8bORJ+16/gY/LCJov3whjAk0x2
AmSAIM5ij8QPbbltay2rDR3r+N/PV2yp7bYltWL3YB/c7KNU/OpgHaS1UMIJo4QXWmmRhDYad4KU
w60gg8EKQyR0EMYFoaOwhA9aWGdGeO88CXLCpSDIi6C8oCSC8cw04KUxIhoSxooYojBBJPA1USSX
hMWMyY4suCvrwBFjVMICjMY3Czg6aOEUsESMBmA0RosxYGrQO2UBAegwQYYX0shF4AcKzEDaB+Eh
j1FReC0IqEVGHPEecgRI4q2gCCbeAXvCM8BrIMVPDUU18sBtyQqfoALPQkIOTQLQTMQkgGJSYqkh
kTUiBOgIfKIX1kANeG3wW8xorYqjBAmtZUVgBE2ykBwqxGcHKAmK8MqIhF971hDe+whRQR4gVYIF
AqYMoIvajTRM4hTsFaABzbqCgh3FrEToCoJoDQO5wDw8tAT7aoLdo4Ot8SUCiWZ1EUihD5d8GMHI
Xil+QbgBXGJFQgY4iNeZEhSadeWgUQVbsYoI+jUJI8MEgcHFsqpjHGkI6aERUELZFu7AfLwDI9gZ
N1C4Zm6BLQlRfdLskXAkFeEjFjfEzgIIwcJdtWE1eBppw1qHTOw2IUbmE0RU7CnwtagS60ZEbfgF
TKGhLK2UiKRt9vxITKsIN4lv2GuNHR0dieJEFH+vv9aieC/eLKrxclLPpH4rfvll9Oa7CR5/4btS
6iNfZnxZ8mXOl5ov53xZ8WXcfp20X2dvd05Czyf5wpeKL1O+lC3Dqp3pu7KKx3+2U2Qo17vnMc/n
+cqXq5bxhudnvpzw5dPj13+0hA+iZwnHWyZdnbXzblPju1auacvmrOVa/pwG7XP+Gf09XxZd5d08
lui4nXHcamLSpX8w5qolrvbKa7fJ+75leNsKXbcYb9qvD57VMUbdleQRlPxht2rccyi/8eV/Xf2v
fkbrD6K6baI+cZOr7gpZ9DDcuxoWLdZpy7+P4Ra3P269bfpSue0OE09amOMW66K9HOTN/jnrT+2P
b7ouuhV6O93Ghcr2dSd0/Na10aRF/eAXG9J3W7hPWobV/oXb46JhR3R4+PG466e9qvyGkkGJL6L4
MFmeMvOjo1Hx9f62EsXn8rIaFe/q2bKaLRcieCYcFV+qRb2aj6sF59v85o/qfFL+Wv8Q3xReeK4D
Ep2OwGCOX6KgaciOZ7MafL5xdcJTIqXlITZDpuLKJA+6GagZTDPYZmgQ+4aLb7j4hotvuISGS2i4
hIZLaLicjjpSZlSj4mR1tszPnyaz61Hxaz0/r+ZZHnVa/F58LN7hAexOWQHjJfTmJTK4QNKVSKaA
KA1AW60kigVQHYunRhxPlpUcX63O76rpFOWYrc4vq2zQQQB5LyOKzA2gYGQ8AM9iWt9e13eL6wkQ
uWX5o57VN/fDoaIQJNdKDMvDOhStVHQAsPnF2KMeGw5JihK1K+rTJGOubBDvFNepUXq7R0G35c1V
uVqQUmZAtWB2rkEZTUDBRZqkiqkXTTldXtWrRUVKh/+WrwKk88MGkLZWGhTUlACEi2At0QGgZSGZ
3HZA3WJpEBRkkoRtCItLo/ch66Vj7fjA2tmLwg6IIinJPRmRkhTgsynIiBaGjJZJ6b0w3IAm0SiP
uCrHkonwVDQi0ApahATPdXEvDD+cq2pnZUpoeTAgSKO/kQkLGvEl2H2B7mKK8M9+elfPr6v5YkBE
PmX7bBBFRDzE/z5EF+ViOb3noAtUaUA4bB+T4XBPlrwMMfWiKa/Lm5KDrqrnk8vJbDg8NllJOdIZ
rOGAVhhrOUc6kmju9kCa1TOoJt4upsOhccpKz1slQGMcoenUCPw6o1GhH026Kuc39WzAlGQDgkwy
vGMhDfplGxFluGuPWO4u7UZ0tZqNr6pz6JLOKtwOt9SNDnBlhFss8RgBzZDkdj6PZsdSf95bDGMw
p+DHvLsRJG8nOIfoBywENekdWLJ6lpPrZX3Nhc305sdweIxKkkxEEkDH40LWkU68UYXwGM1BpZY7
n08ulo8xPap8//Xv//BGWggOYYTEbDWdnu4iyxtTkjehhiFDRYLU0jspJSN566mPDKbS/ZMSNEgo
53vIuELysZcsOhmU3UtlUOwlrkZVkAFF4CG0XHnwHtchtJSLl/2kBvHYIFdEiRKnS/oBLU52oQ9c
dIS4bog414a0fuDdSrX5AC+Mev2A1Rppcw9tmPW9xXu7+QFalrjps0iJuJmCQLSZgbxIG0Y6idQw
AsTi87wen1RYCujJ3n8Qxdfqx/JpG/OkWdM6Pe3WeEPxRe1aaMTgTdRm3Dy79ehf11d1Q2FKubzw
Hv2CoeyEiXdJebU72rraf7+o6yVmq4YMgyjMFactr3KboBVcjbe1UXvsKkXbqLMufcjzw/kra5+u
emKQnhA3kNMtcjxSPZ8z8EIw20PhsjybAlV5O3SVbFANK0Bgy3jiY40oed/YIyC4oP+68vQpDDgI
H2UQHEcZPpdATOByFWnMhgN04p7kBT4+OCQxdOksKr7YS+NRTKOt7aVz3IIcMKexXNulXjpOIHy8
0EeneR/DuF66yLm4h51Hw229CLAH9SDcBHKPBOYPpUWC4MOWg4gtinOVDiTmNR4OhUzolFWfpVpi
FMN83HMQsYYnmz4lb4gDirMUd+e1R6msk406Ge+g1NRJfo8S3kPO6ibFx5nzISm+NK+ZZ7uQfIL1
orzG52k5gZkGHp+mNc96PdJ6XCc+q/ckul0ZRT/0iUghPvGaDc3uBtZkyieoQdq8FbYOfjn2FcdH
R3mG4jjHzOKk+MeXj/z35mq5vF38rSjaVCPH9U1xOy3vL+f1anb+dkds7YdIQWX/5ApRobXORRjy
PO98aBV/HuLd3V27gybr+WWxOJsWL8eHVOMin7VDk3xwiWIhhGajRtv0f4fHllR8OhzRgTs+c4Y6
eXMYaRqqfAG+ZutEjqf1I1O/AiDsyCfqLhjJ/9CAlCAjFoqLJCnq17rg2bS+fIX6LNkcSi0yh0NQ
ci7KxIf+6ETJvcD7GM8T3RXzalGVczTvL1ciGtIU8/8kSMqn/RjhjdZjHSvzl8Hk0G8O61m7dChN
OFfq1EuHihspx/fScSNnyPbSGULZ4UMvHSWP9Oz66bxHGdMvB5nA+8gt2Z99b9b+CmVuZHN0cmVh
bQplbmRvYmoKMTU2IDAgb2JqCjw8Ci9MZW5ndGgxIDE1OTgKL0xlbmd0aDIgODAxMgovTGVuZ3Ro
MyAwCi9MZW5ndGggOTA2OSAgICAgIAovRmlsdGVyIC9GbGF0ZURlY29kZQo+PgpzdHJlYW0KeNqN
twVUlG8TNo6UhEiKILVISLN0d7c0Si6wwFK77C4d0o3S3SEISLcISAtIC4KkhIR097f+8n3f//+c
7zt7DvtcM9fMPTP3Nc9ZmOif63LKWEMtwYpQZyQnDxdQFCCnoaHCAwQAgXxcQCAvHhOTHgTpCP7b
jsdkAIYjIFBn0f9gyMHBICTKJg9CoogaUGeAqqsjgIcPwCMoyiMkCgQCeIFAkb+JULgoQB7kBrEG
aHABVKHOYAQekxwU5gmH2NohUef8/QhgsWIF8IiICHH8EQ6QcQLDIVYgZ4AGCGkHdkKdaAVyBOhC
rSBgpOd/pWARt0MiYaLc3O7u7lwgJwQXFG4rycoBcIcg7QA6YAQY7ga2BvxuGaAJcgL/1RoXHhNA
zw6C+NOhC7VBuoPgYADK4AixAjsjUCGuztZgOAB1OkBXRR2gBQM7/0lW/5PAAfhrOAAeLp5/0v0V
/TsRxPmPYJCVFdQJBnL2hDjbAmwgjmCAlqI6F9IDyQEAOVv/JoIcEVBUPMgNBHEEWaIIf5QOAijK
aANAqA7/6g9hBYfAkAguBMTxd4/cv9OgxqzgbC0HdXICOyMReL/rk4fAwVaouXty/3W5Ds5Qd2fv
v5ENxNna5ncb1q4wbn1niIsrWEX+Lw7KhPevzRaMBAgAhYX4hAUAYBcA2MPKjvv3AXqeMPAfTp7f
ZlQPvt4wKAxgg2oD7AuxAaO+8LwRIDcwAAl3Bft6/6fjvxEeDw/AGmKFBFiCbSHOeP9mR5nBNn9i
1P3DIR4AYyBKfjwA4O/PP0+mKIVZQ50dPf+l/3HF3EbKsgaK+ux/tfyPU1YW6gHw5uTjBXDyCgAB
PEB+YYAQ6sH3v/M8B0H+quM/YlWcbaCA38l+14sa1N81u/0lApa/NoQV8N/JNKEo6YIBLP8q3QQo
ALRC/eH5f9b7HyH/fzL/neX/qvT/rUjR1dHxDz/Ln4T/jx/kBHH0/IuBkq4rErUGGlDUMjj/L9UQ
/OfuaoCtIa5O/+tVQYJQ6yDjbIuSNCcPPxeQ/087BKEI8QBbP4cgrez+lM2fdv3fC+cIcQY/hyIg
v18xqCgg8H98qC2zckC9RhAobf7pAiFQK4f84yJ/YzBqqf67DgVnK6j17+3jFRAEgOBwkCce6vJR
SADgzYNaU2uwxx/qBnBzOUORqBAAqmdfgA0Ujvf7ooVEANxav01/IAEUQi20E+gfCw+QF8Bt8w8U
RCHb368+1NT+pfADuO3+gbwoipPrv14eFIb9e4IwCqHUALX+x8QHRJnsIP8Rgcr3b3peVAQS9G9C
fkEUhkNAvyf/p+b+DUSV7/4H/K8ZWbnC4agh/iFu1AD/xn+8rsBgD7AV3swU1Eos2L4muPW8SobK
nXNtWBxrL/XciJdzuNAMB9mjMG6+HK+blTmrVqo4082jaGbfrinrcp69MH3kvVpLV+fJf8pJp7hh
S2cZO3V3em8ywfuM+ukUYRNanmGyLK1oMbwH7TlNFFEHrpS1bY8uE6HPs5qubwnuzGQlikKqIa2a
bR1VJZnq5NQiBr9+6CCbLfv11gSOKZ7l/HB6E7QSbRKRopn+VE287QIv3r2SaKlvoH+OuJvmU1SA
qlvg2j5jKJJYQayfWp7/fqXBXP7D65xit+10Em9LJVLpbeueskXW5PMazUO71cNtU3qWxA4hO4tE
m2ieX14XNMSwOTLZVHhuwXqk9ffsMDqMxj7JhDOEQVcaRLlz4f0PGgfVsBA1z9nJrrGla1e1FBXj
kd5gFg6NeInb8tVfvvVMH2PcbELRW55VJROvKrCTZ7Ju+doE5fcyOmbNnbKETBryGgun2rXqSb6d
Ewlu8Tci5uMjcIOkVug/5K7/2Xe/6MWptxf/bf5RW5ss86xLZZRzDEm011LtnE96Yd7lHg/35zqr
tOpoOS93p+VTn0qPZVP1Pidoke97r1YngZ2laeLX0VBRAF32u632yOAYCq6WiKfvv690h5/QlqPH
WqOVaOaWXR4HkH/phbai8eG5lQREX2573WyjpwM08WB1Xlilzx+JGYy32wr25ffgo0vOcNwdSLak
aPmr8jvJAIdudPgapprZyPq929jzyVtWSUSIl0MgrmsjGomrWtKEdr6cpN9ZXhMEkmn3B23Gv4lu
lVk6bs6JYp2opprcedBaIhGAwyXy7mfm9jGfLdWTo0yJh3TGbeZ0d5Z3UPNH+7LUBoWLl72Bg/cb
Dg2f0u1Qoq82ZGV0LoEON6EvFRFacazBiYVMe9a8h83u0Zof3k8oS57I+57s43zPiut5kfSwdaeu
msf+ZUWQbclD7HYey7bmTNVSkI9Fm11MseUr1k/uL4L2rIyZgfaJ+zVGaEKe57Z4pKl2lLqNIfnM
WK98SWC3nONbNlNmANDVlDleD5Ujv5fB5tGGs87RUjuNeQxYurKWDd3LJzkuyRDC1SgyxPq6Ly1D
NlT39SKCb+TNG4dcDrNoy/j0fa/BZhwQ/mAIv7ks9soWKRbJ3FXv8CXPHvvYLPHEPcJfhvU1vAMw
aKb8VWZZBEabh+SAzbRy7aUxnamewukn+3Sd/kg/bvYr/NVV8i1AeirRvKPwqpfRXDys5jgnI0uZ
3uBsLsC6gb7BX8yaP79Ar4hwRkCUY+XSjYzBSu0N29yUGLvXyKP7RtGVJF4EDoDHhdoTi+49kiCX
XkvBNZ4YlcvmYTUi5hAp8OjXsziJ8C2b5gbxfXu169cTjA5NjqcLTObHToymRGkiK5zdQblrjx1A
6oOvnsxdpOqNPOfxHg0gfULmnBvx+mu24qy3pd7HoVYb7NAfO7nvvSPUx7eZwzs68AaMskRWBt4u
XZ7t1i9KSgWQzq7W6eV+64fu6rinTyyL4oXRZoCb9/C4D3EjWjZoqD9RkHte7TQ99A3ODUOuzxrl
B7U8FfI/dEEGL9lc+naQrI8lslaFCmPq6kwYJXk+JhHPRNTx2idpmbUuB7UQMXU8eKOf1RKy5C05
GcOdW175Ts4JurgGHGYq982DfX9s/dPbjpxfMpIk8r6Zu/zbfWmw9rH1w26MLRDE+sWY2ZJ0e70U
DuwBhE+MuiZAtqdZhgZ8dUXbd3zyAGPs6Xs1q811czy8Y8nrz9d60DGJQjZq0qbPg5eehf4zDDBS
bMY0/WFq0Fv/Gv8sAW3el3yiFFmNVP3iL5TGvHnO76wMVCirMARZzOEaT88jkCHW/v5B86Wa26G8
plYQ0PIp/9GdxB7NF3jaBzfP75V2ZmyflNVmqn1Mjr+9iHAnrX+isV3Ax8FW3x3pJuDLVVok8vZx
Vc5TQVBrHfFD8IvNdN9YDMF3vL5qQcBdc4Mq8uEP0fe/D3EXC3b4DUYADx1k48N7bx13Jd3jF4y2
xH8ov4ip6sX0cCP5SOrrv6rIyZjxNMOSjJ6l3stBXlvHEilW2/dw076wqTvLAX9Vk/KU//0ENv9F
2vFi7dydvQxbhoXteJh2aXUNLsvbn2KDAVXaBPp0wXIwy40v0mLnXXJoIuBNZkVjlii8/OuQi9iL
t1LDFDFwtMid1NYW8+OKkPvE4zZaOIYLo+grJTklrhfA+bO4GAfu+ArmSoGTB5/HSy7qv37DDajm
XFR/YfCy1PIXv1G28RDQdcieXFJh0qHGv4beqKdDPbat4TyvL04/peo0YwWgEeZ4qadM3e88fuuZ
0Q3W7+29u0aEyGDOZUZCQ/john1M6QCVpmmr61RezQHzmhXMSU8Slb7q80jXh3Jxi6CL9Y2p3Nsa
UfRKZHzb5q//jVsNHcNx2kbQw2UplwbXE6/G3bc6UFmZu5aN6fK7ZZJDQuX1i2pPqMdog33FbopH
QY3ux1QME896VufHUi3ZBhuBqg2UtBfY7HT9VA6gkFxjcq+5IZvUan+SlGkbFbZ5YxtKCXQNEnK+
CVam1oN3FUQJLqUVDVosWO0mnC/poylps7dVu/CUWanh2qex9TTaAqcFr/QoLNV9uSWHBRxIflGc
SWi752vdCpELXIczUIkmTXPk65uTqz+XiqvvG3isKVexrqtx+hWy95VgVjLpIXHvyFn42oO1Az62
aXsGw64s+S3hjSjGwwmfw2z6RsXIxYGhyKbbJ5uz6gli5q/wrLWTVVUYG1qSu170s3yjIHfScdkg
PStQNaaI97OZIsIQ4UguE6z98dic57Jgws8dgP9h+x21LgeWFM8bqSAc/KMpmcmeRU9HlsAV9XvN
I8gPuXQYe/qxJLu/NnA7KMucpMfZyK9i9chEYr8rNKMXGWrZcs4mT32KJqxS3oStUzwEKWPTPsUx
8Sq86STiHp+gDVawN8DyzuKJOOIZCtKrTjJQvxkX8DRU8/HyHz9aSdn3mW1A3i+0l7XeDDGQqPCa
4Zvt0JtS9WtdN65pq7/9ymdx45Z7C3OGB+k/0DAwLM045fpJ+oITuZGWuln1vobXK+vrQVxwEVoY
nriuIJKn3rF73uKDZfp6JFpOC5rKNvkYjTlr1su0o0lzMJHCQ10kQZG+lcCvL3LL0lGB0B4Boj4P
dfkv7TKpkQ2vbno039KM6uAA1KN2Mm16PdZ55VmSA4ecc2tmpzK/Q+ZiSkfG3kUjCLpmWmOCflxy
wRdwqjBojxSM33FilN80/jp5uBFUEuD1MXntDbwCi3BraZyxSLYUXx2dOzL2p2iTLPkJYGphmtlf
iSp7fJjHVRBoirAIwIs/TvJJb0lgqSbnz1ksZtncl6254SR2aP3QnN2b7FC0fHz1QY22wilqXnrB
vFDm2fp0x8uWiQ4SHA5GHTCu06S8Mcb7mI4YmN/gfsV+BD620VyCzI2wk4zXzMnPTEzrNk2xp6tp
fhTYY/ElbbDF1tOUR02UckpvH/onaI7mVL3uXvQRA6jd3xUk6pBZPJvss7BYbbMX5cZHf4z2svaN
/92t/lsmtktBKpNvRw2y68sJs3HiA1trz6MZYRj27/07ejfdu5Ah7JCSBUhFoWrpZHbj9STgo35R
z+A+YuNFS5Z9iG8+nkknUllu6/7ewAVtGjee/PIa4MMArjcE3L3yIA2jXDyvkqpta+TGp5PLO8Wq
KszxHPi6IJylmHz2lRxOKvvuF+om6pmXTbcwRgDzARGomLCOUaE0XlE5xgmNdfHxQiEfVjlyUWcN
kuHICGTycKC/kUsT9RfZ/Gk+zPnB18FPfUz65055J8GgkkS3WZndty1Wh8qMZgiusOVE3Lk0wuzx
uYfSHVdcKA7hNoXWWWj6y6hd+8oVRTK9udZRAg5G0F7QE53vVZcIm8S6gsJvJk7+Vg480Gr29Vc4
YUPri5j+nxS2wiz3ojjkKlyOuphDb4xIt1UKMnonUzHhH02+N3QGfr77caUDhlq4xS+3wK0fw6R+
jUxWVGbafJUbfoRd/W6q2RDrFBY6eeSAnR803C+TS0fEMmOqsUo5TUyIS0R2OhdrFvB+7KtWUrXj
/MiopwT1cYmZl4BCdAClF+Nt4KDVzgJw0EE3Evbmo8w+ul0xHIEf8jHcAkv1S8KtQ1Rr85CSgt0k
84bUo6AQQAHpUgWVRVLWirRIFH0q1ERaPQGkl2Kqg8T/RejVXvnsCdunM32xUE6FsSdrIQnQD3qW
P+bbBVYrG9uvP/ImtkmW/VLzcOHrKlr6bI4spnmfsRk76jNmOM0UDiwYklhXiJOubEnk2uM1W4LX
FonmsNAoS5aDN2afD83XTopVnn3rm84L9nUyzNzkPKjXWJYZ9kJYICx9Y7OjZ266EE3SZOYJiFZu
9JTsFcXw9mBCrXiFzrIUx92oBTsTJQvLe6cgWuHC9EZGloXDfjN9PtJKl/S6yZO9lSM5rKdld27t
UU0n9rfEaDFSqTmXc4MyNBON6wJcJQjRNtM+KjFl3oqQjzVSju11NVZkJKu3aM+Lzo7pwTgF37c4
kTyvv3E/4e6LsxQPTUqYu3G44l7zXsTeHEuEZgznkga/+dKLsfKrSFiJiTgCNtz6ebu3UeNAdCLp
0vmmk9FK13+bSoC+ND67BZgU+WNWOoQ+ucFvVR53gkFY7MGrvMO6uyMEJk2O2VaVhK3cfn5cXcC8
1MXG9rTXfbEYc9OEVrgf6v9W5YTKCG7kNX7X0Yag3DshJdvXzakXn6lECS9kJUQYT+4f9G1TMGaw
NQrGnVz228EJT+iDcOnA5WIbgw/9xw17uEqs/c6UboEKqcvDuGiFC9I8qw1FMR6QqkiDUpcHcUNN
lWWJ74mmYD9tCzXvuXuaLk6ZZM4heF2cdm+lsrm+Fak1XJ6KeZ+c6DXzBxKFduR0vinWzN+bJFrC
bnPYXuq2XvL4pGKnINEXVBxeZBpvCgfoxXf4ErTsqgRe7WTwzlNWMBAUhWGm3W71GONWpeB9jbdy
vfFs1tcJcFjCiEX9IqkfiKAq+xLQHhrs02r0fDLX4GMPy6bXwtiWk7fbx9ddmki2nKGDdCsiNPm0
6qEn8fjmYkiHyQXOjKwtfhqm4uIGLMWSi700ygfn8zs1T+5hyGjlsFSEIj7bVDOxzF3BhuW/Kz/l
ZcZK5YRF4qvt+VVFWK4c89FLuCocaW8mpuCwbMuLi9XaV3UPNF4uzqisXfAiyGjyGxavZOpsQ5US
vmjq9kVa9fJOXrdMw0m4QudXhL7KvTaTk81djtqoIpOYh8eOWSQfkmU6urxn4TWdb0/TBFNlqW0k
AmtpfkkVj8N4ks8O8M1iUg8fkj0itnjup3tHJ6E2fyelcLGuRpWRwVzLfhRRADdh5MVlNJ6O5vaY
gvG1oW3/eKGfV+4ShFXPhm6RCwe8O5PBf5+gL9zb1wONZYMhHlBfECgUnTo6FFtKO2uzHw2J6cRF
O2fHR/B6joRWkgfPNPjSfthQ2/ymZqAXxFAm/GQ5OjsJpiDa5j6QlT1GrmBFgp+Q01XeJaFyshlR
rNpnsf850YhVx2NvIX4zFqPbA1dgjGvWroQBp0VemXIrZwbYj25V7/epmVy16MFKaNNeQJGoCyZ5
b7+dp9p83a2imPiLu5zRkGu/Lp/DssZF3Eli0mM9bnj7zVu6yj2Zbsut1r6CuqtVx3ImR69jYDrI
D/EzQf65nCa/mknD/OG6lALDgY7z+FnS061lB4b5nON4ad3cSx9VfNa7Y2UTTCpsMl+OxHE3fSl5
cVb/weQ908KMm8LdpA/78eU/FjaVRvuIPyVgoTWm6zFuqGicLntGoaULk/Nza9D4VDW2M+RIWAg+
6cVCx4pDEpAOCzsM0ELyN7DFLS+SMnOa7+Gt5FCEs9OKSRBkYCp9f/XKS5hISBcOYw6tYYxwOFn9
Ir2CU/82NQqk4R/emfyYjGGgBuxzlXpsWfmDNg3/AVI9THisGpgyEO4zMrHVpkXLuugyukakmITE
TdbKQS+Q8KgpaunBipol+PbWfL1H4i6B6IY9pXJcS2QtVMZ3iCLPBH/Z04yQQ8LDPPpTmT7Whzcd
i3mCWjhh9rKzK8JSIVLBP9fksT7EoMVRG78+9pRPnGm/72T41pwh3jIKdJfs485KrGKxRPi+CwIC
+YB6ER85uVSz9GBP+fplpJnXPaU/7pD/mAjkxsYOQe9IhnKfvkGOPcH3wE86OmEfImcTathTHjE/
1xY/puBxQ2j5Nwfp3av97vBVIMXaCHGZrPy6OsjawRAmtObiqTMu3ke77IEvccyZ6RaOea00QuZb
9aJ518sqbfK4coSTFYJ+4GQwtchSrp6evGJoG/Xu3i18WIK7mrCdmUdRz1fB9KCVL2+xWJeJmlmj
yTOm4IVcYSKu5cVK09sYdlwZ90dqBXhnHwHU7+MycQsUBFdpHA3hYeLY/LfnGgPmT0z1wtP8nqW6
VdJcSWl74tkvhYxmFy4nvvqEn+rDWWWlToQZfFynh0mcs+vl109MjJ55R6V++SRUaLLovRL7y47B
HNno6sXI9i2JJhw25qEAPaEyYb9XYbEMqeNLve2OSZ3CdI8a6Gp6PjbZqV41vv2US53PYh9zZ7nG
Ri7hg4ym4rAaTwCS9AAdG/eq6r4gxA1a3NHK+3jGE8/y6Njo3ihSBh2mcJZ0fa+9IH7lBRUI6i+a
K6u1LscgUniVcDXA3EUW+A27t7jw/JV6M5cUsG6e8+vKrK6F3AO0QCEXsF56IXmxuGURPgyGrGlc
GK9C6hlqWYRSj+/zc2l5MHrEe/wkPnh9btREmVs+aCuspkRmvguspQ+Ygh57vTUM2h8ahIj2YRu2
sh9ipqjVtrZfT+lhuv98h3AJ0ytvswsUhM9uHaonMIsavojsbk2LA6zYlhbWq1tLRkeEoavdzyCQ
vuL7arKrqykqnFdA/swWc/PtIo6+1ALr6qSOJdPY1Sw0utE/dUMyUpBgpbvPjzUVVyser+xdn5G7
wBfup4PLPg5pJSxgSkZuigXVsjYl/KalBNq+k0/Z1ECNEyiDHWxMb5Op+3DtHqdOLotkEdvwJe54
ya9+XoFwu9aNvRYfFS4B108W2s8LzqYCWS0O3qVoa/c1bLJc3z/jTxCgSKo1Kw5aCA4k01ishIbT
4AgosVlIfdFR1CghWOryv/06ZLvyegvWYTO7iO6McYvWJtDLQ2hdXtgct6PWvU1irI7n2eSCWyfb
0cDYJf2MMnxAcJPecHsJbzj2UuFRQ69K857gOceVit4nxrCY22HPjJmw3YR7yskwSPP6nYGVXbYp
hSPz98U8xa550eZOIq3CTUaG/kgcennRErQoYrQQJlb0+2QgipUMDY+Em/6+p+bqKZdS1J3WJGyX
omFTwD1eUyEPll8t/DD8iufCrWzUXJhuAjTZiEFL8ZPXtabq2qHAPbbzBrWdpGn2RmlJMBfnLLR0
4s3GrRxlBSUhZnJer7/jANFe75iJH6UO+yNGty5osnxR2qxt6CLOrWfAxVbuBoiG/WW6znvdSEDI
mrb2hGE4/c67m2V/wQkK7bgxJqEZhuGkIwFOoL5unvoLHTd8SIDw3QfynryEi3xj6cDU5UZrsyFz
LQuQYaNGoF3bwmgnfY7mxmeA5GftJ6JTw8YU3hTuTyl2A+Xrn5ql3JYMBLm+H/jaLCxaxyeQajlX
i18kKiNmlibXYip0rEbvgOfjEAEvUYXxtF9NM/9Iw+vZJ5mz2vm58YNejTYmOfQZdRKjqC5DzKJv
xVEfPr3+119Bn7B8k52h1Pq/MIWJjcbs6j+9/+mc9TSyTIyF/Upxr6uWqLDHvvDJuJRCLsh49MX4
YNuXmqG1Noq3swbXfELjAsqjDdEiTvf6ENLrO9P4rPVtCRLyYdHYY6Rh6xTi9ekJnWSbTWH01qs+
P1PQAb1vHSWMQ93hTBNdQml3L3GWNoqMNzJEzB97FoU7RRCIEF4ufVFteFoc6uwYLrSAoCzzk1PD
0BS10tGX2czIgscZhqHt1hx8VTW00kzYuxfMRBLWipVQMeIwqvVjd+BGLQMLrVZ2Q9CwuHC1S0wr
vMlG+hGaUA/ONG0U3nuAqX+WxZH3MzRAD669v1Wieeh5AOXsCUNhGvJo6gFuPl3LSS3TNs7UCf50
ecXWrdHyldGy0yXEJ/0lBQLSUb6ck4yhi7/5C81u94euCOV2oI/403sP7NBKk3XsXalVByX791f1
aYqfrFoamy5p7ELXi1MrRBUvb6OAhcOGcSN1+Fm+OCey3x6eLAZRLomPg0rZv/+gUyh/bjTxKzwb
w3xBjPbi0Usexa3JzLH+NGr+1y6hAcqNaAap88h2uN2yEY04QVTpVf+Atp7GmNzS8D59NGwsMqmI
oodURFYZBNxr30XwcX1m033HiIOh7thJ0Dfgdp7q1OI+YoKU0yFRyCq5xdCVWnTd3sDo/Mr1wfWI
Lu9E+GnpeQNtYFhXM69HVPlH98AiuXK3JtWtzWSPIn6PKgt1l/K1X9GW2BS+tWbrhD8AQZQRLqRp
oeEtOsy8cUNhrgPCTarPrCYuLk+jXrOd+CBp1Di839m/2Q9XJes46fte38B+wpJ995BM5V4cR/VH
EY48vuX6uTOVr7qYYkpirGx7zmseUxDeHIUlaOkH7D2OhdAPWllNoo+abGZD0z/K77m/ahLrc76d
k0AWf2DgMuVwi8Q4o/Nktzsx3tht7p4/UnWX/zjKtPBOm3THpG7RXdWq92dV2QfVgTNezudkp3cp
KYzt5f605R6j1I38bc3LicndtisZyrXbaTsg181A9pXw77h9WSwWu0Q8i5cGmBcMhHyQzDoZuIYm
9npbQj92jJkAGw+/gxCde03jXbwS0Ru+tnFDvuEj9DLrIJxYixh6A85yLJtTzCM0gj0SBuM8nztd
iSctmkZLLxSIWoKIDzoT9XfdllWitPV2XjmIgvKiciXCvCqHcl6HqLSyOcBto5XJJaqne2lKP6b3
5igMwLSpwtLP3Vy5V6u/9OV0Oz+ApWN/gfY61O5DHqtDdSfxWE4OBK9/xQNTfqjGd5pkzHn5Wp1U
mposE/bwOKis7hp4KXmNIt0sXFswmdKpGM37Fi72xNjj79bhZcMp+RoTyDF44yHtCuscxXZ/y/qq
Dbvl+uL3gwQjVYf6Qy0BwbC+CDpOD+XmQvaL2qWoMpX8pZjXczM9+U4yZLUWV37iDd0jU9Liwpys
rqTSEucH2hqkmt0rX9wNzm4NshyagmTa6x9pNX2/zdD37q9OnMdE+oBqysAOHd5NgjFTulQJBIUW
C29Jg/weGbVn4L3moMkct1m4kc+d9ePXJT+r3cx7bkTw3Ir3ym22T1X+GZdGSfLKWBCQQku8QL3W
ZZdDfu2EBlZ+Q5rQt7feanK/IPSnc8L2sl8Zc5ir6LP2kJ2gEPtvyI+Dtlg4YUz3jWPtWyztGRrz
gqVUzDdoD10oIEEV1jKD3x4cebFYSvSUmxJOHfgd9KBJvyp8pCV2tgunoCr1ma7ot8gNXj6zxRjh
R+ghJrIH3At/7D7yuGvw+4oxbQ1oNljDeXU5vyOrj61CLn+Jfh0zR+N26vXQJfVxufbQvIUrDoN/
NzCFJtu4Y9U94iDAue7kMatZm3F1zWVAwJ2rD7Uy4q7dDDfMhL41b7kVnz3r28r1/GaGfTOe4YfX
YtwikS69YkeF3QoG8Vexrqfl6xjd7e+cYMylN24h4nEt2H73i928HvSdlvqdfrBV5R9aj6ivtBTy
oxhoifjmMBQzpdDJhAw2w6fmon9yfS6Zm/3ptqEKvtV5i42GxeyyfO8FS+4mxmEtu+WJzahcYvYM
TnAJXO9EIUre6P6J9yHlymh81q26L1XzQWx7adBIC0MSo601zr7hFzmXjPBc+ZWEc+E+uG6ppWQW
tFTXzZ/G+yg0q8ynaKTgndj3l5be8R6pEmj+AflNtyZyK49CDbkS1NQlH8Cw0qby6ru1Mk8p5u8e
cqlQf1t6Yq18vW5a21ReSOXNIXsy/+IlaD+TNP99+fVG6lFhFbOaTMKYXBzmiLZzPiDglvoGGM92
6XNRgDZU10qT+bjfTAX+FLPTsmInvZPmjpWKg+7M/TCXYjviAfjoUthIJ+RVP7CohV+Rf98Cx3zt
V+YNUf46/DEx3af5CHYP9N5RsFht4BR3SEOJvb0JaxEF9opwc9LLJ3s+CoBYg1lMsJK839He0oys
lgXt6EMfhdr9pVv9oUcUh61CmHtuAaY3L3qpK7ojt6obsvHaOV1WmUO603h0Plm8A7Ts8BUK6l/i
p3bf70GnXA9n81lx5MpIcn+ummV7nSWSXp9jxOG69uUq8r7WXnte7UfD9wQb/rzfUm9gQ8IOR6J2
ZbUyEWs9ZSO/4NS4IctzD+EqeMKZmdUkIsFxXX2JhNOm9CHqsTVopzp1y/Pb8vl3YNfzvQXtAMW3
KhQ30pB6HOKs5v3QEHlEMzW2lG4gfXJWwGo41UkRlv6Xn9WglRzWOyXajQ4MJaaZwcf2STmiM7l4
CiQXdin8wO8xnb3inRkF6mLPaxiduE0wlhq++ahKvjLY3up/Mdte4CpY+oiHznq6uG/HJTupuSWt
JUKxmdIxu/LDktdwa+NEcxn/u3gz05hKyryfib6AR8NRFSFi9GVDCFlPKsnivgJ/z4R2phIsUWpy
ksedYkL95bYE8jNmEy61dgfvpRxeD4pbhDzwroDaHc0wALDOZ975HcMSW2JZQuYpfs2eer55rhFf
X+xUOIIx6p2CraqyoPhMZ0cKeXWerci+6S0qO4s/vHTZ4j75wGv2wiPEz5DscucIez7d9DP6/wEI
zcNsCmVuZHN0cmVhbQplbmRvYmoKMTU4IDAgb2JqCjw8Ci9MZW5ndGgxIDE0MDYKL0xlbmd0aDIg
NjAwMgovTGVuZ3RoMyAwCi9MZW5ndGggNjk2NSAgICAgIAovRmlsdGVyIC9GbGF0ZURlY29kZQo+
PgpzdHJlYW0KeNqNdAVUlO/2Li0hIAgoijKkIA4MJSHdHRIiIQwzAwwxAzNDCUgj0iWdCkp3Sjci
IdJdg4AgJdLxH+Oc8/+de9e6d81a33z72fHu/e7n+ThYdPSAslCkJUwJicAA+XlB4gB5TU1VMQAI
JMgLAgmQc3DowzH2sL8wOYchDIWGIxHi/ytAHgUDY3CYAhiDi9NEIgBqzvYAfkEA/0NxfhFxEAgg
AAKJ/SsQiRIHKIBd4FCAJi9ADYmAock55JGO7ii4tQ0Gd8y/XgFcEG4Av5iYyIPf6QBZBxgKDgEj
AJpgjA3MAXciBGwP0ENC4DCM+z9KcEnYYDCO4nx8rq6uvGAHNC8SZS3F/QDgCsfYAB7D0DCUCwwK
+DUwQAvsAPszGS85B0DfBo7+g+shrTCuYBQMgAPs4RAYAo3LcEZAYSgA7nCAnqoGQNsRhvgTrPEn
4AHg790A+Hn5/13ub/avQnDE72QwBIJ0cAQj3OEIa4AV3B4G0FbS4MW4YR4AwAjor0CwPRqJywe7
gOH2YEtcwO/OwQAlWV0AGDfg3/HQEBTcEYPmRcPtf43I96sM7pYVEVB5pIMDDIFBk//qTwGOgkFw
1+7O92ezdgikK8Ljr2EFR0Ctfg0BdXbkM0DAnZxhqgp/Q3AQ+X8waxgGIAwSFREUFQLAnAAwN4gN
36/y+u6OsN9O/l8wbgIvD0ekI8AKNwTMC24Fw/2Re6DBLjAABuUM8/L4345/WuT8/AAoHIIBWMKs
4Qjy/1THwTCrPzZu+Si4G8AEhOMePwD06/fvNzMcvaBIhL37f8J/75dPXl/NUE+N58/E//bJySHd
AB5AATEAUEAYBOAHiQgDRHAvXv8sowOG/20D9J9cVYQVEpfxp13cPf2rZZe/DOD6qw5uwD+LaSFx
tIUBuP7DclOQMAiCe/D/f3P9d8r/jeK/qvy/WP7fDSk529v/dnP99v8fbrAD3N79bwCOtc4YnAI0
kTgdIP479Ansj2o1YVC4s8N/e1UxYJwSZBHWODYD+YV4QUJ/cDhaCe4Gg+rAMRCbP5z5gxv80po9
HAHTQaLhvz4uuCwQ6L98OIFB7HAfEDSOmH9cYDRObZjfa/xlw3B6+mcfiggIEvpLeALCDwFgFArs
To5bPc4SBnjw4xQKhbn9pjaAjxeBxOBSALiZvQBWSBT5rzULiwL4HHG7QUJ/4b8hARyEATv/tv9x
FsQZhcI185siuEb+Zf9WPAzmBoOQT44hIY8CbMsDGo5KZW+7AlcGJIi3E4+MBIAD2c9IMZ2KX8wX
Y/TSUqfU85UmO/iVntk2a8k5HaXPjf/wwFYwV7oLHQCZldasmS2jxi4P8EdiPQ6ZWMeoa/GynsTL
3RV/j+rE07kTeq2FTBpq3anHQe15r7x9ItaVky5XSUQtsEGrqaU0N1WDgUnMcHPpMabOskd/RXj/
5r2MJYdI/+Uw01cJWsms6hJNx+QxriXXFrp7e2ZoOu60hvqqufit7LAHYWgUH/UwKQhdKTGceUN1
lvHeZSOZ1sNS+brMBrSzYJ47/qhca88Gu7dhxnLfqSO95mYH6WaOhnLMi+SsiN4Ymf7o0h/RpmOF
LxFzdG78A83Sdlk+biWMffohEcdBOb2BcoLq/A1Y0GkpA/vG4mTxFlo45T2RPWepwJ5bZ5d/YbOR
9cM5m8TdLms9U26lCU/O7mcXBM/0NLm5H2SG+n2RJNM7TPfXEZ4tHp1b1yBLxyNhCo3Skf1G7m1Z
aEUykndDEU97bw+bcD9voXrc75RYiAeKDv7+8Y4mA/IQNe0Ttufx6evi+k+QQIxnZ/m5YEkpSTXM
w9NQXU667WknXCtF2lurhdp5Bt/3rlArhApd8aSdxHDqVtQz0DyBtJ3kcb8h7bC37go8odqfBXnW
BydfY+Ki0a6xjA5z7Q/Fb4lmiD+YUvuSLYQVy2f3/DQFJ86fFg+ZVmFWeiMJ3EN1ZJII6NY42vHk
bo9mKna+TLxWGkkdNQ/7eMU0Xc47KvgS9mUFTcV1Q0ml44Lifu0L2egUieNQt3BsbJhR1bR7XrB6
CcHdkNcLsoW312XW2rdpi9yp7x1Xa1FKy3BoGtelJaXR357rM+NroJwq9sHrOeD0Vr1hpVTC93RE
J3lYjNueZDtlVVN6jdET9vTTvTneF3nfwtJZITuQXi5aHxpwaPnl2GYqnQs4406AO/zLXv46qUeY
ikmfjZYPOwfgZpLkqFE2F4fImOzV8a6CBz9H/HW21PPzIeiIzz0iXNgaoI34zULBpxXHt4PNXb5u
JQznXt8Dr7lcv9V7g+7rZXLnJ/CNc9cDkDVXXFBvf0SfDvTE5jMP6xJ+8HUWrVcLMKHY2dry6u8y
Y2F6fWV7KZGCCZLmow+qBsqWXZgbL2kABCU+6qb0D8Qz7mSvFHQqQ8IXvm5l6ynwn6bVVxoLVgzx
aHNI7zUpmDxbm3MYkL9BI9/Lu7I5fKo0iJlv8n7oKnS/kN0y1SW3T1v1aby4daxUIMN2+xXdyZSa
D+7DrefXEPUhymK9rwpXbxuxZe+/NI2UjmfuLi5KVsNjaiPdfWFw32SxPjPiyXPTgcU8YAVW2LnN
rmgEEF7nQXnBup3Ufak45DCt5kXVZHInFaGaRteWtd1zTNI5G4ORKWiUpZHDVx9Qkyf+VPswiaSr
8xsRiceMAAvrFPQqJEmeR0BSDvuyoFbG8FbdvcH2UIvNVd4jKMENfUryx612714Rbl04Lh85RCnN
rjVSs7cShcPmAt9KcIbFPGHpYEDvjgSUfCX8gO8uqF+honPX6LpjSqw/sLMjgRtkT2qjSswnsBNj
YF5eNcIZRHHupSjStI24tYofjT+T6H9XXBe5udvNinctxjB248TZuZEzkUoCHH2TdzQ+5Nyt3Gsz
srrVfC5i5zRNf/Tnx3l3qmFGYsUPXIqdBZdzDnEGJ008a4GpUc2tHMLugfYXpGxVXSYsUy0YNVq9
QJ1h/YZvPlwL5TvpLNl8Miuan9rNtLqAvCg7QvgtqBRV0KwrQwUsj5r2iU4uzYCUUUD6AGaamqIs
bwIUYLyUxIIvYnhDPWLwY7coQNnqMepTQSQvlr//81w0+U3z57YLemk2rD3ralYZ6GM9a1HnLtu7
tlvWM7OKfXZzUulZzjLO0hHR+Kahhc+RywTAFvWui6qIn4jREr58pQ5VvfgB/atEW+MRRUYDmSKF
XgHmq2EwX+qLPecFjg7pqMQCCOdYw7Oezgecb6Pw4ZvuS4c09LtPZbiEJL8eml2VInbnjZZQrgNo
INaEKi6967tXaA9FT3klzSlPvKa8stVVL95nOGawcLcq+17pgRq33pX9OEacw/oD7Ow9r6FUa/vU
13h+HZmq+1K4cobCkMWG6ZOTQTi1TmI+wSvDNLO3JNs+JSvlq7arcP6ZMpdji5FU1cWfKiWfXn4t
kFhfNdLpc7Uvil5MDefK0akc+YnU2vR14YllB+O3yZZaOIV0FswtxauEeGT0r2vuCor5ygeXymGn
rgWMyRQPtjVE15/LBzzKv3olG2jjkXHkW9ttRUj/KZfs5AX0A19g2jJHO2jhm5SP/8aT+Fx8lh0N
um03I3Nr9/TvYqJeOWu8S18ygg59CHW5Aml4b2+KcZLvOmWQ1UjTkk3i+futW6exmSzRrog37Fhx
LIBpxs79o2PG5b8YEgdT17toEZLdYOTxXyZy4vVJnBNWyMVOyQWqW38G5hMUjManYVvbLe3tZIFZ
ty04wSach2hSDBgRHB86nD7wQ2iIF/LgbAT/zR3qb7fdZxWNwAyPz+ZqNo8Y79LkydS6/MjWEr1j
kXlycBE09uK55Q9nZBLoWPCwWJy3PeJRnrjqO5DvzW+eCgFKU5ZAC0+voo6oORM5zg9DH+/XxtcI
VyrfWQxXsqm0B0r4mJJ11UKE3hr7NPlmBE7MWS+XV1AP57/VDcF7LgS7UmmS9aB2zsitxtq1uZTp
xYWRQOWowA4fexKDHJCa4jFQ15rhcGu63WWLzO+lc/CDbeJ+xy5C0sNowKVW+Kjw0m34q3xdFW2I
bfTy/tHt9PHGkp9XcskDD2U+3BAQcyPw90eBuysSxVOYaRj0/dhJNjRPvz/z5kxt9NQ5SKzuOzoi
kmIiYvxy9tw3Aklmj96x/2bW43h1XwbzZVXssTiPOU/7raiMK+KLHhh1yfyLkeXQYrJPnBY6ZlMS
8gwK698EykIaza3wWat2FvFIE91aryZl8cBz+ZakveUjZmUX+ZbNnbMwFtqbt0W1CS54KlWLTOqe
304a5RYg85nvEXXR++IpUU91V2Ju8MqW/q2Id4yNhCNgdvJKfqn9oZlU7rf86JdrKEmHw/U4P7qr
l9E8i60XsJqIGnnnKEdqcUrjV985udvrJukf8ox///Hhp4V6xiaVj5VEpl228DxAMqb8xUfJfhNe
QVBC3pDAt5rZ6I/Im/klieYwhUJrqmZfBYCBVCskz3uPbdicHkh/jj6g4cnhI+lWywk/LeNlWI31
IMpOPQUJEd+981xd/MrqzcaCe5m2BIbdMCsse0QD5El3XaS1EaRoUn3zSdVI7jizcL1ojB7tB5/l
Ifep17aMTVRd1unZKtmhFPvM7Gi+Zi2t0WHpd9wpMeIy+X2M9CVzNMdO6uEndBDGbasUqsq9ZMaF
I0gs54O6qi+032Wi7Aovo4SIt7WWMlYfpZubk8GN3x4f2rwYkVkWP3He3Q9XC3YaiBTnI+ZRif1J
812pjyPYJqc27OF8g4pxd+fN+2Zk/XZSZ4lN7FbKByh19iupDUUtdBHFbP5sfoES4hM5Jxp9sh/O
bkw7BdMzlUrE1xwoj2BbdTe0WnSO8RCig3IT0fX5oWfeBsZ+550hVh4nvHWmqmP+byp476EjiVr7
s+j6C/B4yQoCWCQotkgDI10U6WfeB7ngN66YXbWb6WsZQ/nJGEUEENsaDL5U/ZIVH2zJtVdTkxql
t9eQ36G4qo9cwtKneANr5vVTJGpaM4+zlJiePr52ufqGIz/bk0NsLuUip6yCrIxoUP9duG3CellE
GwtT/GKQUPKEIb952CGZNzEM6fgtCjqvGJ2yDiXl+6CQb+npEUPPODc9+0SUocpZKQT9cKZUcIBU
g/wtq93EZwCnFHS7ob42ONVmfDzHbYxsM+zEZ9GV2rfMYoUq+DJhuRYN9JZ2FTAHUZ5xHE8UwaKq
GpWtjr4XawgqnM4HmOvr3zdfYNfjG5YSYz1gu6Y67omd58HTDR3Ndzj0RyhauDpQjG6o7bml9Hhm
ieStZohzzNgxrgRSndDPeejK19j6p1X4BOp2H+wgZh1aaI1ple6SOh71i0skjKRu1/oSRG00XXhe
3nzoPGyemxJcqJAjUSLjmGm0aHedU8f9ocin5QclzlB9VYPB8XfP1V4m3xvutAyxssGeDhEulNHJ
yw5aJZHZ76r4alLEsD46Myt+20gvn88sDCSc7mg7au+O5wdsfZf0i4fMsUdNqJqz1PKVCBIwdWfm
yiVk+2CVnxFqOUuW67Y/Sq7Qs3tyFi8tUk+joejwAUNCJ76P3h3FegVrPScLNlQBZ8zT+WbbcY+e
KZ7VfPX5qdAQV50jKGt8lPeuANqttKX53FcMStV2+w2s0E+cuTrpqBWiVpVEbHDd+ACbHPcG6pGr
e7V+gyha+gPdpt/5SxpsmFi/yc2yHf6SPNqvDMBnP5DciOYkQToikeEx8Grl4J1yyS6arkcCLOKS
D89vdaaf+ZCxDlmr6n7dGAUTiABN6BSvfa2WyXtGb8G3LItVV1PNftEj/SSIvompRFYDRbdPeuIR
B9+OvBP+GnxiQ69clgNn9HPtOyxecADTPY10cNGNGEQ0rxw6pClmvzRrcjKynXtC4L7YN08Ukjw+
bGUpjzdIoGX0VCJyHG54n2X32Au8JSL2uX+nszcvUAiYwDJ8cJPGKfjxSeco8hXAgfIzhV2nSBXQ
p6UXRKxi8DEu70Kwa7ypP3L+lI49HJ4fh24n1ucDMkHRjSdEOvHNt94lI2NaZ2uyr7o5Jm2/P/lx
Pa9yc0xcYDldvpCakqAXxdr65k6W/tBJ+7FJQXdYJjg0lLFX+dw3m7Yhtu187ItYWkJJhbDM5rZE
oIvqUoIE+X2k8D7R7QIlf0rYm91imrvVNxMZQrCME5LxPuQy5QKxbBVcuaHKS805CVSUvjaHsOHZ
RrU5DFX9+3BWY0AxxqrU3QIvkmggwHd6gezcQb9rdhUPcn7bYaeOKMe/4qzKejvXQa5TwGYt6dZK
qXysBTe1/36b3apqgtc3p65Zv6lvhdKMdsNZzlZMABOGWNP9shx14QpEJRUtGZal7OmACC1x+t1R
NfAIJrA/Tvqn3gu4xFvsUQd+XQOrjhpPjJDMkWWUwcldglzP3iK/npQ8/3iuybFagID9rpHmGq02
MBaUdOXyJjVjqJ3+DdNvzj6HF1RSPuKJIblt9Oocisek8FnVrVfXplV2U4om1QbefDE+NMCufyIc
Pcq83wt7lh22T9TSJN3lwGbWzCTWG0Qz/CFEoGdAUrbBQO91K7HUlasELW5WEPobXlWyxXiclaEI
NHp08TW2TVLFaa7Vfpo77HXx6gYNcNP5fOVJwIdw2TKZC00JA41bvvHEFDQ/hq/wsbxPOLdh6rxb
aq/Y92L+3qQvKc9evlsi1YPjd0JjCWR+c/Y0fZCsRDHhI1WAgPfem49BUE8ixFUhraaSU4Y3ceOo
B8pe4kmlOqfpcCa6kvRsxFMvEb4YNuMRsbp7D5FOP5JRs7G+C42MiIrNrdUP4pUhG8aR7z4aL1AM
00lNeKsPB6Y+qL4TSHkfS+lY5W6LCheQ8e7JcKBYCVXXXw8m4I0RQtFpKnA/RBy5EWlMdA0ST59+
3vXQwSYDFK8bXRtRJjHrSDK22JociKCgOxUl2rXNIe5+OfTN+8FgFFde8cclxUHOeimruXuC572P
0hLac1golLRrVGeppL5dvfFFwzFoaRxxfofb2cLX4MkOGCkodEreT8hyJiy29dKm7ZhyaVmXnDiJ
I1zqeMDti5pAgL5G1exeSSkycGZ8S/wVQV3e216pQ3mO09aMLpMOh6avD4vUGJUmB66rfDZRknMa
pUAakz85O8YejEWUto4SbonyezXdTbtavHwpUZ0ncFlEqNpWqoJ1woQQm4XFvVOkfzd7k8M00Q+a
zv6pOSGVg5fDzzlPD36NsYD5tp4ift/PtPEAkAREhSA76oJ6BSl77oEOiD5E6XnJkaev3cjHWMVk
cymtj5s4xgyHNnAk2n+FZGGrKNHXB+NF1YkI36YXAKcsU8xkjUVXajbVWE2fnrYm74TnlEG9y+L4
ASl31D2JYK+/9Df5z0wb5X6wY+9rJpJI8g7TFcQqQ9jCXCVE8/00v2tz1XNKo3o7bNUp7OVGADDK
G5jR4UD45/PNZMKzaSZypKcGxWbZ61faC7lrZY+HYjQFfK5dkuvD6FaSIOZxVZdxG636fa8Ik6mb
KbafYt5/EdpvSDYdYbCoPXmFiF74zOIRsP1qdR5LG+EmZwaS39oNZanjS+/1cKnuexFIm1TKypAX
r2ilmHdoVvuuskRtVXIozQlNkizlLKq+Ofhu4HKrxpzjG/eBhqiBzOJoAbfCGs0kyfLUp04X84Pd
TM58ZYV690qenJ6ZM7YE96tMrg9junSj/MELnCkbN6iRw/PPZx/pHswS+0NTuMpfdNspm0WJdbHK
26xFRtpGiVY+13WlcluTn1/cewJy6jVt51RJRV+/adq0XgXsMdJRwN99+aNuZqqF86dMMaJ5it1/
KN9wrLL4gpzr6pcf3ItVbif37NfK/WbvS30cjS+X1twgexNXVz/rJ1EzIWZTBDpgEo4V29WYwJbm
USxk76dXPpYPJr1vTyKJOo/Iwedko7kLfpp4ix5kMHD5DrYU/dzrlr2lCMa2kU71UoLReFpmuFmy
kkibUMQMGf+CxOHyIufCDe9TIpNRC586/1RpkxIq5h5+zCCCUdyK8GN6LuNLihmN+eDLhvbpBOaG
hha2e8v++7eODRlT7trxduTydScb8jaDa2hrPMcfzUKc/bmYHtF2+Wi/U5/oVnB4+NyTSfgU+dSS
Xl5hSPFYMXteYvDgfmFEyEOdTMuQeAWNrv17gzMOt03iZTa1V2+duk7P0DmGFM83N77dLmTqxZLH
VFa1XF/iuXLhgm2Hu4iKAki7E6TeMaiTa3K9Or+lO/e+l+bzm6hIsZ0+U1ND6KeU05T8i+tVg3lA
CcJNIaEAF+mg5ueRxg4+33mxpaXLYsihrRboXks1x9cTEuZG6kvs97WGn8LtmZQak+8DvvY+IVxX
cPWoTGvLrNfwGaWrdcVbSBXj/VouZ1hn2jUkTxDGKbAYkIZ/h6bqpVamkbhccccMvLjl5ETSRdS+
sHKik1mb7UNWb1Zagqrnol+MzMiVtORr+jI0+tX1TW0RhmwN1x/vHQiwwY4seZLO3HPpMmx5qgfj
RpYLnK5f86DWuPuy6PH4zmrNJim7R8B62+uMe2LBxXKvh6byXIoFiCc27Ezy0YYeddqrBP7KFc9b
C47C1GZi2pV8zK+p4JUaaRA8unLH3BuSuuQgVPp5i+edLhkoZDLV6ZuvdqDmsMeKnfRHpTA9cpXW
3s3xrDbLKyOMtm0DtikWyktuuySyDZSdhsWP/ek0qHfPXECqt/ZA+NvBSlNSkUvftSZvsXpRb61M
6tz0ygDW/azo6Okw0HaNyg+6dvZxpycZON3+9nPv1nbbfPIkzYZf2E/zyfl54oMPGlt6jxOZR0c+
ZsVJ+FUHZLyi7D7jYwXE9XHlSDQmqNAUS69fFnIyOxMUqOplv0U9HSwtetRm8cjtwmfUUY5UlC02
k9JeppIGI3YC7y80YGWVaA7IPofcDJNxbsG3HkBhyZ9STeQpLkRaDQcjny3Wn1X2a1TLBCmgNBSf
7efpCHN6Fg1Y4rvFzvvJykrECgtRlPYJXAQAX8FM2pJC14v2xuxK4Q8bvrvywZPix+LcZPoaWj7n
FzBbx37OuVrUCcM863csbvNWnLbTo4G/9baM5Z61zbA5GQINlQTyzx5xRsZDdzmuBeWxlzzZiR0i
Pap5TdZ2Nu7AHb6vszPfSke84CQc5JUHylS4DhQBPHtsN7xOYlh3pvemw92ZicinaTIxLPktI1MH
42syMpK5gqb88KOcZ61Y05KEoEHFoYRskTbrjqbqVys0+LwN6kCeXLyw2t5yCtjOkruXlg6p/G5O
wAJNU3No9gT7x0avJGaKVQ9po3rMZUYm26OPJaabTgo5JKAbMtUYMUF1BwdlixduTocNp/wWxzvL
rBnkoSqGrq2xWXE9DLf/B6dLgccKZW5kc3RyZWFtCmVuZG9iagoxNjAgMCBvYmoKPDwKL0xlbmd0
aDEgMTY1MgovTGVuZ3RoMiAxMDI3NgovTGVuZ3RoMyAwCi9MZW5ndGggMTEzNjMgICAgIAovRmls
dGVyIC9GbGF0ZURlY29kZQo+PgpzdHJlYW0KeNqNtwVQnOkWLYoEDyG4BGnc3d3dPTgNNNBIQ3AN
EDRIcBLc3YJ7gktwd3d3t0tm5sycOe9V3Vtd1f1/a69t35b6m5JURZ1R1MzOBCRlB3FiZGVi4QOI
K6qxsgBYWNiZWFjYkCkpNcBONqC/YGRKLZCDI9gOwvdfBHEHENDpBZMAOr3wFO0gADlnGwArO4CV
i4+Vm4+FBcDGwsL7H6KdAx9AAugCNgMoMgHk7CAgR2RKcTt7dwewhaXTi5v/PAJoTGkBrLy83Ax/
qANEbUEOYFMgBKAIdLIE2b54NAXaANTtTMEgJ/d/maARsHRysudjZnZ1dWUC2joy2TlYCNEyAFzB
TpYANZAjyMEFZAb4nTBACWgL+jMzJmRKgIYl2PFPXN3O3MkV6AACvAA2YFMQxPFFwxliBnIAvDgH
qMsqAJTtQZA/yQp/EhgAf90NgJWJ9W9zf2n/NgSG/KEMNDW1s7UHQtzBEAuAOdgGBFCWUmBycnNi
AAAhZr+JQBtHuxd9oAsQbAM0eSH8ETkQICWqCgC+JPhXeo6mDmB7J0cmR7DN7xSZf5t5uWVJiJm4
na0tCOLkiPw7PgmwA8j05drdmf+srDXEzhXi+dfBHAwxM/+dhJmzPbMmBPzBGSQr8RflBUL+B7MA
OQE4WVhYuHnZAaAPAJCbqSXzb/Ma7vagP4Ssv+GXDLw97e3sAeYvSYC8weaglx9kT0egCwjg5OAM
8vb8b8G/T8isrAAzsKkTwARkAYYg/2P9BQaZ/3l+Kb4D2A2gx/LSe6wAlt+fv58MXtrLzA5i4/4P
/Y/6Muu+19SUV6T/M+O/ZWJidm4AT0YOFgAjGycLgPV3k3G/PHj/24wKEPxXGP+lKwsxtwPw/hnt
yzX9J2KXvxqA5q/hoAX825aS3UvXggA0/zS5Pgsni+nLF+v/c6v/ofL/1+G/rfzfmvx/A5JytrH5
Q0zzh/z/Iwbagm3c/yK8NK2z08sAKNq9jAHkf6naoD+HVhFkBna2/V+prBPwZRBEIRY2f18j2FEK
7AYyUwE7mVr+2S1/4pq/p8wGDAGp2DmCf68VAONLaf5H9jJaptYvq8PxpSX/EIFeJuffLiUhpnZm
v0eMjZMLAHRwALojvxT55cQJ8GR9mUUzkNsfTQxgZoLYOb2oAF7S8waY2zkg/64oLyuA2cQBaGoN
etl+5k6/hX/i7H/jf1bwP4IXL8ygfyFcLyZAH5xfSvc350XZHPwyCn8DbC+AnbPDPwA3gBnykuDf
AAcvgNnuv88sAGb7l80E+VdUHKx/of+Oif3Fmj3I4WUD/Rf1JQZ7G2fHf1xyApgdQS4v2+xv5MWa
k6UD6L/ifPHq5Gr3jxEeALMHyOFP4F/3burs8BKG0x+T8VKU/5z/2HMgkBvIFHl2ys6UP8CqMqD5
5rvoO1fGzSHBccpN7W+0jJ6zDi3Od28Q4mnLUz4tO1yJxve1v11Yl6S5FJkjefTcb6hGCG6MVW26
93owilYb3WxCnhnB6R7O2Ret6iJCImTUENnyevzgpeVnDdsA/VOOMuODM88blSzMG9dOabeqrqL5
gaCpTdWtci55lIeiMcYIzXB9v/wJykyT1Ek8MngnRiJEOowTN7SJy6txjPThZxK5aHpk74MI9lxP
3RW2L7eTHoslGmyOrfgU+Lp4RLCXGAOjVJ5iOwlyuNOeBbkL3TNuDQK5JOmoDF8XGN8y7bAll4PV
wiB1HRUuA7M/WDcy4gEB1O+6MTdiKwrrsIwcyJSxy5uMwjCdKtitQUQ7P8zFFpuvtNrMrb4SzvGO
VT0DJlB1LPd969s876s/LPb96ma8DvraeNNX92u9zVs7X7hLmNDClZVO0lIvdGGeL5noK1yR0yBM
qzZIFustw5xLPM8DHDBQwPPTqdgdAetaDguLLg9cB/QA4RFnhtfpF+/SmhOlHysT6NM2rhgG/s/+
XErPJj+/npzk4FuySxqnBNFkJku2fc5ciqRW5a8E1Uz4FzGfrJTiMEkUupMoxKxxzpz2UORyyEp3
bE6X9YXqf3K3uuXNZjrSKtVsiuLMViXdOAhjHNyp8esV8w/s5L0y21m7Ki4WM8TetdO6PSl1DRHr
+7KqwR2Q+fmHmm96q6NyorRoGEze9fpkB5IJ+aGGmAupbV0kmraG4N36YGvegytDkawEJXXurGKX
/K5AsNeswYxEbgf+d18RnM+Xdb5slS3KNzRQr1PeLn6hTNmahyU3aumr0zp9IhB7p65xk0XusQLV
MT02uE7aP7pO4WlTqp/P0VkP4OcMT4S1iaYinV73TTpfFqQJD30yD61f0nQVrZ4jrEie6AYtH/QO
vBIjR2hhZ8ESGjqQAeQUUqcsKeTSYz1PxaZZrXmkityRRNYLljnqVy5hXQoEFgvqt+pAUyxLCIdo
7iGNbD1wxaePuUlnqkJ6it8lheJvgMspp+LSSKdHkRXYoHAr9NKS0C/Wc31oScPNA99/QjTdQQ9D
hFoXmKTG6q2MTDhVw1Rhl8wkDWDkq0CnRl95GhF9I4dWzgQ321kpLjcEJedUBEXV4ckNH8VVgUzu
pzXSMdK6PzklM/ku9jyMufDXG6lpC1cyKc64SNdT9RAKr/JnPztVgaHtoa8oKKPGH2sFUolZWQq9
EBOfBZp2bY+r625nUpb6LE+WMgKWS3d9EWtqvn9PFu7DNxY+507Yx0ExGsiA04v/cc7jpiLAwTpJ
dC7oNHwjAzWHhsrPldhQ7+0g78y6y36fpCkOBQdOwqmWcSqtHB33vnLHI556+mhKTKm//OHYV7+x
cYtDmcOFVC/Z6Fq2Mev7cVX5A3b3lmkYAcsyUfGZotytYroOS8lApIsn1zJe3JT+TQcAxiH9Q18S
GTu+4DVsXKrGmI4804I83l4fbRsDrvQveU9giLiumHRaCzIxkfs8zZtQeeqgDjZllnGtr2VcsioU
FDb3u3cl9YyxuCt6rXj7E6DBvrCbHgJEfPmBaSo2Sos4k3KP4Gu5AfxEBme7j4olbJ14HkvOMYkZ
wRNcdElNdHmoXe2oxaPPvD+HCpaFO7Pl43BMafH6h69X9U8s0p1KqYQL178Md17cQ+A19l1bYrea
KTLMlPTF65NzhuaUr6aGRXK12dxIdng+kCqYjZWtv7Pb/7jBqsUc3ismKFJxcXdIyhLTppNp53FL
cXg7ct3jS9lZ+nO0D9t1dWmVzcCuqGMZUGb0KCxr2Y/mvJMpZnskBY/LV8P6BnEmwQyxsNed6/pT
69wSgEgKtSAATwHCqX7mSlXIuD/+vTxN2uOmgHcPT7CXOmaDZuCxWfbBUumuespzQxkD8OYbK6yC
i+mkLTYcuCavlaqXTPFgz7ZTpE57MqgUL6fUdsGEkmX2GxzdnXHSPkJnZuxyLLP5ZUeqTQuliiRb
Jh+xliitupgC85ZAEc4RJ2aReJpo9vJ1qg1/mWd/KwoNeePMeziIFHwMGWIY1DeoAB5PtRm7GPS2
Tg1cmg0j7RMYE9EnH3kvO0UUI8yp8a/a6MtPhNEtqO4bijvPXL7FGRWGLddApzQSRBFl1v1M5lQo
qVOSuFp2d2LyxHVTNEXF6RHpLt3HRT1Y25LnRo/hcCkfeCQMm6LbYrJ2OaEy0KsZLbFIbTFC720t
2qhXC+q982B8hsxjv6X8YzUMnHqc3JYmqYge2KIWlVSmnRaFV6O+bjev8vCM9Ibea4Wg4/acX6hm
lKNqqDxfuvhn3CKDfjHE2D/NEfg7+FjG3tXHOuOcRgWEG9PbeBIgXoNUr6eijETMcbnYCWSWVYAu
ox74moPYRt/TB7G6dYtZiemKNnoiMMojFel7TOx9g/g9F4sGkPxKVdlxdrS0+GcymwdDxt+gYpQp
MymnrYAZmnl4iqeI/Q86ggIt0gX1BVdEyKRW7uSlbjQyTe6/Rf/Q8vtiQ2NjUdaWOmcyVhqxSFq/
UzSZMNmvv/p4C+RQZcX9PvARUMy79kErtz5/IBcQ42hofZjlaPYlGfLGI7oNEaE0ezuHb4pQIc0D
3+AL+kmRA0poblaRv4uSxI8wRWluXgpZBfATVazojMW7VYgNlzt0sBxSpJRyzZmAPNLmvspgjvIX
UVG8Xy5BsT5LYzZZVNs1Nzqb09XUs0NQ2nMjm/5UrVksfvKAJ3zsJGYwEnh2zBnJJI2gXRyZp6fT
Q1QmdzKdHRrZnelML8OtYW3RiVXUubQo9bW96DCTHke2+gybiWscvSnAqTDnSAlEgGdJKDFQuYjS
RZZISvxxo5ifntteP8fVDR9DZ00a2XCRU7JscGEnFhuDMN1ooSFBuuZ69WTXl4ZY9LVNHeboEavx
Ao8z07kz/dH6LNnduRD/CYOPR1/1KCWyXVP5coYbbC/LN8dP6FO9+BjarFJuw0cTO1+XARZPttER
NW5a7pc1c+ijqWQG5B4f8b7m27uctaGmEgVFJ17NdBUwOYjxfqbAhtTriJeKs951OhWZiZBfF/BA
jVgrBU+EyX+Hzhjnz27dm4i18ZO6o4FHmQlXOg/Ng+ZfWc01eyppvz+Ejil9+7BM1xwq0J2XGb/e
hRmAWQTr2JrHK1AjHYkqLmkcqLWbZbnS0tdJia0aOySVa6fS0rk2iu7vQ1EU1UI2ys7efK3CO817
oBvhyBsMTW28XkqMeuAwp33LpxSXe9DrOH7ZE1dHIgJv7v86xZBIezGQio3DFaPQxgNli2KCTfsY
s9J1MbD7QJnX5Dl7k0w5Lx3z16B2B50UhsEic56xe1G4agVSSF+cvmp8+zspuqIFsAbOacSOoRLg
yswoW9HYPydInVKjSqlRnjuyHJFeLXHqQM8hN/mhV+eyC/NQ5wPIu7lihvB1btj1jE6wyt0F8pAU
tKZk1sH5U/jJuLx/6ySaTDh1ZY0QtK6qyBCa7OyKE2X2xnNCSqteAS13J9WPhwzLIUjq6wr8XR3q
iXlge61Gxyn1ewefieVEZogRJB5WTiETBwWRJkEEuXI7o38kCbm0RonIU16qZnn+xNA62WSpHbL3
EefQWKE82wBxHpijmQnd0OX5EILhsnassLzQuJXFEXvB+o3CB9PBVvT5yDEeq737/AyiuwxLl9gk
WHj9y/HyxC4Zy0TEM9p9CgWRVFycJMwT1xSRSdtHt/bgmHiLBReCsmJiH2jhqPLNjIJxVP+qfGgi
mUpBwP7nK4x6NBvM114NH5OreXbumPo6E2rpzYd6PNwLXPxJVo0qxTzKfgWnB12wCbtMNCPCw+yd
N19OB3e8hwZmk/LgT+bYIifMB+NZuM6SIiAj3nBvSiHpiLirG3w8DUyHSSy9tbETm9otiUUiSUh1
IWW53akLlYr79Hpx+e6oUHIZqBfyyfxGxY3DVyYwA9trD0H7oZp/Xpp4CuutDiYZu9gF5+z5w9bN
qow+2XixHvwNa8JQ4qEpp9INb5G9EBu3XJPY43mNIzPsUWitBc1FoRu2KsMbJyG9sjWewVhpx656
Pz4SNQpeAy4sqpA7W/cyWnANfqhL365V+5V2QZhCp5qYIZGaGNDm575blVHGtE4qXyWnYn75q+Wt
o3ms41AEzC9NpWg173wK7pmtcgJXumYzSb2XjOOO9iWotAl9e4s2plTfN1DAyyznb6MNOMnmlDYj
+fROMs3qEJ6KzECwix0S3hpdHEAW/NoRUX8oP6w7iSrBMSqgQhLCvgrDGS3hGBoFzltgxdR8TMPp
juSPMCb+PnJYIC8WvHTCBeqsbVsgKY+uRxaK27H5qWofHURQnOUzTtsaVJt6W5N7xhzBj6COT/3a
sOGSb8PplVyFlcgelltxlb8kDYv0L/6hRux51Q8wXwp74qw1qBtO0t7ypwlEfXgHmdlw9nOyURBn
jX3fCeAcJPiK/CF6uvPDWK6f8EbYiAeruDp9K2G2CmvHR2JQH4w62yAKe7FcguLcr4B4G5rT8RoK
ROJGUJ/qJrOtvRKnPDe09iMo1Iu2Y35mCRgqk1C6otswXs7hHKHp/bOrc7vjogAeSxMwStqfoBN/
sAd1SzoBLYs4obNZMJ6OL0+5Y5orWV5/QHyfLCg2OyBr8M5XHZ71GkB+Pt6IbvlmQE81SMGySIdx
89NHdYcndyAnQFFFR7pwcoSfmPdVBKHBq8JRXB0onLBAEU7fmMXlURoC5JuUaCGU1A7/uj4JGavg
rLfrjtgO2J/cFhKQt5jaheZGpsrLM4etv5bN2XTyUyWUkwtszyV9PwNF0ZqPbkh5JBvX9dQJZ63L
mkKJqMtQJQg8wzXHHL0CuUCgeDD9UqU+Eeqva1UUsXedA0tFSd3dm9f5TsfpsdJMSbPdTuASPpkM
Kz5NfV5lNvdmX05I3u/P61knky5MQC/dpjZXdBxFmCB5r6356P1wVVNXr9NZE2GI4jsxTWk12EMq
8+M4TFnmGbFv8AuJ0W1tGP9OcOXQmU/0mly9S+abSj+DBXJkilmEIrR5anFLYT/ORIEAdbxHoqbD
/u9tpyKxpXipSEnAkmpfRqxEUR/T0KBdGztt6GpFmrNIeAeounzyeePpEYiOp9W8MbuXDYwLUZlx
I7WsTcajz0oF6Wb1Q+bluEr7rwPPuCx4yfJvx4JD9sAdQxS/Gct9ZWtY49S6o+R1+5u716U8zu4L
FA5nCYvn8c7I5t6mHzroOdvcP5I+LhpMpt69u2k9eKPJUAr9wymDdgvMJ3OW8UM5sHOepswIpOy3
SySl9ePpwwg8jlCJ885KJ6M0X8jqaaeHf1pgsoyuPmWk5qHLTCsUMeqIx7oh3kq/WIQ7pa+Sxlp9
LbsgXtn7/RXhZlssuZgbHMZx9oBrIvD6tIzIQpSf+bD/o3W9GtN+8uWjC7Vvjy0TBvWg+nq7RNPA
rI37AwkedyxO1mudyynxqtIu290aw9pyaWdOI+lkhJuaWda8ezQn5vAJlKeViIG1E+QVjs8VrKWQ
EKN7CSFve3j6LfMiC15LCqK7gi5oA5FjxVvjGcOxBmn5K37OYvgc1579plcbsg4fjkUL2M1FPy3r
oIOdS3zbFzc6zlpGjw/GMHQc3u4SSVxe8UVGzJkRI6jlwi4CYkWd0F/vMxZFMWDRrjUCi3L6Gi3X
hnn1JvKdnxHVt/F45WPwA9A7NeQLge8pNlwt+mJrlf311mDcwt596PHPdn8lS5Pw3Gz1llMhv0i2
1bTG28uSuJUi2kNiDVNzuD3KtUkngr7lsUSXb+h4u3M4pyuF9edZjY3PLKj1XQ+0sfONCAyB16uS
AxLsqYWQneqkbsM5rndHzGnuo/fGwJNMjLxe1FC98qHQt8ZjPwYk07LbXQna4A6AxO9eZ3psgc8U
gAG4GN5Wv75v94ncZ4duenf5uKFtHWvXwiEkbkKCHb98Y4HQvfF8U24jrFvocR4W/wsjTKh+m+eQ
xJ5RYZSqN/se9ljeWAhgXF1A2W6ckHW0+LPPsUi40aW/qdtQ/+EzXQz21KPqr9UCJRPzQPr55h9L
AWl2ZEgRs/maSM0eo+cWexaDwI0vUc7VUhmjiQIdmO/v3Bfri0pGYO7ommF6La6eOYTfsxm0R3EU
yCQNZiVPnyUZto18UADZVaZ80zw8//j6OjcmZoRb6IC2O+c8UQYSlQbTWFAqyk226ykRpCbAzOb0
qNjVc3HruJnne2/NK/v+IsY8uzBlFHbtefjxnh5zNu+95EF+wttepr1V0taRDjI6uXl17jetczrE
5YiEO3DHVvOoRFRjs6I7cq/pi7dCfjY0IWLMYQheJihlblJwuVSqE2jooH8mn8crU/j6zDGUf7Qt
nAw1TH11cN1x6yOFa6YlrTDFQL+N44hdIv2Us2LIXF/4obrjVd8VtGV4F1rJ7a0ucYlHgEShk8hr
9msQRlJy+o7ijIiQFa2AtqXxhmJziNDzdFbf88dV0MqhloTcpNfXxsb3aN6j+eIOob243Rq9or07
KOZ4jzDfsmPiVLz54ULJxpvlr8bJh6I1MureSF3f6W8TPF4bTsTCEhHAovAnIrV67akBJPQ7P6HK
OE9wPat2PY58o05VZe814Xcjr/9Cwn5Ooj7AV2Rlgn44T1nvJBeNwCz0K1P5+SiFyEFrya8d383g
ewN8sxDt2nF6W42Br03qLSyn3Y+3etuZI1L8bxmUqAqoMcGFofoVSqptsmcyE4MXIyStwhp8hyIz
Use420rPKAjq79sWWSoESmibLFe0p+D9WjjMG6Qk6iwj55lmqjRgaA3V4UYZiQMhrt6PDCghukr1
ktgj4tAX5dcoOigRanCgGo/2iasT9uYxfeTaGafDpyedVU7jSFypj0bJbm0R/rCaaV5h1O9janqC
A6RF0DSn3nLJouiTJAZsL1wJPfD1aRndw/QJTebx0smyeOOM1+iTec5gIx6za855dJ/2OW9IpZjD
DszmBF6qLBf8opWMCuFB+/SgmZty50pbdmKBGdqP/WGCb8XMijy3oXwBO8QS4UMPSm5Ks6MdKmOD
SAyyPKw0d+Q6WamX6kgwzFbR3SZA98zD0Svwk3d2p8JktTpmaC6fr3nRpG1zfrso+3Hk1Ik6Clun
IH70lF6VWd1M7INciv5CFQ5xKeEZjunBHJ7vwy2aF3y/0w8r1tHuZNFth6dQ7LLW0bIn/AE5l3YG
eRIvaKSz6sDheK2lqKgU5G8PyaoB1XoLSwKabe/5CF99mpsXNqW/olypQDpUaloQU+fkDbrxb6uC
jihKI+uY6kypstjR2G1e3DA0KdTuQoSfp6mkowCEu8KX3OzQYoeGx64HGmIpkTqUduh45ArkBlHh
OnzlFzWTFX9nzBzi543MaAWA5vLQ77c5Qxt4DE2R5yCgG/STZ8SfXtTOVd9UCRssEy2SpvbvxOlc
uMOtGhkbkDxmmxmRUeFuwy0nPtTZ0O5jrJRq+/o8h0630bZHCP1R+8ExzV5oippGzk0YKqZnh3V/
n6uFtKJfsGxCjYRzUVg09puqYfADl4xmoidaTAFDvMrUNRg+LOECnW8JMY+vDss+Je6nqEIIZ1q9
kBq5mDMHixWrHZ1ZwQWY15tUOSdz7pkQSdVj4TjYUiuctWJVGZS7OCHW/WXTfpVYjwwX5xyLtU4Y
SdJN57B8itjVktyuNYdFVkJoRMUI/BwomQT6clHEqX3DttQbEIeBQNnKL8pW10i5XocKUmiUAz16
4t+edsvtBqJw+WZBHRdYfC8kmwkBbt54zc+QlPQs+r68OvtFb9fdMZddYpDJqgANsmBTlaoqwoOb
SWegj54Ch64bNq/US4Wnrey7qnTJozZH5IN+cQiRW4JxtWlImDu02GV8GNAGyjavJrLfOPaGhE4o
0PYYdTlvUqPe3LR2s83cpzozYE8vrOvD44wVm2CFxki2XEdkkHIkwrBTI7y1bjJgcTc+8IfB+WhD
3qu3Pd5mYrDcX/MVdqDLULDMdwj+s2FJL/YooYp4H+TzbivXHnkSKqzE1qaJN5A/SwM1+8QshsJ+
EqbsfGmYsriv1Jf94Us1SFdKxSOQkjK0jEd3uiY4f2cz7ZbJpm2s2c8Q/QaqfWdmVfEt7kIAjTth
1BtuTzfJb+mfLBytpBjWwdm8Lpaxwwq224awgaempLnjuVEQUsRlQ56H2S6jCywHiezJwSdekdbs
BrGlVxgmJ0p2P/uBI11Mm7rrJSe1CRsSiitNHNFPAXmsepmRbmpeVHYDwWYwuoLs6Ts47xJLBKcZ
5wVbPcn2RKPxDVq87pNmITj8q9UGBiaFnoOwsZjx2FNj6GGeIWN5IzTjUtFNtWdFRj/ZP/tAJ3pT
xkcwx+YJNxGp+ZuGmsJRRyJY9E/rNVDBZFUuii8I+5dFxFyeLMDtGIl9/rqWz5pzga+UAa53v8i/
uBHF1Dv0CEB2KX46VEeDh60KaA2v0dnQmfIYRZQfpjVn/5HT3/bd+MTtzGemLXqoPoluw2F1CDdG
Dqk8xpj8p+zEe9tzLHJIdxK3p1RTZh789c8ErQJiVA3sBsyMV8Cd/OxETTuGrWX/RsR15txM07xc
tGFnkq+P0J98ME4bXcsCTjQ0PJExMCr6o9jV/Vzi6SlOyxSFqSHdz4EMgYmWjn3DocQ2tAvioAVC
YG/HZ6g+Qgv0VZsSTf7OKf9RaZORU0+2rugAxLBz7OVQi0Ffwy5VClRLzakvuSX4gIv1+Pjlikoa
z593Kath7jX6eEBMjW2vPVVgagC3nnPAjZ2EBokqpkgXUwiBSUXTx+REB6yEUxYeekSaIoUHCjHC
0oQLVlPZjL46E73oNJeh52PeQO+87+R6ROB+wkj5yLhvvLYLhMeRLRITzAYUiIQoek4+0TaTTTf3
+2eeQJ9vrsHWV/7e+7wDXiS9e0VdzLdQNIl+rNbdbxAa8s5FenHBGG6FOWqBMed0LiOWp00C1loG
pD9qSq4+Le5Gl4TBaHwNZIJtRiAqYqrtCmyJT78Z6QcvSBmxYXq/k4uMqnM/yv3x8eTYGqWtYhUQ
/AvMtE+HJAwOoyfnyDEGX78lc0yS0xRJPIUZvHvihapdpDlH1RpdYgmXjfFYUXidrZ9VG8wQnmKC
qSM0aXdga5gWLqyD0ZBSt2Zd4YiSxg/7jRnma+ZTIH2cHnroXPOFXSNLphE7xzDaLJe1btwKkVjS
4B7BgERQ59OqQ9S0uhFKaUBirk7SdPMVNSd30jA70mJXxznq9Hi2G5SxOYxeQ0Au/sOhxLeNnEFg
y5wRiAH2wCzSizgalpf74X6DOxWtHP4Z9kAG4acvZ5/j5q/JNHmoDH3J7cKmlBgVXlVJ5e3yrJTF
44Rd1aLC+qOq2+9dTX0xet8Got1OuyUmXq94KNlXeVgResAVOC+WZD+X1v0IlrArBcmMnF3jXmCx
cLibMr3Vr3lVoBXJmok8QrTBPjAh4bnSPrWkU9Fiki6dSOHsLOOe8CpNgodTobs25jP4w1kgpg49
Dd6U8iLzcS/rhsbNyJFhGtemkQQlvX4EUbb5oX3Sa0r3g/vhum0HYoQ+FX6Zu45sJBqLV9ydyKLu
hBUKrb5ls6Z8SfkwjWVFMupwUmR1xJY7+4H29BIm4hwjrAkex4ZEogXzZ5M/GhAHHHdg0XIYhZfS
YiTj+MhNPFbaOuQNrSs05UlZNujOCehug2uOfWpmenTnhAn0Naw4d88CFHGbFnBDn78vVcsK0h8t
umFkpaprfH2wKz+BdzG4JDba4bK5s4X/vGt29/hpg7LWQDhCf7u98ERB5gBm9bDAM5zC7nPGPtlo
92PFB7FymBTao+n+qtszLhEhWfexbJAdWoCLKt+96B7IpCtFn+ZGZxKnxuSHTcQWl2VtG/EK8eVe
Emf8XMTs22lXOP8yMK39Woct4YUgQc0BwiMMiKhSyzDgG6xRKvTNcdE35MeVX3SsDN+9VoV4uqF7
0RSNE+W/ibrp1t3xufQmi84PU+UG1P1sMOEX/KgTjyadLFYFy3q0K3v9xrJCFlq+dmerSSrnGJyK
sIrTIa4H+Yza9G62vuzt2hSWoBYP/j7BIs2bs7ihdz0iB1EZLkpR1FOEm7FhGNhbssbXqRpBws7S
hjHfRYnUm5UXYQvLt/Zd3qiFhnpVbH8JbzGKwwB9pSy4pVH0wPLzzjBD9a713U6Pon1Od7eTaYmY
m1bXVJPQwPFOkiIeqAVSZjCZctfxDwK+ZvGoSwz5Hjl+/nU611Rc8ioet6PQQJq4LNV/y2x66DpC
dYLR78ktWGMF9cQ5RQ6cSlTcs2xxE/Cu6jt10aWNZ6jE/pZnlfzB4cMp+dZTLpK4VKvVCcnphJvc
OEf0/D1ukZVI/huzswKfKGYaLuxGbgvBu9uVsYN6eLiyclhFlVEfOlrMWl4HtAsLza/evXnTS3Dw
C+rq56N8U+b9BTddEOqD1u9TSB0TOwVpJSU9w6gKwnDJUHgjg0dKvsefIUntlpr0MOYlS/0YEeVy
bddWDvHBaoPuWiW9/bG0fhZD74QFSCgmh/2VJBskKunmkL7faEUWqw6MqQ7wGXwtlSlML6P5JjOG
N1mDGRyCt69NPxjAQknNYqahminK3MXsVT6LY+1isiQXVqpWIpOvF2morL7rZhCIuqee8w6zA7HW
YIRleS3+2FLUIN11lHqqD77+WDe0u5gfbqCy30RmVWnjTdUM6HokKfzYr1dDqEht7I0w7hoVgBR3
+MflTXVukqemAGJRY+xnMW3pujbixVzKstpgwzniG6u9wYKThu7ziojTvid5D7oe7ogKz0KY1M45
BTb2ohLZ4RIWwGLOnlU7EH6qA8lynHgYBoqi5wSdBhVqEZQZogtBhL3O5nak0Q0vlvgi7IhGgoAX
cImJ4gTRgMJvuUvrezTD21S9q3H4DgOxCArAHZ1XEtH5AaZbaF+r07H2lLduNK3Dec4KR1rn1ZK+
g2y1DiqYy2maEkwdNRw98jjPPBR3plXcuQXK7oalQ9XvED6i2EA/2HCstAca9LiUBfeYp0yMwHDG
ZGxqUfaFg7FIhOYs3ZOrkMyxBRByxkrHMg1OeZK/QBeIU7TukXsLHnWjxQ4s9indIeODLGuuCeBj
GuNYvk9R3ea5ASI0sz8nzk14slxIfC/SM2eMHHRl5Nt+RitFHTdrsEwiv5Lrgmtam2RxnkkvxPGj
mbsYav0WR6ddFIg4OFz2MHCP5+9L81rVcdg+vFntNeEsvw+/vFvZ1WiCvCT5wbwpZy1f3KTjrqcL
VjqhQ0DBlNKKcMcbJ2UHUZ/MT5heP3LUjZI7d9Ixabu8+RiYsTcfxM3oERrHexeCmiL3WbfNGdB9
Mt3UZoWd+t0Bn9N22ge1zKXT3JA+yHrIidSy3IzgO+XgErgGEItb5S3shm5FozuLbvH6WpXHtG4u
7eB/DdkOIvDkpbx/4lMSMi3+Ah+9Xtu4Mvv+cXUV9ld3irKpkiUagLqiS+sw2Hl0kUoMOUCOWKBn
y/1klV+iexPXPh2q7JkKuEJSLhETO6Mm0DCNfmZTZcoX7Mm+GkSliE8T3lqXQ9QjNkz36v3D/hOs
aloyLgeV1aPZWt5oNnX0InHfkNyOF9z05a/rBS9NUR6HDi2j2Ng4NDSZEsaIN1Nu25ohbjQ/OUic
zGlvDcelWpeNNKYmgHFFBJNTCkV7tOFo/anvTwf0NvPuVfaPtYAB/tkMxb/S4aqDhx90ozKVYtZj
NALW74pI7+Y+v7qe+3SJDtI1OtxjezupPHYkn944CEuLVyaGy9khFWbc5CtU4JE3pWb/9vL+sOML
mTXmEtlHozf8qL9wF7IvqhO4UXylvT4QRsHP9axQ5jtPfTnafp1hYOU9bt/zM8spEz9hWOpp695F
hS9jv1PPfs2zVtok8hpE7npIUYcs+e79fCVoWx7xsOVGFM4vHuMVq9D0lSNYK4zb0HjjUBSfeMe+
mEAZjhHTHBaZW3O/6sEsKqqh81Nq3sCepfyw6lSGdc/UZ0dhNjVwm8Cr9qnLYFgt/LD5BPuPLbI4
nwjcng1IAls2o8DN3qYa76NMeZ6QzX7VfVZD4p/EkKxixyaqiSg49UqPMlrMlT5Rfr19kOfiNTpI
FhW8gZSN74fhNuOuUrswTGbUjwoZdyt2RfPRuL+VgmOr1oKupHyfcLnMIcGWOhTGgmqXHhUNcY6/
S7+HILwuqNRegf2ogFTJZ8cn7KV7ZuyQn6MRdbgTTYkb73JVHEt0eV6OhFS8KPVj1sSh7TTmOTwQ
QxfZQJawx6ruaPwwesSIEy8lfzHyC5mnKgeq0b4pMo+SFhA/iuFd0Hzf+nX4e3vyN6l5Sc0MiiNw
VMcxFSMsp7uCCDta6WNFu9oPpNHP2FWcXOIeSOHOBPddnjuvZouAmrIT+4fYGFEpyZN5Qa8nNU9t
1etXq4Q+Jc0u5zWM3sKlBY0K+4R8DCLNxf5u+L7kc+a75evn2PvgxiYMb8NQ1XaD+SODcu+mE2Of
+s4jQ+MvormpijWrwW+rDrjfGNJ1Bxk8aQqS5u4mVyvgXyGFNtvOLuMdvG66RXD0TdO/o1WkIZVt
zG9KTIDzcRE4hVQzv9JJZBSFBj9f68Xq1DxHlQ/LCEOBtmymXIhCaGr51H/Kpg5VH5JrI4ivPzu9
71egUBeQy+uwOupa8Kt9rZKRtCLUk15zpnlf1g+1U/15iWJQ5vu4NSEeRzwRr6QhVW7krPCy68N7
4wosOHc0EUctH+mMN4+G8qzIZ3XYDUgtAV6EsnmyZnWg/HqMtQslcwU25Hw3xZmf23GwFboZYxjc
49yCNtUHIoHuUo+hQpbheoZ7cisued/pXRzH2RTQqqxp37Zh63qrtzXxidgh/1iggudaMQZHsut+
kR0Nhsy1FhbxcBCiqtaq1X/DHtlJGE6lvxxhxordTrmHslbCY3DjEtlVZC5Bd3YXTgtvpS7Wai8t
udVZol+4r7O67pQOuUbor22YbpFXkPG8hfsWvxGtATeUy8JWft2BwN8G80ppn3COZCa/dPfspPSX
JdxPWCE/tPP649Dv9CZDiRQENWu0LiHIlppq41A/i2n6G5FQpikYDWM9DdnGznksmwarwVNS74Tr
rGyNlHuqvHQV5ZtrCvu2Vq19cnOOxckQ2boaXMeQ0sOqk1SVdYUk59uYU2AaVzXDXWWhZ23oXR6Z
suZJaDC81e8qUf05eWaZHJAqB5a7esoHWdZ3Y9Sqgzi6zFWc7YqpWN/qffTCscjo4JxDVgyy4gEc
whZxX5xxKjDEzpShCw96GI3N7sAzKSWJ28E3YYuLM6LDsPnLu5/VqgjSq6/BPi5AOycE1UVXna8h
nUKmfzZbc9qIDhUOY0pWh0vKl5lBgFafR8i/+QDorDY9s3tnjP1phg5Nlv3Z9kNb+UmrPpZhT67w
+F7XHrGfZQfrCUH5R5H0936q++l+CTDScvJ/1z6BU0+VdZRE29wGxsrTIDqsIjPtkrEuO/GmK/9c
bZN9k3cUMMZw/ranvjQy4lTFQwSvtc+MP5tgAzm6YCyHMf+6ogHEvJWZLUSuLK1pE2uvDLAxJLYC
X1MUQ+jcW/QU2Y/KZib6Q0LVXkl+IRwn3rufh9lrgQwIke07/OhA44Bx2dddqoiiusCpMjVVSx3P
T+pUYNwFh6dUCeJbP4jfGtXrwmCdfcgmzapSrdQcU4pyioVqwTVobPWjCG0k2ZATjPZadG/ZG8oS
Ia0TXBDYv+zpTD3lTzEuRn8anvJX7FDOwKjhrHTe+/Hu6lk3jn0xP+6dCFEjEJyvWYD3+lCYPwXP
1vRe2L3lyJ6FrDWYZ2Xj9cvfGOzUz1s3wwip6tcY4WSTYQxJaazclSP/B8YtRmsKZW5kc3RyZWFt
CmVuZG9iagoxNjIgMCBvYmoKPDwKL0xlbmd0aDEgMTM5MQovTGVuZ3RoMiA2MjY4Ci9MZW5ndGgz
IDAKL0xlbmd0aCA3MjIyICAgICAgCi9GaWx0ZXIgL0ZsYXRlRGVjb2RlCj4+CnN0cmVhbQp42o13
BVSU7dY2jYB0CKgwxNAxdHd3g5QwDAMMMQMzAwyNlLQ0giAhiHSIlEgoktJSkgaINAISEt+o7znv
ec//r/V961lrnvu+du997WetAbIZmwmqOCOcoJoIOFpQRAgkC1AzMJUEgEBiQiCQKCkQaA5De0L/
oKRASygSBUPAZf9DroaEgtFYTB2MxqoZIOAAXV9PgIgYQERSVkRKFgQCiIJAMv9SRCBlAepgP5gz
wEAIoIuAQ1GkQDWEdwAS5uqGxkb51xHAA+EFiMjISAn8NgeoeEGRMAgYDjAAo92gXtiIELAnwAwB
gUHRAf9wwSPvhkZ7ywoL+/v7C4G9UEIIpKsirwDAH4Z2A5hCUVCkH9QZ8KtcgCHYC/q7MCFSIMDc
DYb6A5shXND+YCQUgAU8YRAoHIU18IU7Q5EAbGyAmY4+wMgbCv+jrP9HQQDwV2sAIkIi/3b3l/Uv
RzD4b2MwBILw8gbDA2BwV4ALzBMKMNLUF0Jj0AIAMNz5lyLYE4XA2oP9wDBPsBNW4XfiYICmigkA
jK3vr+pQECTMG40SQsE8f1Uo/MsNtskacGc1hJcXFI5Gkf7KTx2GhEKwXQ8Q/j1WDzjCHx705+wC
gzu7/CrB2ddb2AIO8/GF6qj/pYGFSP/GXKFogAQIBJKSlgFAfQBQDMRN+Jdz8wBv6G+hyC8Ym39I
kDfCG+CCLQEaAnOBYl+kQSiwHxSARvpCQ4L+U/DPG6mICMAZBkEDnKCuMDjp396xMNTlzx07eSQM
A7AFYYknAgD9ev59ssdyyxkB9wz4W/33cIU1VHTNLAz4fxf8b5GqKgIDCBIUBQEERSVAABERGTGA
FPYQ8k8vxmDYX1mA/rbVgbsgADJ/ksV26V8J+/01fZ6/FoMX8E9fhggsY6EAnr8JbgeSAEGwPyL/
Z5r/Nvn/sfuXl/+F4P+dj6avp+dvKc8v8f8jBXvBPAP+kmP56ovGct8Agd0A+H+rWkH/rKsB1Bnm
6/XfUh00GLsDKnBXz383EYbShGGgzsYwNMTtD1X+4Ba/FswTBocaI1CwXx8UgKAICPRfMuxWQTyw
Hw0Ulo+/RVDs0vwzpAYcgnD+tV2iEpIAMBIJDiDFjhh7kwAEiWDX0BmK+c1ggLAQHIHGmgCw5YUA
XBBI0l/zlJACCMOxkX6hvwFxGYAw4j/v0gDhQCgS8Rv4R2iILxKJXbzf1MDm9a/77y2HQjFQCOnc
NAIiF+XeENV+Uqdy019wdURhErhq9ZBXMGgO+cr3jII4k7c2L2IZ+UMlc+A11cJnDZ4j5Q+sF0Gb
rY3E99vSTV7+DD53SDUdX31JOjvG0Dtasqny/O1tkluC5sprwRc+wZb3PPBbcTt1gYU+vtIUxsW0
J/49Wpjnbyvm38VMr5qs1UrqkZ1XTAgmWSTa3St7Dyxyyp9iZCdCC96+xkezh6F8f/RjkqZg9IpV
N5WfNGQrSaw0yGZFNPl0KnCxylwU1cXEyWTDeBv/iObdOFeQ6nqW7o2ZoGely8h32VMMr4Y/emWI
eK7zBK4amp4gv32/ywUcleVhYhTGp9NJSFxu007zKmNLIxLP31vQXcbofJdqdUIJGKXBrow8pRoI
qiafsq050d3aYbi7ubw23jgiuKGhSCFWhpbTIk6UX5Xz3Jd9Q3JSamSWSVX80YzPSOmNTHvh6PLc
x5XswzqagpNE1vFbgpf3CX+WE534AwJcGaVx9FHW6OkWjQwyH+06b1CJ4tB9ir5V0nUBn5WN+fjW
DEqflLoYOpIqL2obdXupwbZWIw9BLYdFu09mQ7R1AVp5R/qPDy8ycmNSDJmlz1wfbYmaEIXIfntT
QrUWfKYmfFVYWND4jvnn+4FUz+vj6T1JanuLoo5d4cn6vmLDi5QrLxnURwiv8VFOqfWVS7C8Gs9Z
Rb0f14+0YPJg9NKuvK7pM2/uMmjDuX64Vz0RnLOw1iL6DuP5ocbovu8MpiPNVWtdOBiXSHaLyxAe
tsepO6BhsrYbcP51KVL86uC9Yrl3APcXFrGHkVfusEWh+fNJ5r6ndwiGZELjP48MO4HIfNfyneQ0
K6R5jDWt8YJn6NTNgGkBCpcxrnA2k3s2WffHHj6uqzCCPYuN+bFW/SxFWyDmK1jK8Sgrac3BRn6f
1jV/36bzYnN4mKax4iGUaLmgICxsqiDCJzNWOJTIndtWQ2SR5OaAv6tAv151eMYhBcJrWtFAulGu
DlkOiFe7Q4d/u4kl5b4ltQc9neusoHBU1eGGqfIE61yw574Tjto94fbRwIg6vSIWB4KKGjyYAPe0
yKjJfo7U3XSxNo3Wk8mK3a2whNsynPhdNt9pp5wD7D3RLMlIqkJqhQLG3NxBxURaOr1w4LsJMJXI
K7sdHjTlZwYhDZbAB1Y8sRwRBobvUpskP4TyzWjITXdejan1MhXXgu+KHAdIlC12cru1BriQ1qOo
qT4ISd8brZOo6YLAqLU4JYZcQbt65p6X+N7nM8pzivZMVy6f5vCsJr5GzUuZPNCy3MxYqYKXUIUO
FSjYE36zSXFMpC7eSY/hW8MLlSJbZ39MWXjtwYdEyNrssf9tUEsRXln8hUWQdT5caNABo9NpXFhd
Zv3UxJ7Z8UVqOUGvgSHbGFE6w1H3xzv+32T31p6bysWgq3NnGfPS+e1dU+s2aG3e0w1EX5JfIFD+
FenrJhb3ePOapRNq+sHxn1Tugvv8FDG9ST1D2hHtDvDBuVCcezkJIUy7rFcLYQlm6NxBrfx4qarr
E3rtjFKxoh0u+dVqj2dhIC16LxFfpYjIG1PicVxZ9ptfPzysdR6+0gxf8PbaoCVusaCppXRrKZxs
KOhm4vQvtavVdSaW5u8yK9RQKOu6E3cFbx6yTAVOzitN1E4XaA3aikcmvlEf5Z3fnnhAlBqyESmf
9IJ3C+h9laIO9EF6jCO+R93h4SJK7ehrghDE06fI333fZhQpp6mDX1LUbKqW81XvTBDP5ci9/Wgn
eyFwhPhlc9H4GMsCIG9z69ztcyKKf4UvnclCMK+WdZnSrueC51a3grqtM6/y+RKQAB1+lMXL8Wwu
Lc5gLltF4VTCkPMZo4hJtkc1pVvlWg9N8K3asFe8Nv2Q3QX6mfYEhZCUzFHJrrt47/xLuKG+710I
tWvJvdkwQoddxOwottNps2fesw1+hjjX+rMDpDNDfwBzH9+PHmOgc9j2eq8u3dcSi/xWN/DcLcHf
yteh+/OU5GtbhqY0hSbSZMs++1vWlS2iSsB20uq2txu88cJ6phmtYcFQhZ35YcIK/KI4J1yHqKsm
kNl61GCWRFt8tJjIbKfXAGZNMev61MNGo/wzavq6LpY7bLafI+ZmCwmSHU8H/AhcvgeHfDQ9SyER
Z09gIArlpSbypd/2u76swWlRmdNhl/DCSm4z8THzhB6o+rrkS87p0rK1hJRqYw+lt8MBLwOuYsWj
22jlCX8sLu0NpfkoqGlxAvZuZLUoO8911xM2hx4MqIiYSEeoCAYvxzmJOAZW17vjABpTsuafntvY
URUL9SF3y68Xhn7pQ3XmsL9w2rhhbxqQk5PDhexXB1G56eeaTfFuVAVKGqwpfMqmvWTnbjUyWs+6
7MX2nyRIlD+Tk2ryMKROfmblZdr3QSvHHw2n79+QDIg0KHDvpeQJTC+6lb/5HunR+2BuU81FI++e
xJmmffxYQkAW3C341jvnazeIicaEeTpDuS6/dhnXlarKvFC7woQnypCeLm2QPAAyfjwWkCkgxqUe
NbqmtzW5rc/4cIHA7xadtkAineJEcvRh4i0BycYMPHZ+9d6WA6Sbvrw9sQq/5Jrua90XMl9X5ztT
dujDRI/d5dmEPUUrn2S//rLRKcHcm1nf5XpliZvWR3JjlY+EbilPWuex3ijE7jBvy4j1PL8sZjIl
JMQ8a+OYfvEnrUz+LfUJnm9DELxJmd2ihyjoDFN0vv+26X1pqUW2hpE6RCoqrZXRCZ1xPVS12LDE
mPWke0/7jmv/MDGH6nPgCD1LqvRpTEkm7FNBRmvG1uG5a+k8uVZGRqpkhtQllUi2vCn7dBK3C7xa
UDTPHMrb3Lf2RMWqN/iemPyxtcDjzKZTdacL/5q4sNFw0WjQleXOwgyw3qYml0zhNnPVpU5/dF+R
x5na+faudF2EsqJJCItTtGaRLcEG7UF54AG3dyGX2SscPotGTpbns1ksT3CSI8COpuM6ClOPnbf9
MhxYZ+1Y5q3yy49VV9qO6h1oX0k0lb2F2+bsL3N9t9i4aLoDq977lGr4shbiO9KJ3POj0cm2t9R5
tlwTY2e2s8Ouk1xDtOZHEVaAIiFK87H2ziMaNba/kgi+wg9GGn2Iww3HhUC+qYLoD5L0LINnCjdj
xI+XQGpgd+9PTzdRA9Iqvesv87O/Unwe3nhxVWSNJy64Nbmp37j69frz4dqePTwY2e7ijqZlfRCw
F4N/U4PQ4Xp1Hp/jmL7RG4utA9K+DL3Oaq3Bgduo4LAKL90nr4ESTIu1aaO7T51V/GjlmdxXajoi
GggFrQgeb8suUwoo0Ktab1RdehVVrDzcgrIjJdAU1ZQ1xeED22dvyxoIbm0pCqz4z2F0HABH0Oeo
uGbqj+/mMFmmaJzixlITaFw7oZvcFUDQljlPy+V2xkQULo9jEd/pvvDndp2GIP89cdhDIzD7z6ue
pF072oKVVmCQ4Al/0ZljpfTiR2W5N842RWH7zP0seDeXbmIKDqy4GVf2XFVwU1c48f26fMaAeLTp
CgzKlWQA4wA6B/+ysW9lHeFB8VWt3t2SecvjW5cU+njFBlkXXikGHBekpqTR36wfhTW251WOc44V
blWH78YcEtzsDX4q2ZoTzLqak9L/QOsBnU52s2OPi4fPTXCIMrqF0IYrnzv1tcKXa2KlUe+dCHTK
XG9ZPJa4FgkNr+7vvShXeVWL+6UwhEbgvOw771cGWRjTtV7InpuNrGfnt9qJiOvymrlS7wmE+aUP
ajvtija7LYWe5z1A2HncKSGG4rYXvqkh4Kd50jvMLOlfqtoEU+v2NnpEVk9DqTnYnW2IUbcfLpBn
ufGan8TaBjSLGcm53b9BcN/WJnQ6IqPsS3RHjrfSyYFTs6RMyj3VY81nAoxayVLgnRvdlkTW0wtp
PzfRt8hf48f+MAjzgyiKMlhxPBOrAn3dRBpwVoNJrsh1GLz8Ho19PzPa6GB/JkBKGynLUwhU22xb
2i03gDUr7w7bHeXb1hMdki4cJcWhMydW6BXWkywM9uG2qg70/aJZDvhJFMpw34dK+hMC9OpWFnTv
LhPfY1pwmBR8QzI5vJoyJW9PYlTIb2PuEprY/OQH0pE82IzjC7oxGj/VjASYapPY8lkHZLeBVmF9
1SCwE+HFTWOp8oGA6Y44bz8WjzLzD+9mzE35gW+lcHbOr7E2LLDF1X9gdDlp1KQEuGotreDkG3cl
iCqZAWmDm5yAdZ8vL7KLtwy50L2yiowaRoPWurq7uoRXJWk2yekV365UtQXZcEID2ieYvKfexU9U
4X4ujIpdma513ianDhTeKDlbFitZcadPLeHr4rmti2v86C0nd21JtcoX85Om5ptDFRj2preHTg/F
Q8Xt71BMta2ldRzffihTI2Mu/+p9weAjvQ38J9H9BTIMtjpBD43PFCOZIyUoTH0hXDw7FQw/JkEL
FX751A37hQVye0HfxC4wBCEvHYBCHQROBVCrwh3qimJRqBlmSx03QprlSeVNxFbO+seg+Zdd35rX
80KuEXX6wwWsjPcK6WoCH+FlJebJTfObxqKjLYfv7H9WGCazm/B92qaaSfx2+8CCR82vF99fSXuG
xB19FYqjXlDCiEFvn01Gtp3Faxin2fZjKHEqJ4WTGqKKRJsjeGvG+Vcam3MoCyjGB+sHMNHvxFOa
j8spUiR1tF3rEBrT3PeLZ+ENTms3e+w8q9/pp7lB8DbPnYQpKvRCPDYscy+X1El8CykkOfjnvzHK
IIgJq3ZeD8OeM9DwuAZIeJol7N9v+RnU0UdMZvNqhNUkjjyxGZT/wvnIO8HKVVA/xam0wPv4J1OA
3XwgEY+raZnktRXobt9IV5Ve0otLrRtPFWQsRBfL1j5GMjxvVau7eMpykDKlTfapG+GdjOQ+/UCg
abY5wE9u8WpgaIHzpKlvpI2WiazVTW6OZEwHtyiU+N5IVkmELAtC/aTf4lU1o0blqWZLAEIO9OEy
/Pae0tL8xLyX8ZgiM/sQR19m71kdOV2yuYQuGx/zSdjqjVOzG8plBmtSHNJc01uCT8tOCwPuwc96
ZB4tHZ6mT0g012lF1ZsvTb0fiLIMIz6kIT2uzN7mt8KpN7NlNtrwEqNPNfZyjvsmQF3Jn2EWPsbY
fVG2b75VFONxEnBEZSrPSUY//GUxnOSj6BX4GtfEjxaGgnuzCqVq7wt/7NZ9NBwhl2GQauKoaPgU
OthrkHB0lLdgXt+l1KgaSP99xnR8uLWw2ISuIbCyfMaehhaVUGG+uXc4aaxsHJVDQRKtJdi3BDCV
MegMXw2sXj0IX+UVo0zJ3TFo/0Fcql39mBhz8/WVJTdxWqkQzySq7kxuZSh42YHIyLxg6jHxnc0J
GUcWLcKo6+ecxlZzJVDr3cj9+XEFFw3g+xIjZqZkb2f10kWvw8B+wvLpHvuPrfQxDS+mSwkDu+7r
ZfATYHToLT1I/YnrZQ8PDdqIC73GZ8SHziusLTs4ik4/tbXkthqcF+/ZPz3h6yueeSLzmTqWAH3K
KMGB9PrwiVtjBkqB4BzJLS7LXJzgD5SGCysowd3HnzM+HuepJp7pGeIRYMh9anRP1J/sm7xkkSYc
UijCtqrSGnjTcsz05hl9j07Oy43ZBn5zjy7EDZmah/OylMsDVnansX4pQlR4AeEqEvQZa72vXb/j
uNgruUvyXvViHlUEzLMZPpAoTnAVmJQVzU/Ijd3RTGqnBn71ndJw3KnZxplUXceE+R9f41msHYjJ
5WqkuJt7MByRH0GXYPj0yHJ0vX7+ccmoSr8quQc/F95r5QHu0fGHMajXkTFtMQ5ybcQ5Vc108T5H
PA7lFy35stvtQnOyvDsRDCy24yTMSgROl+i3QoZ7T4mCu94bz3n1hrzuEo71rV3hkFJht6h8w9sU
ZW43Y4PZ1CZHIkIQovN3CsZ7hsDCp377r+6pi3lYZB7adk3M8DMLbFY2TL9hYWQUGMK/ZkS2LQ5c
vs9JSKvNff62Xo2IWpim8bIpIZXgeuJ5cfdUsECxn0Lrbsi3mDxWtdiKvLwAR0lrCmO+lrXDB/jp
yKUuaWIgXRBCHJIhstZmZLav2sTmrEJ8TXKz2t4K6NoFWTUv/J63VNBU7kxwpWgQK9rdetfQPWyH
otvWcEo5s5DP5sWP22tyHG5uC3pSXzlE5WrVFpuKI37Wi5L7q9E8qE1OZZ9k7bVtDFCv1O0X4Bh2
CnsdZxMVa8knBcBQLz/U+yL3OCF5LCNgyC88U0ZSh1eHnYSTLbVnSvjZ6QvpjiNEGo9xcYDpRncj
daSF2RNHCkp51lM6tiCm+Hytp2Pd0Hb+iMg1HrWI574qda99CJjGPNfNIb62WWQnme7TCg80con2
pwqYRE/UxIFDB41hVXX0ovzOSJOdtgmGYjphue7UwpQPqachar//hCqHBV9xQaLedu4mifzU6ce7
ZRTShivxcYeLPIJNHmngkF6376k2PvfoK2U48wAh/YwhJcfTvpTk5+IUGYp+AvwGS/siG1+7vL3j
HD7XJm9Vg/ZgxuGXw5mZu4kR7VX791NaXEs7bERiH8iGR4euwXjSPBPjPyt4+NSAa6v2hLpEKL/k
zS5xy8rxTi/Zi7PuCWxK3vDFQL7qz6nUgyPn7rKVH+pT4DTEpbEX+jI8Zn30iXQgL1ShdFRtTCzK
tgMgJCJ9gbvgrnN6Zm40a0JOahJ5Rc/6OCNggadUg56v66diZxX38v3lSIlYchY38rAoy/DsRUeB
9SM/pJj57WTzyaDlq1di9EYd8xe7+Q5NScnymyNRk+pb/CRlV7hLbvRLzHENYiy0gxG08h9XYUIb
e/7azLJ1kyOc7ddE1XnuNV88Vais3qmcZNFDVOV7cOb305R18snFGY4NpwM4rDTJuIjomMuPOSZ+
Pl+nZsQXT6IIKQ5E2igN3BjgOOCA7B8V0uyPPmLtB6wSglfX0hK9j0MTvHIPA1NfbOnxNDBqQA+B
MS5zZqv+zqd+wdm6Hfn3rpdD76fTnhsh1F6H754LgEzQKTAczsSQ6Qj2YHbXHqNHOjWkwvX35XMa
NIwr+FhnlrnWAt3WnlA256q368Yu0gul/BiMhDAxq/fZ7H8ijWq9soFRjWzUHy+nv3XL/VloK89i
3gttCAZEfUgy5x1hv0eosvFq9qOIFZ/WSjCazHLbjsW+4ElmPm5HqdLLfINbK+BYqiMilhPf1XdG
vtE1MnFMHwq/fPt2Xvn9cl16fEM/lDvJff7HfPHOZS/BI8USb7OLMCpLjvRuX1nFVy6OoxTsDqr5
CHgGm79hRzbZaICwmsSTUaST0gecB1I/R5SfKPFHW0okTLGMbt6crakuIlVNjJZsG/yxjbB+s+8T
1nO3WiLDxhvQjBRYUE27cfeTLL7hW10Cuq7Gh6VXoAMpldH45TJk6lRZiIZ44UCgSvX6EoXVA+S7
L0DHae05b5u2Y2+FgaACRNgboa6grxzcFUfPfQ2o15PN61e+v8l8S2Ab4XqgE/TGWV/FMK03jCTE
Cf8WdCtGWFOJXKXF3sk3f9pvoPteZYnPYnqKrZj8qLiBqnkJvTe4eQVp+Mq2GhS9fG4UTituN1+C
t14bo4robXn3OVeziuzBMzyc/Iv5PcW0Ie63xM41cEy7YXYKB4yq0MNBZelR09TzyLpiFIdc+wf/
/h/Dqbi4oqXTVPFdN55F4KQ1lNnnciE4IV+f4RTTOzrfD8hw1w2nXJS+M4XayVFeK52f2jQTf8Qi
aM1+LLUwqbNBorgsXf1ZlohH8hrn5sTPregNBgHYYF0NbIKq9nmhiz2fkUOEkHDIm+nquIYeskAT
GkLboQKWeGnan56anwa8TteiKLkdFRaB+xNEVJpqsTanfDdny9+Bpc7nH+P4ch0EAUrMOrOoin2O
RiW+Bmt1z3pkpgvtbA+u5GOqw6rZiEJz50wrZyhHMuNzjyQvm/Cfa/Gp6LMQJ4V5sRZ9dv7CFEzf
g0Jp+JKxxPjJcPGU3q5Cyl1Sr9/oQarJT1bJbU3QCbwShVtVOyhneD0b0LIS4jgondv2LK8x83w5
swfBfxPhZrL9VODspsjLtyudad611Rh7nxoimoFYqZzkPXyB1+U9CMuPpXZ3rxsbfXcgjdin1u2y
3laeVEKWk4kWuk+9peO+TqFjG9Cm6O6gnxDiPJ9F0obO5UDR4HOWDsRtDfbyPSkkZIqI0KX6pN2B
1o9u2imb3oHn58voklw9gySd4XlwtBfHP3WaIQiO3tqNPsrlQt3pHZzz9LjO1rk3YAM0J/evktu9
ZhC7zioC1r8VC9inJB5k2d0LE7iBs2xsL3bgN/E4m6k5SPETsCSFB8SAuY5Oy3jOhpqDryo3/dxs
WLxxHgdcl67jSecr32wjRGwmvuxsTwJehLw3ZtZhwX1xQPsx7XhiIjOypi2w3pXS2ll3M34328Ri
R5uvrWXXaZcSH3DRPrz3fSk/nHs9fXZmAeWeUW2d+j+xKOV0CmVuZHN0cmVhbQplbmRvYmoKMTY0
IDAgb2JqCjw8Ci9MZW5ndGgxIDE0MjYKL0xlbmd0aDIgNjU2MQovTGVuZ3RoMyAwCi9MZW5ndGgg
NzUzMCAgICAgIAovRmlsdGVyIC9GbGF0ZURlY29kZQo+PgpzdHJlYW0KeNqNdgVUE2zbPwISo0NJ
ZZTS22iQ7u6WGmPAgG0wRg6QkBQFREJQUklFFEG6ERApCQnpllQBab6pz/u87/P+/+d839k52339
rriv+F33GS+nkamwsjPaCa6BRmGFISJgWaCqvokUEAwWEwGDRQG8vGYIrCf8DwrgtYBjfBBolOx/
6FUxcCgWj6lBsXgzfTQKqOPrCYSIASGSshApWTAYKAoGy/zLEI2RBapB/RDOQH0RoA4aBfcB8Kqi
vQIxCFc3LP6Wfx2BfDB+IERGRkrotztQGQnHIGBQFFAfinWDI/E3wqCeQFM0DAHHBv4jBJ+cGxbr
JQsC+fv7i0CRPiJojKsCvxDQH4F1A5rAfeAYP7gz8Fe5QAMoEv67MBEAL9DMDeHzBzZFu2D9oRg4
EA94ImBwlA/ewRflDMcA8XcDTbX1gIZecNQfY70/BkLAv1oDhIhA/g73l/evQAjUb2coDIZGekFR
gQiUK9AF4QkHGmroiWADsEJAKMr5lyHU0weN94f6QRGeUCe8we/EoUANZWMgFF/fX9X5wDAIL6yP
iA/C81eFoF9h8E1WRzmropFIOArrA/iVnxoCA4fhux4I+j1WDxTaH4X7c3ZBoJxdfpXg7OsFMkch
vH3h2mp/WeAhwL8xVzgWKAEGg6VkwEC4NxAeAHMD/QpuFugF/62E/ILx+YfgvNBeQBd8CfAQhAsc
/wPA+UD94EAsxhcegvtPxT8lAAQCdEbAsEAnuCsCBfh3dDwMd/kj4yePQQQAb4PxxIMAwb8+f5/s
8NxyRqM8A/9t/nu4ICsdGw1Lc8HfBf+tUlFBBwBxwqJSQGFRCTAQAhEVBUrhDyH/jGIERfyVBfjf
vtooFzRQ5k+y+C79K2G/v6bP99di8AP/GcsAjWcsHMj3b4LbgiXAMPwX5P9M898u/z92/4ryvxD8
v/PR8PX0/K3l+6X+f7RQJMIz8C89nq++WDz39dH4DUD9t6kl/M+66sOdEb7I/9ZqY6H4HVBGuXr+
3USEjwYiAO5shMDC3P5Q5Q9u/mvBPBEouBHaB/HrQQEKQ8Dg/9LhtwrmgX80fPB8/K2C45fmn1eq
o2Bo51/bJSohCYRiMNBAAH7EeEkCiIPg19AZHvCbwUCQCAqNxbsA8eWFAF3QGMCveYrLAEH4Z+kX
+FvGu4F84H74df8bgQBBWDcM/D9swHjEH/23LC4NBAXBMX+Af2QH88Vg8Lv5mz341P8l/34I4PAA
OAwwMYaG3brr/uZuw2GFMpu/8HK//DDvsmUGvzBuAtPoe0xNmsr/6knELOZAObWnjfbLojrfvtIk
xxluo/YtaUxdinH9SfCpQ7LJ0HI9YHzw6vuBZxvKlZ3XyNmFzZRWgs+8gy3CPYhqLzXr8OZ6+0pT
G+UzHPp3aAZUdpZOfYweWzZeeSWpS3Fa+kn4vnmCbXjRCG+e09NRZi4SrPA1MgH63QCakf2DYfqc
gQsOnWRBQMjmfbHnOJs50QdHo0HTL8xEfVpYeFhsmK8R7dN/HLqBU1lL02H6jCt+PlMwYutbGCf2
pYXATjN0bIFcSi4QkSz9WrGbiHPFdf7nZjNFTS9KSDO2fDLt2cqZUNmdci9CiZXVU/B+Tvcd2m3c
2LVS+uo3XM2nz6RUD98+vrIgGRemw83JKi+/f/MRxy7m3qQfh8Ikh+YeS1o5ZzSIisOYSoNa/21o
pwsIeZ1NIA9xjy+bixNR0poD0A2TYFCg7Cw4JXdOEdKxL6uKYmMhFtodsIuwzwcErTIxsX4SYCP/
XiUY6+FWMkzobui/1vjFe5OQfNfjhlDKioNi2OOP5z2xsOtcKSjFg8L+UcvYFP7slLTRexwMLaz9
14gKye97tKetxKc6bt23efnuUTtoL9GUnooiTaBPMbWK5A4smHTp0bJlpyu6KXk7+WyU9UP5G6dW
hLQb3OewqcKYBnF8t6dOnF8jL/mIwa/mw0FmmBGlxfZy8dXxpBYvhEdyjaP7zujukmNLVlWrepk5
P5ps+2uV5S6Fu4qBy73WqZaaSKMes4RxkrrCT1AHnp112pdUPb5qzozR42IPjMkO0lVYbExdAn3F
KdeyiwPa5grr5meHDI7kznMSIONsnxbyrOY9UqWYhrWzahV42U7XQobvAMZvTi2bPb7gLwm9wqPN
23/hPffQSJu7UlifPmVgzSLAo5+6LaBzU2mmYWTqCYPNrI6kW9jOy4VJeTflyYrZ/o8ksrTN3Elo
pzG/uhlGMLzJ9oxjjyZv61JbXuc1cErP2uV9mNErlSBcJ2u+C4H87GG1MyT+67Rm5k1cO+Rzi5Jz
v1pooBWmKVWt3NAmqVi9R2Qg6Yv8Rgofr31xI0jUoqWGib+mifXp10+dXUt8s7tbyJ06Fpc6FtLL
9OwmD0TBzI4zce/M9JB7oEsHS8YMD/QefmCPoArSHde/hnzN0ff89fMnu6fj5IL26zVjfsqVDQC0
eu+5ZgBHqR/75pbVO+0AZcKeH5Zvc56Rdh+PKgRMqraVNm9IDBFHPtrb4fTPG7ZfT6E8YhzveD7u
94iPaG9IXEi4IALe9q1huL6ATBFkEre4ma74QK3SG+7dmtZG9/R+GTtZpXBebjFZgPrWNpBn/0vG
/atJ+QJi6Ib58owI6xFBME7QQOT4rCqsU2EgNvamfG74uy5tnRP2doCL3ccYVS4fL1RERa5oBIQc
J3Ysr3466V6+QSi+P2Jj8EEUQPBqXzdUwD+8TvH80t7VZ2vb3Glvc6OJZUpZb+0B3hIrX+bPNAqk
ppCKDfliX4X0ZdPYfjLeJXocn/foRUVAKFKyjUTOwl7Xk4ijP8giMfBn+TMu9efSNJq0h3krnUsd
7zqaVGLdG6lXG+LbTTMck2ztaVgvMk8En9tl80A7rW4aqbo/mtQkVYYLAmSseVicTkqrP/cPpmbs
UNPkfN5g11px/exyStMuKF9KF7hzEY5d7v34xC5FbP2c4rF5yCD6JE8pgfzHbWrNabuAgm4JmTeZ
1SEIryLoHulJ7mEo14dm4CSDcyc5nYNd9hA8FZdvluoQO+XSz87q0L+bXCh5o8VKmHUHsxj3uj/1
UGGpjIZD/AaZZqci5rltsGRWMfXjbj1+uH9bIXPyl/YMFUHMiEoSbHUqO1csqtUPkJU+x/n2hSwY
58uiB7jenj+ofJ10yj0E5y1maa9CUHLz6TTfGQOz9XOCbjcUeMyyw2Qt0XRekcCX/ohgsoPyjHAz
3aaTo6I6NTYRkYx6uzj6QX6isWYytyuDfyMFV+XzSn4NaRsRHpHa7Evnaa/pZtDNMU6idLIxx8ee
nuRDFUBcfyx5JWWC/TWx07F+TPhNeoGvZNU3iUoLOyWXFZeWN1DNyrm1uCfZFY85hOofQ2JxWeoH
sZsiYyYBSANxljqP2RU+RgJ/hqxaTzGw/hFtKVFzztTKvK06QTxLJQZwsUb4dpbs8b7X2VYfditw
mpx1Fr1Fo3AEuIQrOoc6pL96Z3rQ0loKuK32uEwkbRs7pE2Xwaw+3Lh9qZcizi78vkvn8arF1/LR
lLIZdykLqAO0p+XHPpcwjntreItppYhNOPz4CuBAdpXdyTB96vY3frptrZcNpCPKVoST6hv1jzou
in6au+bIeVR5FxHosbRXqpStjH0QcH8xXEfnRj2mnXCTkudyk9KkLFJEJBrknc5b6uUJVAkDsVHZ
uqwv++rArqc3UuvmLO9muj267xdghyR8JEG5tSrAhdk+THvXnHDLVnpHwjd0e/m2LIegpmqY7N4b
DUEuA1rA4DDrnY0YmwwkS7oyVsl0IHjzYCAHOSUoX1Fq0cGgRWKZazQ4J/Y9+IQw1wv5GMxV/7zJ
3FlqtfpzE0v3bQur7J1UkUJs4yuND00hmNHqwFrr0NyCt8wuk1WNg6O8V7ojD4M49qM09eeMQ0fk
Hxj17qgNeBIs7enRmXl1Wb/30lk8oGSJdYDNGD+V3Z4lcE9ZXyyelR09BvaXZefG0a712krIyliZ
DwHd4wlNsmZdue12CC29q57s2NQUJy/Wh2W29qKGh3NViZ6u7QRyZceRbbxx5xbsWujqtn08hkvp
e3QnMHW1NNVusJHG8LCQdcpfHf7Qi8zi5MdJMPBV8Km2nY3zi9Un4KoqdNOKs4UOj1J58M69643R
TAkUAl+LWZuyAv13r57R0lHq5tAMcH7PH6UGl69tiB0SefsRp4tolDtcs1JOy9MIObgnYakSaE9I
G5JgqTAyLBpkmOq9QlxUdMe7IrIggY0rGxh1jtHuCe35wsFTpOCzQjqztV9AchlcYa1UfFTXXSxx
XLJG+w6n3fhgnFCB4WPg5dWIN+hB1bfTm5EcyqLyLSpHitsFDa1cJrF0FYBWV4ceodDqk5/eIurB
QBT640C6meQthKJVvNNH8cjpvRDsT3h2yzkRM+HI5MU7vQFI6MaNFD1nm76QPdFoyx9ZdCIb4kUP
IkW26+15+wSeD16rvNqrNhG8Y6NYuXVX6u4DS8jupZeUAlRqckaLkF53u6O4OYognSaGw9TcaZKv
DxWufWNUY81RNHK42MEOovP6fujGpybpxd+Elcbvv7tGsD9D/oV9Nib3HpKZ0ZREgbFV+GnCOHdw
8gPKW3f6F26bQIiWJ/PvpTruAaqUlNDV/ahDN/bdBpGRTouxaQ3BXn8xhumc9CV+Eysa7ms1hUf5
Ms99gsS/WcVxveF2WqDxJ9LDZcMIojXCDF4SEMy7k93Mep+Qaxw/koytPWA/EmX7bDaJCt0W2SqL
BN5t7mVLDS516LzOsMs8m1Rz7jHA91LjAglALUoLZJ+yWxOIHXGJuBKErouZqoy/4OxL/97nMyPd
QC7YvzgdTZWWisiomVhXk6rtuap2Wn9U/oN7+dX+VAta/UTfCDwM9ipBlX68p24b3jFRfiI4fk0q
7YMDRb3xT7KgSJOOOKoBZoQaWuXhE/ng3FwUD5Go0xWL9qwmS469nSpGk13f3Uz7zVq7t1Ki3NEv
m2N2XwACpBiX35mqX62XqChINcweH9wx/yCriH7pTVlJa2lLc/7hyrdljhzveMJCJiajWYIPWLn9
K26XFqvauvrmTYT8Xkndo1F3IojoXKmzkWCUZ91XaM86Sid9vNs59oTxsID7Sr2bKb2JcuWmgmjH
DEkkmeGooicNl/cMH82Q2lfD6Jh9X499InGHEI6prmzuEkqC544GzbHHYIMy0gjaegfV5RcTKnIL
8mWuG7qG1BDQMbSRc4szZiSFz1Gn9+VnFhmRmC6Tgt7iQAipO2nhN09Uul7lT8djl6OBq2GlEcwv
x0L7Sn3r43Veu/urDTBDZHa7de0tpfQuLvFVfWr20FqTxnTeYdpUBSVc7SJxIIsqWx9a5GSgbLwb
DXFtd3UEvvvk9O1ytW8aefXJgoUz2qzWoUydJ7ooGjhEr2ejuhHu9JV6jrY/MYmZv4jb9xxesDY9
R7omIJdPiyTpDGEjubgeEndP7o7N23cQ6hd7h6l2UtXpi6i1qLPUlWZqeVrJuIMNWOh1bseXxGh9
xxrtuaWHmqrxLLDOOe37Jm18LnSX3lJCaBQXUtcVBEmtdUnZVG0Yo3hLH/kw8nt9Gvg5E7B7cKFl
yKRm8tntrt4JYVxCzBTdQkmJIkBD6OuB0tS7pMyudk/hBd4AaoYqyznf1fd6hC1m6blpsVLQ3D4J
wPIQS/d5nJP8Avpw6MHVmmLY/Sdx0HPACsbI2rv63TWGNhe2KznjYubwwmxjSfeHpL6023GcVVTJ
hdg7y9Z6QtzqX8/9InvHzmqkFcNolAbl1ukukIolO+13Mxfaas6Gm62305lapEbtzcExXd/0HZsm
rIQmeg7QhEGFmeSUUwZ20cXnX05IqFVNd/O9nMZ6h5u7L2y7B3CxR53MokKQ2QKzGzomO6q+N8jP
QGr3uSvgTf0pwb0nIdd1Tu6uLwwLo58yZwUZ9lubpanarSBGukDH77+eAHVZ7KsKY4xJoN2q1xF5
uASSW5fmn5XQk951LIrZugVQqrRUne796REnaq01R/soSZNnQ2eiY38kJd2wSkFXMJyKXVBj6ocI
Ba/ul638i8+WkzTUk+szljaXKVN9YezGtPknoyYPGAuTVs2eQbKrngGnFXYwa5EHWWlb8Qm3NAav
a44Vfbt51nRN9k1nSYHzlc2rVjEDqGDthn27vuKCAG/QKjOELOa0zgdRaMDj5JUW9snrnZy50z6Y
uye5REtjY/eo8mbXl0vWTImvugeFinrzCjqufohoMyu8KV3f45X6zA/ok1oEIgiX6ZAnUT4jliEb
uTmm6mQDIpUpPI9D3eDx6CyDMMz4DN1fTYmeD+Afv07nxVgNHeW03WrhGHRrulS715duimEkmr6C
piIn97WZ0m8i9lN945B/DjKLRg9eFbYUw929SJsvqZbvbB3zPxAZTPDpbDOZF067FhsIaRmsmJl2
kevlF/crci7mSJppbtUgSZhI39y9vbXb5DgBmBMb9Ws5TLgViUvbZGMO5Xq8gRj5OQGb2ehj1vJw
nc/4NiUP6p1Xo0I74Qh4bvjYCzg8OFqrBN1zm7KdvrrDw4S8YeNmEE56i7SymvutsqakimI1R2cX
iP4Cbs/JeKOQ6HRPMM6hZHMgnXpCufFSq1Zh67bZHZrvQNoOjUrH7xF1qeVewEkvBurr92XeYYWg
JbCpokDS8Ydpoy/yJ939FwGn10XoTib6JFYoPmLn85F9k5uevau+5sUwLGN8uzCos1dFwoeCXUwo
rf+1Jmx8ZYQN3dCOvcoSfSahPETAnhjELFghOA9Vv0LZnQLpJpo72FFUVd51qrpCHmB1EwL/KLnw
PGxYxlhvNe+yJ9RIw1HtgV0saUj2lQWbn8lv+F8kSntFFN6OofZfr+kT4Cvjqr99o8w3X7ZHgOgp
JtN3W7iPPF4+o7iKC6OqgvJxHWU7uLv7pM91+HAA9aakVD1oUs7pTX8ZlOJHYNBEzAKbIP0b/H+c
i6CBpyNTIA3xlKS17Wj5WskX6NfFL5i+Hz0bpS6/5jLS55CSZL3RCrbSKuEVrxDUn9IiwvpvMQMH
E1rvjZLxhRx5hv3omGyAhqoUnNkHwJLFUDjBYlyG08CPVHB7cWY5NDpRmwGy5F64aHuVlp7IrZbc
fMid/LnWpd6OksRH2noRxmOn9/Pc+NfuGPT3F09dXSzVVaAAV2ELHRapBBwNi8hkJRoo4vQ3szMX
Q5KDD5dtDOrNu34+2ODknqUy/tRIo1qRlq3dDKgNXUGz/aQABmcTxy/w6EIYUF3BATJP6mK3RmWe
zZN+x0GNkqqcLjPpMoFc6JBDJMxC4ETFUxcZr2KkdJKwZBCteX83syvhV9oMkVVN5/w16nthHKzK
OqtXeMXJ5aYGQ4s9h8cYHER7tx5ZVrmX1jvrG7Y3cywRxC+bTiHhJWxtXO2NsxQD8vnIS6UyKfGw
Hy49TsFRMYqzlMup1QDra8YkSi2RhHZZ+29ZjETdnoM+W25E8Ft985tqTrEG9JwSfZ8QbEm5hdJ9
MitToxfeypBQLsBY5lgnfB9CGSb4mqj1e3rWDnO5e+fgxymt7z8ssbYJP7ffD37XbNGJdPFk2Vxu
2lB+/N1lz0UBKqGmSstTIlm74Oma1HSWWi0gvgPKE2DIYF/k0Z9jKys8Ry4485BWphTz0IMTiOEr
Y55SUOiX0/JYKj62bX+xWNv1x7ZW2YvK3c1Zd8SzHD/avdpKC07xi16MnBSFNPMnUmSfReU4N0oS
i0hp1HmoroDmCCDjOhLOWSvM8Cea7a/jjlkjvSPK02rDOOYJ/CLM2GZbZrMNugbWgpVsG3mJ3pNG
w1UdNhXaGXis9qVhKt9rbrrgKJ/noHKMr7+xMXiPITepTETlFIaYNCZBZkhVgqhW1h8zOQw+Sfic
udq2KkwzTKZesO/hvjKw8QWJ8uB6yPZZosj9ACSaEPpi0ele4r56eZTMj1juVo00pPVUyWposIGa
18t0M3YzSRvebyeDWuQw2tNOrHvp9yCxnCeTtleAAo9oK0HgOvbnMibXbme9zxdrHwXNwdbFJ8ZK
t5IJdGdOX9lX3qGYF3Pa4VVhVeIp1Xeu3uSR5tvwSbln9MESVmh9sSsrmjpkcOO7Nx1x3xfxjP0k
njxAsYW1X2Xbe61qklomU2AEiyaGQlAxsaxEsmdJYcEHt3vjXXmJEpVVEB3l0skb7qUAei0tQTXe
BD+bUEvD+4oWZGKdYkQGFBpRw+FPZAYvkeYCbnNRctVXYZAv4E9i0zcyenHjI+diehysUomrrk+e
dlWmN2yYEDsa60q/5rA93N2eTA1zAbvt574GhsmVX0gz5kVRBUaOvwfIxPbaNhjNHm2qRdfav+yC
6M1APt61jeIhoK1QbdJw2vnhqW98Kei+CEdd70LervbUK4IK6RoXP8oy4Yn+OULeyeznhuHDKmYW
D4mZtEqmrJkEW7x0QkwBsz1vkF5NOixi0cU91lFn0HwfyumcNuIqAVNja706FSOH2xFalsQq9B3G
ri4rQMfdJvZQNrriB5u3Az5OESWCiAkDvRYByX65CIoahawgloAP9ONdy76DvV72HU1Kj7l9/Qfl
xBedaIUuIwVCSr1etkUZJOPqXfZy1cNilVwMcudcqfNErjk6c3VWRdIzF7/AUCws042z+mDqxCVY
EkyF280Ze2iZHAIyCecuHD9qcFPPLjcn4foJEuXMZ4rNn/vA7whwDKJf67YPTRXyeThWhB2/focM
JaqQPVyMBHde9pzFPXg03ycmKRzD4Fk2osgUvjsRaXefkHL0UufbHzfiYyE/avu0RUz1H9saJsNf
7zAhKdCPKlmXtta4v3+aMsl9dOe4xEvk9tK2+Wtu91BuGkWQNZ8skd3Y6KwEz/GXOO7e7VYoj+Qh
jLmlwEc4Y2jz0IojZwxmEJFxJqnGd1N6VhkHj2GpG4527+vk4KeM4CYu1XaC2YsmCvOSwqkdv1iw
lH3CZEqLkc/AuPN4lyMNT0fpAoWM39+XXFGCzohObKS282GJYCEGnMNIiOu5ScEN3+q+9iSORjIf
59uwi4Wwh21rJdWSSYkNS4Ybm7xadNqvVVZ6529XgQwPk7qJZdZpJF4c1a7QwDcm1MwHrnXxxhIs
ShCK53HEu8/NL8KhboNt4ryiG5lu5Atd8enuej80Ag1uogqO515rK35/PctZmhAJ/6rMPLplZb0f
ZhD14TPoRoMzqPdCVE7AH+mHRBNTxXZ+xgVdZw/TZvB5YP1+wEeH75AqzcOLQYmFKp4bG6FQzWMr
upuhnlUVMNZWbmS23kHvn8/qVNNrGcvyQbTyRUTTDpkBXyrtl3B5nfGydEePZfrcjWliE+rNrP77
QyMKCbjwmbBVlSjDuAMA3QoP4OuQXTg9Jwv7LeLrS0+vKCzGOkhGhcbWyYWNbF1ZhQQQaQr95Mlm
Eidn/saZyrK5RBI0Td/4PdvNX0EZ9O3N9a3l46tLtoIUB7SiOXdtLnFOUyC7lSpG3upk/lR9sduq
T8xKHBL96dVgZ7t57yeSrWHJglnN1kYeVLKKUIt0FHP4rGiGKuEGM3GE2sceaH+gmfFke1H9kwPZ
jRIeN++3cfLPBWTq7yINMs6+h8ghYFBmGcWR+YRqx8N7mVaNgxkN7b2Sw2jQmK4u+REpUZapUU4P
xyuvt+/szzWy+LzmAwKVPBYfXyfiC5sWL3ihFVrEqkXkuh5uH5tAOEmIe+ObdLG9OtuwPm2hTtp6
mpfSP0H4gi74oMjOv3Vyi95KIkKUPSpRlFo6hmZvrdLXTs5TKP5Tm/c32JTU7bEU9Bc3FcUSV44N
xCAyV7Fcs+KlCl1mNshmUWOeWEFQ6+ZTUfcSZX7ZnvSx1PwKma8Ox4gBjz1zSfca9YICTM4zWtcN
2cEwcmH3i/fXD62iv88PFcd5it0taxeJkiBotF+92bpk3t2vTE3azQgAY7DlGhI3Jm+HW9DbmAXH
27sPfngq++C1PWPZUS7zzxxI7Y3dqBxiaYgYa+XUiSl50FzwYLb7j4uqM+yUeMvcuedZXdFXk/aO
p4FEBfsKYRkqDQqCRDnFNIGtfJd5WQYp7SMePFa4fdGcDh0IJ1zlLrbI/B9DgXhlCmVuZHN0cmVh
bQplbmRvYmoKMTY2IDAgb2JqCjw8Ci9MZW5ndGgxIDE1MTUKL0xlbmd0aDIgODYwNwovTGVuZ3Ro
MyAwCi9MZW5ndGggOTYzMyAgICAgIAovRmlsdGVyIC9GbGF0ZURlY29kZQo+PgpzdHJlYW0KeNqN
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
RbFaCiR55pEU2Y2v3PuMXkdsaOVPqibAvcdbmQjb/nCt4niHHt3hbFokHt9UX4G6UJ2zn7rzkXAq
Gi5YZPCcL0lZWc7fH3AIPVeSGbmc3uwZdGHGHN0V9MfYU6kCeOnjGIXvw9HhFMdLUTBcl6ooasMJ
WlNstJDQxbO37GwXsL0LcB4ekOWpj/kEqp5ahRvwXC+tnkSBnMLHtTFRi0yFt1nLeT6NoX3Atd/b
6A9eiCUxOBPkZF0tRSy5Ej19Tqfm4iti3kmU9O+7b8XvZ5GRYmRiIMIfVUh6ENQH7/310puSXsmF
/iBtrtDjNaWLzQ8oGZymmBLSP35tmWI/fIdxsFhaUCE2sOdoSAMlGRtqXtxlpox5rvvVlVMTJMYU
qDYhI6dd07c58j8iNzTBuShgsD5NOJPz6cLFQg3NcrOXs5xT2h7EdmwjROUOmaVGgmaq0arY1NK+
9dNJnv6QQVRK2DSGDLdchHPTvdV7KUGgDoKxkf7tmMFd3fszvLFlmL0Q+rjzBHl/ofykGWQewzIw
PAJBpxJzoaxUyt80hvM4TECo4pTCsy2Y/zRqCllmB4ajYnfTpK4Gdzu5FTMi0nva1XZt4v33ODjW
dXG2Cir1S/QD8J9fX3epNY9KNoYzGYXleoePv1CDYEBgPTcWUmReVJGgfn10mc8LJKf8NMfOZQwX
BXm9aYUwMXne1lQHwlHoyqzj+D7nOsFr7tONFwQslz0EpX9mZbS4i6oB4f0PPVf26QplbmRzdHJl
YW0KZW5kb2JqCjE3NiAwIG9iago8PAovTGVuZ3RoMSAxNjMwCi9MZW5ndGgyIDE5MzU4Ci9MZW5n
dGgzIDAKL0xlbmd0aCAyMDIwNyAgICAgCi9GaWx0ZXIgL0ZsYXRlRGVjb2RlCj4+CnN0cmVhbQp4
2qy3Y3RmXbcmHNt27ti2bZsV27btVGw7Fdu2bbtiq4Kvnvft06fH+br/dJ8fe4y9Jq6Ja6459iYj
UlShEzKxNzIVt7dzoWOiZ+QGyFvaGrk6K9vbyttzydIpm5q7Av7K2WDIyEScTA1dLO3tRA1dTLkB
GqYmAFFTYwAzM4CJi4sLhgwgYu/g6WRpbuECoFRT1qCioaH9T8k/JgAjz//Q/PV0tjS3A5D/fXEz
tbF3sDW1c/kL8X/tqGJqCnCxMAWYWdqYAkQUFLWk5CUAlBLyagAJUztTJ0MbgKKrkY2lMUDW0tjU
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
Zt74hbn79bqb6LI92Il65OzNnttLX9hJ+nvfRXd3WVtcatsMz9aWthxPz0/stW+LnR3YfbrNtk01
PDjytilOl9KOrJ9Jxn5UTaCgD7t/t38nRV1Xy8nhUp2GqplwcN+r4eQ4Px0zh7EvGKOUP7Y/V23z
xMQj59wBm6ZM2xoznKPpVQebjsqOVVP2VzHsAGmRkKysiuH6Rs+idpeB5N3nebD1tjm20WrFpm/u
8Dz0n6TwIZq+9KXtq+aD3X9R5k52l647WahgPFqvWWmPrqCb/XlfWzb9acAb5f2zs0zSu/Cqira0
525f2H7ffNhoxfmarfJ8Hdmm/HYmuU85HEdu4rh8gYfS8doBBvGGACMcIFBNxB6YA0CK8CkmA7AE
oAlIOQDUEJkHFIDcxVJ4IHGARLpcEmpSAEiXhgCqodBWgcG5AjBDekxd+AzCYrBjdJHzOXTMwUg8
Yw6GRhe9DMNpzGVEGM4oAIswnEG6MWE4p84BWRjOoEbKw3CpBKBuw7lbH693thivu/i376/OcLVE
GocMKTm6cunxBWJfaWkQz3y8Qewt0NDgkiimOtf5KJduUUiqmROeY25BfG4o9t5miKXvS7j0fTNc
i/R9M9SRvm9OuO/rJnZx4mPioKaMDVlLXscp+MqbIaFfGR/DbZV6XynOPJ4j3nic+FRHUv0Z93eF
vjH1UhKzx7mPgc+JIwTwhHoJBQ0J9ZIK2pLMc3BXCdXhGfDF1U7gmns9uGctgl9aBr+0Cn7pWfBL
x8EvPQ9+6ST4pXXwS2fBLyODX2YZ/ErFzS/6suhLwj8bW+i2M4pL37t1QquK1gQWRNXY2zbr2g5Z
9KM1OC5dvL3k0X/t24L8CmVuZHN0cmVhbQplbmRvYmoKMTgyIDAgb2JqCjw8Ci9MZW5ndGggNzM5
ICAgICAgIAovRmlsdGVyIC9GbGF0ZURlY29kZQo+PgpzdHJlYW0KeNptVU1v4jAUvOdXeA+V2gPF
dkgCVYRk50PisG1VqtVeITHdSJCgEA799+vxI3jZ9gAaP4+fZ+zB3P14XU9U3W3NJHzk7M2cunNf
mUn2c3MM7u7yrjofTDs8G1Obepw9PbHXvqvWZmD32Spftc3wYMmrttqfazOyvidp89G0noJ92P27
+T2pDr3gk+252Q9NO+HgvjfD3nK+m2a2xm5qzC35ZfpT07VPTDxyzm2haOusO8DDKZhedLDpqGzX
tHV/EcO2kBYIyeqmGi4j910d7GFg8frzNJjDqt11QZqy6ZudPA39p1P4EExf+tr0TfvB7m+U2Zn1
+XjcG6hgPFguWW12tqH1/rw5GDb9zuCV8v55NEy6sSBVVVeb03FTmX7Tfpgg5XzJ0rJcBqat/5tL
aMV2N1ITS+VzfIUqWgapDC2WMQrcYlvAZKipMLeFsLQ4ooLFQRoLixPlChYHaYLJJEMjLtBDoYda
XHexukYFyXxUVP3Z9BftPFxgGUdjKXkMLKkOBTwkrIFnhAvgiHbgwDFh1+eys1sLnVJI15NMxDE+
GGd+vMA49+MM4+If/sgpb2vgCedBhDgLAQ/2JBNgSVzoE84D1zNg50FmjuM8yBxaBV2DwiGLhOoK
eE5rHcd547nj0B0U8CKcNxHBvyBfpeOTp8xxCuJIYPLh9pWCbhv6paRrzIETwvAdUk8FTkg9Q3BC
OiMNPdElAjiTiDgROFFBfqEhKskXesac+NCQ5FQHPyF+jj4J6XR3qTjpxHkq4XOjpM+NCn1u1Mzn
RkU+Nyr2uVGJz41SPjeKsqKgR128O37u86SK2zyp8jZPmt/mSYuvedLya5506POkZz5POvJ50rHP
k058nvTc50kvfJ608nnS2udJZz5POvd50oXPky59njLu85QJn6dM+jxls+uduV+++6XjbcI7en31
qnPf2wfRPbbuocMT17Tm+h4fuyNWuY97yMe/DYxeyuAv8fOoUAplbmRzdHJlYW0KZW5kb2JqCjE4
MyAwIG9iago8PAovTGVuZ3RoIDczOSAgICAgICAKL0ZpbHRlciAvRmxhdGVEZWNvZGUKPj4Kc3Ry
ZWFtCnjabVVNb+IwFLznV3gPldoDxXZIAlWEZOdD4rDbqlSrvUJiupEgQSEc+u/X40dw2fYAGj+P
n2fswdz9eFlPVN1tzSR85OzVnLpzX5lJ9nNzDO7u8q46H0w7/DKmNvU4e3piL31Xrc3A7rNVvmqb
4cGSV221P9dmZH1P0ua9aT0F+7D7N/NnUh36eLI9N/uhaScc1Ldm2FvKN7PMltjnEnMLfpv+1HTt
ExOPnHNbKNo66w4wcAqmFxFsOsraNW3dX5SwLXQFQrK6qYbLyH1XB3sSWLz+OA3msGp3XZCmbPpq
J09D/+H0PQTT5742fdO+s/vPwuzE+nw87g1EMB4sl6w2O9vP+v61ORg2/cbdlfH2cTRMurEgTVVX
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
WgVdg8Ihi4TqCnhOax3HeeO549AdFPAinDcRwb8gX6Xjk6fMcQriSGDy4faVgm4b+qWka8yBE8Lw
HVJPBU5IPUNwQjojDT3RJQI4k4g4EThRQX6hISrJF3rGnPjQkORUBz8hfo4+Cel0d6k46cR5KuFz
o6TPjQp9btTM50ZFPjcq9rlRic+NUj43irKioEddvDt+7vOkits8qfI2T5rf5kmLr3nS8muedOjz
pGc+TzryedKxz5NOfJ703OdJL3yetPJ50trnSWc+Tzr3edKFz5MufZ4y7vOUCZ+nTPo8ZbPrnblf
vvul423CK3p99Kpz39v30D217qHDE9e05voaH7sjVrmPe8bHfwyMnsvgH929p4gKZW5kc3RyZWFt
CmVuZG9iagoxODYgMCBvYmoKPDwKL0xlbmd0aCA5MDAgICAgICAgCi9GaWx0ZXIgL0ZsYXRlRGVj
b2RlCj4+CnN0cmVhbQp42m1VTW/bOhC861ewhwDpwTU/JFIuDAOkZAM59ANN8PCujsTkCYhlQ7YP
+fePs2ubbZFDjNVwuTs7HIZ3n34+zny/f44z80WKX/G4P09dnDXftofi7q7dd+ddHE/fY+xjf109
fhU/p333GE/ivnloH8bh9DklP4zd27mP16yPk0J8Hcacgj7i/in+O+t2x3clZ8/n4e00jDOJ5Kfh
9JaSPlwXCRR/goI2/ROn47Afvwr1RUqZgPXYN/sdxjgW8wsVMb+SexnGfrrwEc9gVygt+qE7Xb7o
t9slPbD58f14iruH8WVfLJdi/istHk/TO3H8XMx/TH2chvFV3P9JLS09ng+HtwgaQharlejjS6qY
5v++3UUx/3DGW87T+yEKTd+KeXX7Ph4P2y5O2/E1FkspV2K52ayKOPZ/rWnHW55frrl1ypVN+tF6
Ua2KpdIpVoaA2gIoAVQE2BKABeAAeL8B4AEE3qIBoJ5qeYsHsAawIcAB0NQAlbVaGADUwDLgAFA9
IqZaZBjUMFzDg0epUlyht5QpLpYVMirO0KhhIYRVvAXELIaz1NtI8LCgYCsGagDQwy4AuDUAB07O
sUDo4rDo0FZLLRPgAXifJfSY3DMPmiWgQbBZ04B6oc6aBtQIPmsaUCOss6YB9RqZNW0wV6NvmqbD
vp5qra6n3P23nS6G0FqhjlQkWAAvqSluKeYjVxSXhG8o5pNvwFJa3gsZJEuicDSSjlq2LWLiXK0x
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
MBC98xXeQ6X2kMY2hNhVFIlAIuWwbdVUq72m4HSRGkCEHPr3O29smna7UoKeHzPz3oxtrn487iZZ
1b64SXwrxZM7tee+dJP8576Lrq6KtjwfXTPcO1e5anx7uhOPfVvu3CCu822xberhhoK3Tfl2rtwY
9f+glXutm0sIdMT1s/s96YZjX5t+Qj+JwOd6eKOAb+8EEeJCCA7+5fpT3TZ3Qt1KKYlYN1XeHmH9
FE2DvJiOhg51U/XBg3iBo0hpUdXlEFb8LI80AyTv3k+DO26bQxstFmL6RC9PQ//O3m6i6UNfub5u
XsX1xRbRu3PXvTlYEDJaLkXlDlSN+r3fH52Yfuvr4/3ze+eE5rXyfsq2cqduX7p+37y6aCHlUiw2
m2XkmuqfdyqkvBzG2JRi5RwPlaglEWvgDRPzgghlCCtLD63ThAiN8przJGEiEDHbeMIQkSrCcy4k
UxQ1iDZQ0T7FxoRtwoTKQSDC+ggVE5GhRpZzjQw1srXviok1Nzd2kdixq/LPvqcekCt1YdGP9jZS
+vM6vqwhLL2JBJ3Jmc9D29J4vAK2HmfAK4/Rp8x5KkpjTJL5fA7M+iqGbcX6Omb+k3aKdfJpHfyp
2VcOHlXqp4/JqbnXXANnjCXrrzzPmt4X7SLhAvXinHPDljAO+wVfOswd+qn0GP0ZjzN4MIpraszD
aB+DeRjuSVl4MGFD4c3M/G6jT+NnmTPmkyRjeDAZ57Ifs/I8PBjedjXjmvBPI+bcte+RdTeME/i0
QQvxNuwbHyrrc5kPWpiPDVqoY4MWzpwt/NygZVlrlnNMuA7Qygo/tyKcQD5xuGj4HHzc3/Lc93S1
+ZvBtxb3tW7cx2elaztk8Z+/R+NHD6uHTfQXgEBjtgplbmRzdHJlYW0KZW5kb2JqCjIwNiAwIG9i
ago8PAovUHJvZHVjZXIgKHBkZlRlWC0xLjQwLjIyKQovQXV0aG9yKCkvVGl0bGUoKS9TdWJqZWN0
KCkvQ3JlYXRvcihMYVRlWCB3aXRoIGh5cGVycmVmKS9LZXl3b3JkcygpCi9DcmVhdGlvbkRhdGUg
KEQ6MjAyNjA1MTgyMDU2MjJaKQovTW9kRGF0ZSAoRDoyMDI2MDUxODIwNTYyMlopCi9UcmFwcGVk
IC9GYWxzZQovUFRFWC5GdWxsYmFubmVyIChUaGlzIGlzIHBkZlRlWCwgVmVyc2lvbiAzLjE0MTU5
MjY1My0yLjYtMS40MC4yMiAoVGVYIExpdmUgMjAyMi9kZXYvRGViaWFuKSBrcGF0aHNlYSB2ZXJz
aW9uIDYuMy40L2RldikKPj4KZW5kb2JqCjE0MiAwIG9iago8PAovVHlwZSAvT2JqU3RtCi9OIDc2
Ci9GaXJzdCA2NjgKL0xlbmd0aCAzODM0ICAgICAgCi9GaWx0ZXIgL0ZsYXRlRGVjb2RlCj4+CnN0
cmVhbQp42u1bWXPcNrZ+16/AYzRTFokdrEpNlWxH8R5d24q38gMtUVJHvaWX2J5ff78DgGxw6VZ3
4scpmySWA+A7O0Cxea5YznjumKJHwRweHJegJ2dcF3gKxguHbs2ERD03TDiFp2VSoC4ck1YdcamY
4qBTkmmD8UoxQ3MpzVxBT0N9VACRlRKFggnuUNA5EwJ0XHMmlLQoCCa00UdcS6xmsYxWTKqCMGms
A8hcW6a0UR6lcgLDDWc6l+gywABqFDTT2oADY5m2DhBMwUwuiyNuOTOCgFnJjBagsZoZxzHKWmYF
BzEWthYLcmWZI04dZKQFKpI5g4EOTY6jrtBl+FEhWcEhVSdYITCowFNiEQi2ACJMwgpjHcP/woFb
4izPhcGsKIgc3dQiSREYi6kAVftCYZjyaiABkPwNcHi9GQyWhjSiDXRCCkWXIGKHLkHERaGY12pO
OjSkXuWOSLecAzRoucTqip6WFodauAIwXlCbhkh4AYycuOXAAhsB/7xATUBDwUaEMjSCrMIocSRy
siWHdYkzLABMIseaEpQoSSp5YFhDYghKmkpOH/3881H2mH3iUsNEX7Ps/YePTBOBPbGQ4nQ9Hn8+
+s9/ttFBhycGsriXThUnbh867k5gUPeRWXcCC9xNJnl+UoAFC0vdj5DzE/KIvYiNzU8kNLUfscqB
1+5JjKfu8HY2m67Yzz+z7IzcGtbsR52R3zldV+DZsPdQgS24pizJn2LZkK/EAQWcpi5r8jxfwZLZ
+WJ2+aZasU8sO398xrK31bcV82g+aVOcwNv3vX8++mRhIzBIfw9lDYPtlva5w4dzP+SwYXtM6m/D
rfV6m5aEeFM3ZD3xPkgqrI6UxpxYyMXk4gTBBo6JWEzyQkDQnAIoPwltArYOM2O60JjACH1iEUOp
1wiBEQgDvpdanHBYmcZLI4haqxPRReJvItGHThjc5xL36FJLGDGzyDRWw0fhUwqYESepVTogMkoC
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
osv6Libao4f5X45n87vZ1+UdaVevym+z6Wzi1ZDqfzkvJ7fleiny3CtXJn2r0d1qdkeiGU++Hfuf
gvhO+qMYnShPJGmliPKcIydS3dqkLo79r0iGWNuGrx7Y48q3E0jZrLAobxbl/PZfHofut+ZEXfTa
ydFMr5XcrT+zIQ56dlljaVMOQG56Lc3TX9RRc39VsiQZBRvP78SjbLeAD9tuIfHwPtgURULbw1t3
IdLwoj0zjFR0FoNoVKcJ8+toJcv1l2YlH3d0r11RewiJKd4ERZe6j3jTr72E+qtrkpPUA+2QVm0d
rXYsrKKoV+WXMdywnDdyEWKoh3xY9IJzF11vUMNP2EHy+IMHHuK8/61NeJr4tPHpduWBAQ3X8wd2
RZ7vEvo9KEWMIKIftFIUW2fBbh3EIh94qfCoxJ5+dnMUdtisiPm83jQnOdjrX+TN9uOmeontenax
rDY77N/m1fTUs8V0s5v8f6cL6Y4KZW5kc3RyZWFtCmVuZG9iagoyMDcgMCBvYmoKPDwKL1R5cGUg
L1hSZWYKL0luZGV4IFswIDIwOF0KL1NpemUgMjA4Ci9XIFsxIDMgMV0KL1Jvb3QgMjA1IDAgUgov
SW5mbyAyMDYgMCBSCi9JRCBbPEU0N0RGRjI4QkZGOUM5MkMyNTMxNEQxODg2NzEzNjNFPiA8RTQ3
REZGMjhCRkY5QzkyQzI1MzE0RDE4ODY3MTM2M0U+XQovTGVuZ3RoIDUxMyAgICAgICAKL0ZpbHRl
ciAvRmxhdGVEZWNvZGUKPj4Kc3RyZWFtCnjaHdNLb41RFMbxtXZdqrR1a0/v7am6U1pKLwdtlaOn
9KYUpaXSRBCJKRNj4hkZmvoMZjowNSMR34JEZ5La/zX55TnrPdnvfvda28xsM5klcxsbMtLpjC6S
HBIMULtAqoItMEStRNoK2+AytRHSdqiGCWrDpB1QA1epsUDaCbvgGrVBUi3UwSS186R62A1T1M6R
9sBeuEGNTaZ9sB+mqZ0lNUAjzFA7QypAEyxT6yc1Qwu0Qhu0Qwd0QhcUoRsOQA8chENwGI7AUTgG
x+EEnIQ4yRE3q48T72UHPFAk/iz+LBYQK4tFdYo/B3385G2Kl8fu+SzxNsXL48vjmOL84mDpguhv
egiPYBUe84C9iDaK5onmiREQIyAaLxqvaHcMyCUYhTG4CSW3wnh81jhcgTJU4DrMwhzMs16MxS24
DXfgLtzjaczLgltvQyx6Hx7ACizCkqfn/bF7pklMk5ghMUOiR2J8xPiIoRFDI0ZFjIoYEDW6VX7F
KgW3F18iNbm9fRap2e1zOVKL2/eNSK1uf35GanMv/I7U7j6wHKnDff5dpE73N+8jdbmvf4hU9FT3
L1K3p4mv5qn8LVP5kZmuzsyVMgsvM4ufMkuvMiszmdXBzFox86QmFohhoBWiFaIV4uwVtzGuH11Q
XDpaobhqcbdoiqY8Pf2b13v90f4D+ERm6AplbmRzdHJlYW0KZW5kb2JqCnN0YXJ0eHJlZgoxNjI3
MTYKJSVFT0YK
CHUDFLARE_BIN_B64_EOF_v1_8c0ffee_CHUD_DEN_3
mkdir -p "$ROOT/papers"
cat > "$ROOT/papers/index.html" <<'CHUDFLARE_SDK_FILE_EOF_v1_8c0ffee_CHUD_DEN_3'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <title>Chudflare Research | Pre-prints &amp; Tech Notes</title>
  <meta name="description" content="Pre-prints from Chudmaxx Labs. Edge filtering, looksmaxxing detection, and other parody research."/>
  <link rel="icon" type="image/svg+xml" href="../assets/img/favicon.svg"/>
  <link rel="preconnect" href="https://fonts.googleapis.com"/>
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin/>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&family=JetBrains+Mono:wght@400;500&family=Crimson+Pro:ital,wght@0,400;0,600;1,400&display=swap" rel="stylesheet"/>
  <link rel="stylesheet" href="../assets/css/style.css?v=3"/>
  <style>
    .px-wrap { max-width: 940px; margin: 0 auto; padding: 48px 24px 96px; font-family: 'Crimson Pro', 'Inter', serif; color: #1B1F23; }
    .px-wrap h1 { font-family: 'Crimson Pro', serif; font-size: 40px; letter-spacing: -0.01em; margin: 0 0 6px; }
    .px-wrap .lead { font-size: 17px; color: #4A5057; margin: 0 0 40px; max-width: 640px; line-height: 1.55; }
    .px-list { border-top: 1px solid var(--chud-line); }
    .px-paper { padding: 22px 0 24px; border-bottom: 1px solid var(--chud-line); }
    .px-paper .ax-id { font-family: 'JetBrains Mono', monospace; font-size: 12px; color: #6B7280; margin-bottom: 4px; }
    .px-paper h3 { font-family: 'Crimson Pro', serif; font-size: 22px; font-weight: 600; margin: 0 0 6px; line-height: 1.3; }
    .px-paper h3 a { color: #1B1F23; text-decoration: none; }
    .px-paper h3 a:hover { color: var(--chud-orange-dark); }
    .px-paper .authors { font-size: 14px; color: #4A5057; font-style: italic; margin-bottom: 10px; }
    .px-paper .abstract { font-size: 15px; color: #2A2E33; line-height: 1.55; margin-bottom: 10px; max-width: 720px; }
    .px-paper .links { font-size: 13px; font-family: 'JetBrains Mono', monospace; }
    .px-paper .links a { color: var(--chud-orange-dark); text-decoration: none; margin-right: 14px; }
    .px-paper .links a:hover { text-decoration: underline; }
    .px-paper .subj { display: inline-block; font-size: 11px; padding: 2px 8px; background: #FEF3E6; color: #B8541E; border-radius: 4px; margin-left: 6px; font-family: 'JetBrains Mono', monospace; font-weight: 500; letter-spacing: 0.02em; }
    .px-aside { background: #FFF7ED; border-left: 3px solid var(--chud-orange); padding: 14px 18px; margin: 32px 0; font-size: 14px; color: var(--chud-ink-2); border-radius: 4px; font-family: 'Inter', sans-serif; }
    .px-aside strong { color: var(--chud-orange-dark); }
  </style>
</head>
<body>
  <div class="compliance" style="background:#FAF7F1;color:#5a6068;font-size:12px;line-height:1.5;text-align:center;padding:10px 24px;border-bottom:1px solid var(--chud-line)">
    Chudflare is a parody of Cloudflare. It is not affiliated with, endorsed by, sponsored by, or in any way related to Cloudflare, Inc. Cloudflare ships excellent infrastructure that this site has nothing to do with. For real infrastructure, visit <a href="https://cloudflare.com" style="color:var(--chud-orange-dark);font-weight:600">cloudflare.com</a>.
  </div>

  <header class="nav">
    <div class="container nav-row">
      <a href="../index.html" class="nav-logo">
        <img src="../assets/img/chudflare-mascot.png" alt="" aria-hidden="true"/>
        <span>Chudflare</span>
      </a>
      <nav class="nav-links">
        <a href="../products.html">Products</a>
        <a href="../pricing.html">Pricing</a>
        <a href="../chud-check.html">Verify your site</a>
        <a href="../docs.html">Docs</a>
        <a href="../playground.html">Playground</a>
        <a href="../status.html">Status</a>
        <a href="../blog/index.html">Blog</a>
      </nav>
      <div class="nav-cta">
        <a href="../pricing.html" class="btn btn-primary btn-sm">Start chudmaxxing</a>
      </div>
    </div>
  </header>

  <main class="px-wrap">
    <div style="font-family:'JetBrains Mono',monospace;font-size:12px;color:#6B7280;margin-bottom:8px;text-transform:uppercase;letter-spacing:0.08em">Chudmaxx Labs Pre-print Server</div>
    <h1>Research</h1>
    <p class="lead">Pre-prints and technical notes from Chudmaxx Labs. None of these have been peer reviewed. None of them are real. All of them are typeset in LaTeX.</p>

    <div class="px-aside">
      <strong>Submission policy.</strong> Chudmaxx Labs accepts submissions on any topic at the intersection of CDN engineering and the broader cosmetic-coded computing field. We do not accept submissions. There is no submission portal. There is no reviewer pool. Each paper that appears here was written by one person over the course of one (1) evening.
    </div>

    <div class="px-list">
      <article class="px-paper">
        <div class="ax-id">arXiv:2026.05.chud.0001v2 <span class="subj">cs.CR</span> <span class="subj">cs.SI</span></div>
        <h3><a href="2026.05.chud.0001.pdf">PSL-Based Adversarial Filtering at the CDN Edge: A Production Evaluation Across 310 Points of Presence</a></h3>
        <div class="authors">Hugo Slopwell, Madison Chudwell, Brennan Slopkowski (Chudmaxx Labs, Chudflare Inc.)</div>
        <p class="abstract">We present the design, deployment, and evaluation of an adversarial request-filtering system based on the Perceived Sigma Level (PSL) metric, a 1.0-10.0 continuous-valued classifier trained on 4.2&times;10<sup>9</sup> labeled HTTP request samples. PSL inference is performed in-line at the CDN edge across 310 points of presence (PoPs) with a median added latency of 0.91 ms (p99: 4.3 ms). The classifier achieves 98.7% true-positive rate at a 0.4% false-positive rate against a held-out adversarial corpus. We further introduce <em>Chad Fight Mode</em>, a deployment posture in which all requests scoring above 5.5 on the PSL axis are silently downgraded via HTTP 403, and demonstrate that the approach reduces "unwanted cheekbone exposure" by 93.4% at the edge.</p>
        <div class="links">
          <a href="2026.05.chud.0001.pdf">[PDF, 3 pages]</a>
          <a href="paper.tex">[LaTeX source]</a>
          <a href="../playground.html">[Reference impl (Chudscript)]</a>
        </div>
      </article>

      <article class="px-paper">
        <div class="ax-id">arXiv:2026.??.chud.???? <span class="subj">cs.SE</span></div>
        <h3 style="color:#6B7280">Continuous Lowercasing as a Compiler Pass <span style="font-style:italic;font-weight:400;font-size:14px">(in preparation)</span></h3>
        <div class="authors">M. Chudwell, et al.</div>
        <p class="abstract" style="color:#6B7280">We formalize the under-mew transform as a single-pass AST rewrite and prove its idempotency under repeated application. A reference implementation in the Chudders runtime achieves &lt;3% throughput overhead. Manuscript pending.</p>
        <div class="links" style="color:#9CA3AF">[manuscript not yet released]</div>
      </article>

      <article class="px-paper">
        <div class="ax-id">arXiv:2026.??.chud.???? <span class="subj">cs.NI</span></div>
        <h3 style="color:#6B7280">Anycast Routing Under Posture Constraints <span style="font-style:italic;font-weight:400;font-size:14px">(in preparation)</span></h3>
        <div class="authors">B. Slopkowski</div>
        <p class="abstract" style="color:#6B7280">A revisit of BGP best-path selection in the presence of operator-reported posture telemetry. We argue for the inclusion of an OPTIONAL community attribute encoding the median jawline angle of users served by a given PoP. The IETF has not responded.</p>
        <div class="links" style="color:#9CA3AF">[manuscript not yet released]</div>
      </article>
    </div>

    <p style="margin-top:48px;font-family:'Inter',sans-serif;font-size:13px;color:#6B7280;line-height:1.6">
      For correspondence, do not contact <code style="font-family:'JetBrains Mono',monospace;font-size:12px">{slopwell, chudwell, slopkowski}@chudflare.com</code>. None of these inboxes exist. For real research, see the <a href="https://blog.cloudflare.com/research/" style="color:var(--chud-orange-dark)">Cloudflare Research blog</a>.
    </p>
  </main>

  <footer class="foot">
    <div class="container">
      <div style="text-align:center;padding:20px 0;color:#9CA3AF;font-size:13px">
        &copy; 2026 Chudflare, Inc. All rights chudded. &middot; From our couch to yours.
      </div>
    </div>
  </footer>
</body>
</html>
CHUDFLARE_SDK_FILE_EOF_v1_8c0ffee_CHUD_DEN_3

# ═════════════════════════════════════════════════════════════════════════════
# STEP 7 — playground.html (Chudscript transpiler)
# ═════════════════════════════════════════════════════════════════════════════
say ""
say "${C_BOLD}7. /playground (Chudscript transpiler)${C_RESET}"
ok "wrote playground.html"

# ═════════════════════════════════════════════════════════════════════════════
# STEP 8 — /actions/chudflare-verify (GitHub Action)
# ═════════════════════════════════════════════════════════════════════════════
say ""
say "${C_BOLD}8. /actions/chudflare-verify (GitHub Action)${C_RESET}"
ok "wrote actions/chudflare-verify/{action.yml,index.js,README.md,LICENSE,example-workflow.yml}"
ok "wrote actions/index.html"

# ═════════════════════════════════════════════════════════════════════════════
# STEP 9 — /papers (research pre-print + LaTeX source + PDF)
# ═════════════════════════════════════════════════════════════════════════════
say ""
say "${C_BOLD}9. /papers (PSL pre-print)${C_RESET}"
ok "wrote papers/{paper.tex,2026.05.chud.0001.pdf,index.html}"

# ═════════════════════════════════════════════════════════════════════════════
# STEP 10 — insert "Playground" link into <nav class="nav-links"> on every page
# ═════════════════════════════════════════════════════════════════════════════
say ""
say "${C_BOLD}10. nav links (Playground)${C_RESET}"

PLAY_NAV_SED='
  /<a href="(\.\.\/)?docs\.html"[^>]*>Docs<\/a>/ {
    h
    s/(.*)(<a href="(\.\.\/)?docs\.html"[^>]*>Docs<\/a>)(.*)/\1\2\4\
\1<a href="\3playground.html">Playground<\/a>/
  }
'

find "$ROOT" \
  \( -path "$ROOT/node_modules" -o -path "$ROOT/.git" -o -path "$ROOT/sdk" -o -path "$ROOT/actions/chudflare-verify" \) -prune -o \
  -type f -name "*.html" -print \
| while IFS= read -r file; do
  grep -q 'class="nav-links"' "$file" 2>/dev/null || continue
  patch_file "$file" "$PLAY_NAV_SED" '>Playground</a>'
done

# ═════════════════════════════════════════════════════════════════════════════
# STEP 11 — .htaccess rewrite rule for /playground
# ═════════════════════════════════════════════════════════════════════════════
say ""
say "${C_BOLD}11. .htaccess (/playground)${C_RESET}"

PLAY_HTACCESS_SED='
  /RewriteRule \^docs\$ docs\.html \[L\]/ {
    h
    s/(.*RewriteRule \^docs\$ docs\.html \[L\])(.*)/\1\2\
  RewriteRule ^playground$ playground.html [L]/
  }
'
patch_file "$ROOT/.htaccess" "$PLAY_HTACCESS_SED" 'RewriteRule \^playground\$ playground\.html'

# ═════════════════════════════════════════════════════════════════════════════
# STEP 12 — sitemap.xml entries
# ═════════════════════════════════════════════════════════════════════════════
say ""
say "${C_BOLD}12. sitemap.xml (/playground, /papers/, /actions/)${C_RESET}"

PLAY_SITEMAP_SED='
  /<\/urlset>/ {
    h
    s|(.*)(</urlset>)(.*)|\1  <url><loc>https://chudflare.com/playground</loc><priority>0.9</priority></url>\
  <url><loc>https://chudflare.com/papers/</loc><priority>0.6</priority></url>\
  <url><loc>https://chudflare.com/papers/2026.05.chud.0001.pdf</loc><priority>0.6</priority></url>\
  <url><loc>https://chudflare.com/actions/</loc><priority>0.6</priority></url>\
\2\3|
  }
'
patch_file "$ROOT/sitemap.xml" "$PLAY_SITEMAP_SED" '<loc>https://chudflare.com/playground</loc>'

# ─────────────────────────────────────────────────────────────────────────────
# Done.
# ─────────────────────────────────────────────────────────────────────────────
say ""
ok "${C_BOLD}Chud Docs + SDKs + Playground + Action + Paper applied.${C_RESET}"
say ""
say "  Test locally:"
say "    cd \"$ROOT\" && python3 -m http.server 8000"
say "    open http://127.0.0.1:8000/             # homepage (Playground in nav)"
say "    open http://127.0.0.1:8000/docs.html    # docs"
say "    open http://127.0.0.1:8000/playground.html"
say "    open http://127.0.0.1:8000/actions/     # GitHub Action landing"
say "    open http://127.0.0.1:8000/papers/      # research pre-print"
say "    open http://127.0.0.1:8000/papers/2026.05.chud.0001.pdf"
say ""
say "  Try the SDKs from your local server:"
say "    pip install http://127.0.0.1:8000/sdk/chudflare-4.0.0.tar.gz"
say "    npm install http://127.0.0.1:8000/sdk/chudflare-4.0.0.tgz"
say ""
say "  Backups live alongside each modified file as <file>.pre-docs-bak."
say "  To roll back a single file:  mv <file>.pre-docs-bak <file>"
say "  To remove every backup:      find \"$ROOT\" -name '*.pre-docs-bak' -delete"
say ""
