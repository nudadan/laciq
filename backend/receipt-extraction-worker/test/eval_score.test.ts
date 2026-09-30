import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, it } from "node:test";
import { merchantMatches, renderReport, scoreOne, summarize, type Expected } from "../eval/score.ts";

const NOW = new Date("2026-09-30T00:00:00Z");
const EXPECTED: Expected = {
  merchant: "Indomaret",
  categoryId: "cat-exp-belanja",
  total: 40100,
  date: "2026-09-28",
};

describe("eval/score", () => {
  it("semua benar", () => {
    const s = scoreOne(
      EXPECTED,
      { merchant: "INDOMARET Cikini", categoryId: "cat-exp-belanja", total: 40100, date: "2026-09-28" },
      NOW,
    );
    assert.deepEqual(s, { merchant: true, category: true, total: true, date: true });
  });

  it("dinilai setelah validasi produksi: total/tanggal tak wajar dianggap salah", () => {
    const s = scoreOne(
      EXPECTED,
      { merchant: null, categoryId: null, total: 40100.5, date: "2026-02-31" },
      NOW,
    );
    assert.deepEqual(s, { merchant: false, category: false, total: false, date: false });
  });

  it("nama toko: salah satu memuat yang lain, tanpa peduli huruf dan tanda baca", () => {
    assert.equal(merchantMatches("Sederhana", "RM. SEDERHANA Barokah"), true);
    assert.equal(merchantMatches("Warung Bu Tini", "warung bu tini"), true);
    assert.equal(merchantMatches("Indomaret", "Alfamart"), false);
    assert.equal(merchantMatches("Indomaret", null), false);
    assert.equal(merchantMatches("", "apa saja"), false);
  });

  it("summarize dan laporan memuat kandidat, galat, dan rata-rata token", () => {
    const ok = scoreOne(
      EXPECTED,
      { merchant: "Indomaret", categoryId: "cat-exp-belanja", total: 40100, date: "2026-09-28" },
      NOW,
    );
    const bad = scoreOne(
      EXPECTED,
      { merchant: null, categoryId: null, total: null, date: null },
      NOW,
    );
    assert.deepEqual(summarize([ok, bad]), { total: 1, date: 1, merchant: 1, category: 1 });

    const report = renderReport([
      {
        candidate: "gemini:m",
        rows: [
          { name: "a", score: ok, tokensIn: 800, tokensOut: 60 },
          { name: "b", score: null, error: "Gemini HTTP 429" },
        ],
      },
    ]);
    assert.match(report, /### gemini:m/);
    assert.match(report, /galat: Gemini HTTP 429/);
    assert.match(report, /\| gemini:m \| 1\/2 \| 1\/2 \| 1\/2 \| 1\/2 \| 1 \| 800 \| 60 \|/);
  });

  it("receipts.json: 10 struk sintetis; nilai yang diharapkan valid dan muncul di teks struk", () => {
    const data = JSON.parse(
      readFileSync(join(import.meta.dirname, "..", "eval", "receipts.json"), "utf8"),
    ) as {
      categories: { id: string }[];
      receipts: { name: string; rawText: string; expected: Expected }[];
    };
    assert.equal(data.receipts.length, 10);
    const ids = new Set(data.categories.map((c) => c.id));
    for (const r of data.receipts) {
      assert.ok(ids.has(r.expected.categoryId), `${r.name}: kategori ${r.expected.categoryId}`);
      assert.ok(r.rawText.length > 20, r.name);
      // Nilai yang diharapkan sendiri harus lolos validasi produksi.
      const s = scoreOne(r.expected, r.expected, NOW);
      assert.deepEqual(s, { merchant: true, category: true, total: true, date: true }, r.name);
      // Total yang diharapkan benar-benar muncul di teks struk (dengan atau tanpa titik).
      const plain = String(r.expected.total);
      const dotted = plain.replace(/\B(?=(\d{3})+(?!\d))/g, ".");
      assert.ok(r.rawText.includes(dotted) || r.rawText.includes(plain), `${r.name}: total ${dotted}`);
    }
  });
});
