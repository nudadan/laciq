import { resolveAccess } from "./access.ts";
import type { TrialQuota } from "./promo_budget.ts";
import type { EntitlementState } from "./revenuecat.ts";

export interface CategoryOption {
  id: string;
  name: string;
}

export interface Extraction {
  merchant: string | null;
  categoryId: string | null;
  /** Total yang benar-benar dibayar, Rupiah bulat. */
  total: number | null;
  /** Tanggal transaksi, `YYYY-MM-DD`. */
  date: string | null;
}

export interface Deps {
  /** Apakah pengguna ini punya entitlement Ultimate aktif (dicek ke RevenueCat). */
  hasUltimate(appUserId: string): Promise<boolean>;
  /** Keadaan entitlement lengkap (sumber); bila ada, menggantikan [hasUltimate]. */
  getEntitlement?(appUserId: string): Promise<EntitlementState>;
  /** Kuota + anggaran khusus pengguna uji coba (hibah promosional). */
  trial?: TrialQuota;
  /** Jumlah pemakaian untuk kunci tertentu. */
  getUsage(key: string): Promise<number>;
  /** Menyimpan jumlah pemakaian; kunci kedaluwarsa sendiri setelah [ttlSeconds]. */
  setUsage(key: string, count: number, ttlSeconds: number): Promise<void>;
  extract(rawText: string, categories: CategoryOption[]): Promise<Extraction>;
  now(): Date;
  monthlyLimit: number;
  /** Batas per hari (UTC) per pengguna; 0/kosong = tanpa batas harian. */
  dailyLimit?: number;
  /** Pembatas laju per IP (opsional, mis. Cloudflare Rate Limiting). true = boleh. */
  allowIp?(ip: string): Promise<boolean>;
}

const MAX_BODY_BYTES = 20_000;
const MAX_TEXT_CHARS = 4000;
const MAX_CATEGORIES = 80;
// ID kategori buku non-utama berbentuk `ledger-<uuid>:cat-exp-<slug>` (bisa 67 karakter);
// batas 64 dulu menolak SELURUH permintaan sehingga scan AI diam-diam gagal di buku bisnis.
const MAX_ID_CHARS = 128;
const MAX_NAME_CHARS = 80;
const USER_ID_PATTERN = /^[\w$:.\-]{8,128}$/;

/** Batas wajar satu struk (Rupiah). Di atas ini hampir pasti salah baca. */
export const MAX_TOTAL = 1_000_000_000;
const MONTH_TTL_SECONDS = 35 * 24 * 3600;
const DAY_TTL_SECONDS = 2 * 24 * 3600;
const DATE_PATTERN = /^(\d{4})-(\d{2})-(\d{2})$/;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" },
  });
}

interface ParsedRequest {
  appUserId: string;
  rawText: string;
  categories: CategoryOption[];
}

function parseBody(body: unknown): ParsedRequest | null {
  if (typeof body !== "object" || body === null) return null;
  const { appUserId, rawText, categories } = body as Record<string, unknown>;
  if (typeof appUserId !== "string" || !USER_ID_PATTERN.test(appUserId)) return null;
  if (typeof rawText !== "string" || rawText.trim() === "") return null;
  if (!Array.isArray(categories) || categories.length === 0) return null;
  if (categories.length > MAX_CATEGORIES) return null;

  const parsed: CategoryOption[] = [];
  for (const c of categories) {
    if (typeof c !== "object" || c === null) return null;
    const { id, name } = c as Record<string, unknown>;
    if (typeof id !== "string" || id === "" || id.length > MAX_ID_CHARS) return null;
    if (typeof name !== "string" || name === "" || name.length > MAX_NAME_CHARS) return null;
    parsed.push({ id, name });
  }
  return { appUserId, rawText: rawText.slice(0, MAX_TEXT_CHARS), categories: parsed };
}

export function usageKey(appUserId: string, now: Date): string {
  const month = `${now.getUTCFullYear()}-${String(now.getUTCMonth() + 1).padStart(2, "0")}`;
  return `usage:${appUserId}:${month}`;
}

export function dailyUsageKey(appUserId: string, now: Date): string {
  const day = now.toISOString().slice(0, 10);
  return `usage-day:${appUserId}:${day}`;
}

/** Total harus bilangan bulat positif yang wajar; selain itu `null`. */
export function sanitizeTotal(value: unknown): number | null {
  if (typeof value !== "number" || !Number.isFinite(value)) return null;
  const n = Math.round(value);
  if (n !== value) return null; // pecahan: hampir pasti salah baca
  return n >= 1 && n <= MAX_TOTAL ? n : null;
}

