/**
 * Cloudflare Pages Function: /api/registrar  — the Chud Registrar backend.
 *
 * Sells SUBDOMAINS of a domain you own (e.g. bob.imafatfuckingchud.com) for
 * $5/yr, settled in USDC on Solana (cheap fees, and $5 deters spammers).
 * Payment is verified on-chain: the buyer pays to your
 * USDC address with a memo binding the payment to the requested name, then
 * submits the transaction signature here. We verify amount + memo via RPC,
 * dedupe the signature, run an abuse/reserved-name filter, and write the
 * registration to KV.
 *
 *   GET  /api/registrar?name=bob&parent=imafatfuckingchud.com   -> availability + pay details
 *   GET  /api/registrar?whois=bob.imafatfuckingchud.com         -> RDAP-ish record
 *   POST /api/registrar { name, parent, signature }            -> verify + register
 *
 * Required env (Cloudflare Pages -> Settings -> Environment variables):
 *   CHUD_PAY_ADDRESS   Solana owner wallet that holds the receiving USDC ATA
 *   SOLANA_RPC         RPC endpoint (e.g. a Helius/QuickNode URL)
 * Optional env:
 *   USDC_MINT          SPL mint (defaults to mainnet USDC)
 *   CHUD_PRICE_USDC    price in USDC (default 1)
 *   CHUD_PARENTS       comma-separated sellable parent domains
 * Required binding:
 *   CHUD_REGISTRY      KV namespace (the name + signature ledger)
 *
 * NOTE ON ABUSE: selling public subdomains under your domain WILL attract
 * phishing / slurs / worse. The blocklist below is a STARTER, not a shield.
 * Keep a manual-review + takedown path, and expand RESERVED/BLOCK over time.
 */

const USDC_MINT_DEFAULT = 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v'; // mainnet USDC
const PRICE_DEFAULT = 5;
const PARENTS_DEFAULT = ['imafatfuckingchud.com'];
const MEMO_PROGRAM = 'MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr';

// Functional subdomains people must not be able to buy.
const RESERVED = new Set([
  'www', 'api', 'mail', 'smtp', 'imap', 'pop', 'ns', 'ns1', 'ns2', 'dns', 'dns-query',
  'cdn-cgi', 'assets', 'static', 'cdn', 'blog', 'docs', 'status', 'dashboard', 'radar',
  'slop', 'verify', 'apply', 'pricing', 'products', 'registrar', 'sdk', 'papers', 'actions',
  'admin', 'root', 'chud', 'chudflare', 'app', 'staging', 'dev', 'test', 'mx', 'autodiscover',
  // anti-phishing: brand/auth lures
  'login', 'signin', 'secure', 'account', 'wallet', 'pay', 'billing', 'support', 'paypal',
  'coinbase', 'binance', 'metamask', 'phantom', 'solana', 'apple', 'google', 'microsoft',
  'amazon', 'irs', 'gov', 'bank'
]);

// Starter abuse blocklist (substring match). EXPAND THIS + keep manual review.
const BLOCK = [
  'csam', 'childporn', 'cp-', 'rape', 'kill', 'nazi', 'hitler', 'kkk',
  'nigger', 'faggot', 'retard', 'tranny', 'kike', 'spic', 'chink',
  'porn', 'xxx', 'onlyfans', 'escort', 'cocaine', 'fentanyl'
];

