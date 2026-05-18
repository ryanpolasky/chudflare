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
├── verify.html              Cloudflare-style "checking if you're a chud" interstitial (works as a real gate via `?return=<url>`)
├── chud-gate.js             Drop-in script: gate any site behind /verify (24h pass per visitor)
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
├── _headers                 Cloudflare Pages / Netlify response-header config
├── _redirects               Cloudflare Pages / Netlify URL canonicalization (strips .html)
├── vercel.json              Vercel deploy + headers config
├── .htaccess                Apache header + rewrite config
├── README.md                This file
└── assets/
    ├── css/style.css        Full design system
    ├── img/                 SVG logos + favicon
    └── js/chudflare.js      All interactive widgets + verifier + console easter eggs
```

## How to serve it

Drop the folder onto any static host (Netlify, Vercel, S3+CloudFront, Caddy,
nginx, GitHub Pages, Cloudflare Pages, your favorite shared host, etc.) and
you're done.

To preview locally:

```bash
cd chudflare
python3 -m http.server 8000
# open http://localhost:8000
```

## Interactive features

| Feature | Page | What it does |
|---|---|---|
| Live stat tickers | `/` | 6.9M chuds, 320 Tbps slop, 9.8B requests, animate in real time |
| Chad Fight Mode WAF tester | `/products#mog` | Paste any string → fake PSL detection + verdict |
| CNS resolver | `/products#dns` | Type any domain → fake A/TXT/MX records via `dig @6.9.6.9` |
| Verify gate | `/verify` | Real "I am a chud" checkbox CAPTCHA before the auto-verify runs |
| **Gate your own site** | `chud-gate.js` | Drop `<script src="https://chudflare.com/chud-gate.js"></script>` in your `<head>`. Visitors get bounced to `/verify`, prove chud-ness, and return with a 24h pass in `localStorage`. |
| Cookie Slop banner | every page | "Accept all slop" / "Refuse (chud)", persists in localStorage |
| Chud chat | every page (floating, bottom-right) | Keyword-aware mumble engine |
| Site verification | `/chud-check` | The virality flywheel, see below |
| **Chudify** | `/chudify` | Paste any text, get it rewritten in chud-speak. Shareable URL. |
| **PSL Detector** | `/psl-detector` | Paste an image URL or name. Deterministic hash → PSL score |
| **Fake status page** | `/status` | Operational dashboard + 4 historical incidents + subscribe form |

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
`X-Hunch-Angle`, `X-Mewing`, `X-Mog-Status`, etc.). Header configs are provided
for the three major static hosts:

- **`_headers`** for Cloudflare Pages / Netlify (response headers)
- **`_redirects`** for Cloudflare Pages / Netlify (canonicalize `.html` URLs)
- **`vercel.json`** for Vercel (also includes pretty-URL rewrites)
- **`.htaccess`** for Apache

## Tier 1 features at a glance

The whole point of the v2 update was to match every layer of real Cloudflare
corporate apparatus:

| Real Cloudflare | Chudflare |
|---|---|
| `cloudflarestatus.com` | `/status` |
| `cf-ray:` header | `cf-ray: 8c0ffee-CHUD-DEN` |
| `/cdn-cgi/trace` | `/cdn-cgi/trace` (real plaintext endpoint) |
| `robots.txt` / `humans.txt` | same, but chud-flavored |
| `/.well-known/security.txt` | same, with chud-bounty severity scale |
| The Cloudflare Blog | `/blog` with 5 engineering posts |
| Cloudflare Radar / Speed | `/psl-detector` |
| Cloudflare Workers playground | `/chudify` |
| View-source easter eggs | every page has a chud comment block |
| Console branding | every page logs hiring + cf-ray + psl |

## Hosting notes

If your host supports clean paths, map (or use one of `_headers` / `vercel.json` / `.htaccess`):

```
/                  → index.html
/products          → products.html
/pricing           → pricing.html
/chud-check        → chud-check.html
/verify            → verify.html
/chudify           → chudify.html
/psl-detector      → psl-detector.html
/status            → status.html
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
