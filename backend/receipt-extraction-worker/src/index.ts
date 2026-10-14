import { buildExtractor, type AiEnv } from "./extractor.ts";
import { withEntitlementStateCache } from "./entitlement_cache.ts";
import { handleExtract } from "./handler.ts";
import { parseIntegrityMode } from "./integrity.ts";
import { buildNarrator } from "./narrator.ts";
import { makePromoBudget, REPORT_COST_RP, SCAN_COST_RP } from "./promo_budget.ts";
import { handleReportInsight } from "./report_handler.ts";
import { makeEntitlementLookup, makeTrialGranter } from "./revenuecat.ts";
import { handleTrialClaim, handleTrialStatus, hmacHex } from "./trial_handler.ts";

export interface Env extends AiEnv {
  REVENUECAT_SECRET_KEY: string;
  ULTIMATE_ENTITLEMENT: string;
  MONTHLY_LIMIT: string;
  /** Batas per hari per pengguna; kosong/0 = tanpa batas harian. */
  DAILY_LIMIT?: string;
  /** Batas ringkasan laporan AI per bulan / per hari per pengguna (terpisah dari scan). */
  REPORT_MONTHLY_LIMIT?: string;
  REPORT_DAILY_LIMIT?: string;

  // --- Uji coba Ultimate tanpa kartu (docs/RENCANA-IMPLEMENTASI-TRIAL-ULTIMATE.md) ---
  /** "1" menyalakan POST /trial/claim. Bawaan mati. */
  TRIAL_ENABLED?: string;
  /** Rahasia HMAC pengenal perangkat (`wrangler secret put TRIAL_HASH_SECRET`). Tanpa ini trial mati. */
  TRIAL_HASH_SECRET?: string;
  /** Entitlement Premium yang ikut dihibahkan (Ultimate memegang `premium` dan `ultimate`). */
  PREMIUM_ENTITLEMENT?: string;
  TRIAL_DAYS?: string;
  /** Kuota AI pengguna uji coba (lebih kecil daripada pelanggan berbayar). */
  TRIAL_MONTHLY_LIMIT?: string;
  TRIAL_DAILY_LIMIT?: string;
  TRIAL_REPORT_MONTHLY_LIMIT?: string;
  TRIAL_REPORT_DAILY_LIMIT?: string;
  /** Maksimal klaim baru per hari (UTC). */
  TRIAL_DAILY_CLAIM_CAP?: string;
  /** Hari catatan perangkat disimpan SETELAH uji coba berakhir, lalu terhapus otomatis (bawaan 365). */
  TRIAL_RECORD_RETENTION_DAYS?: string;
  /** Batas penegakan anggaran AI promo (Rupiah/bulan). 0/kosong = habis. */
  PROMO_AI_MONTHLY_BUDGET_RP?: string;
  /** off | shadow | lenient | strict (Play Integrity). */
  INTEGRITY_MODE?: string;

  /** Penghitung pemakaian + cache entitlement + catatan trial. */
  RATE_LIMIT: KVNamespace;
  /** Cloudflare Rate Limiting per IP (opsional; tanpa binding ini pembatasan IP dilewati). */
  IP_LIMITER?: { limit(options: { key: string }): Promise<{ success: boolean }> };
}

const num = (v: string | undefined, fallback: number): number => {
  const n = Number(v);
  return v !== undefined && v !== "" && Number.isFinite(n) ? n : fallback;
};

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const ipLimiter = env.IP_LIMITER;
    const getEntitlement = withEntitlementStateCache(
      makeEntitlementLookup(env.REVENUECAT_SECRET_KEY, env.ULTIMATE_ENTITLEMENT),
      env.RATE_LIMIT,
    );
    const getUsage = async (key: string) => Number((await env.RATE_LIMIT.get(key)) ?? 0);
    const setUsage = (key: string, count: number, ttlSeconds: number) =>
      env.RATE_LIMIT.put(key, String(count), { expirationTtl: ttlSeconds });
    const allowIp = ipLimiter
      ? async (ip: string) => (await ipLimiter.limit({ key: ip })).success
      : undefined;
    const budget = makePromoBudget(num(env.PROMO_AI_MONTHLY_BUDGET_RP, 0), getUsage, setUsage);

    const common = {
      hasUltimate: async (id: string) => (await getEntitlement(id)).active,
      getEntitlement,
      getUsage,
      setUsage,
      now: () => new Date(),
      allowIp,
    };

    const path = new URL(req.url).pathname;

    if (path === "/trial/claim" || path === "/trial/status") {
      const secret = env.TRIAL_HASH_SECRET ?? "";
      const handle = path === "/trial/claim" ? handleTrialClaim : handleTrialStatus;
      return handle(req, {
        enabled: env.TRIAL_ENABLED === "1" && secret !== "",
        days: num(env.TRIAL_DAYS, 30),
        dailyClaimCap: num(env.TRIAL_DAILY_CLAIM_CAP, 300),
        recordRetentionDays: num(env.TRIAL_RECORD_RETENTION_DAYS, 365),
        store: {
          get: (key) => env.RATE_LIMIT.get(key),
          put: (key, value, ttlSeconds) =>
            env.RATE_LIMIT.put(key, value, ttlSeconds ? { expirationTtl: ttlSeconds } : undefined),
        },
        hashDevice: (deviceId) => hmacHex(secret, deviceId),
        getEntitlement,
        grant: makeTrialGranter(env.REVENUECAT_SECRET_KEY, [
          env.ULTIMATE_ENTITLEMENT,
          env.PREMIUM_ENTITLEMENT || "premium",
        ]),
        invalidateEntitlement: (id) => env.RATE_LIMIT.delete(`ent:${id}`),
        budget,
        integrityMode: parseIntegrityMode(env.INTEGRITY_MODE),
        // Pendekode Play Integrity belum dipasang (butuh kredensial akun layanan Google);
        // mode `shadow` hanya mencatat bahwa vonis tidak tersedia.
        now: common.now,
        allowIp,
      });
    }

    if (path === "/report-insight") {
      return handleReportInsight(req, {
        ...common,
        narrate: buildNarrator(env),
        monthlyLimit: Number(env.REPORT_MONTHLY_LIMIT) || 30,
        dailyLimit: Number(env.REPORT_DAILY_LIMIT) || 0,
        trial: {
          monthlyLimit: num(env.TRIAL_REPORT_MONTHLY_LIMIT, 6),
          dailyLimit: num(env.TRIAL_REPORT_DAILY_LIMIT, 2),
          costRp: REPORT_COST_RP,
          budget,
        },
      });
    }
    return handleExtract(req, {
      ...common,
      extract: buildExtractor(env),
      monthlyLimit: Number(env.MONTHLY_LIMIT) || 300,
      dailyLimit: Number(env.DAILY_LIMIT) || 0,
      trial: {
        monthlyLimit: num(env.TRIAL_MONTHLY_LIMIT, 60),
        dailyLimit: num(env.TRIAL_DAILY_LIMIT, 10),
        costRp: SCAN_COST_RP,
        budget,
      },
    });
  },
};
