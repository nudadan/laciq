/**
 * Cache hasil pengecekan entitlement di KV supaya tidak memanggil RevenueCat
 * di setiap permintaan (dan supaya permintaan sampah dari non-Ultimate tidak
 * menguras batas REST RevenueCat). Hasil `true` disimpan lebih lama daripada
 * `false`, karena pelanggan yang baru membeli harus cepat terbuka. KV
 * mensyaratkan TTL minimal 60 detik.
 */
import { NO_ENTITLEMENT, type EntitlementState } from "./revenuecat.ts";

export interface KvLike {
  get(key: string): Promise<string | null>;
  put(key: string, value: string, options: { expirationTtl: number }): Promise<void>;
}

export const POSITIVE_TTL_SECONDS = 300;
export const NEGATIVE_TTL_SECONDS = 60;

export function withEntitlementCache(
  check: (appUserId: string) => Promise<boolean>,
  kv: KvLike,
): (appUserId: string) => Promise<boolean> {
  return async (appUserId) => {
    const key = `ent:${appUserId}`;
    const cached = await kv.get(key);
    if (cached === "1") return true;
    if (cached === "0") return false;
    const result = await check(appUserId); // galat tidak di-cache
    await kv.put(key, result ? "1" : "0", {
      expirationTtl: result ? POSITIVE_TTL_SECONDS : NEGATIVE_TTL_SECONDS,
    });
    return result;
  };
}

/**
 * Cache keadaan entitlement lengkap (aktif + sumber + kedaluwarsa). Nilai:
 * `0` = tidak aktif, `s:<ms|->` = berbayar, `p:<ms|->` = hibah uji coba. Format
 * lama `1` dibaca sebagai berbayar tanpa kedaluwarsa. Hibah uji coba di-cache
 * lebih singkat supaya kuota uji coba tidak "bocor" lama setelah trial habis
 * (docs/RENCANA-IMPLEMENTASI-TRIAL-ULTIMATE.md 5.3).
 */
export const PROMO_TTL_SECONDS = 60;

function encodeState(s: EntitlementState): string {
  if (!s.active) return "0";
  return `${s.source === "promo" ? "p" : "s"}:${s.expiresAtMs ?? "-"}`;
}

function decodeState(raw: string): EntitlementState | null {
  if (raw === "0") return NO_ENTITLEMENT;
  if (raw === "1") return { active: true, source: "store", expiresAtMs: null };
  const m = /^([ps]):(-|\d+)$/.exec(raw);
  if (!m) return null;
  return {
    active: true,
    source: m[1] === "p" ? "promo" : "store",
    expiresAtMs: m[2] === "-" ? null : Number(m[2]),
  };
}

export function withEntitlementStateCache(
  lookup: (appUserId: string) => Promise<EntitlementState>,
  kv: KvLike,
): (appUserId: string) => Promise<EntitlementState> {
  return async (appUserId) => {
    const key = `ent:${appUserId}`;
    const cached = await kv.get(key);
    if (cached !== null) {
      const state = decodeState(cached);
      if (state) return state;
    }
    const state = await lookup(appUserId); // galat tidak di-cache
    await kv.put(key, encodeState(state), {
      expirationTtl: !state.active
        ? NEGATIVE_TTL_SECONDS
        : state.source === "promo"
          ? PROMO_TTL_SECONDS
          : POSITIVE_TTL_SECONDS,
    });
    return state;
  };
}
