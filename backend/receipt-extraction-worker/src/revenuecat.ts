/**
 * Verifikasi server-ke-server: tanya RevenueCat langsung memakai secret key
 * (bukan percaya klaim dari app). Catatan: endpoint v1 membuat record
 * pelanggan kosong untuk ID yang belum dikenal — ID anonim RevenueCat sulit
 * ditebak, dan format ID divalidasi ketat di handler.
 *
 * Selain memeriksa entitlement, modul ini mengenali SUMBERNYA (hibah promosional
 * untuk uji coba atau langganan berbayar) dan menghibahkan entitlement uji
 * coba dengan pembacaan ulang (lihat docs/RENCANA-IMPLEMENTASI-TRIAL-ULTIMATE.md,
 * hasil Fase 0).
 */

const API = "https://api.revenuecat.com/v1";

/** Awalan `product_identifier` entitlement promosional (terbukti di Fase 0). */
export const PROMO_PRODUCT_PREFIX = "rc_promo_";

/** Toleransi selisih `expires_date` terhadap `end_time_ms` yang diminta (Fase 0: 0-659 ms). */
export const GRANT_TOLERANCE_MS = 60_000;

export type EntitlementSource = "promo" | "store";

export interface EntitlementState {
  active: boolean;
  /** Null bila tidak aktif. `store` = berbayar (Play); `promo` = hibah uji coba. */
  source: EntitlementSource | null;
  /** Kedaluwarsa dalam ms epoch; null bila tanpa batas atau entitlement tidak ada. */
  expiresAtMs: number | null;
}

export const NO_ENTITLEMENT: EntitlementState = { active: false, source: null, expiresAtMs: null };

interface RcEntitlement {
  expires_date: string | null;
  product_identifier?: string;
}

interface RcSubscription {
  store?: string;
  expires_date: string | null;
}

export interface RcSubscriber {
  entitlements?: Record<string, RcEntitlement>;
  subscriptions?: Record<string, RcSubscription>;
}

type FetchLike = (input: string, init?: RequestInit) => Promise<Response>;

const isFuture = (date: string | null, nowMs: number): boolean =>
  date === null || Date.parse(date) > nowMs;

async function fetchSubscriber(
  secretKey: string,
  appUserId: string,
  doFetch: FetchLike,
): Promise<RcSubscriber> {
  const res = await doFetch(`${API}/subscribers/${encodeURIComponent(appUserId)}`, {
    headers: { Authorization: `Bearer ${secretKey}` },
  });
  if (!res.ok) throw new Error(`RevenueCat ${res.status}`);
  const data = (await res.json()) as {
    subscriber?: RcSubscriber;
    value?: { subscriber?: RcSubscriber };
  };
  return data.subscriber ?? data.value?.subscriber ?? {};
}

/**
 * Keadaan entitlement [entitlement] dari data pelanggan RevenueCat.
 *
 * Sumber: bila ada langganan berbayar (toko selain `promotional`) yang masih
 * berlaku, entitlement dianggap `store` walau hibah uji coba berjalan bersamaan
 * (pelanggan berbayar tidak boleh dibatasi kuota uji coba). Selain itu,
 * `product_identifier` berawalan `rc_promo_` = `promo`.
 */
export function entitlementStateOf(
  sub: RcSubscriber,
  entitlement: string,
  nowMs: number,
): EntitlementState {
  const ent = sub.entitlements?.[entitlement];
  if (!ent) return NO_ENTITLEMENT;
  const expiresAtMs = ent.expires_date === null ? null : Date.parse(ent.expires_date);
  if (!isFuture(ent.expires_date, nowMs)) {
    return { active: false, source: null, expiresAtMs };
  }
  const hasPaid = Object.values(sub.subscriptions ?? {}).some(
    (s) => s.store !== "promotional" && isFuture(s.expires_date, nowMs),
  );
  const promo = ent.product_identifier?.startsWith(PROMO_PRODUCT_PREFIX) ?? false;
  return { active: true, source: hasPaid || !promo ? "store" : "promo", expiresAtMs };
}

/** Pencari keadaan entitlement (aktif/tidak, sumber, kedaluwarsa). */
export function makeEntitlementLookup(
  secretKey: string,
  entitlement: string,
  doFetch: FetchLike = fetch,
  now: () => number = Date.now,
) {
  return async function lookup(appUserId: string): Promise<EntitlementState> {
    return entitlementStateOf(await fetchSubscriber(secretKey, appUserId, doFetch), entitlement, now());
  };
}

/** Versi boolean (kompatibel dengan kode lama): apakah entitlement aktif. */
export function makeEntitlementChecker(secretKey: string, entitlement: string) {
  const lookup = makeEntitlementLookup(secretKey, entitlement);
  return async function hasUltimate(appUserId: string): Promise<boolean> {
    return (await lookup(appUserId)).active;
  };
}

/** HTTP 201 tetapi hibah tidak berlaku (mis. dianggap duplikat oleh RevenueCat). */
export class GrantIgnoredError extends Error {
  constructor(entitlement: string) {
    super(`hibah ${entitlement} diabaikan`);
    this.name = "GrantIgnoredError";
  }
}

/**
 * Menghibahkan [entitlements] sampai [endMs] lalu MEMBACA ULANG hasilnya.
 * Pelajaran Fase 0: RevenueCat menjawab 201 walau hibah diabaikan (hibah dalam
 * 2 jam dari hibah promosional sebelumnya pada ID yang sama dianggap duplikat),
 * jadi 201 saja tidak cukup.
 */
export function makeTrialGranter(
  secretKey: string,
  entitlements: string[],
  doFetch: FetchLike = fetch,
) {
  return async function grant(appUserId: string, endMs: number): Promise<void> {
    const id = encodeURIComponent(appUserId);
    for (const e of entitlements) {
      const res = await doFetch(`${API}/subscribers/${id}/entitlements/${encodeURIComponent(e)}/promotional`, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${secretKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ end_time_ms: endMs }),
      });
      if (res.status !== 200 && res.status !== 201) {
        throw new Error(`RevenueCat grant ${e} ${res.status}`);
      }
    }
    const sub = await fetchSubscriber(secretKey, appUserId, doFetch);
    for (const e of entitlements) {
      const expires = sub.entitlements?.[e]?.expires_date;
      if (!expires || Math.abs(Date.parse(expires) - endMs) > GRANT_TOLERANCE_MS) {
        throw new GrantIgnoredError(e);
      }
    }
  };
}
