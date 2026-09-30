import { makeExtractor } from "./anthropic.ts";
import { handleExtract } from "./handler.ts";
import { makeEntitlementChecker } from "./revenuecat.ts";

export interface Env {
  ANTHROPIC_API_KEY: string;
  REVENUECAT_SECRET_KEY: string;
  ULTIMATE_ENTITLEMENT: string;
  MONTHLY_LIMIT: string;
  RATE_LIMIT: KVNamespace;
}

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    return handleExtract(req, {
      hasUltimate: makeEntitlementChecker(env.REVENUECAT_SECRET_KEY, env.ULTIMATE_ENTITLEMENT),
      getUsage: async (key) => Number((await env.RATE_LIMIT.get(key)) ?? 0),
      // Kunci kedaluwarsa sendiri setelah ~35 hari (bulan berikutnya pakai kunci baru).
      setUsage: (key, count) =>
        env.RATE_LIMIT.put(key, String(count), { expirationTtl: 35 * 24 * 3600 }),
      extract: makeExtractor(env.ANTHROPIC_API_KEY),
      now: () => new Date(),
      monthlyLimit: Number(env.MONTHLY_LIMIT) || 60,
    });
  },
};
