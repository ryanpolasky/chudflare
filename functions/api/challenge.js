/**
 * Cloudflare Pages Function: GET/POST /api/challenge  — ChudPoW
 *
 * A real hashcash-style proof-of-work, used as (useless) bot defense on the
 * /verify gate: "prove you're chud enough." The challenge is stateless and
 * HMAC-signed so the server never has to remember anything.
 *
 *   GET  /api/challenge            -> { challenge, bits, exp, sig }
 *   POST /api/challenge { challenge, bits, exp, sig, nonce }
 *        -> { ok } if sha256(challenge + ":" + nonce) has `bits` leading zero bits
 *
 * Optional env: CHUD_POW_SECRET (HMAC key). Falls back to a default so it
 * works with zero configuration.
 */

const DEFAULT_BITS = 16;
const MIN_BITS = 8;
const MAX_BITS = 22;
const TTL_MS = 5 * 60 * 1000;

const TE = new TextEncoder();
function hex(buf) { return Array.from(new Uint8Array(buf)).map((b) => b.toString(16).padStart(2, '0')).join(''); }
function randHex(n) { const a = new Uint8Array(n); crypto.getRandomValues(a); return hex(a); }
async function hmac(secret, msg) {
  const key = await crypto.subtle.importKey('raw', TE.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  return hex(await crypto.subtle.sign('HMAC', key, TE.encode(msg)));
}
async function sha256hex(msg) { return hex(await crypto.subtle.digest('SHA-256', TE.encode(msg))); }
function leadingZeroBits(h) {
  let bits = 0;
  for (let i = 0; i < h.length; i++) {
    const v = parseInt(h[i], 16);
    if (v === 0) { bits += 4; continue; }
    bits += Math.clz32(v) - 28;
    break;
  }
  return bits;
}

const CORS = { 'access-control-allow-origin': '*', 'access-control-allow-methods': 'GET, POST, OPTIONS', 'access-control-allow-headers': 'content-type' };
function json(obj, status) {
  return new Response(JSON.stringify(obj, null, 2), {
    status: status || 200,
    headers: Object.assign({ 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' }, CORS)
  });
}

export async function onRequest(context) {
  const { request, env } = context;
  if (request.method === 'OPTIONS') return new Response(null, { headers: CORS });
  const secret = (env && env.CHUD_POW_SECRET) || 'chud-pow-default-secret-nothing-ever-happens';
  const url = new URL(request.url);

  if (request.method === 'GET') {
    let bits = parseInt(url.searchParams.get('bits') || DEFAULT_BITS, 10);
    if (!(bits >= MIN_BITS && bits <= MAX_BITS)) bits = DEFAULT_BITS;
    const challenge = randHex(16);
    const exp = Date.now() + TTL_MS;
    const sig = await hmac(secret, challenge + '|' + bits + '|' + exp);
    return json({
      challenge, bits, exp, sig,
      algo: 'sha256', preimage: 'challenge + ":" + nonce',
      note: 'find a nonce so sha256(challenge + ":" + nonce) has ' + bits + ' leading zero bits. prove you are chud enough.'
    });
  }

  if (request.method === 'POST') {
    let body;
    try { body = await request.json(); } catch (e) { return json({ ok: false, error: 'send JSON, chud.' }, 400); }
    const { challenge, bits, exp, sig, nonce } = body || {};
    if (!challenge || !bits || !exp || !sig || nonce === undefined || nonce === null) return json({ ok: false, error: 'missing fields.' }, 400);
    if (Date.now() > Number(exp)) return json({ ok: false, error: 'challenge expired. you took too long. very chud of you.' }, 400);
    const expectSig = await hmac(secret, challenge + '|' + bits + '|' + exp);
    if (expectSig !== sig) return json({ ok: false, error: 'bad signature. nice try, gigachad.' }, 400);
    const h = await sha256hex(challenge + ':' + nonce);
    const got = leadingZeroBits(h);
    if (got < Number(bits)) return json({ ok: false, error: 'insufficient work: ' + got + '/' + bits + ' bits. not chud enough.', hash: h }, 400);
    return json({
      ok: true, bits: Number(bits), nonce: String(nonce), hash: h,
      ray: randHex(8) + '-CHUD',
      message: 'verified chud enough. ' + bits + ' bits of pure cope. nothing ever happens.'
    });
  }

  return json({ ok: false, error: 'method not allowed' }, 405);
}
