import { GeminiError } from "./gemini.ts";
import { modelChain, parseThinkingConfig, type AiEnv } from "./extractor.ts";
import {
  REPORT_SYSTEM,
  allowedAmounts,
  reportUserPrompt,
  validateNarrative,
  type ReportInput,
} from "./report_prompt.ts";

const ENDPOINT = "https://generativelanguage.googleapis.com/v1beta/models";
const MAX_OUTPUT_TOKENS = 1536;

export type Narrator = (report: ReportInput) => Promise<string>;

export function buildNarrationRequest(report: ReportInput, thinkingConfig?: Record<string, unknown>) {
  return {
    systemInstruction: { parts: [{ text: REPORT_SYSTEM }] },
    contents: [{ role: "user", parts: [{ text: reportUserPrompt(report) }] }],
    generationConfig: {
      temperature: 0.3,
      maxOutputTokens: MAX_OUTPUT_TOKENS,
      responseMimeType: "application/json",
      responseSchema: {
        type: "OBJECT",
        properties: { summary: { type: "STRING" } },
        required: ["summary"],
      },
      ...(thinkingConfig ? { thinkingConfig } : {}),
    },
  };
}

interface GeminiResponse {
  candidates?: { content?: { parts?: { text?: string }[] }; finishReason?: string }[];
  promptFeedback?: { blockReason?: string };
  usageMetadata?: {
    promptTokenCount?: number;
    candidatesTokenCount?: number;
    thoughtsTokenCount?: number;
  };
}

/** Mengambil teks ringkasan dari respons; melempar bila diblokir/terpotong/rusak. */
export function parseNarration(data: unknown): string {
  const res = (data ?? {}) as GeminiResponse;
  if (res.promptFeedback?.blockReason) {
    throw new Error(`Gemini blocked: ${res.promptFeedback.blockReason}`);
  }
  const candidate = res.candidates?.[0];
  if (!candidate) throw new Error("Gemini: no candidates");
  if (candidate.finishReason && candidate.finishReason !== "STOP") {
    throw new Error(`Gemini finishReason: ${candidate.finishReason}`);
  }
  const text = (candidate.content?.parts ?? []).map((p) => p.text ?? "").join("");
  let parsed: unknown;
  try {
    parsed = JSON.parse(text);
  } catch {
    throw new Error("Gemini: invalid JSON");
  }
  const summary = (parsed as { summary?: unknown } | null)?.summary;
  if (typeof summary !== "string") throw new Error("Gemini: no summary");
  return summary;
}

/** Model yang menjawab 404 dilewati sebentar (per isolate), seperti di extractor.ts. */
const DEAD_MODEL_SKIP_MS = 10 * 60 * 1000;
const skipUntil = new Map<string, number>();

export function resetNarratorSkips(): void {
  skipUntil.clear();
}

export function buildNarrator(
  env: AiEnv,
  log: (message: string) => void = console.log,
  fetchFn?: typeof fetch,
): Narrator {
  const doFetch = fetchFn ?? fetch;
  return async (report) => {
    const key = env.GEMINI_API_KEY;
    if (!key) throw new Error("GEMINI_API_KEY belum diisi");
    if ((env.AI_PROVIDER ?? "gemini").toLowerCase() !== "gemini") {
      throw new Error("AI_PROVIDER tidak dikenal");
    }
    const chain = modelChain(env);
    const thinkingConfig = parseThinkingConfig(env.AI_THINKING_CONFIG);
    const allowed = allowedAmounts(report);
    let lastError: unknown = new Error("Tidak ada model yang tersedia");
    for (const [i, model] of chain.entries()) {
      const isLast = i === chain.length - 1;
      if (!isLast && (skipUntil.get(model) ?? 0) > Date.now()) continue;
      try {
        const res = await doFetch(`${ENDPOINT}/${encodeURIComponent(model)}:generateContent`, {
          method: "POST",
          // Kunci lewat header, bukan query string, supaya tidak masuk log URL.
          headers: { "content-type": "application/json", "x-goog-api-key": key },
          body: JSON.stringify(buildNarrationRequest(report, thinkingConfig)),
        });
        if (!res.ok) throw new GeminiError(`Gemini HTTP ${res.status}`, res.status);
        const data = (await res.json()) as GeminiResponse;
        const u = data.usageMetadata;
        log(
          `ai_usage kind=report model=${model} in=${u?.promptTokenCount ?? "?"} out=${u?.candidatesTokenCount ?? "?"} thoughts=${u?.thoughtsTokenCount ?? 0}`,
        );
        // Keluaran yang tidak lolos pemeriksaan dianggap kegagalan model ini.
        return validateNarrative(parseNarration(data), allowed);
      } catch (e) {
        lastError = e;
        const status = e instanceof GeminiError ? e.status : undefined;
        // Kunci ditolak: model lain memakai kunci yang sama, jadi percuma.
        if (status === 401 || status === 403) throw e;
        if (status === 404) skipUntil.set(model, Date.now() + DEAD_MODEL_SKIP_MS);
        log(
          `ai_report_failed model=${model} reason=${e instanceof Error ? e.message : "unknown"}${
            isLast ? "" : " (mencoba cadangan)"
          }`,
        );
      }
    }
    throw lastError;
  };
}
