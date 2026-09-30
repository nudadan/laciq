export interface CategoryOption {
  id: string;
  name: string;
}

export interface Extraction {
  merchant: string | null;
  categoryId: string | null;
}

export interface Deps {
  /** Apakah pengguna ini punya entitlement Ultimate aktif (dicek ke RevenueCat). */
  hasUltimate(appUserId: string): Promise<boolean>;
  /** Jumlah pemakaian bulan ini untuk kunci tertentu. */
  getUsage(key: string): Promise<number>;
  setUsage(key: string, count: number): Promise<void>;
  extract(rawText: string, categories: CategoryOption[]): Promise<Extraction>;
  now(): Date;
  monthlyLimit: number;
}

const MAX_BODY_BYTES = 20_000;
const MAX_TEXT_CHARS = 4000;
const MAX_CATEGORIES = 80;
const MAX_ID_CHARS = 64;
const MAX_NAME_CHARS = 80;
const USER_ID_PATTERN = /^[\w$:.\-]{8,128}$/;

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

export async function handleExtract(req: Request, deps: Deps): Promise<Response> {
  const url = new URL(req.url);
  if (url.pathname !== "/extract") return json({ error: "not_found" }, 404);
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

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

  let ultimate: boolean;
  try {
    ultimate = await deps.hasUltimate(body.appUserId);
  } catch {
    return json({ error: "entitlement_check_failed" }, 502);
  }
  if (!ultimate) return json({ error: "not_ultimate" }, 403);

  const key = usageKey(body.appUserId, deps.now());
  const used = await deps.getUsage(key);
  if (used >= deps.monthlyLimit) {
    return json({ error: "quota_exceeded", limit: deps.monthlyLimit }, 429);
  }

  let result: Extraction;
  try {
    result = await deps.extract(body.rawText, body.categories);
  } catch {
    return json({ error: "extraction_failed" }, 502);
  }
  // Hanya dihitung bila ekstraksi berhasil; pengguna tidak dirugikan oleh
  // kegagalan di sisi kita.
  await deps.setUsage(key, used + 1);

  // Jangan percaya keluaran model: kategori harus salah satu yang dikirim app.
  const categoryId = body.categories.some((c) => c.id === result.categoryId)
    ? result.categoryId
    : null;
  const merchant = result.merchant?.trim().slice(0, 60) || null;
  return json({ merchant, categoryId, remaining: deps.monthlyLimit - used - 1 });
}
