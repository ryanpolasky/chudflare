# Chudflare

A static-site parody of cloudflare.com that riffs on TikTok "chudmaxxing"
culture. Pure HTML, CSS, and JS. No build step, no framework, no dependencies.

> ### This is a joke.
>
> Chudflare is a parody. It is not affiliated with, endorsed by, sponsored
> by, or in any way related to Cloudflare, Inc. Cloudflare ships excellent
> infrastructure that this project does not, will not, and could not exist
> without admiring. The whole site is a love letter to their design system,
> dressed up as a roast of the TikTok "chudmaxxing" subculture (an ironic,
> self-deprecating internet trend about chronically online posture and diet).
> Nothing here is a swing at Cloudflare or any real person. If a line on the
> site reads that way to you, please re-read it: every joke is aimed at the
> author, the audience, and the internet itself, in that order.
>
> Do not point your nameservers at any of this. There is no infrastructure
> behind it. The "Slop Delivery Network" is one anycast joke and zero servers.

## What's in the box

```
chudflare/
├── index.html               Homepage (hero, products, pillars, live stats, testimonials, CTA)
├── products.html            Product catalog + interactive WAF tester + CNS resolver + CLI pillar
├── pricing.html             Four-tier pricing (Chud / Looksminned / Permachud / Gigachud)
├── chud-check.html          Verify your site & claim the Verified Chud badge
├── chudify.html             Free chud-speak text rewriter (deterministic, shareable URLs)
├── psl-detector.html        Free PSL detector (image URL or name → hash → PSL score)
├── status.html              Fake status page (operational dashboard + incident history)
├── radar.html               Chud Radar: network-wide trends dashboard (parody of radar.cloudflare.com)
├── dashboard.html           Chud Dashboard: logged-in zone view + editable CNS records (parody of dash.cloudflare.com)
├── slop.html                Dial-up SDN demo (streams an asset at a chosen baud via /cdn-chud/slop)
├── registrar.html           Chud Registrar: $5/yr subdomains paid in USDC on Solana
├── verify.html              Cloudflare-style "checking if you're a chud" interstitial (works as a real gate via `?return=<url>`)
├── apply.html               Chudtern™ internship application form (posts to Discord via Pages Function)
├── chud-gate.js             Drop-in script: gate any site behind /verify (24h pass per visitor)
├── chud-pow.js              ChudPoW: client SHA-256 hashcash solver for the /verify gate
├── 404.html / 500.html / 1020.html   Error pages
├── chudflare                The CLI (bash script, no extension on purpose)
├── install.sh               curl-installable installer for the CLI
├── cdn-cgi/trace            Plaintext cf-trace endpoint (curl-able)
├── robots.txt               User-agent: Gigachad / Disallow: /
├── humans.txt               Team credits (all PSL-redacted)
├── sitemap.xml              Sitemap of all routes
├── .well-known/
│   ├── security.txt         security.txt + chud-bounty severity scale
│   └── chud-verified.json   Self-attested chud-verification record
├── blog/
│   ├── index.html           Blog landing
│   ├── post.css             Shared blog post styles
│   ├── postmortem-chud-ai-coherent-output.html
│   ├── announcing-mewing-ai-2.html
│   ├── why-we-rotated-counter-clockwise.html
│   ├── zero-chud-at-scale.html
│   └── the-great-doordash-degradation.html
├── _headers                 Cloudflare Pages response-header config
├── _redirects               Cloudflare Pages URL canonicalization (strips .html)
├── functions/                  Cloudflare Pages Functions (real serverless endpoints)
│   ├── dns-query.js            DoH resolver: /dns-query (JSON + RFC 8484 wire + dig text)
│   ├── cdn-chud/
│   │   └── slop.js             Dial-up SDN: /cdn-chud/slop streams an asset throttled to baud
│   ├── api/
│   │   ├── apply.js            POST /api/apply -> Discord webhook
│   │   ├── challenge.js        ChudPoW: /api/challenge (HMAC-signed proof-of-work)
│   │   └── registrar.js        Chud Registrar: /api/registrar (Solana USDC verify + KV ledger)
│   └── _middleware.js          Optional per-subdomain pages for registered names (env-gated, OFF)
├── README.md                This file
└── assets/
    ├── css/style.css        Full design system
    ├── img/                 SVG logos + favicon
    └── js/chudflare.js      All interactive widgets + verifier + console easter eggs
```

