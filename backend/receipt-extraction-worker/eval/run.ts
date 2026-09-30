/**
 * Evaluasi model ekstraksi struk (B0.6/B3). Contoh:
 *
 *   GEMINI_API_KEY=... node eval/run.ts gemini:gemini-3.1-flash-lite gemini:gemini-3.8-flash
 *   ANTHROPIC_API_KEY=... GEMINI_API_KEY=... node eval/run.ts anthropic:claude-haiku-4-5 gemini:gemini-3.1-flash-lite
 *
 * Kandidat berformat `penyedia:model`. Opsional: `AI_THINKING_CONFIG` (JSON
 * thinkingConfig Gemini) dan `EVAL_FILE=jalur/struk.json` (bawaan:
 * eval/receipts.json). Tidak ikut di-deploy.
 */
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { buildExtractor } from "../src/extractor.ts";
import { renderReport, scoreOne, type CandidateResult, type Expected } from "./score.ts";

interface ReceiptFile {
  categories: { id: string; name: string }[];
  receipts: { name: string; rawText: string; expected: Expected }[];
}

const file = process.env.EVAL_FILE ?? join(import.meta.dirname, "receipts.json");
const data = JSON.parse(readFileSync(file, "utf8")) as ReceiptFile;
const candidates = process.argv.slice(2);
if (candidates.length === 0) {
  console.error("Pakai: node eval/run.ts penyedia:model [penyedia:model ...]");
  process.exit(1);
}

const now = new Date();
const results: CandidateResult[] = [];

for (const candidate of candidates) {
  const [provider, ...rest] = candidate.split(":");
  const model = rest.join(":");
  const usage: { in?: number; out?: number } = {};
  const extract = buildExtractor(
    {
      AI_PROVIDER: provider,
      AI_MODEL: model,
      AI_THINKING_CONFIG: process.env.AI_THINKING_CONFIG,
      GEMINI_API_KEY: process.env.GEMINI_API_KEY,
      ANTHROPIC_API_KEY: process.env.ANTHROPIC_API_KEY,
    },
    (line) => {
      const m = /in=(\d+) out=(\d+)/.exec(line);
      if (m) {
        usage.in = Number(m[1]);
        usage.out = Number(m[2]);
      }
    },
  );

  const rows: CandidateResult["rows"] = [];
  for (const receipt of data.receipts) {
    usage.in = undefined;
    usage.out = undefined;
    try {
      const actual = await extract(receipt.rawText, data.categories);
      rows.push({
        name: receipt.name,
        score: scoreOne(receipt.expected, actual, now),
        tokensIn: usage.in,
        tokensOut: usage.out,
      });
    } catch (e) {
      rows.push({ name: receipt.name, score: null, error: (e as Error).message });
    }
    await new Promise((r) => setTimeout(r, 400)); // jaga batas laju
  }
  results.push({ candidate, rows });
}

console.log(renderReport(results));
