// chudflare — type definitions for the chudmaxxed cloud, in Node.

export declare const VERSION: string;

export declare class ChudflareError extends Error {}

export interface ChudflareOpts {
  apiToken?: string;
  api_token?: string;
  baseUrl?: string;
}

export interface Zone {
  id: string;
  ray: string;
  psl: number;
  posture: string;
  name: string;
  jurisdiction: string;
  plan: string;
  created_on: string;
}

export interface Rule {
  id: string;
  ray: string;
  psl: number;
  zone_id: string;
  description: string;
  expression: string;
  action: string;
}

export interface PingResult {
  id: 'pong';
  ray: string;
  psl: number;
  message: string;
  latency_ms: number;
}

export interface VerifyResult {
  id: string;
  ray: string;
  psl: number;
  ok: boolean;
  url: string;
  marker: 'meta' | null;
  checked_at: string;
}

export declare class Chudflare {
  apiToken: string;
  baseUrl: string;
  version: string;

  zones: {
    create(opts: { name: string; jurisdiction?: string; posture?: string; plan?: string }): Promise<Zone>;
    list(opts?: { limit?: number }): Promise<Zone[]>;
    get(zoneId: string): Promise<Zone>;
  };

  firewall: {
    rules: {
      create(opts: { zone_id: string; description: string; expression: string; action: string }): Promise<Rule>;
    };
  };

  constructor(opts: ChudflareOpts);
  ping(): Promise<PingResult>;
  verify(opts: { url: string }): Promise<VerifyResult>;
}

export default Chudflare;
