/**
 * POST /api/apply
 *
 * Cloudflare Pages Function that receives a Chudtern application from
 * apply.html and forwards a formatted embed to a Discord webhook.
 *
 * Required environment variable (set in Cloudflare Pages dashboard
 * under Settings -> Environment variables):
 *
 *   DISCORD_WEBHOOK_URL
 *     full URL to the discord webhook, e.g.
 *     https://discord.com/api/webhooks/<id>/<token>
 *
 * Optional environment variable:
 *
 *   APPLY_RATE_LIMIT_SECONDS
 *     minimum seconds between submissions from the same IP. defaults to 60.
 *     in-memory only, so not a hard guarantee across edge isolates, but
 *     enough to slow casual abuse.
 *
 * Defenses (cheap, layered, no external deps):
 *   - method must be POST
 *   - content-type must be application/json
 *   - body size capped at 16KB
 *   - per-field length caps mirroring apply.html client-side limits
 *   - honeypot field "company_url" silently returns success if filled
 *   - per-isolate rate limit by CF-Connecting-IP
 *   - all user strings are run through stripMentions() before being
 *     embedded so submissions can't @everyone or @here the channel
 */

const ROLE_LABELS = {
  'edge-reliability-intern': 'Edge Reliability Intern, Slop Delivery Network',
  'hunching-intern': 'Hunching Intern',
  'chud-ai-trainer': 'Mumble Engineer Intern, Chud AI',
  'zero-chud-pm': 'PM Intern, Zero Chud',
};

const MEWED_LABELS = {
  yes: 'Yes, currently mewing',
  no: 'No, jaw is freak-coded',
  declined: 'Declined to state',
};

const MAX_BODY_BYTES = 16 * 1024;
const DEFAULT_RATE_LIMIT_SECONDS = 60;

// per-isolate IP cooldown map. CF Pages Functions can spin up many isolates
// so this isn't a hard rate limit, but it suppresses casual repeat-submit
// abuse without needing KV/D1.
const LAST_SUBMIT_AT = new Map();

function jsonResponse(status, body) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'content-type': 'application/json; charset=utf-8',
      'cache-control': 'no-store',
    },
  });
}

