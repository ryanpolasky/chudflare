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