/**
 * Tanggal harus `YYYY-MM-DD` yang benar-benar ada di kalender dan wajar untuk
 * sebuah struk: tidak lebih dari 5 tahun ke belakang dan tidak lebih dari
 * sehari ke depan (selisih zona waktu). Selain itu `null`.
 */
export function sanitizeDate(value: unknown, now: Date): string | null {
  if (typeof value !== "string") return null;
  const m = DATE_PATTERN.exec(value);
  if (!m) return null;
  const [y, mo, d] = [Number(m[1]), Number(m[2]), Number(m[3])];
  const t = Date.UTC(y, mo - 1, d);
  const check = new Date(t);
  if (
    check.getUTCFullYear() !== y ||
    check.getUTCMonth() !== mo - 1 ||
    check.getUTCDate() !== d
  ) {
    return null; // mis. 2026-02-31
  }
  const dayMs = 24 * 3600 * 1000;
  if (t < now.getTime() - 5 * 365 * dayMs) return null;
  if (t > now.getTime() + dayMs) return null;
  return value;
}

export async function handleExtract(req: Request, deps: Deps): Promise<Response> {
  const url = new URL(req.url);
  if (url.pathname !== "/extract") return json({ error: "not_found" }, 404);
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  // Pembatas per IP paling awal: sebelum membaca body atau memanggil layanan luar.
  const ip = req.headers.get("cf-connecting-ip");
  if (deps.allowIp && ip && !(await deps.allowIp(ip))) {
    return json({ error: "rate_limited" }, 429);
  }

  const text = await req.text();
  if (text.length > MAX_BODY_BYTES) return json({ error: "payload_too_large" }, 413);

  let raw: unknown;
  try {
    raw = JSON.parse(text);
  } catch {
    return json({ error: "invalid_json" }, 400);
  }
  const body = parseBody(raw);
  if (!body) return json({ error: "invalid_request" }, 400);

  let access;
  try {
    access = await resolveAccess(deps, body.appUserId);
  } catch {
    return json({ error: "entitlement_check_failed" }, 502);
  }
  if (!access.active) return json({ error: "not_ultimate" }, 403);

  const now = deps.now();
  // Pengguna uji coba: anggaran AI promo global dicek lebih dulu.
  if (access.trial && (await access.trial.budget.exhausted(now))) {
    return json({ error: "promo_budget_exhausted" }, 429);
  }
  const { monthlyLimit, dailyLimit } = access;
  const monthKey = usageKey(body.appUserId, now);
  const used = await deps.getUsage(monthKey);
  if (used >= monthlyLimit) {
    return json({ error: "quota_exceeded", limit: monthlyLimit }, 429);
  }
  const dayKey = dailyUsageKey(body.appUserId, now);
  const usedToday = dailyLimit ? await deps.getUsage(dayKey) : 0;
  if (dailyLimit && usedToday >= dailyLimit) {
    return json({ error: "daily_limit_exceeded", limit: dailyLimit }, 429);
  }

  let result: Extraction;
  try {
    result = await deps.extract(body.rawText, body.categories);
  } catch {
    return json({ error: "extraction_failed" }, 502);
  }
  // Hanya dihitung bila ekstraksi berhasil; pengguna tidak dirugikan oleh
  // kegagalan di sisi kita.
  await deps.setUsage(monthKey, used + 1, MONTH_TTL_SECONDS);
  if (dailyLimit) await deps.setUsage(dayKey, usedToday + 1, DAY_TTL_SECONDS);
  if (access.trial) await access.trial.budget.add(now, access.trial.costRp);

  // Jangan percaya keluaran model: kategori harus salah satu yang dikirim app,
  // total dan tanggal harus wajar.
  const categoryId = body.categories.some((c) => c.id === result.categoryId)
    ? result.categoryId
    : null;
  const merchant = result.merchant?.trim().slice(0, 60) || null;
  // Diagnostik tanpa data pengguna: hanya jumlah dan status (tanpa teks/nama/ID).
  console.log(
    `ai_result categories=${body.categories.length} model_category=${result.categoryId === null ? "null" : "set"} category_valid=${categoryId !== null} merchant=${merchant !== null}`,
  );
  return json({
    merchant,
    categoryId,
    total: sanitizeTotal(result.total),
    date: sanitizeDate(result.date, now),
    remaining: monthlyLimit - used - 1,
  });
}
