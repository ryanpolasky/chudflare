/**
 * Cloudflare Pages Function: GET/POST /dns-query
 *
 * The Chud Name System (CNS). It resolves domains the way a guy at a party
 * answers questions he does not know the answer to: instantly, confidently, and
 * the same way every time. You get A records in 10.20.0.0/16, a "v=chud1" TXT,
 * and your mail routed through DoorDash. None of it is real. All of it is wrong.
 *
 * The inconvenient part: it speaks actual DoH, so real clients believe it.
 * Point one at it and watch it nod along:
 *
 *   # JSON DoH (the Google/Cloudflare dialect)
 *   curl -s 'https://chudflare.com/dns-query?name=imafatfuckingchud.com&type=A' \
 *        -H 'accept: application/dns-json'
 *
 *   # RFC 8484 wire format (what your browser's Secure DNS speaks)
 *   kdig @https://chudflare.com/dns-query imafatfuckingchud.com
 *
 * Resolver identity: 6.9.6.9. Same domain in, same nonsense out (FNV-1a seed).
 */

const TYPE_BY_NAME = { A: 1, NS: 2, CNAME: 5, SOA: 6, MX: 15, TXT: 16, AAAA: 28, ANY: 255 };
const NAME_BY_TYPE = { 1: 'A', 2: 'NS', 5: 'CNAME', 6: 'SOA', 15: 'MX', 16: 'TXT', 28: 'AAAA', 255: 'ANY' };

const STATUS_WORDS = ['fat', 'hunched', 'no-bone', 'mogged', 'slopped', 'chudded', 'looksminned'];
const MX_HOSTS = ['mail.doordash.routing.chud.', 'mail.uber-eats.routing.chud.', 'fallback.gelato-fridge.chud.'];
const NS_HOSTS = ['chad.ns.chudflare.com.', 'val.ns.chudflare.com.'];
const TTL = 60;

