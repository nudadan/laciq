import { buildExtractor, type AiEnv } from "./extractor.ts";
import { withEntitlementCache } from "./entitlement_cache.ts";
import { handleExtract } from "./handler.ts";
import { buildNarrator } from "./narrator.ts";
import { handleReportInsight } from "./report_handler.ts";
import { makeEntitlementChecker } from "./revenuecat.ts";

export interface Env extends AiEnv {
  REVENUECAT_SECRET_KEY: string;
  ULTIMATE_ENTITLEMENT: string;
  MONTHLY_LIMIT: string;
  /** Batas per hari per pengguna; kosong/0 = tanpa batas harian. */
  DAILY_LIMIT?: string;
  /** Batas ringkasan laporan AI per bulan / per hari per pengguna (terpisah dari scan). */
  REPORT_MONTHLY_LIMIT?: string;
  REPORT_DAILY_LIMIT?: string;
  /** Penghitung pemakaian + cache entitlement. */
  RATE_LIMIT: KVNamespace;
  /** Cloudflare Rate Limiting per IP (opsional; tanpa binding ini pembatasan IP dilewati). */
  IP_LIMITER?: { limit(options: { key: string }): Promise<{ success: boolean }> };
}

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const ipLimiter = env.IP_LIMITER;
    const common = {
      hasUltimate: withEntitlementCache(
        makeEntitlementChecker(env.REVENUECAT_SECRET_KEY, env.ULTIMATE_ENTITLEMENT),
        env.RATE_LIMIT,
      ),
      getUsage: async (key: string) => Number((await env.RATE_LIMIT.get(key)) ?? 0),
      setUsage: (key: string, count: number, ttlSeconds: number) =>
        env.RATE_LIMIT.put(key, String(count), { expirationTtl: ttlSeconds }),
      now: () => new Date(),
      allowIp: ipLimiter
        ? async (ip: string) => (await ipLimiter.limit({ key: ip })).success
        : undefined,
    };

    if (new URL(req.url).pathname === "/report-insight") {
      return handleReportInsight(req, {
        ...common,
        narrate: buildNarrator(env),
        monthlyLimit: Number(env.REPORT_MONTHLY_LIMIT) || 30,
        dailyLimit: Number(env.REPORT_DAILY_LIMIT) || 0,
      });
    }
    return handleExtract(req, {
      ...common,
      extract: buildExtractor(env),
      monthlyLimit: Number(env.MONTHLY_LIMIT) || 300,
      dailyLimit: Number(env.DAILY_LIMIT) || 0,
    });
  },
};