## How to serve it

This is a Cloudflare Pages site. Push the repo (or drag the folder into the
Pages dashboard) and you're done: Pages reads `_headers` and `_redirects`
natively and runs `functions/api/apply.js` at `POST /api/apply`. A plain
static host will serve the pages fine, but the response headers, clean-URL
redirects, and the apply endpoint are Cloudflare Pages-specific.

To preview locally:

```bash
cd chudflare
python3 -m http.server 8000
# open http://localhost:8000
```

## Interactive features

| Feature                    | Page                                | What it does                                                                                                                                                                          |
|----------------------------|-------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Live stat tickers          | `/`                                 | 6.9M chuds, 320 Tbps slop, 9.8B requests, animate in real time                                                                                                                        |
| Chad Fight Mode WAF tester | `/products#mog`                     | Paste any string → fake PSL detection + verdict                                                                                                                                       |
| CNS resolver               | `/products#dns`                     | Type any domain → fake A/TXT/MX records via `dig @6.9.6.9`                                                                                                                            |
| Verify gate                | `/verify`                           | Real "I am a chud" checkbox CAPTCHA before the auto-verify runs                                                                                                                       |
| **Gate your own site**     | `chud-gate.js`                      | Drop `<script src="https://chudflare.com/chud-gate.js"></script>` in your `<head>`. Visitors get bounced to `/verify`, prove chud-ness, and return with a 24h pass in `localStorage`. |
| Cookie Slop banner         | every page                          | "Accept all slop" / "Refuse (chud)", persists in localStorage                                                                                                                         |
| Chud chat                  | every page (floating, bottom-right) | Keyword-aware mumble engine                                                                                                                                                           |
| Site verification          | `/chud-check`                       | The virality flywheel, see below                                                                                                                                                      |
| **Chudify**                | `/chudify`                          | Paste any text, get it rewritten in chud-speak. Shareable URL.                                                                                                                        |
| **PSL Detector**           | `/psl-detector`                     | Paste an image URL or name. Deterministic hash → PSL score                                                                                                                            |
| **Fake status page**       | `/status`                           | Operational dashboard + 4 historical incidents + subscribe form                                                                                                                       |
| **Chudtern™ applications** | `/apply`                            | Four parody internship roles; submissions POST to a Cloudflare Pages Function that forwards a formatted embed to a Discord webhook                                                    |
| **Chud Radar**             | `/radar`                            | Network-wide trend dashboard: live KPIs, PSL-over-time chart, top mogged domains, region/vector bars, PoP health                                                                      |
| **Chud Dashboard**         | `/dashboard`                        | Fake logged-in zone view: live tiles, 24h traffic chart, security events, and an editable CNS records table with proxy toggles                                                        |
| **Chud DNS (DoH)**         | `/dns-query`                        | A real DNS-over-HTTPS resolver (JSON + RFC 8484 wire). The CNS widget and `chudflare dig` query it live; point a browser's Secure DNS at it.                                          |
| **Dial-up SDN**            | `/slop`                             | Streams a real asset back at a chosen baud (110–56k) through a throttled edge stream. The CDN you can feel.                                                                           |
| **ChudPoW**                | `/verify`                           | Real HMAC-signed hashcash; the gate makes you "prove you're chud enough" (`/api/challenge`) before opening.                                                                           |
| **Chud Registrar**         | `/registrar`                        | Buy a real subdomain for $5/yr; pay in USDC on Solana, verified on-chain (`/api/registrar`), recorded in a KV ledger.                                                                 |

## Site verification (`/chud-check`)

1. **Add a marker** to your site (any one of three options):
   - `<meta name="chudflare-verified" content="chud">` in `<head>`
   - `<!-- chudflare:verified -->` anywhere in HTML
   - The literal text `i am a fat fucking chud` somewhere in `<body>`
2. **Run the check**, either paste a URL (we fetch via CORS proxy chain) or paste raw HTML.
3. **Claim the badge**, self-contained inline-HTML embed snippet + share link.

## The CLI

```bash
curl -fsSL https://chudflare.com/install.sh | sh
```

```
chudflare verify <url>      # actually curls + greps for the marker
chudflare badge             # prints the embeddable Verified Chud badge HTML
chudflare psl <text>        # WAF classifier (same engine as the web tool)
chudflare dig <domain>      # CNS resolver fake output
chudflare mew               # random mumbled response
chudflare login             # fake auth, prints chud ray-id
chudflare init              # writes chudflare.yml
chudflare deploy            # fake deploy logs
chudflare hunch             # current operator hunch angle (time-varying)
chudflare status            # chudflare system status page
chudflare --version
```

