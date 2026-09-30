import { sanitizeDate, sanitizeTotal } from "../src/handler.ts";

export interface Expected {
  merchant: string;
  categoryId: string;
  total: number;
  date: string;
}

export interface Actual {
  merchant: string | null;
  categoryId: string | null;
  total: number | null;
  date: string | null;
}

export interface Score {
  merchant: boolean;
  category: boolean;
  total: boolean;
  date: boolean;
}

export const FIELDS = ["total", "date", "merchant", "category"] as const;

const norm = (s: string) => s.toLowerCase().replace(/[^a-z0-9]/g, "");

/** Nama toko dianggap benar bila salah satu memuat yang lain (mis. "Sederhana" vs "RM Sederhana Barokah"). */
export function merchantMatches(expected: string, actual: string | null): boolean {
  if (!actual) return false;
  const [e, a] = [norm(expected), norm(actual)];
  return e !== "" && a !== "" && (a.includes(e) || e.includes(a));
}

/**
 * Menilai keluaran SETELAH divalidasi seperti di produksi (total/tanggal yang
 * tidak wajar menjadi null), supaya skor mencerminkan yang dilihat pengguna.
 */
export function scoreOne(expected: Expected, actual: Actual, now: Date): Score {
  return {
    merchant: merchantMatches(expected.merchant, actual.merchant),
    category: actual.categoryId === expected.categoryId,
    total: sanitizeTotal(actual.total) === expected.total,
    date: sanitizeDate(actual.date, now) === expected.date,
  };
}

export function summarize(scores: Score[]): Record<(typeof FIELDS)[number], number> {
  return {
    total: scores.filter((s) => s.total).length,
    date: scores.filter((s) => s.date).length,
    merchant: scores.filter((s) => s.merchant).length,
    category: scores.filter((s) => s.category).length,
  };
}

type Row = {
  name: string;
  score: Score | null;
  error?: string;
  tokensIn?: number;
  tokensOut?: number;
};

export interface CandidateResult {
  candidate: string;
  rows: Row[];
}

const mark = (ok: boolean | undefined) => (ok === undefined ? "-" : ok ? "ya" : "TIDAK");

/** Tabel markdown: satu blok per kandidat, plus ringkasan lintas kandidat. */
export function renderReport(results: CandidateResult[]): string {
  const lines: string[] = [];
  for (const r of results) {
    lines.push(
      `### ${r.candidate}`,
      "",
      "| Struk | Total | Tanggal | Toko | Kategori | Token in/out |",
      "|---|---|---|---|---|---|",
    );
    for (const row of r.rows) {
      const s = row.score ?? undefined;
      const tokens = row.error
        ? `galat: ${row.error}`
        : `${row.tokensIn ?? "?"}/${row.tokensOut ?? "?"}`;
      lines.push(
        `| ${row.name} | ${mark(s?.total)} | ${mark(s?.date)} | ${mark(s?.merchant)} | ${mark(s?.category)} | ${tokens} |`,
      );
    }
    lines.push("");
  }
  lines.push(
    "### Ringkasan (benar dari jumlah struk)",
    "",
    "| Kandidat | Total | Tanggal | Toko | Kategori | Galat | Token in (rata-rata) | Token out (rata-rata) |",
    "|---|---|---|---|---|---|---|---|",
  );
  for (const r of results) {
    const scores = r.rows.flatMap((x) => (x.score ? [x.score] : []));
    const sum = summarize(scores);
    const n = r.rows.length;
    const avg = (pick: (x: Row) => number | undefined) => {
      const vals = r.rows.map(pick).filter((v): v is number => v !== undefined);
      return vals.length ? Math.round(vals.reduce((a, b) => a + b, 0) / vals.length) : "?";
    };
    const errors = r.rows.filter((x) => x.error).length;
    lines.push(
      `| ${r.candidate} | ${sum.total}/${n} | ${sum.date}/${n} | ${sum.merchant}/${n} | ${sum.category}/${n} | ${errors} | ${avg((x) => x.tokensIn)} | ${avg((x) => x.tokensOut)} |`,
    );
  }
  return lines.join("\n");
}
