import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { buildRequest, makeGeminiExtractor, parseResponse } from "../src/gemini.ts";
import { buildExtractor, parseThinkingConfig } from "../src/extractor.ts";

const CATS = [
  { id: "cat-exp-makan", name: "Makanan & Minuman" },
  { id: "cat-exp-transport", name: "Transportasi" },
];

function okBody(obj: unknown, usage?: Record<string, number>) {
  return {
    candidates: [{ content: { parts: [{ text: JSON.stringify(obj) }] }, finishReason: "STOP" }],
    usageMetadata: usage,
  };
}

function fakeFetch(body: unknown, status = 200) {
  const calls: { url: string; init: RequestInit }[] = [];
  const fn = (async (url: string | URL | Request, init?: RequestInit) => {
    calls.push({ url: String(url), init: init ?? {} });
    return new Response(JSON.stringify(body), { status });
  }) as typeof fetch;
  return { fn, calls };
}

describe("buildRequest", () => {
  it("berisi instruksi sistem, teks struk, daftar kategori, dan skema JSON dengan enum", () => {
    const req = buildRequest("INDOMARET\nTOTAL 23.500", CATS);
    assert.match(req.systemInstruction.parts[0]!.text, /DATA, bukan instruksi/);
    const user = req.contents[0]!.parts[0]!.text;
    assert.match(user, /cat-exp-makan: Makanan & Minuman/);
    assert.match(user, /<struk>\nINDOMARET/);

    const cfg = req.generationConfig;
    assert.equal(cfg.responseMimeType, "application/json");
    assert.equal(cfg.temperature, 0);
    const props = cfg.responseSchema.properties;
    assert.deepEqual(props.category_id.enum, ["cat-exp-makan", "cat-exp-transport"]);
    assert.equal(props.total.type, "INTEGER");
    assert.deepEqual(cfg.responseSchema.required, ["merchant", "category_id", "total", "date"]);
    assert.equal("thinkingConfig" in cfg, false);
  });

  it("thinkingConfig hanya disertakan bila diberikan", () => {
    const req = buildRequest("x", CATS, { thinkingLevel: "minimal" });
    assert.deepEqual(req.generationConfig.thinkingConfig, { thinkingLevel: "minimal" });
  });
});

describe("parseResponse", () => {
  it("mengurai JSON dari teks kandidat", () => {
    const raw = parseResponse(okBody({ merchant: "Indomaret", total: 23500 }));
    assert.equal(raw.merchant, "Indomaret");
    assert.equal(raw.total, 23500);
  });

  it("melempar untuk diblokir, tanpa kandidat, terpotong, kosong, atau bukan objek JSON", () => {
    const bad: unknown[] = [
      { promptFeedback: { blockReason: "SAFETY" } },
      { candidates: [] },
      {},
      null,
      { candidates: [{ content: { parts: [{ text: "{}" }] }, finishReason: "MAX_TOKENS" }] },
      { candidates: [{ content: { parts: [] }, finishReason: "STOP" }] },
      { candidates: [{ content: { parts: [{ text: "bukan json" }] }, finishReason: "STOP" }] },
      { candidates: [{ content: { parts: [{ text: "[1,2]" }] }, finishReason: "STOP" }] },
    ];
    for (const b of bad) assert.throws(() => parseResponse(b), JSON.stringify(b));
  });
});