## Chudtern™ applications (`/apply`)

The careers page (`apply.html`) collects parody intern applications and
forwards each one to a Discord channel via a Cloudflare Pages Function
(`functions/api/apply.js`, exposed at `POST /api/apply`).

### Setup (Cloudflare Pages)

1. **Create a Discord webhook** in your server:
   `Server Settings → Integrations → Webhooks → New Webhook`. Copy the webhook URL.
2. **Add the env var** in the Cloudflare Pages dashboard for this project:
   `Settings → Environment variables → Add variable`
   - Name: `DISCORD_WEBHOOK_URL`
   - Value: the full webhook URL (looks like `https://discord.com/api/webhooks/<id>/<token>`)
   - Optional: `APPLY_RATE_LIMIT_SECONDS` (defaults to `60`) controls the per-IP cooldown in seconds.
3. **Redeploy** the site so the function picks up the new env vars.
4. Visit `/apply`, submit a test application. A formatted embed should
   appear in the Discord channel with all fields plus IP, country, and UA.

### Local dev

The function only runs through Cloudflare's runtime, not a plain static
server. To test locally, install Wrangler and use `wrangler pages dev`:

```bash
echo 'DISCORD_WEBHOOK_URL = "https://discord.com/api/webhooks/your/test"' > .dev.vars
npx wrangler pages dev .
# open http://localhost:8788/apply
```

`python3 -m http.server` will serve the page fine, but every submit
fails with a 405 because there is no function runtime.

### Defenses (built into `functions/api/apply.js`)

- POST-only with `application/json` content-type required
- 16KB body cap
- Server-side field validation (mirrors the client-side `maxlength` / range rules)
- Honeypot field `company_url`: silently 200s if a bot fills it, no Discord forward
- Per-IP cooldown in an in-memory map (best-effort, not guaranteed across edge isolates)
- All user-supplied strings are sanitized to neutralize `@everyone` / `@here` / role pings
- Discord payload also sets `allowed_mentions: { parse: [] }` as a server-side belt-and-suspenders

## Chud Registrar (`/registrar`)

Sells real **subdomains** of a domain you own (e.g. `bob.imafatfuckingchud.com`)
for $5/yr, settled in **USDC on Solana** (cheap fees, and $5 deters spam).
`functions/api/registrar.js` verifies payment on-chain: the buyer sends USDC with
a memo binding the payment to the requested name, then submits the transaction
signature; we verify amount + memo via RPC, dedupe the signature, run a
reserved/abuse filter, and write the registration to KV.

### Setup (Cloudflare Pages)

1. **Bind a KV namespace** called `CHUD_REGISTRY` (Settings → Functions → KV bindings).
2. **Environment variables:**
   - `CHUD_PAY_ADDRESS` — your Solana wallet holding the receiving USDC token account
   - `SOLANA_RPC` — an RPC endpoint (Helius/QuickNode; public RPCs rate-limit)
   - `USDC_MINT` *(optional)* — defaults to mainnet USDC `EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v`
   - `CHUD_PRICE_USDC` *(optional)* — defaults to `5`
   - `CHUD_PARENTS` *(optional)* — comma-separated sellable parents (default `imafatfuckingchud.com`)
3. **(Optional) live subdomains:** point a wildcard DNS record `*.imafatfuckingchud.com`
   at this Pages project and set `REGISTRAR_WILDCARD=on`. `functions/_middleware.js`
   then renders a "verified chud" page per registered name; it is a no-op otherwise.

### Abuse / moderation (read this)

Selling public subdomains under your domain **will** attract phishing, slurs, and
worse. `registrar.js` ships a `RESERVED` set and a starter `BLOCK` list, but that
is a **floor, not a shield**. Keep a manual-review + takedown path (delete the
`name:<fqdn>` KV key), expand the lists, and act on `security@chudflare.com`
reports. At $5 (minus trivial Solana fees) this is still mostly the bit, not a profit center — don't
take on liability you aren't willing to police.

## /cdn-cgi/trace + response headers

