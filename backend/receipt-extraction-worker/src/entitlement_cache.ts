/**
 * Cache hasil pengecekan entitlement di KV supaya tidak memanggil RevenueCat
 * di setiap permintaan (dan supaya permintaan sampah dari non-Ultimate tidak
 * menguras batas REST RevenueCat). Hasil `true` disimpan lebih lama daripada
 * `false`, karena pelanggan yang baru membeli harus cepat terbuka. KV
 * mensyaratkan TTL minimal 60 detik.
 */
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
