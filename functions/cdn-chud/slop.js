/**
 * Cloudflare Pages Function: GET /cdn-chud/slop
 *
 * NOTE ON THE PATH: this lives at /cdn-chud/ and NOT /cdn-cgi/ on purpose.
 * Cloudflare reserves the /cdn-cgi/ prefix for its own edge services and
 * intercepts those requests before Pages Functions run, so a function at
 * /cdn-cgi/slop never executes (it 404s even on Pages). /cdn-chud/ is a normal
 * route, so the SDN actually works while still looking like an internal path.
 *
 * The Slop Delivery Network, except it delivers slop at authentic dial-up
 * speeds. It streams a real same-origin asset back to you, throttled to a
 * chosen baud rate via a paced ReadableStream. This is genuinely functional:
 * the bytes really do trickle out at ~baud/10 bytes per second.
 *
 *   GET /cdn-chud/slop?url=/assets/img/chudflare-mascot.png&baud=2400
 *
 * Guardrails:
 *   - same-origin assets only (no open proxy)
 *   - refuses to slop /cdn-chud/* (no loops)
 *   - total delivery time capped at ~30s (the "slop nap"); below that the
 *     requested baud is honored exactly.
 */

const ALLOWED_BAUD = [110, 300, 1200, 2400, 9600, 14400, 28800, 56000];
const BUDGET_MS = 30000;   // hard cap so a 300-baud request can't run for an hour
const TICK_MS = 90;
const MAX_BYTES = 2 * 1024 * 1024;

function err(msg, status) {
  return new Response('; SDN error: ' + msg + '\n', {
    status: status || 400,
    headers: { 'content-type': 'text/plain; charset=utf-8', 'cache-control': 'no-store' }
  });
}

export async function onRequest(context) {
  const { request } = context;
  const url = new URL(request.url);

  let baud = parseInt(url.searchParams.get('baud') || '2400', 10);
  if (ALLOWED_BAUD.indexOf(baud) === -1) baud = 2400;

  const path = url.searchParams.get('url') || '/assets/img/chudflare-mascot.png';
  let target;
  try { target = new URL(path, url.origin); } catch (e) { return err('that is not a slop-deliverable URL.'); }
  if (target.origin !== url.origin) return err('the SDN only slops same-origin assets. no open proxy, chud.');
  if (target.pathname.startsWith('/cdn-chud/')) return err('refusing to slop the slop endpoint. that way lies agartha.');

  let assetResp;
  try { assetResp = await fetch(target.toString(), { cf: { cacheTtl: 300 } }); }
  catch (e) { return err('could not reach origin. the fridge is unplugged.', 502); }
  if (!assetResp.ok) return err('origin returned ' + assetResp.status + '. nothing ever happens.', 502);

  const data = new Uint8Array(await assetResp.arrayBuffer());
  if (data.length > MAX_BYTES) return err('asset too thicc for dial-up (' + data.length + ' bytes). the SDN tapped out.', 413);
  const contentType = assetResp.headers.get('content-type') || 'application/octet-stream';

  const bytesPerSec = baud / 10; // ~10 bits per byte (8N1)
  const naiveMs = (data.length / bytesPerSec) * 1000;
  const capped = naiveMs > BUDGET_MS;
  const effBytesPerSec = capped ? data.length / (BUDGET_MS / 1000) : bytesPerSec;
  const perTick = Math.max(1, Math.round((effBytesPerSec * TICK_MS) / 1000));

  let offset = 0, cancelled = false;
  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
  const stream = new ReadableStream({
    async pull(controller) {
      if (cancelled) return;
      if (offset >= data.length) { controller.close(); return; }
      const end = Math.min(offset + perTick, data.length);
      controller.enqueue(data.slice(offset, end));
      offset = end;
      await sleep(TICK_MS);
    },
    cancel() { cancelled = true; }
  });

  return new Response(stream, {
    headers: {
      'content-type': contentType,
      'content-length': String(data.length),
      'cache-control': 'no-store',
      'access-control-allow-origin': '*',
      'access-control-expose-headers': 'x-slop-baud, x-slop-bytes, x-slop-eta-sec, x-slop-capped',
      'x-slop-baud': String(baud),
      'x-slop-bytes': String(data.length),
      'x-slop-eta-sec': String(Math.round((capped ? BUDGET_MS : naiveMs) / 1000)),
      'x-slop-capped': capped ? 'yes (slop nap intervened)' : 'no',
      'x-resolver': '6.9.6.9'
    }
  });
}
