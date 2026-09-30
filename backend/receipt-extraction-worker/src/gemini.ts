import type { CategoryOption, Extraction } from "./handler.ts";
import { SYSTEM, toExtraction, userPrompt, type RawExtraction } from "./prompt.ts";

/**
 * Pemanggil Google Gemini lewat REST `generateContent` (tanpa SDK).
 *
 * Seluruh detail HTTP terkumpul di [buildRequest] dan [parseResponse], dua
 * fungsi murni yang diuji tanpa jaringan. Dokumentasi Google saat ini
 * menonjolkan endpoint `interactions`; `generateContent` masih terdokumentasi
 * dan tidak ditandai usang, tetapi bentuk keluaran terstruktur dan
 * `thinkingConfig` HARUS diverifikasi dengan satu permintaan nyata sebelum
 * deploy (lihat docs/RENCANA-IMPLEMENTASI-ULTIMATE-LANJUTAN.md, B0.1).
 *
 * Wajib memakai paid tier untuk data pengguna sungguhan: free tier dipakai
 * Google untuk memperbaiki produk dan melarang data pribadi.
 */
const ENDPOINT = "https://generativelanguage.googleapis.com/v1beta/models";

/** Ruang untuk token berpikir; keluaran JSON-nya sendiri hanya puluhan token. */
const MAX_OUTPUT_TOKENS = 1024;

export interface GeminiUsage {
  model: string;
  promptTokens?: number;
  outputTokens?: number;
  thoughtsTokens?: number;
}

export interface GeminiOptions {
  fetchFn?: typeof fetch;
  /**
   * Objek `thinkingConfig` mentah (mis. `{"thinkingLevel":"minimal"}` untuk
   * seri 3, `{"thinkingBudget":0}` untuk 2.5). Kosong = bawaan model. Token
   * berpikir ditagih sebagai token keluaran, jadi isi setelah diverifikasi.
   */
  thinkingConfig?: Record<string, unknown>;
  /** Menerima pemakaian token tiap permintaan (bahan mengukur biaya nyata). */
  onUsage?: (usage: GeminiUsage) => void;
}

export function buildRequest(
  rawText: string,
  categories: CategoryOption[],
  thinkingConfig?: Record<string, unknown>,
) {
  return {
    systemInstruction: { parts: [{ text: SYSTEM }] },
    contents: [{ role: "user", parts: [{ text: userPrompt(rawText, categories) }] }],
    generationConfig: {
      temperature: 0,
      maxOutputTokens: MAX_OUTPUT_TOKENS,
      responseMimeType: "application/json",
      responseSchema: {
        type: "OBJECT",
        properties: {
          merchant: { type: "STRING", nullable: true },
          category_id: {
            type: "STRING",
            nullable: true,
            enum: categories.map((c) => c.id),
          },
          total: { type: "INTEGER", nullable: true },
          date: { type: "STRING", nullable: true },
        },
        required: ["merchant", "category_id", "total", "date"],
      },
      ...(thinkingConfig ? { thinkingConfig } : {}),
    },
  };
}

interface GeminiResponse {
  candidates?: {
    content?: { parts?: { text?: string }[] };
    finishReason?: string;
  }[];
  promptFeedback?: { blockReason?: string };
  usageMetadata?: {
    promptTokenCount?: number;
    candidatesTokenCount?: number;
    thoughtsTokenCount?: number;
  };
}

/** Mengurai respons menjadi keluaran mentah; melempar bila diblokir/terpotong/rusak. */
export function parseResponse(data: unknown): RawExtraction {
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
  if (text.trim() === "") throw new Error("Gemini: empty text");
  let parsed: unknown;
  try {
    parsed = JSON.parse(text);
  } catch {
    throw new Error("Gemini: invalid JSON");
  }
  if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) {
    throw new Error("Gemini: unexpected JSON shape");
  }
  return parsed as RawExtraction;
}

export function makeGeminiExtractor(apiKey: string, model: string, options: GeminiOptions = {}) {
  const doFetch = options.fetchFn ?? fetch;
  return async function extract(
    rawText: string,
    categories: CategoryOption[],
  ): Promise<Extraction> {
    const res = await doFetch(`${ENDPOINT}/${encodeURIComponent(model)}:generateContent`, {
      method: "POST",
      // Kunci lewat header, bukan query string, supaya tidak masuk log URL.
      headers: { "content-type": "application/json", "x-goog-api-key": apiKey },
      body: JSON.stringify(buildRequest(rawText, categories, options.thinkingConfig)),
    });
    // Jangan sertakan isi respons/kunci dalam pesan galat.
    if (!res.ok) throw new Error(`Gemini HTTP ${res.status}`);
    const data = (await res.json()) as GeminiResponse;
    const usage = data.usageMetadata;
    options.onUsage?.({
      model,
      promptTokens: usage?.promptTokenCount,
      outputTokens: usage?.candidatesTokenCount,
      thoughtsTokens: usage?.thoughtsTokenCount,
    });
    return toExtraction(parseResponse(data));
  };
}