```bash
curl -s https://chudflare.com/cdn-cgi/trace
# fl=chud47
# h=chudflare.com
# colo=DEN-CHUD-3
# chudmaxxed=yes
# hunch_angle=47deg
# psl=2.1
# nothing_ever_happens=true
```

Every page also returns chud-flavored response headers (`CF-RAY`, `CF-Cache-Status`,
`X-Hunch-Angle`, `X-Mewing`, `X-Mog-Status`, etc.). These are configured for
Cloudflare Pages, which reads two files at the deploy root:

- **`_headers`** — response headers (`CF-RAY`, `X-Hunch-Angle`, the `/1020` block headers, `.well-known` content-types)
- **`_redirects`** — canonicalizes `.html` URLs to clean paths and aliases `/psl`

## Tier 1 features at a glance

The whole point of the v2 update was to match every layer of real Cloudflare
corporate apparatus:

| Real Cloudflare                              | Chudflare                                          |
|----------------------------------------------|----------------------------------------------------|
| `cloudflarestatus.com`                       | `/status`                                          |
| `cf-ray:` header                             | `cf-ray: 8c0ffee-CHUD-DEN`                         |
| `/cdn-cgi/trace`                             | `/cdn-cgi/trace` (real plaintext endpoint)         |
| `robots.txt` / `humans.txt`                  | same, but chud-flavored                            |
| `/.well-known/security.txt`                  | same, with chud-bounty severity scale              |
| The Cloudflare Blog                          | `/blog` with 5 engineering posts                   |
| Cloudflare Radar                             | `/radar`                                           |
| Cloudflare dashboard (`dash.cloudflare.com`) | `/dashboard`                                       |
| Cloudflare Speed / scan                      | `/psl-detector`                                    |
| Cloudflare Workers playground                | `/playground`                                      |
| `1.1.1.1` DNS-over-HTTPS                     | `/dns-query` (real DoH: JSON + RFC 8484 wire)      |
| The Cloudflare CDN                           | `/slop` (real, but dial-up speed)                  |
| Turnstile / managed challenge                | `/verify` + ChudPoW (`/api/challenge`)             |
| Cloudflare Registrar                         | `/registrar` (subdomains, $5/yr in USDC on Solana) |
| View-source easter eggs                      | every page has a chud comment block                |
| Console branding                             | every page logs hiring + cf-ray + psl              |

## Hosting notes

Cloudflare Pages serves `/foo` from `foo.html` automatically and applies `_headers` + `_redirects`. Route map:

```
/                  → index.html
/products          → products.html
/pricing           → pricing.html
/chud-check        → chud-check.html
/verify            → verify.html
/apply             → apply.html
/api/apply         → functions/api/apply.js  (Cloudflare Pages Function; on other hosts you need a server runtime)
/chudify           → chudify.html
/psl-detector      → psl-detector.html
/status            → status.html
/radar             → radar.html
/dashboard         → dashboard.html
/blog              → blog/index.html
/install.sh        → install.sh     (Content-Type: text/x-shellscript)
/chudflare         → chudflare      (Content-Type: text/x-shellscript)
/cdn-cgi/trace     → cdn-cgi/trace  (Content-Type: text/plain)
/404               → 404.html       (also: global 404 handler)
/500               → 500.html
/1020              → 1020.html      (use this as the WAF block page)
```

## Easter eggs

- Every page contains an HTML comment block visible via View Source.
- Every page logs a hiring banner + cf-ray + PSL/hunch/mewing status to the JS console.
- `/cdn-cgi/trace` is a real plaintext endpoint. `curl` it.
- `/robots.txt` disallows `Gigachad`, `Looksmaxxer`, `MewingBot`, `SigmaGrindsetCrawler`.
- Every footer links to **imafatfuckingchud.com**.
- Chud Ray IDs are all variants of `8c0ffee-chud-X`.
- Public DNS resolver is `6.9.6.9`.
- `/chudify` and `/psl-detector` are **fully deterministic**, same input always
  returns the same output. Both encode their input in the URL hash so results
  are shareable.

## Disclaimer (again)

This is a parody. Chudflare is not affiliated with Cloudflare, Inc., who ships
excellent infrastructure that this site has nothing to do with. The "fat
fucking chud" line on the pricing page is performative self-deprecation, a
direct reference to the TikTok "chudmaxxing" subculture's habit of using that
exact phrasing as ironic self-roast. It is not aimed at any real person.

Do not point your nameservers at this site in production. Or do. Nothing
ever happens.
