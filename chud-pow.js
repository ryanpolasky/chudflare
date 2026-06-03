/*!
 * chud-pow.js: ChudPoW client. A real hashcash proof-of-work solver.
 *
 * Exposes window.__chudPow(onProgress) -> Promise<result>. It:
 *   1. asks /api/challenge for a signed challenge,
 *   2. grinds nonces with a synchronous SHA-256 until the digest has enough
 *      leading zero bits ("prove you're chud enough"),
 *   3. submits the nonce to /api/challenge for real server-side verification.
 *
 * If the edge function is unreachable (e.g. a plain static server), it falls
 * back to solving a locally-generated challenge so the bit still works.
 * It never rejects: this is parody bot-defense, not a bouncer.
 */
(function () {
  'use strict';

  // ---- synchronous SHA-256 (matches Web Crypto / the server byte-for-byte) ----
  var K = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
  ];
  var TE = new TextEncoder();
  function rotr(x, n) { return (x >>> n) | (x << (32 - n)); }

  function sha256hex(str) {
    var msg = TE.encode(str);
    var l = msg.length;
    var withPad = new Uint8Array((((l + 8) >> 6) + 1) * 64);
    withPad.set(msg);
    withPad[l] = 0x80;
    var bitLen = l * 8;
    // 64-bit big-endian length; inputs here are tiny so high word stays 0
    var dv = new DataView(withPad.buffer);
    dv.setUint32(withPad.length - 4, bitLen >>> 0);
    dv.setUint32(withPad.length - 8, Math.floor(bitLen / 0x100000000));

    var H = [0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19];
    var w = new Array(64);
    for (var off = 0; off < withPad.length; off += 64) {
      for (var t = 0; t < 16; t++) {
        w[t] = (withPad[off + t * 4] << 24) | (withPad[off + t * 4 + 1] << 16) | (withPad[off + t * 4 + 2] << 8) | (withPad[off + t * 4 + 3]);
      }
      for (t = 16; t < 64; t++) {
        var s0 = rotr(w[t - 15], 7) ^ rotr(w[t - 15], 18) ^ (w[t - 15] >>> 3);
        var s1 = rotr(w[t - 2], 17) ^ rotr(w[t - 2], 19) ^ (w[t - 2] >>> 10);
        w[t] = (w[t - 16] + s0 + w[t - 7] + s1) | 0;
      }
      var a = H[0], b = H[1], c = H[2], d = H[3], e = H[4], f = H[5], g = H[6], h = H[7];
      for (t = 0; t < 64; t++) {
        var S1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25);
        var ch = (e & f) ^ (~e & g);
        var t1 = (h + S1 + ch + K[t] + w[t]) | 0;
        var S0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22);
        var maj = (a & b) ^ (a & c) ^ (b & c);
        var t2 = (S0 + maj) | 0;
        h = g; g = f; f = e; e = (d + t1) | 0; d = c; c = b; b = a; a = (t1 + t2) | 0;
      }
      H[0] = (H[0] + a) | 0; H[1] = (H[1] + b) | 0; H[2] = (H[2] + c) | 0; H[3] = (H[3] + d) | 0;
      H[4] = (H[4] + e) | 0; H[5] = (H[5] + f) | 0; H[6] = (H[6] + g) | 0; H[7] = (H[7] + h) | 0;
    }
    var out = '';
    for (var i = 0; i < 8; i++) out += ('00000000' + (H[i] >>> 0).toString(16)).slice(-8);
    return out;
  }

  function leadingZeroBits(h) {
    var bits = 0;
    for (var i = 0; i < h.length; i++) {
      var v = parseInt(h[i], 16);
      if (v === 0) { bits += 4; continue; }
      bits += Math.clz32(v) - 28;
      break;
    }
    return bits;
  }

  function localChallenge() {
    var a = new Uint8Array(16);
    (crypto.getRandomValues ? crypto.getRandomValues(a) : a.forEach(function (_, i) { a[i] = (Math.random() * 256) | 0; }));
    var hx = Array.prototype.map.call(a, function (b) { return ('0' + b.toString(16)).slice(-2); }).join('');
    return { challenge: hx, bits: 14, exp: Date.now() + 300000, sig: 'local', local: true };
  }

  function sleep(ms) { return new Promise(function (r) { setTimeout(r, ms); }); }

  async function chudPow(onProgress) {
    function report(msg) { try { if (typeof onProgress === 'function') onProgress(msg); } catch (e) {} }
    report('ChudPoW: requesting challenge…');

    var ch;
    try {
      var res = await fetch('/api/challenge', { headers: { accept: 'application/json' } });
      if (!res.ok) throw new Error('http ' + res.status);
      ch = await res.json();
      if (!ch || !ch.challenge || !ch.bits) throw new Error('bad challenge');
    } catch (e) {
      report('ChudPoW: edge offline, proving locally…');
      ch = localChallenge();
    }

    var bits = ch.bits, prefix = ch.challenge + ':';
    var nonce = 0, hash = '', start = (performance && performance.now) ? performance.now() : Date.now();
    var deadline = start + 20000; // never hang the gate longer than ~20s
    var solved = false;
    for (;;) {
      for (var i = 0; i < 2000; i++) {
        hash = sha256hex(prefix + nonce);
        if (leadingZeroBits(hash) >= bits) { solved = true; break; }
        nonce++;
      }
      if (solved) break;
      var now = (performance && performance.now) ? performance.now() : Date.now();
      var rate = Math.round(nonce / Math.max(0.001, (now - start) / 1000));
      report('ChudPoW: ' + nonce.toLocaleString() + ' hashes @ ' + rate.toLocaleString() + ' H/s — proving you\u2019re chud enough…');
      await sleep(0); // yield so the UI can paint
      if (now > deadline) break;
    }

    var ms = ((performance && performance.now) ? performance.now() : Date.now()) - start;
    var rateFinal = Math.round(nonce / Math.max(0.001, ms / 1000));
    var result = { ok: solved, nonce: nonce, hash: hash, bits: bits, hashes: nonce, ms: Math.round(ms), hashrate: rateFinal, local: !!ch.local, ray: '' };

    if (solved && !ch.local) {
      report('ChudPoW: verifying with the edge…');
      try {
        var vr = await fetch('/api/challenge', {
          method: 'POST',
          headers: { 'content-type': 'application/json' },
          body: JSON.stringify({ challenge: ch.challenge, bits: ch.bits, exp: ch.exp, sig: ch.sig, nonce: String(nonce) })
        });
        var vj = await vr.json();
        result.ok = !!vj.ok;
        result.ray = vj.ray || '';
        result.serverMessage = vj.message || vj.error || '';
      } catch (e) { /* keep client result; parody gate proceeds regardless */ }
    }

    report(solved
      ? 'ChudPoW: \u2713 chud enough — ' + nonce.toLocaleString() + ' hashes in ' + (ms / 1000).toFixed(1) + 's (' + rateFinal.toLocaleString() + ' H/s)'
      : 'ChudPoW: gave up grinding. proceeding anyway, you absolute chud.');
    return result;
  }

  window.ChudPoW = { sha256hex: sha256hex, leadingZeroBits: leadingZeroBits, solve: chudPow };
  window.__chudPow = chudPow;

  if (window.console && console.log) {
    console.log('%cChudPoW%c loaded. real sha256 hashcash. window.ChudPoW.sha256hex("agartha")',
      'color:#F38020;font-weight:bold', 'color:#6b7280');
  }
})();