function cors() {
  return { 'access-control-allow-origin': '*', 'access-control-allow-methods': 'GET, POST, OPTIONS', 'access-control-allow-headers': 'content-type' };
}
function json(obj, status) {
  return new Response(JSON.stringify(obj, null, 2), {
    status: status || 200,
    headers: Object.assign({ 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' }, cors())
  });
}

function normName(s) { return (s || '').trim().toLowerCase(); }
function validName(n) {
  return n.length >= 1 && n.length <= 63 && /^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$/.test(n) && !n.includes('--');
}
function abuseReason(n) {
  if (RESERVED.has(n)) return 'reserved';
  for (var i = 0; i < BLOCK.length; i++) if (n.indexOf(BLOCK[i]) !== -1) return 'blocked';
  return null;
}
function parents(env) {
  return (env && env.CHUD_PARENTS ? env.CHUD_PARENTS.split(',').map(function (s) { return s.trim().toLowerCase(); }) : PARENTS_DEFAULT);
}
function priceUsdc(env) { return Number((env && env.CHUD_PRICE_USDC) || PRICE_DEFAULT); }
function memoFor(fqdn) { return 'chud-reg:' + fqdn; }

function solanaPayUrl(env, fqdn) {
  var addr = env && env.CHUD_PAY_ADDRESS;
  if (!addr) return null;
  var mint = (env && env.USDC_MINT) || USDC_MINT_DEFAULT;
  var p = new URLSearchParams();
  p.set('amount', String(priceUsdc(env)));
  p.set('spl-token', mint);
  p.set('memo', memoFor(fqdn));
  p.set('label', 'Chud Registrar');
  p.set('message', 'Registering ' + fqdn + ' for 1 year. Nothing ever happens.');
  return 'solana:' + addr + '?' + p.toString();
}

async function kv(env) { return env && env.CHUD_REGISTRY ? env.CHUD_REGISTRY : null; }
async function getReg(env, fqdn) { var k = await kv(env); return k ? k.get('name:' + fqdn, 'json') : null; }
async function putReg(env, fqdn, rec) { var k = await kv(env); if (k) await k.put('name:' + fqdn, JSON.stringify(rec)); }
async function sigSeen(env, sig) { var k = await kv(env); return k ? k.get('sig:' + sig) : null; }
async function markSig(env, sig, fqdn) { var k = await kv(env); if (k) await k.put('sig:' + sig, fqdn); }

async function rpc(env, method, params) {
  var r = await fetch(env.SOLANA_RPC, {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ jsonrpc: '2.0', id: 1, method: method, params: params })
  });
  var j = await r.json();
  if (j.error) throw new Error(j.error.message || 'rpc error');
  return j.result;
}

function txHasMemo(tx, memo) {
  try {
    var ixs = (tx.transaction.message.instructions || []).slice();
    (tx.meta.innerInstructions || []).forEach(function (g) { ixs = ixs.concat(g.instructions || []); });
    for (var i = 0; i < ixs.length; i++) {
      var ix = ixs[i];
      var isMemo = ix.program === 'spl-memo' || ix.programId === MEMO_PROGRAM;
      if (!isMemo) continue;
      var data = typeof ix.parsed === 'string' ? ix.parsed : (ix.memo || '');
      if (data && data.indexOf(memo) !== -1) return true;
    }
  } catch (e) {}
  return false;
}

async function verifyPayment(env, signature, fqdn) {
  if (!env || !env.CHUD_PAY_ADDRESS || !env.SOLANA_RPC) {
    return { ok: false, error: 'registrar payment is not configured on this deployment (missing CHUD_PAY_ADDRESS or SOLANA_RPC).' };
  }
  if (!/^[1-9A-HJ-NP-Za-km-z]{60,100}$/.test(signature || '')) return { ok: false, error: 'that does not look like a Solana transaction signature.' };

  var mint = env.USDC_MINT || USDC_MINT_DEFAULT;
  var dest = env.CHUD_PAY_ADDRESS;
  var needed = Math.round(priceUsdc(env) * 1e6); // USDC has 6 decimals

  var tx;
  try { tx = await rpc(env, 'getTransaction', [signature, { maxSupportedTransactionVersion: 0, encoding: 'jsonParsed', commitment: 'confirmed' }]); }
  catch (e) { return { ok: false, error: 'RPC error verifying payment: ' + e.message }; }
  if (!tx) return { ok: false, error: 'transaction not found yet. wait a few seconds for confirmation and retry.' };
  if (tx.meta && tx.meta.err) return { ok: false, error: 'that transaction failed on-chain.' };

  function sum(arr) {
    return (arr || []).filter(function (b) { return b.mint === mint && b.owner === dest; })
      .reduce(function (s, b) { return s + Number(b.uiTokenAmount.amount); }, 0);
  }
  var delta = sum(tx.meta.postTokenBalances) - sum(tx.meta.preTokenBalances);
  if (delta < needed) return { ok: false, error: 'insufficient USDC to ' + dest + ': received ' + (delta / 1e6) + ', need ' + priceUsdc(env) + '.' };

  if (!txHasMemo(tx, memoFor(fqdn))) {
    return { ok: false, error: 'payment is missing the memo "' + memoFor(fqdn) + '". it binds your payment to this exact name (anti-reuse). pay again with the memo, or use the Solana Pay link.' };
  }
  return { ok: true, amount: delta / 1e6, slot: tx.slot, blockTime: tx.blockTime || null };
}

function rayId() {
  var hex = '0123456789abcdef', s = '';
  for (var i = 0; i < 8; i++) s += hex[(Math.random() * 16) | 0];
  return s + '-CHUD';
}

