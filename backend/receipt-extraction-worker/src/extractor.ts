import type { CategoryOption, Extraction } from "./handler.ts";
import { makeGeminiExtractor } from "./gemini.ts";

export type Extractor = (rawText: string, categories: CategoryOption[]) => Promise<Extraction>;

/** Variabel lingkungan yang menentukan penyedia dan model AI. */
export interface AiEnv {
  /** `gemini` (bawaan) atau `anthropic`. */
  AI_PROVIDER?: string;
  /** ID model; kosong = bawaan penyedia. Simpan di wrangler.toml, bukan di kode. */
  AI_MODEL?: string;
  /** JSON mentah untuk `thinkingConfig` Gemini (opsional; lihat gemini.ts). */
  AI_THINKING_CONFIG?: string;
  GEMINI_API_KEY?: string;
  ANTHROPIC_API_KEY?: string;
}

export const DEFAULT_GEMINI_MODEL = "gemini-3.1-flash-lite";
export const DEFAULT_ANTHROPIC_MODEL = "claude-haiku-4-5";

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
      const model = env.AI_MODEL || DEFAULT_GEMINI_MODEL;
      const extract = makeGeminiExtractor(key, model, {
        fetchFn,
        thinkingConfig: parseThinkingConfig(env.AI_THINKING_CONFIG),
        // Jumlah token saja (tanpa isi struk) untuk mengukur biaya nyata.
        onUsage: (u) =>
          log(
            `ai_usage model=${u.model} in=${u.promptTokens ?? "?"} out=${u.outputTokens ?? "?"} thoughts=${u.thoughtsTokens ?? 0}`,
          ),
      });
      return extract(rawText, categories);
    };
  }

  if (provider === "anthropic") {
    const key = env.ANTHROPIC_API_KEY;
    return async (rawText, categories) => {
      if (!key) throw new Error("ANTHROPIC_API_KEY belum diisi");
      const { makeExtractor } = await import("./anthropic.ts");
      return makeExtractor(key, env.AI_MODEL || DEFAULT_ANTHROPIC_MODEL)(rawText, categories);
    };
  }

  return async () => {
    throw new Error(`AI_PROVIDER tidak dikenal: ${provider}`);
  };
}
