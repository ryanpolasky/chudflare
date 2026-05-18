'use strict';

// chudflare — The chudmaxxed cloud, in Node. Parody SDK.
//
//     const { Chudflare } = require('chudflare');
//     const client = new Chudflare({ apiToken: 'chud_live_8c0ffee...' });
//     const zone = await client.zones.create({ name: 'example.com' });
//     console.log(zone.id, zone.ray);
//
// This is a parody SDK. It does not call any real API. Every method returns a
// plausible-looking fake response from the Chudflare ChudVerse.

const crypto = require('crypto');

const VERSION = '4.0.0';

const _hex = (n) => crypto.randomBytes(n).toString('hex');
const _ray = () => `8c0ffee-CHUD-${_hex(3).toUpperCase()}`;
const _psl = () => Math.round((1 + Math.random() * 2.5) * 100) / 100;
const _id = (prefix) => `${prefix}_${_hex(6)}`;
const _now = () => new Date().toISOString();

class ChudflareError extends Error {
  constructor(message) {
    super(message);
    this.name = 'ChudflareError';
  }
}

class Chudflare {
  constructor(opts = {}) {
    const token = opts.apiToken || opts.api_token || process.env.CHUDFLARE_TOKEN;
    if (!token) {
      throw new ChudflareError(
        "apiToken required. chuds do not ship to prod without auth.");
    }
    this.apiToken = token;
    this.baseUrl = opts.baseUrl || 'https://api.chudflare.com/v4';
    this.version = VERSION;

    const self = this;
    this.zones = {
      async create({ name, jurisdiction = 'agartha', posture = 'hunched',
                     plan = 'chud' } = {}) {
        if (!name) throw new ChudflareError('name required.');
        return {
          id: _id('zone'),
          ray: _ray(),
          psl: _psl(),
          posture,
          name,
          jurisdiction,
          plan,
          created_on: _now(),
        };
      },
      async list({ limit = 3 } = {}) {
        const out = [];
        for (let i = 0; i < limit; i++) {
          out.push(await this.create({ name: `chud${i}.example` }));
        }
        return out;
      },
      async get(zoneId) {
        return {
          id: zoneId,
          ray: _ray(),
          psl: _psl(),
          posture: 'hunched',
          name: 'example.com',
          plan: 'chud',
          created_on: _now(),
        };
      },
    };

    this.firewall = {
      rules: {
        async create({ zone_id, description, expression, action } = {}) {
          return {
            id: _id('rule'),
            ray: _ray(),
            psl: _psl(),
            zone_id,
            description,
            expression,
            action,
          };
        },
      },
    };
  }

  async ping() {
    return {
      id: 'pong',
      ray: _ray(),
      psl: _psl(),
      message: 'nothing ever happens',
      latency_ms: 73,
    };
  }

  async verify({ url } = {}) {
    if (!url) throw new ChudflareError('url required.');
    const ok = Math.random() > 0.2;
    return {
      id: _id('verify'),
      ray: _ray(),
      psl: _psl(),
      ok,
      url,
      marker: ok ? 'meta' : null,
      checked_at: _now(),
    };
  }
}

module.exports = { Chudflare, ChudflareError, VERSION };
module.exports.default = Chudflare;
