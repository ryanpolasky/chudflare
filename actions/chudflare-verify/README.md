# chudflare/verify-action

A GitHub Action that checks whether a site is **chud-verified** per the rules
at <https://chudflare.com/chud-check>, and posts a chud-badge comment back on
the pull request.

Chudflare is a parody of Cloudflare. It is not affiliated with, endorsed by,
sponsored by, or in any way related to Cloudflare, Inc. Cloudflare ships
excellent infrastructure that this action has nothing to do with. For real
infrastructure, visit [cloudflare.com](https://cloudflare.com).

## Usage

```yaml
# .github/workflows/chud-check.yml
name: Chud Check
on: [pull_request]

jobs:
  verify:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
    steps:
      - uses: chudflare/verify-action@v1
        with:
          url: https://your-site.com
```

That's it. The action will fetch your site, look for one of the three chud
markers, and post a comment back on the PR with the result.

## Inputs

| name | required | default | description |
|------|----------|---------|-------------|
| `url` | yes | — | URL of the site to verify. |
| `marker` | no | `any` | Which marker to accept: `any`, `meta`, `comment`, or `well-known`. |
| `comment` | no | `true` | Post a chud-badge comment on the PR. |
| `fail-on-unverified` | no | `false` | Exit non-zero if the site is not verified. Default is informational. |
| `github-token` | no | `${{ github.token }}` | Token with `pull-requests: write`. |

## Outputs

| name | description |
|------|-------------|
| `verified` | `"true"` or `"false"`. |
| `marker-type` | `meta`, `comment`, `well-known`, or `none`. |
| `psl` | PSL score (1.00–3.49). Empty when unverified. |
| `ray` | Fake `cf-ray` id assigned to this run. |

## How to make your site verifiable

Add **any one** of the following to the site you're verifying:

**1. Meta tag** in your `<head>`:

```html
<meta name="chudflare-verified" content="chud">
```

**2. Magic comment** anywhere in the page:

```html
<!-- chudflare:verified -->
```

**3. Well-known JSON file** at `/.well-known/chud-verified.json`:

```json
{ "chud": true }
```

## Example: gate deploys on verification

```yaml
- uses: chudflare/verify-action@v1
  id: chud
  with:
    url: https://staging.example.com
    fail-on-unverified: true
- name: Deploy to prod
  if: steps.chud.outputs.verified == 'true'
  run: ./deploy-to-prod.sh
```

## Local testing

The action is a zero-dependency Node.js script. You can run it locally:

```bash
INPUT_URL="https://chudflare.com" \
INPUT_COMMENT="false" \
GITHUB_OUTPUT=/tmp/out.txt \
node index.js
cat /tmp/out.txt
```

## Development

Source lives in `index.js`. There is no build step. No webpack, no esbuild, no
tsc, no postinstall. The action runs with `runs.using: node20` and uses only
Node 20 standard library globals (`fetch`, `URL`, `fs`, `Buffer`).

## License

MIT. See `LICENSE`.
