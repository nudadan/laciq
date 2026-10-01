import type { CategoryOption, Extraction } from "./handler.ts";
import { GeminiError, makeGeminiExtractor } from "./gemini.ts";

export type Extractor = (rawText: string, categories: CategoryOption[]) => Promise<Extraction>;

/** Variabel lingkungan yang menentukan penyedia dan model AI. */
export interface AiEnv {
  /** Saat ini hanya `gemini` (bawaan). Penyedia lain = galat saat dipanggil. */
  AI_PROVIDER?: string;
  /** ID model; kosong = bawaan penyedia. Simpan di wrangler.toml, bukan di kode. */
  AI_MODEL?: string;
  /**
   * Model cadangan, dipisah koma, dicoba berurutan bila model utama gagal
   * (mis. dihentikan Google: HTTP 404). Kosong = tanpa cadangan. Jangan isi
   * `AI_THINKING_CONFIG` bila cadangan berasal dari seri berbeda: format
   * `thinkingConfig` berbeda antarseri.
   */
  AI_MODEL_FALLBACK?: string;
  /** JSON mentah untuk `thinkingConfig` Gemini (opsional; lihat gemini.ts). */
  AI_THINKING_CONFIG?: string;
  GEMINI_API_KEY?: string;
}

export const DEFAULT_GEMINI_MODEL = "gemini-3.1-flash-lite";

/** Utama + cadangan; paling banyak 3 model (biaya dan latensi terbatas). */
const MAX_MODELS = 3;

/** Model yang menjawab 404 dilewati selama ini (per isolate Worker), supaya tidak dicoba tiap permintaan. */
const DEAD_MODEL_SKIP_MS = 10 * 60 * 1000;
const skipUntil = new Map<string, number>();

/** Untuk tes: melupakan model yang sedang dilewati. */
export function resetModelSkips(): void {
  skipUntil.clear();
}

/** Urutan model: utama, lalu cadangan; kosong/duplikat dibuang. */
export function modelChain(env: AiEnv): string[] {
  const list = [
    env.AI_MODEL || DEFAULT_GEMINI_MODEL,
    ...(env.AI_MODEL_FALLBACK ?? "").split(","),
  ]
    .map((m) => m.trim())
    .filter((m) => m !== "");
  return [...new Set(list)].slice(0, MAX_MODELS);
}

/** JSON rusak/bukan objek diabaikan (bukan menggagalkan seluruh permintaan). */
export function parseThinkingConfig(raw: string | undefined): Record<string, unknown> | undefined {
  if (!raw || raw.trim() === "") return undefined;
  try {
    const parsed: unknown = JSON.parse(raw);
    if (typeof parsed === "object" && parsed !== null && !Array.isArray(parsed)) {
      return parsed as Record<string, unknown>;
    }
  } catch {
    // jatuh ke undefined
  }
  return undefined;
}

export function buildExtractor(
  env: AiEnv,
  log: (message: string) => void = console.log,
  fetchFn?: typeof fetch,
): Extractor {
  const provider = (env.AI_PROVIDER ?? "gemini").toLowerCase();

  if (provider === "gemini") {
    const key = env.GEMINI_API_KEY;
    return async (rawText, categories) => {
      if (!key) throw new Error("GEMINI_API_KEY belum diisi");
      const chain = modelChain(env);
      const thinkingConfig = parseThinkingConfig(env.AI_THINKING_CONFIG);
      let lastError: unknown = new Error("Tidak ada model yang tersedia");
      for (const [i, model] of chain.entries()) {
        const isLast = i === chain.length - 1;
        // Lewati model yang baru saja 404, kecuali tinggal model terakhir.
        if (!isLast && (skipUntil.get(model) ?? 0) > Date.now()) continue;
        const extract = makeGeminiExtractor(key, model, {
          fetchFn,
          thinkingConfig,
          // Jumlah token saja (tanpa isi struk) untuk mengukur biaya nyata.
          onUsage: (u) =>
            log(
              `ai_usage model=${u.model} in=${u.promptTokens ?? "?"} out=${u.outputTokens ?? "?"} thoughts=${u.thoughtsTokens ?? 0}`,
            ),
        });
        try {
          return await extract(rawText, categories);
        } catch (e) {
          lastError = e;
          const status = e instanceof GeminiError ? e.status : undefined;
          // Kunci ditolak: model lain memakai kunci yang sama, jadi percuma.
          if (status === 401 || status === 403) throw e;
          if (status === 404) skipUntil.set(model, Date.now() + DEAD_MODEL_SKIP_MS);
          // Pesan galat tanpa isi struk dan tanpa kunci.
          log(
            `ai_model_failed model=${model} reason=${e instanceof Error ? e.message : "unknown"}${
              isLast ? "" : " (mencoba cadangan)"
            }`,
          );
        }
      }
      throw lastError;
    };
  }

  return async () => {
    throw new Error(`AI_PROVIDER tidak dikenal: ${provider}`);
  };
}
