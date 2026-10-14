import {
  evaluateVerdict,
  isEnforcing,
  type IntegrityMode,
  type IntegrityVerifier,
} from "./integrity.ts";
import type { PromoBudget } from "./promo_budget.ts";
import { GrantIgnoredError, type EntitlementState } from "./revenuecat.ts";

/**
 * POST /trial/claim — memberi uji coba Ultimate tanpa kartu
 * (docs/RENCANA-IMPLEMENTASI-TRIAL-ULTIMATE.md, bagian 3 dan 4).
 *
 * Kunci kelayakan adalah pengenal PERANGKAT yang di-hash (HMAC) di server dan
 * disimpan tanpa kedaluwarsa, BUKAN ID RevenueCat (ID itu baru setiap pasang
 * ulang; terbukti di Fase 0). Pasang ulang di masa trial mendapat SISA hari.
 */

export interface TrialStore {
  get(key: string): Promise<string | null>;
  /** Tanpa [ttlSeconds] = disimpan tanpa kedaluwarsa. */
  put(key: string, value: string, ttlSeconds?: number): Promise<void>;
}

export interface TrialDeps {
  /** Trial dinyalakan? (saklar mati: TRIAL_ENABLED). */
  enabled: boolean;
  /** Lama trial (hari). */
  days: number;
  /** Maksimal klaim BARU per hari (UTC). */
  dailyClaimCap: number;
  store: TrialStore;
  /** HMAC pengenal perangkat dengan rahasia server. */
  hashDevice(deviceId: string): Promise<string>;
  /** Keadaan entitlement `ultimate` saat ini untuk ID RevenueCat. */
  getEntitlement(appUserId: string): Promise<EntitlementState>;
  /** Menghibahkan entitlement sampai [endMs] dan membaca ulang hasilnya. */
  grant(appUserId: string, endMs: number): Promise<void>;
  /** Membuang cache entitlement agar hibah baru langsung terlihat. */
  invalidateEntitlement(appUserId: string): Promise<void>;
  budget: PromoBudget;
  integrityMode: IntegrityMode;
  integrity?: IntegrityVerifier;
  now(): Date;
  allowIp?(ip: string): Promise<boolean>;
}

const MAX_BODY_BYTES = 2_000;
const USER_ID_PATTERN = /^[\w$:.\-]{8,128}$/;
const DEVICE_ID_PATTERN = /^[\w.\-]{8,64}$/;
const MAX_TOKEN_CHARS = 8_000;
const DAY_TTL_SECONDS = 2 * 24 * 3600;
const DAY_MS = 24 * 3600 * 1000;

interface TrialRecord {
  grantedAt: string;
  endsAt: number;
  appUserId: string;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" },
  });
}

export const trialKey = (deviceHash: string) => `trial:${deviceHash}`;
export const trialDayKey = (now: Date) => `trial-day:${now.toISOString().slice(0, 10)}`;

function parseRecord(raw: string | null): TrialRecord | null {
  if (raw === null) return null;
  try {
    const r = JSON.parse(raw) as Partial<TrialRecord>;
    if (typeof r.endsAt === "number" && typeof r.appUserId === "string") {
      return { grantedAt: String(r.grantedAt ?? ""), endsAt: r.endsAt, appUserId: r.appUserId };
    }
  } catch {
    // rusak: perlakukan seolah tidak ada
  }
  return null;
}

interface ParsedClaim {
  appUserId: string;
  deviceId: string;
  integrityToken: string | null;
}

function parseClaim(body: unknown): ParsedClaim | null {
  if (typeof body !== "object" || body === null) return null;
  const { appUserId, deviceId, integrityToken } = body as Record<string, unknown>;
  if (typeof appUserId !== "string" || !USER_ID_PATTERN.test(appUserId)) return null;
  if (typeof deviceId !== "string" || !DEVICE_ID_PATTERN.test(deviceId)) return null;
  let token: string | null = null;
  if (integrityToken !== undefined && integrityToken !== null) {
    if (typeof integrityToken !== "string" || integrityToken.length > MAX_TOKEN_CHARS) return null;
    token = integrityToken === "" ? null : integrityToken;
  }
  return { appUserId, deviceId, integrityToken: token };
}