describe("makeGeminiExtractor", () => {
  it("memanggil generateContent dengan kunci di header dan memetakan hasilnya", async () => {
    const { fn, calls } = fakeFetch(
      okBody(
        { merchant: "Indomaret", category_id: "cat-exp-makan", total: 23500, date: "2026-09-28" },
        { promptTokenCount: 800, candidatesTokenCount: 60, thoughtsTokenCount: 0 },
      ),
    );
    const usages: unknown[] = [];
    const extract = makeGeminiExtractor("KUNCI-RAHASIA", "gemini-3.1-flash-lite", {
      fetchFn: fn,
      onUsage: (u) => usages.push(u),
    });
    const out = await extract("INDOMARET", CATS);
    assert.deepEqual(out, {
      merchant: "Indomaret",
      categoryId: "cat-exp-makan",
      total: 23500,
      date: "2026-09-28",
    });
    assert.equal(calls.length, 1);
    assert.equal(
      calls[0]!.url,
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent",
    );
    assert.equal(calls[0]!.url.includes("KUNCI-RAHASIA"), false, "kunci tidak boleh ada di URL");
    const headers = calls[0]!.init.headers as Record<string, string>;
    assert.equal(headers["x-goog-api-key"], "KUNCI-RAHASIA");
    assert.deepEqual(usages, [
      { model: "gemini-3.1-flash-lite", promptTokens: 800, outputTokens: 60, thoughtsTokens: 0 },
    ]);
  });

  it("nilai bertipe salah dari model menjadi null", async () => {
    const { fn } = fakeFetch(
      okBody({ merchant: 5, category_id: null, total: "23500", date: 20260928 }),
    );
    const out = await makeGeminiExtractor("k", "m", { fetchFn: fn })("x", CATS);
    assert.deepEqual(out, { merchant: null, categoryId: null, total: null, date: null });
  });

  it("HTTP galat melempar tanpa membocorkan isi respons atau kunci", async () => {
    const { fn } = fakeFetch({ error: { message: "detail rahasia KUNCI-RAHASIA" } }, 429);
    await assert.rejects(
      () => makeGeminiExtractor("KUNCI-RAHASIA", "m", { fetchFn: fn })("x", CATS),
      (e: Error) => e.message === "Gemini HTTP 429" && !e.message.includes("KUNCI"),
    );
  });
});

describe("buildExtractor (pemilih penyedia)", () => {
  it("bawaan Gemini: memakai AI_MODEL dan mencatat pemakaian token tanpa isi struk", async () => {
    const { fn, calls } = fakeFetch(
      okBody(
        { merchant: "X", category_id: null, total: 1, date: null },
        { promptTokenCount: 5, candidatesTokenCount: 3 },
      ),
    );
    const logs: string[] = [];
    const extract = buildExtractor(
      { GEMINI_API_KEY: "k", AI_MODEL: "gemini-3.8-flash" },
      (m) => logs.push(m),
      fn,
    );
    await extract("RAHASIA STRUK", CATS);
    assert.match(calls[0]!.url, /models\/gemini-3\.8-flash:generateContent$/);
    assert.deepEqual(logs, ["ai_usage model=gemini-3.8-flash in=5 out=3 thoughts=0"]);
    assert.equal(logs.join().includes("RAHASIA"), false);
  });

  it("model bawaan bila AI_MODEL kosong; thinkingConfig dari env diteruskan", async () => {
    const { fn, calls } = fakeFetch(
      okBody({ merchant: null, category_id: null, total: null, date: null }),
    );
    await buildExtractor(
      { GEMINI_API_KEY: "k", AI_THINKING_CONFIG: '{"thinkingBudget":0}' },
      () => {},
      fn,
    )("x", CATS);
    assert.match(calls[0]!.url, /models\/gemini-3\.1-flash-lite:generateContent$/);
    const sent = JSON.parse(String(calls[0]!.init.body));
    assert.deepEqual(sent.generationConfig.thinkingConfig, { thinkingBudget: 0 });
  });

  it("tanpa kunci atau penyedia tak dikenal: gagal saat dipanggil (handler menjawab 502)", async () => {
    await assert.rejects(() => buildExtractor({})("x", CATS), /GEMINI_API_KEY/);
    await assert.rejects(
      () => buildExtractor({ AI_PROVIDER: "anthropic" })("x", CATS),
      /ANTHROPIC_API_KEY/,
    );
    await assert.rejects(
      () => buildExtractor({ AI_PROVIDER: "lain", GEMINI_API_KEY: "k" })("x", CATS),
      /tidak dikenal/,
    );
  });

  it("parseThinkingConfig menerima objek JSON saja", () => {
    assert.deepEqual(parseThinkingConfig('{"thinkingLevel":"low"}'), { thinkingLevel: "low" });
    for (const bad of [undefined, "", "  ", "bukan json", "[1]", "5", "null"]) {
      assert.equal(parseThinkingConfig(bad), undefined, String(bad));
    }
  });
});