// ---------- deterministic chud record generation ----------
function fnv1a(str) {
  let h = 2166136261 >>> 0;
  for (let i = 0; i < str.length; i++) { h ^= str.charCodeAt(i); h = Math.imul(h, 16777619) >>> 0; }
  return h >>> 0;
}
function mulberry32(a) {
  return function () {
    let t = (a += 0x6D2B79F5);
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
function chudData(domain) {
  const d = domain.toLowerCase().replace(/\.$/, '');
  const rng = mulberry32(fnv1a(d));
  const a = [];
  for (let i = 0; i < 3; i++) a.push('10.20.' + Math.floor(rng() * 254) + '.' + Math.floor(rng() * 254));
  const psl = +(2.0 + rng() * 7.0).toFixed(1);
  const hunch = Math.floor(rng() * 60);
  const status = STATUS_WORDS[Math.floor(rng() * STATUS_WORDS.length)];
  const g = () => Math.floor(rng() * 65536).toString(16);
  const aaaa = '2606:6969:' + g() + ':' + g() + ':' + g() + ':' + g() + ':6:9';
  return { d, a, aaaa, txt: 'v=chud1 hunch=' + hunch + ' psl=' + psl + ' status=' + status, cname: 'chud-edge.' + d + '.' };
}
function isResolvable(d) { return /^(?=.{1,253}$)([a-z0-9_](-?[a-z0-9_])*\.)+[a-z]{2,}$/i.test(d); }

// ---------- JSON DoH ----------
function jsonAnswers(c, qtype) {
  const name = c.d + '.';
  const out = [];
  const add = (type, data) => out.push({ name, type, TTL, data });
  if (qtype === 1 || qtype === 255) c.a.forEach((ip) => add(1, ip));
  if (qtype === 28 || qtype === 255) add(28, c.aaaa);
  if (qtype === 16 || qtype === 255) add(16, '"' + c.txt + '"');
  if (qtype === 15 || qtype === 255) MX_HOSTS.forEach((h, i) => add(15, (10 + i * 10) + ' ' + h));
  if (qtype === 2 || qtype === 255) NS_HOSTS.forEach((h) => add(2, h));
  if (qtype === 5) add(5, c.cname);
  if (qtype === 6) add(6, NS_HOSTS[0] + ' chud.chudflare.com. 2026060301 7200 3600 1209600 60');
  return out;
}
function jsonResponse(domain, qtype, cors) {
  const resolvable = isResolvable(domain);
  const c = chudData(domain);
  const ans = resolvable ? jsonAnswers(c, qtype) : [];
  const body = {
    Status: resolvable ? 0 : 3,
    TC: false, RD: true, RA: true, AD: false, CD: false,
    Question: [{ name: domain.replace(/\.?$/, '.'), type: qtype }],
    Answer: ans,
    Comment: resolvable
      ? 'resolved by CNS (6.9.6.9). nothing ever happens.'
      : 'NXCHUD: that is not a domain. did you fall asleep mid-type?'
  };
  return new Response(JSON.stringify(body, null, 2), {
    headers: Object.assign({
      'content-type': 'application/dns-json; charset=utf-8',
      'cache-control': 'max-age=60',
      'x-resolver': '6.9.6.9',
      'x-chud-mode': 'ON'
    }, cors)
  });
}

// ---------- human-readable dig output (format=dig / ct=text) ----------
function digText(domain, qtype) {
  const resolvable = isResolvable(domain);
  const ans = resolvable ? jsonAnswers(chudData(domain), qtype) : [];
  const lines = [
    '; <<>> chudflare DoH <<>> ' + domain + ' ' + (NAME_BY_TYPE[qtype] || qtype) + ' @6.9.6.9',
    '; (1 server found in 4ms, operator was already hunched)',
    ';; ->>HEADER<<- opcode: QUERY, status: ' + (resolvable ? 'NOERROR' : 'NXCHUD') + ', records: ' + ans.length,
    ''
  ];
  if (ans.length) {
    lines.push(';; ANSWER SECTION:');
    ans.forEach((a) => lines.push(a.name + '\t' + a.TTL + '\tIN\t' + (NAME_BY_TYPE[a.type] || a.type) + '\t' + a.data));
  } else {
    lines.push(';; no records. NXCHUD: did you fall asleep mid-type?');
  }
  lines.push('', ';; Query time: 4 msec', ';; SERVER: 6.9.6.9#443(6.9.6.9) (DoH)', ';; chudmaxxed=yes, nothing ever happens.');
  return lines.join('\n');
}

// ---------- RFC 8484 wire format ----------
const enc = new TextEncoder();
function b64urlToBytes(s) {
  s = s.replace(/-/g, '+').replace(/_/g, '/');
  while (s.length % 4) s += '=';
  const bin = atob(s);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}
function readName(view, off) {
  const labels = [];
  let jumped = false, next = off, safety = 0;
  while (safety++ < 128) {
    const len = view.getUint8(off);
    if (len === 0) { if (!jumped) next = off + 1; break; }
    if ((len & 0xc0) === 0xc0) {
      const ptr = ((len & 0x3f) << 8) | view.getUint8(off + 1);
      if (!jumped) next = off + 2;
      jumped = true; off = ptr; continue;
    }
    off += 1;
    let s = '';
    for (let i = 0; i < len; i++) s += String.fromCharCode(view.getUint8(off + i));
    labels.push(s);
    off += len;
  }
  return { name: labels.join('.'), next };
}
function encodeName(name) {
  const clean = (name || '').replace(/\.$/, '');
  const out = [];
  if (clean.length) for (const part of clean.split('.')) {
    const b = enc.encode(part);
    out.push(b.length & 0x3f);
    for (const x of b) out.push(x);
  }
  out.push(0);
  return out;
}
function ipv4Bytes(ip) { return ip.split('.').map((n) => parseInt(n, 10) & 0xff); }
function ipv6Bytes(ip) {
  const groups = ip.split(':').map((g) => parseInt(g || '0', 16) & 0xffff);
  const out = [];
  for (let i = 0; i < 8; i++) { const g = groups[i] || 0; out.push((g >> 8) & 0xff, g & 0xff); }
  return out;
}
function u16(n) { return [(n >> 8) & 0xff, n & 0xff]; }
function u32(n) { return [(n >>> 24) & 0xff, (n >>> 16) & 0xff, (n >>> 8) & 0xff, n & 0xff]; }
function rr(out, type, rdata) {
  out.push(0xc0, 0x0c);          // NAME -> pointer to question (offset 12)
  out.push(...u16(type), ...u16(1), ...u32(TTL), ...u16(rdata.length), ...rdata);
}
function wireAnswers(c, qtype) {
  const recs = [];
  if (qtype === 1 || qtype === 255) c.a.forEach((ip) => recs.push([1, ipv4Bytes(ip)]));
  if (qtype === 28 || qtype === 255) recs.push([28, ipv6Bytes(c.aaaa)]);
  if (qtype === 16 || qtype === 255) { const t = enc.encode(c.txt); recs.push([16, [t.length & 0xff, ...t]]); }
  if (qtype === 15 || qtype === 255) MX_HOSTS.forEach((h, i) => recs.push([15, [...u16(10 + i * 10), ...encodeName(h)]]));
  if (qtype === 2 || qtype === 255) NS_HOSTS.forEach((h) => recs.push([2, encodeName(h)]));
  if (qtype === 5) recs.push([5, encodeName(c.cname)]);
  return recs;
}
function buildWireResponse(query) {
  const view = new DataView(query.buffer, query.byteOffset, query.byteLength);
  const id = view.getUint16(0);
  const rd = (view.getUint8(2) & 0x01);
  const q = readName(view, 12);
  const qtype = view.getUint16(q.next);
  const qclass = view.getUint16(q.next + 2);
  const resolvable = isResolvable(q.name);
  const recs = resolvable ? wireAnswers(chudData(q.name), qtype) : [];

  const out = [];
  out.push(...u16(id));
  // flags: QR=1, Opcode=0, AA=0, TC=0, RD=copy, RA=1, rcode 0 or 3 (NXDOMAIN)
  const flagsHi = 0x80 | (rd ? 0x01 : 0x00);
  const flagsLo = 0x80 | (resolvable ? 0x00 : 0x03);
  out.push(flagsHi, flagsLo);
  out.push(...u16(1));            // QDCOUNT
  out.push(...u16(recs.length));  // ANCOUNT
  out.push(...u16(0), ...u16(0)); // NS, AR
  // question section (echo)
  out.push(...encodeName(q.name), ...u16(qtype), ...u16(qclass));
  // answers
  for (const [type, rdata] of recs) rr(out, type, rdata);
  return Uint8Array.from(out);
}

// ---------- handler ----------
const CORS = { 'access-control-allow-origin': '*', 'access-control-allow-methods': 'GET, POST, OPTIONS', 'access-control-allow-headers': 'content-type, accept' };

export async function onRequest(context) {
  const { request } = context;
  if (request.method === 'OPTIONS') return new Response(null, { headers: CORS });

  const url = new URL(request.url);
  const accept = request.headers.get('accept') || '';
  const ct = request.headers.get('content-type') || '';

  try {
    // ----- wire format: POST application/dns-message, or GET ?dns=base64url -----
    let wireQuery = null;
    if (request.method === 'POST' && ct.includes('application/dns-message')) {
      wireQuery = new Uint8Array(await request.arrayBuffer());
    } else if (url.searchParams.has('dns')) {
      wireQuery = b64urlToBytes(url.searchParams.get('dns'));
    }
    if (wireQuery) {
      const resp = buildWireResponse(wireQuery);
      return new Response(resp, {
        headers: Object.assign({
          'content-type': 'application/dns-message',
          'cache-control': 'max-age=60',
          'x-resolver': '6.9.6.9'
        }, CORS)
      });
    }

    // ----- JSON DoH: ?name=&type= -----
    const name = (url.searchParams.get('name') || '').trim().replace(/^https?:\/\//, '').replace(/\/.*$/, '');
    if (!name) {
      return new Response(JSON.stringify({
        resolver: '6.9.6.9',
        usage: 'GET /dns-query?name=<domain>&type=A  (Accept: application/dns-json)  |  or RFC 8484 wire via ?dns= / POST application/dns-message',
        note: 'this is a parody DoH resolver. every answer is deterministic chud nonsense. nothing ever happens.'
      }, null, 2), { headers: Object.assign({ 'content-type': 'application/json; charset=utf-8' }, CORS) });
    }
    const typeParam = (url.searchParams.get('type') || 'A').toUpperCase();
    const qtype = TYPE_BY_NAME[typeParam] || parseInt(typeParam, 10) || 1;
    const fmt = (url.searchParams.get('format') || '').toLowerCase();
    if (fmt === 'dig' || url.searchParams.get('ct') === 'text') {
      return new Response(digText(name, qtype) + '\n', {
        headers: Object.assign({ 'content-type': 'text/plain; charset=utf-8', 'x-resolver': '6.9.6.9' }, CORS)
      });
    }
    return jsonResponse(name, qtype, CORS);
  } catch (e) {
    return new Response(JSON.stringify({ Status: 2, error: 'SERVFAIL: the resolver got mogged. ' + (e && e.message) }), {
      status: 200, headers: Object.assign({ 'content-type': 'application/dns-json; charset=utf-8' }, CORS)
    });
  }
}
