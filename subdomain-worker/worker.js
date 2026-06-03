/**
 * chud-subdomains — a standalone Cloudflare Worker that serves registered
 * Chud Registrar subdomains (e.g. bob.imafatfuckingchud.com).
 *
 * WHY THIS EXISTS: Cloudflare PAGES cannot serve wildcard custom domains, so a
 * proxied `*.imafatfuckingchud.com` CNAME to pages.dev dead-ends with a 522.
 * Worker ROUTES, however, support wildcards. This Worker attaches to the route
 * `*.imafatfuckingchud.com/*`, reads the SAME `CHUD_REGISTRY` KV namespace the
 * Pages registrar writes to, and renders the "verified chud" page for any
 * registered host. Unregistered subdomains bounce to the registrar.
 *
 * Deploy:
 *   1. put your KV namespace id in wrangler.toml  (npx wrangler kv namespace list)
 *   2. cd subdomain-worker && npx wrangler deploy
 *
 * It supersedes functions/_middleware.js for the wildcard (Pages can't do it),
 * so you can leave REGISTRAR_WILDCARD off.
 */
export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const host = url.hostname.toLowerCase();

    const parents = (env.CHUD_PARENTS ? env.CHUD_PARENTS.split(',') : ['imafatfuckingchud.com'])
      .map((s) => s.trim().toLowerCase());
    const isSub = parents.some((p) => host.endsWith('.' + p) && host !== p && host !== 'www.' + p);
    if (!isSub) return Response.redirect('https://chudflare.com/registrar', 302);

    let rec = null;
    try { if (env.CHUD_REGISTRY) rec = await env.CHUD_REGISTRY.get('name:' + host, 'json'); } catch (e) { /* fall through */ }

    if (!rec) {
      const label = host.split('.')[0];
      return Response.redirect('https://chudflare.com/registrar?suggest=' + encodeURIComponent(label), 302);
    }

    return new Response(renderChud(rec, host), {
      headers: { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store', 'x-chud-registrar': 'active' }
    });
  }
};

function renderChud(rec, host) {
  const safe = String(host).replace(/[<>&"']/g, '');
  const since = rec.registered ? new Date(rec.registered).toISOString().slice(0, 10) : 'recently';
  return '<!doctype html><html lang="en"><head><meta charset="utf-8"/>' +
    '<meta name="viewport" content="width=device-width, initial-scale=1"/>' +
    '<title>' + safe + ' &middot; a verified chud</title>' +
    '<style>body{margin:0;font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif;background:#0B0F14;color:#fff;display:grid;place-items:center;min-height:100vh;text-align:center}' +
    '.c{padding:40px}.b{display:inline-flex;align-items:center;gap:8px;background:#F38020;color:#fff;font-weight:800;border-radius:99px;padding:6px 14px;font-size:13px}' +
    'h1{font-size:clamp(28px,6vw,52px);margin:18px 0 6px;word-break:break-all}p{color:#9CA3AF}a{color:#FBAD41}</style></head>' +
    '<body><div class="c"><span class="b">&#10003; Verified Chud</span>' +
    '<h1>' + safe + '</h1>' +
    '<p>Registered through the <a href="https://chudflare.com/registrar">Chud Registrar</a> &middot; chud since ' + since + '.</p>' +
    '<p>$5/yr. No banks. No Visa. Nothing ever happens.</p></div></body></html>';
}
