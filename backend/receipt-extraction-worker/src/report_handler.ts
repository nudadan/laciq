import type { Deps } from "./handler.ts";
import type { ReportBudget, ReportCategory, ReportInput } from "./report_prompt.ts";

/** Bagian [Deps] yang dipakai ulang (entitlement, kuota, jam, pembatas IP). */
export type ReportDeps = Pick<
  Deps,
  "hasUltimate" | "getUsage" | "setUsage" | "now" | "allowIp"
> & {
  /** Menulis ringkasan dari angka agregat; melempar bila gagal/tidak layak. */
  narrate(report: ReportInput): Promise<string>;
  monthlyLimit: number;
  dailyLimit?: number;
};

const MAX_BODY_BYTES = 8_000;
const MAX_CATEGORIES = 8;
const MAX_BUDGETS = 6;
const MAX_NAME_CHARS = 60;
const MAX_AMOUNT = 1_000_000_000_000; // 1 triliun Rupiah
const USER_ID_PATTERN = /^[\w$:.\-]{8,128}$/;
const MONTH_PATTERN = /^\d{4}-(0[1-9]|1[0-2])$/;
const MONTH_TTL_SECONDS = 35 * 24 * 3600;
const DAY_TTL_SECONDS = 2 * 24 * 3600;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" },
  });
}

export function reportUsageKey(appUserId: string, now: Date): string {
  const month = `${now.getUTCFullYear()}-${String(now.getUTCMonth() + 1).padStart(2, "0")}`;
  return `report-usage:${appUserId}:${month}`;
}

export function reportDailyUsageKey(appUserId: string, now: Date): string {
  return `report-usage-day:${appUserId}:${now.toISOString().slice(0, 10)}`;
}

const isAmount = (v: unknown): v is number =>
  typeof v === "number" && Number.isSafeInteger(v) && v >= 0 && v <= MAX_AMOUNT;

/** Nama kategori dibersihkan: tanpa karakter kontrol atau kurung sudut (anti memecah <data>). */
function cleanName(v: unknown): string | null {
  if (typeof v !== "string") return null;
  const name = v
    .replace(/[\u0000-\u001f\u007f<>]/g, " ")
    .replace(/\s{2,}/g, " ")
    .trim();
  return name === "" || name.length > MAX_NAME_CHARS ? null : name;
}

export function parseReport(body: unknown): { appUserId: string; report: ReportInput } | null {
  if (typeof body !== "object" || body === null) return null;
  const { appUserId, report } = body as Record<string, unknown>;
  if (typeof appUserId !== "string" || !USER_ID_PATTERN.test(appUserId)) return null;
  if (typeof report !== "object" || report === null) return null;
  const r = report as Record<string, unknown>;

  if (typeof r.month !== "string" || !MONTH_PATTERN.test(r.month)) return null;
  const { daysElapsed, daysInMonth } = r;
  if (typeof daysInMonth !== "number" || !Number.isInteger(daysInMonth)) return null;
  if (daysInMonth < 28 || daysInMonth > 31) return null;
  if (typeof daysElapsed !== "number" || !Number.isInteger(daysElapsed)) return null;
  if (daysElapsed < 1 || daysElapsed > daysInMonth) return null;
  if (!isAmount(r.income) || !isAmount(r.expense) || !isAmount(r.previousExpense)) return null;
  // Tanpa data sama sekali tidak ada yang bisa diringkas.
  if (r.income === 0 && r.expense === 0) return null;
  let projectedExpense: number | null = null;
  if (r.projectedExpense !== null && r.projectedExpense !== undefined) {
    if (!isAmount(r.projectedExpense)) return null;
    projectedExpense = r.projectedExpense;
  }

  if (!Array.isArray(r.categories) || r.categories.length > MAX_CATEGORIES) return null;
  const categories: ReportCategory[] = [];
  for (const c of r.categories) {
    if (typeof c !== "object" || c === null) return null;
    const { name, total, previousTotal } = c as Record<string, unknown>;
    const clean = cleanName(name);
    if (clean === null || !isAmount(total) || !isAmount(previousTotal)) return null;
    categories.push({ name: clean, total, previousTotal });
  }

  const rawBudgets = r.budgets ?? [];
  if (!Array.isArray(rawBudgets) || rawBudgets.length > MAX_BUDGETS) return null;
  const budgets: ReportBudget[] = [];
  for (const b of rawBudgets) {
    if (typeof b !== "object" || b === null) return null;
    const { name, percent } = b as Record<string, unknown>;
    const clean = cleanName(name);
    if (clean === null || typeof percent !== "number" || !Number.isInteger(percent)) return null;
    if (percent < 0 || percent > 1000) return null;
    budgets.push({ name: clean, percent });
  }

  return {
    appUserId,
    report: {
      month: r.month,
      daysElapsed,
      daysInMonth,
      income: r.income,
      expense: r.expense,
      previousExpense: r.previousExpense,
      projectedExpense,
      categories,
      budgets,
    },
  };
}

export async function handleReportInsight(req: Request, deps: ReportDeps): Promise<Response> {
  const url = new URL(req.url);
  if (url.pathname !== "/report-insight") return json({ error: "not_found" }, 404);
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

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
  const body = parseReport(raw);
  if (!body) return json({ error: "invalid_request" }, 400);

  let ultimate: boolean;
  try {
    ultimate = await deps.hasUltimate(body.appUserId);
  } catch {
    return json({ error: "entitlement_check_failed" }, 502);
  }
  if (!ultimate) return json({ error: "not_ultimate" }, 403);

  const now = deps.now();
  const monthKey = reportUsageKey(body.appUserId, now);
  const used = await deps.getUsage(monthKey);
  if (used >= deps.monthlyLimit) {
    return json({ error: "quota_exceeded", limit: deps.monthlyLimit }, 429);
  }
  const dayKey = reportDailyUsageKey(body.appUserId, now);
  const usedToday = deps.dailyLimit ? await deps.getUsage(dayKey) : 0;
  if (deps.dailyLimit && usedToday >= deps.dailyLimit) {
    return json({ error: "daily_limit_exceeded", limit: deps.dailyLimit }, 429);
  }

  let summary: string;
  try {
    summary = await deps.narrate(body.report);
  } catch {
    return json({ error: "narration_failed" }, 502);
  }
  // Dihitung hanya bila berhasil.
  await deps.setUsage(monthKey, used + 1, MONTH_TTL_SECONDS);
  if (deps.dailyLimit) await deps.setUsage(dayKey, usedToday + 1, DAY_TTL_SECONDS);

  // Diagnostik tanpa data pengguna.
  console.log(`ai_report_result chars=${summary.length} categories=${body.report.categories.length}`);
  return json({ summary, remaining: deps.monthlyLimit - used - 1 });
}