export async function handleTrialClaim(req: Request, deps: TrialDeps): Promise<Response> {
  const url = new URL(req.url);
  if (url.pathname !== "/trial/claim") return json({ error: "not_found" }, 404);
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const ip = req.headers.get("cf-connecting-ip");
  if (deps.allowIp && ip && !(await deps.allowIp(ip))) {
    return json({ error: "rate_limited" }, 429);
  }

  const text = await req.text();
  if (text.length > MAX_BODY_BYTES + MAX_TOKEN_CHARS) {
    return json({ error: "payload_too_large" }, 413);
  }
  let raw: unknown;
  try {
    raw = JSON.parse(text);
  } catch {
    return json({ error: "invalid_json" }, 400);
  }
  const claim = parseClaim(raw);
  if (!claim) return json({ error: "invalid_request" }, 400);

  // Saklar mati: jawaban jelas, tanpa menyentuh layanan luar.
  if (!deps.enabled) return json({ error: "trial_disabled" }, 503);

  const now = deps.now();
  const nowMs = now.getTime();

  let state: EntitlementState;
  try {
    state = await deps.getEntitlement(claim.appUserId);
  } catch {
    return json({ error: "entitlement_check_failed" }, 502);
  }
  // Pelanggan Ultimate berbayar tidak perlu trial. (Pelanggan Premium boleh: entitlement
  // `ultimate` mereka belum aktif.)
  if (state.active && state.source === "store") {
    console.log("trial_claim result=already_ultimate");
    return json({ error: "already_ultimate" }, 409);
  }

  const deviceHash = await deps.hashDevice(claim.deviceId);
  const record = parseRecord(await deps.store.get(trialKey(deviceHash)));

  // Hibah sudah aktif pada ID ini: idempoten. Bila catatan perangkat hilang
  // (gagal tulis setelah hibah), pulihkan dari kedaluwarsa hibah.
  if (state.active && state.source === "promo") {
    const endsAt = state.expiresAtMs ?? record?.endsAt ?? nowMs;
    if (!record) {
      await deps.store.put(
        trialKey(deviceHash),
        JSON.stringify({ grantedAt: now.toISOString(), endsAt, appUserId: claim.appUserId }),
      );
    }
    console.log("trial_claim result=active");
    return json({ status: "active", endsAt: new Date(endsAt).toISOString() });
  }

  // Perangkat sudah pernah memakai trial.
  if (record) {
    if (record.endsAt <= nowMs) {
      console.log("trial_claim result=already_used");
      return json({ error: "already_used", endsAt: new Date(record.endsAt).toISOString() }, 409);
    }
    // Pasang ulang di masa trial: ID RevenueCat baru mendapat SISA hari.
    try {
      await deps.grant(claim.appUserId, record.endsAt);
    } catch (e) {
      return grantFailure(e);
    }
    await deps.store.put(
      trialKey(deviceHash),
      JSON.stringify({ ...record, appUserId: claim.appUserId }),
    );
    await deps.invalidateEntitlement(claim.appUserId);
    console.log("trial_claim result=resumed");
    return json({ status: "resumed", endsAt: new Date(record.endsAt).toISOString() });
  }

  // Klaim BARU. Pagar global dulu; menolak di sini TIDAK menghabiskan hak trial perangkat.
  const dayKey = trialDayKey(now);
  const claimedToday = Number((await deps.store.get(dayKey)) ?? 0);
  if (claimedToday >= deps.dailyClaimCap) {
    console.log("trial_claim result=paused_daily_cap");
    return json({ error: "trial_paused" }, 429);
  }
  if (await deps.budget.exhausted(now)) {
    console.log("trial_claim result=paused_budget");
    return json({ error: "promo_budget_exhausted" }, 429);
  }

  const integrityFailure = await checkIntegrity(claim, deps);
  if (integrityFailure) return integrityFailure;

  const endMs = nowMs + deps.days * DAY_MS;
  try {
    await deps.grant(claim.appUserId, endMs);
  } catch (e) {
    return grantFailure(e);
  }
  // Catatan perangkat ditulis SETELAH hibah berhasil; bila penulisan gagal, klaim
  // berikutnya memulihkannya lewat cabang "hibah sudah aktif" di atas.
  await deps.store.put(
    trialKey(deviceHash),
    JSON.stringify({
      grantedAt: now.toISOString(),
      endsAt: endMs,
      appUserId: claim.appUserId,
    } satisfies TrialRecord),
  );
  await deps.store.put(dayKey, String(claimedToday + 1), DAY_TTL_SECONDS);
  await deps.invalidateEntitlement(claim.appUserId);
  console.log("trial_claim result=granted");
  return json({ status: "granted", endsAt: new Date(endMs).toISOString() }, 201);
}

function grantFailure(e: unknown): Response {
  if (e instanceof GrantIgnoredError) {
    console.log("trial_claim result=grant_ignored");
    return json({ error: "grant_ignored" }, 502);
  }
  console.log("trial_claim result=grant_failed");
  return json({ error: "grant_failed" }, 502);
}

