import { buildExtractor, type AiEnv } from "./extractor.ts";
import { withEntitlementCache } from "./entitlement_cache.ts";
import { handleExtract } from "./handler.ts";
import { makeEntitlementChecker } from "./revenuecat.ts";

export interface Env extends AiEnv {
  REVENUECAT_SECRET_KEY: string;
  ULTIMATE_ENTITLEMENT: string;
  MONTHLY_LIMIT: string;
  /** Batas per hari per pengguna; kosong/0 = tanpa batas harian. */
  DAILY_LIMIT?: string;
  /** Penghitung pemakaian + cache entitlement. */
  RATE_LIMIT: KVNamespace;
  /** Cloudflare Rate Limiting per IP (opsional; tanpa binding ini pembatasan IP dilewati). */
  IP_LIMITER?: { limit(options: { key: string }): Promise<{ success: boolean }> };
}

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const ipLimiter = env.IP_LIMITER;
    return handleExtract(req, {
      hasUltimate: withEntitlementCache(
        makeEntitlementChecker(env.REVENUECAT_SECRET_KEY, env.ULTIMATE_ENTITLEMENT),
        env.RATE_LIMIT,
      ),
      getUsage: async (key) => Number((await env.RATE_LIMIT.get(key)) ?? 0),
      setUsage: (key, count, ttlSeconds) =>
        env.RATE_LIMIT.put(key, String(count), { expirationTtl: ttlSeconds }),
      extract: buildExtractor(env),
      now: () => new Date(),
      monthlyLimit: Number(env.MONTHLY_LIMIT) || 60,
      dailyLimit: Number(env.DAILY_LIMIT) || 0,
      allowIp: ipLimiter ? async (ip) => (await ipLimiter.limit({ key: ip })).success : undefined,
    });
  },
};