export async function onRequest(context) {
  var request = context.request, env = context.env;
  if (request.method === 'OPTIONS') return new Response(null, { headers: cors() });
  var url = new URL(request.url);

  try {
    // ---- WHOIS / RDAP ----
    var whois = url.searchParams.get('whois');
    if (whois) {
      var rec = await getReg(env, normName(whois));
      if (!rec) return json({ found: false, query: whois, status: 'available', note: 'no such chud. yet.' });
      return json({ found: true, fqdn: rec.fqdn, status: rec.status, registered: rec.registered, expires: rec.expires, registrar: 'Chud Registrar', payment: { chain: 'solana', token: 'USDC', signature: rec.payment && rec.payment.signature } });
    }

    // ---- availability ----
    if (request.method === 'GET') {
      var qname = normName(url.searchParams.get('name'));
      var qparent = normName(url.searchParams.get('parent')) || parents(env)[0];
      if (!qname) return json({ ok: true, service: 'Chud Registrar', parents: parents(env), price_usdc: priceUsdc(env), note: 'GET ?name=<label>&parent=<domain> to check availability.' });
      if (parents(env).indexOf(qparent) === -1) return json({ available: false, reason: 'unknown parent domain' }, 400);
      if (!validName(qname)) return json({ available: false, name: qname, reason: 'invalid format (a-z, 0-9, hyphens; 1-63 chars; no leading/trailing or double hyphen)' });
      var why = abuseReason(qname);
      if (why) return json({ available: false, name: qname, reason: why });
      var fqdn = qname + '.' + qparent;
      var taken = await getReg(env, fqdn);
      return json({
        available: !taken, fqdn: fqdn, price_usdc: priceUsdc(env),
        pay: taken ? null : {
          chain: 'solana', token: 'USDC',
          mint: (env && env.USDC_MINT) || USDC_MINT_DEFAULT,
          address: (env && env.CHUD_PAY_ADDRESS) || null,
          amount: priceUsdc(env),
          memo: memoFor(fqdn),
          solana_pay: solanaPayUrl(env, fqdn),
          configured: !!(env && env.CHUD_PAY_ADDRESS && env.SOLANA_RPC)
        }
      });
    }

    // ---- register (verify payment) ----
    if (request.method === 'POST') {
      var body;
      try { body = await request.json(); } catch (e) { return json({ ok: false, error: 'send JSON.' }, 400); }
      var name = normName(body.name);
      var parent = normName(body.parent) || parents(env)[0];
      var signature = (body.signature || '').trim();

      if (parents(env).indexOf(parent) === -1) return json({ ok: false, error: 'unknown parent domain.' }, 400);
      if (!validName(name)) return json({ ok: false, error: 'invalid name format.' }, 400);
      var reason = abuseReason(name);
      if (reason) return json({ ok: false, error: 'name not allowed (' + reason + ').' }, 400);
      if (!signature) return json({ ok: false, error: 'missing transaction signature.' }, 400);

      var fqdn2 = name + '.' + parent;
      if (await getReg(env, fqdn2)) return json({ ok: false, error: fqdn2 + ' is already a chud.' }, 409);
      if (await sigSeen(env, signature)) return json({ ok: false, error: 'that payment signature was already used.' }, 409);

      var v = await verifyPayment(env, signature, fqdn2);
      if (!v.ok) return json({ ok: false, error: v.error }, 402);

      if (!(await kv(env))) return json({ ok: false, error: 'payment verified, but the registry (KV) is not bound, so we cannot persist it. bind CHUD_REGISTRY.' }, 500);

      var now = Date.now();
      var rec2 = {
        fqdn: fqdn2, name: name, parent: parent, status: 'active',
        registered: now, expires: now + 365 * 24 * 60 * 60 * 1000,
        payment: { chain: 'solana', token: 'USDC', amount: v.amount, signature: signature, slot: v.slot },
        ray: rayId()
      };
      await putReg(env, fqdn2, rec2);
      await markSig(env, signature, fqdn2);
      return json({
        ok: true, registration: rec2,
        certificate: 'CERTIFICATE OF CHUDATION\n' + fqdn2 + '\nregistered ' + new Date(now).toISOString().slice(0, 10) +
          ' | expires ' + new Date(rec2.expires).toISOString().slice(0, 10) + '\npaid ' + v.amount + ' USDC (sol) | ray ' + rec2.ray + '\nnothing ever happens.'
      });
    }

    return json({ ok: false, error: 'method not allowed' }, 405);
  } catch (e) {
    return json({ ok: false, error: 'registrar got mogged: ' + (e && e.message) }, 500);
  }
}