/**
 * Mode bayangan: hanya mencatat vonis. Mode penegakan: menolak vonis buruk,
 * token yang tidak ada/tidak bisa diverifikasi, dan konfigurasi tanpa verifier.
 */
async function checkIntegrity(claim: ParsedClaim, deps: TrialDeps): Promise<Response | null> {
  const mode = deps.integrityMode;
  if (mode === "off") return null;
  const enforcing = isEnforcing(mode);

  if (!deps.integrity) {
    console.log(`integrity mode=${mode} verdict=unavailable`);
    return enforcing ? json({ error: "integrity_unavailable" }, 503) : null;
  }
  if (!claim.integrityToken) {
    console.log(`integrity mode=${mode} verdict=missing_token`);
    return enforcing ? json({ error: "integrity_required" }, 403) : null;
  }
  try {
    const verdict = await deps.integrity.verify(claim.integrityToken, { appUserId: claim.appUserId });
    const r = evaluateVerdict(verdict, mode);
    console.log(`integrity mode=${mode} ok=${r.ok}${r.reason ? ` reason=${r.reason}` : ""}`);
    return enforcing && !r.ok ? json({ error: "integrity_failed" }, 403) : null;
  } catch {
    console.log(`integrity mode=${mode} verdict=verify_error`);
    return enforcing ? json({ error: "integrity_failed" }, 403) : null;
  }
}

/** HMAC-SHA256 heksadesimal dengan pemisah domain; rahasia tidak pernah dikirim ke klien. */
export async function hmacHex(secret: string, message: string): Promise<string> {
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    enc.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("HMAC", key, enc.encode(`trial-device:${message}`));
  return [...new Uint8Array(sig)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

export type TrialStatusState =
  | "disabled" // saklar mati
  | "ultimate" // pelanggan Ultimate berbayar
  | "active" // hibah uji coba sedang berjalan pada ID ini
  | "resumable" // perangkat punya trial berjalan; ID baru bisa melanjutkan sisa hari
  | "used" // perangkat sudah memakai trial dan sudah habis
  | "paused" // pagar global (klaim harian / anggaran AI promo) sedang penuh
  | "available";

/**
 * POST /trial/status — BACA SAJA (tanpa efek samping): apakah penawaran trial
 * pantas ditampilkan untuk perangkat dan ID ini. Dipakai aplikasi agar tidak
 * menjanjikan "coba gratis" kepada pengguna yang akan ditolak setelah menekan
 * tombol (mis. memasang ulang setelah trial habis).
 */
export async function handleTrialStatus(req: Request, deps: TrialDeps): Promise<Response> {
  const url = new URL(req.url);
  if (url.pathname !== "/trial/status") return json({ error: "not_found" }, 404);
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const ip = req.headers.get("cf-connecting-ip");
  if (deps.allowIp && ip && !(await deps.allowIp(ip))) {
    return json({ error: "rate_limited" }, 429);
  }
  const text = await req.text();
  if (text.length > MAX_BODY_BYTES + MAX_TOKEN_CHARS) {
    return json({ error: "payload_too_large" }, 413);
  }
  let raw: unknown;
  try {
    raw = JSON.parse(text);
  } catch {
    return json({ error: "invalid_json" }, 400);
  }
  const claim = parseClaim(raw);
  if (!claim) return json({ error: "invalid_request" }, 400);

  const reply = (state: TrialStatusState, endsAtMs?: number | null) =>
    json({
      state,
      ...(endsAtMs ? { endsAt: new Date(endsAtMs).toISOString() } : {}),
    });

  if (!deps.enabled) return reply("disabled");

  const now = deps.now();
  const nowMs = now.getTime();
  let state: EntitlementState;
  try {
    state = await deps.getEntitlement(claim.appUserId);
  } catch {
    return json({ error: "entitlement_check_failed" }, 502);
  }
  if (state.active && state.source === "store") return reply("ultimate");
  if (state.active && state.source === "promo") return reply("active", state.expiresAtMs);

  const record = parseRecord(await deps.store.get(trialKey(await deps.hashDevice(claim.deviceId))));
  if (record) {
    return record.endsAt > nowMs ? reply("resumable", record.endsAt) : reply("used", record.endsAt);
  }

  const claimedToday = Number((await deps.store.get(trialDayKey(now))) ?? 0);
  if (claimedToday >= deps.dailyClaimCap || (await deps.budget.exhausted(now))) {
    return reply("paused");
  }
  return reply("available");
}