// neutralize @everyone / @here / role / channel pings inside a user-supplied
// string. discord substitutes a zero-width-space variant so the mention
// renders as literal text without firing notifications.
function stripMentions(s) {
  if (typeof s !== 'string') return '';
  return s
    .replace(/@everyone/gi, '@\u200beveryone')
    .replace(/@here/gi, '@\u200bhere')
    .replace(/<@!?(\d+)>/g, '<@\u200b$1>')
    .replace(/<@&(\d+)>/g, '<@\u200b&$1>')
    .replace(/<#(\d+)>/g, '<#\u200b$1>');
}

// hard clip a string to a max char count, adding an ellipsis when truncated.
function clip(s, max) {
  if (typeof s !== 'string') return '';
  if (s.length <= max) return s;
  return s.slice(0, max - 1) + '\u2026';
}

function isValidEmail(s) {
  return typeof s === 'string' && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(s);
}

function isValidUrl(s) {
  if (typeof s !== 'string' || !s) return true; // optional
  try {
    const u = new URL(s);
    return u.protocol === 'http:' || u.protocol === 'https:';
  } catch (_) {
    return false;
  }
}

export async function onRequestPost({ request, env }) {
  // env var must be present; without it we have nowhere to deliver the
  // application and there's no point pretending the form works.
  const webhook = env.DISCORD_WEBHOOK_URL;
  if (!webhook || typeof webhook !== 'string' || !webhook.startsWith('https://')) {
    return jsonResponse(500, {
      ok: false,
      error: 'Application intake is not configured. Try again later.',
    });
  }

  // require json content-type to keep this off the form-encoded path
  const ct = (request.headers.get('content-type') || '').toLowerCase();
  if (!ct.includes('application/json')) {
    return jsonResponse(415, { ok: false, error: 'Send JSON.' });
  }

  // read with a size cap to keep memory predictable
  let raw;
  try {
    raw = await request.text();
  } catch (_) {
    return jsonResponse(400, { ok: false, error: 'Could not read request body.' });
  }
  if (raw.length > MAX_BODY_BYTES) {
    return jsonResponse(413, { ok: false, error: 'Application too large.' });
  }

  let body;
  try {
    body = JSON.parse(raw);
  } catch (_) {
    return jsonResponse(400, { ok: false, error: 'Body is not valid JSON.' });
  }
  if (!body || typeof body !== 'object') {
    return jsonResponse(400, { ok: false, error: 'Body must be a JSON object.' });
  }

  // honeypot: if a bot filled the hidden field, fake success without
  // forwarding anything to discord. silent + cheap.
  if (typeof body.company_url === 'string' && body.company_url.length > 0) {
    return jsonResponse(200, { ok: true });
  }

  // simple per-isolate IP cooldown
  const ip = request.headers.get('cf-connecting-ip') || 'unknown';
  const cooldownSec = Number(env.APPLY_RATE_LIMIT_SECONDS) || DEFAULT_RATE_LIMIT_SECONDS;
  const now = Date.now();
  const last = LAST_SUBMIT_AT.get(ip) || 0;
  if (now - last < cooldownSec * 1000) {
    const wait = Math.ceil((cooldownSec * 1000 - (now - last)) / 1000);
    return jsonResponse(429, {
      ok: false,
      error: `Slow down. Try again in ${wait}s.`,
    });
  }

  // validate fields. caps mirror the client-side maxlength values.
  const name = clip(String(body.name || '').trim(), 80);
  const email = String(body.email || '').trim().toLowerCase();
  const role = String(body.role || '').trim();
  const hunch = Number(body.hunch_angle);
  const psl = Number(body.psl);
  const mewed = String(body.mewed || '').trim();
  const why = clip(String(body.why || '').trim(), 1500);
  const crushed = clip(String(body.crushed || '').trim(), 1500);
  const link = clip(String(body.link || '').trim(), 240);

  if (!name) return jsonResponse(400, { ok: false, error: 'Name is required.' });
  if (!isValidEmail(email) || email.length > 120) {
    return jsonResponse(400, { ok: false, error: 'Email is invalid.' });
  }
  if (!ROLE_LABELS[role]) {
    return jsonResponse(400, { ok: false, error: 'Unknown role.' });
  }
  if (!Number.isFinite(hunch) || hunch < 0 || hunch > 90) {
    return jsonResponse(400, { ok: false, error: 'Hunch angle must be 0-90.' });
  }
  if (!Number.isFinite(psl) || psl < 0 || psl > 10) {
    return jsonResponse(400, { ok: false, error: 'PSL must be 0-10.' });
  }
  if (!MEWED_LABELS[mewed]) {
    return jsonResponse(400, { ok: false, error: 'Mewing status is invalid.' });
  }
  if (why.length < 40) {
    return jsonResponse(400, { ok: false, error: '"Why Chudflare?" must be at least 40 characters.' });
  }
  if (!isValidUrl(link)) {
    return jsonResponse(400, { ok: false, error: 'Portfolio URL must be http(s).' });
  }

  // build the discord embed
  const country = request.headers.get('cf-ipcountry') || '??';
  const userAgent = request.headers.get('user-agent') || 'unknown';

  const fields = [
    { name: 'Name', value: stripMentions(name) || '(blank)', inline: true },
    { name: 'Email', value: stripMentions(email), inline: true },
    { name: 'Role', value: ROLE_LABELS[role], inline: false },
    { name: 'Hunch angle', value: `${hunch}\u00b0`, inline: true },
    { name: 'PSL', value: String(psl), inline: true },
    { name: 'Mewing', value: MEWED_LABELS[mewed], inline: true },
    { name: 'Why Chudflare?', value: stripMentions(why) || '(blank)', inline: false },
  ];

  if (crushed) {
    fields.push({ name: 'Crushed it', value: stripMentions(crushed), inline: false });
  }
  if (link) {
    fields.push({ name: 'Link', value: stripMentions(link), inline: false });
  }
  fields.push({
    name: 'Meta',
    value: `IP: \`${stripMentions(ip)}\` · Country: \`${stripMentions(country)}\` · UA: \`${clip(stripMentions(userAgent), 200)}\``,
    inline: false,
  });

  const payload = {
    username: 'Chudflare HR',
    avatar_url: 'https://chudflare.com/assets/img/chudflare-mascot.png',
    // top-level content is also pingable; we keep it harmless and skip role
    // mentions so the channel can decide who to ping via channel settings.
    content: ':rotating_light: new chudtern application :rotating_light:',
    embeds: [{
      title: `New Chudtern\u2122 application: ${ROLE_LABELS[role]}`,
      color: 0xF38020, // chud-orange
      fields,
      footer: { text: 'chudflare.com/apply · this is a parody site' },
      timestamp: new Date().toISOString(),
    }],
    // discord-side override: even if a payload contains a mention, this
    // forbids resolving any of them, so @everyone in a user string can't
    // notify the channel.
    allowed_mentions: { parse: [] },
  };

  // forward to discord. ?wait=true so we get a non-202 status if the
  // webhook is dead, but we treat anything 2xx as success.
  let discordResp;
  try {
    discordResp = await fetch(webhook, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(payload),
    });
  } catch (err) {
    return jsonResponse(502, {
      ok: false,
      error: 'Could not reach the application intake server.',
    });
  }

  if (!discordResp.ok) {
    return jsonResponse(502, {
      ok: false,
      error: `Application intake server returned ${discordResp.status}.`,
    });
  }

  LAST_SUBMIT_AT.set(ip, now);
  return jsonResponse(200, { ok: true });
}

// non-POST methods fall through to here. cf pages dispatches by method
// handler, so this is only ever reached for GET / OPTIONS / etc.
export async function onRequest() {
  return new Response(
    JSON.stringify({ ok: false, error: 'POST only.' }),
    {
      status: 405,
      headers: {
        'content-type': 'application/json; charset=utf-8',
        'allow': 'POST',
      },
    },
  );
}
