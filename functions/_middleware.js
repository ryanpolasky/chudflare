/**
 * Optional per-subdomain renderer for Chud Registrar names.
 *
 * OFF BY DEFAULT. It only does anything when ALL of these are true:
 *   - env REGISTRAR_WILDCARD === "on"
 *   - the CHUD_REGISTRY KV namespace is bound
 *   - the request Host is a registered subdomain of a configured parent
 *   - the path is exactly "/"
 * In every other case it calls next() unchanged, so the main site, assets,
 * and all other Functions are completely unaffected.
 *
 * To actually serve sold subdomains: point a wildcard DNS record
 * (*.imafatfuckingchud.com) at this Pages project, then set REGISTRAR_WILDCARD=on.
 */
export async function onRequest(context) {
  const { request, env, next } = context;
  try {
    if (!env || env.REGISTRAR_WILDCARD !== 'on' || !env.CHUD_REGISTRY) return next();

    const url = new URL(request.url);
    if (url.pathname !== '/') return next();

    const host = (request.headers.get('host') || url.hostname).toLowerCase();
    const parents = (env.CHUD_PARENTS ? env.CHUD_PARENTS.split(',') : ['imafatfuckingchud.com']).map((s) => s.trim().toLowerCase());
    const isSub = parents.some((p) => host.endsWith('.' + p) && host !== p && host !== 'www.' + p);
    if (!isSub) return next();

    const rec = await env.CHUD_REGISTRY.get('name:' + host, 'json');
    if (!rec) return next();

    return new Response(renderChud(rec, host), {
      headers: { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store', 'x-chud-registrar': 'active' }
    });
  } catch (e) {
    return next();
  }
}

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
