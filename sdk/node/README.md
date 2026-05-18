# chudflare

The chudmaxxed cloud, in Node. Parody SDK for the Chudflare ChudVerse.

```bash
npm install https://chudflare.com/sdk/chudflare-4.0.0.tgz
```

```javascript
const { Chudflare } = require('chudflare');
// or:  import { Chudflare } from 'chudflare';

const client = new Chudflare({ apiToken: 'chud_live_8c0ffee...' });

const zone = await client.zones.create({
  name: 'example.com',
  jurisdiction: 'agartha',
  posture: 'hunched',
  plan: 'chud',
});
console.log(`created zone ${zone.id} (ray: ${zone.ray})`);

await client.firewall.rules.create({
  zone_id: zone.id,
  description: 'block visible cheekbones',
  expression: '(http.req.psl gt 5.5)',
  action: 'mog_back',
});
```

## What this is

This is a parody SDK. It does not call any real API — there is no Chudflare
ChudVerse to call. Every method returns a plausible-looking fake response so
your demo / talk / tweet / dashboard works without a backend.

For real infrastructure, see [cloudflare.com](https://cloudflare.com).

## License

MIT. Forged with love by an actual chud.
