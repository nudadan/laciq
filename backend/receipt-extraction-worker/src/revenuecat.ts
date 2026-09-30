/**
 * Verifikasi server-ke-server: tanya RevenueCat langsung memakai secret key
 * (bukan percaya klaim dari app). Catatan: endpoint v1 membuat record
 * pelanggan kosong untuk ID yang belum dikenal — ID anonim RevenueCat sulit
 * ditebak, dan format ID divalidasi ketat di handler.
 */
export function makeEntitlementChecker(secretKey: string, entitlement: string) {
  return async function hasUltimate(appUserId: string): Promise<boolean> {
    const res = await fetch(
      `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(appUserId)}`,
      { headers: { Authorization: `Bearer ${secretKey}` } },
    );
    if (!res.ok) throw new Error(`RevenueCat ${res.status}`);
    const data = (await res.json()) as {
      subscriber?: { entitlements?: Record<string, { expires_date: string | null }> };
    };
    const ent = data.subscriber?.entitlements?.[entitlement];
    if (!ent) return false;
    return ent.expires_date === null || new Date(ent.expires_date).getTime() > Date.now();
  };
}
