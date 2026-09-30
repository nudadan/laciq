import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  MAX_TOTAL,
  dailyUsageKey,
  handleExtract,
  sanitizeDate,
  sanitizeTotal,
  usageKey,
  type Deps,
} from "../src/handler.ts";

const USER = "$RCAnonymousID:0123456789abcdef0123456789abcdef";
const CATS = [
  { id: "cat-exp-makan", name: "Makanan & Minuman" },
  { id: "cat-exp-transport", name: "Transportasi" },
];

function makeDeps(over: Partial<Deps> = {}) {
  const usage = new Map<string, number>();
  const calls: { rawText: string; categories: unknown }[] = [];
  const deps: Deps = {
    hasUltimate: async () => true,
    getUsage: async (k) => usage.get(k) ?? 0,
    setUsage: async (k, n) => void usage.set(k, n),
    extract: async (rawText, categories) => {
      calls.push({ rawText, categories });
      return { merchant: "Indomaret", categoryId: "cat-exp-makan", total: 23500, date: "2026-09-28" };
    },
    now: () => new Date("2026-09-29T10:00:00Z"),
    monthlyLimit: 3,
    ...over,
  };
  return { deps, usage, calls };
}

function post(body: unknown, path = "/extract", method = "POST") {
  return new Request(`https://w.example${path}`, {
    method,
    body: method === "POST" ? (typeof body === "string" ? body : JSON.stringify(body)) : undefined,
  });
}

const valid = { appUserId: USER, rawText: "INDOMARET\nTOTAL 23.500", categories: CATS };

describe("handleExtract", () => {
  it("mengembalikan hasil untuk pengguna Ultimate dan menghitung kuota", async () => {
    const { deps, usage } = makeDeps();
    const res = await handleExtract(post(valid), deps);
    assert.equal(res.status, 200);
    assert.deepEqual(await res.json(), {
      merchant: "Indomaret",
      categoryId: "cat-exp-makan",
      total: 23500,
      date: "2026-09-28",
      remaining: 2,
    });
    assert.equal(usage.get(usageKey(USER, deps.now())), 1);
  });

  it("menolak non-Ultimate dengan 403 tanpa memanggil model", async () => {
    const { deps, calls } = makeDeps({ hasUltimate: async () => false });
    const res = await handleExtract(post(valid), deps);
    assert.equal(res.status, 403);
    assert.equal(calls.length, 0);
  });

  it("502 bila RevenueCat gagal (fail closed)", async () => {
    const { deps, calls } = makeDeps({
      hasUltimate: async () => {
        throw new Error("down");
      },
    });
    const res = await handleExtract(post(valid), deps);
    assert.equal(res.status, 502);
    assert.equal(calls.length, 0);
  });

  it("429 setelah kuota bulanan habis, dan kuota bulan baru mulai dari nol", async () => {
    const { deps, calls } = makeDeps();
    for (let i = 0; i < 3; i++) {
      assert.equal((await handleExtract(post(valid), deps)).status, 200);
    }
    const blocked = await handleExtract(post(valid), deps);
    assert.equal(blocked.status, 429);
    assert.equal(calls.length, 3);

    const october = { ...deps, now: () => new Date("2026-10-01T00:00:01Z") };
    assert.equal((await handleExtract(post(valid), october)).status, 200);
  });

  it("kegagalan model tidak memotong kuota (502)", async () => {
    const { deps, usage } = makeDeps({
      extract: async () => {
        throw new Error("boom");
      },
    });
    const res = await handleExtract(post(valid), deps);
    assert.equal(res.status, 502);
    assert.equal(usage.size, 0);
  });

  it("membuang categoryId hasil model yang bukan dari daftar", async () => {
    const { deps } = makeDeps({
      extract: async () => ({
        merchant: "  Toko X  ",
        categoryId: "cat-karangan",
        total: null,
        date: null,
      }),
    });
    const body = (await (await handleExtract(post(valid), deps)).json()) as Record<string, unknown>;
    assert.equal(body.categoryId, null);
    assert.equal(body.merchant, "Toko X");
  });

  it("memotong teks OCR ke 4000 karakter", async () => {
    const { deps, calls } = makeDeps();
    await handleExtract(post({ ...valid, rawText: "x".repeat(9000) }), deps);
    assert.equal(calls[0]!.rawText.length, 4000);
  });

  it("validasi: body rusak, ID pengguna aneh, kategori kosong, terlalu besar", async () => {
    const { deps } = makeDeps();
    const bad: [unknown, number][] = [
      ["bukan json", 400],
      [{ ...valid, appUserId: "../../etc" }, 400],
      [{ ...valid, appUserId: "a b c d e f g h" }, 400],
      [{ ...valid, rawText: "  " }, 400],
      [{ ...valid, categories: [] }, 400],
      [{ ...valid, categories: [{ id: "x" }] }, 400],
      [{ ...valid, rawText: "x".repeat(25_000) }, 413],
    ];
    for (const [body, status] of bad) {
      assert.equal((await handleExtract(post(body), deps)).status, status, JSON.stringify(body).slice(0, 60));
    }
  });

  it("404 untuk path lain, 405 untuk selain POST", async () => {
    const { deps } = makeDeps();
    assert.equal((await handleExtract(post(valid, "/lain"), deps)).status, 404);
    assert.equal((await handleExtract(post(null, "/extract", "GET"), deps)).status, 405);
  });
  describe("total dan tanggal dari model", () => {
    const now = new Date("2026-09-29T10:00:00Z");
    const ask = async (over: { total?: unknown; date?: unknown }) => {
      const { deps } = makeDeps({
        extract: async () =>
          ({ merchant: "X", categoryId: "cat-exp-makan", total: null, date: null, ...over }) as never,
      });
      return (await (await handleExtract(post(valid), deps)).json()) as {
        total: number | null;
        date: string | null;
      };
    };

    it("total wajar diteruskan; tidak wajar dibuang", async () => {
      assert.equal((await ask({ total: 244850 })).total, 244850);
      for (const bad of [0, -5, 12.5, 2_000_000_000, Number.NaN, "244850", null, undefined]) {
        assert.equal((await ask({ total: bad })).total, null, String(bad));
      }
    });

    it("tanggal wajar diteruskan; tidak ada di kalender atau di luar rentang dibuang", async () => {
      assert.equal((await ask({ date: "2026-09-28" })).date, "2026-09-28");
      assert.equal((await ask({ date: "2026-09-30" })).date, "2026-09-30"); // besok (selisih zona) masih boleh
      for (const bad of ["2026-02-31", "28/09/2026", "2026-9-8", "2019-01-01", "2026-10-15", 20260928, null]) {
        assert.equal((await ask({ date: bad })).date, null, String(bad));
      }
    });

    it("sanitizeTotal dan sanitizeDate langsung", () => {
      assert.equal(sanitizeTotal(1), 1);
      assert.equal(sanitizeTotal(MAX_TOTAL), MAX_TOTAL);
      assert.equal(sanitizeTotal(MAX_TOTAL + 1), null);
      assert.equal(sanitizeDate("2024-02-29", now), "2024-02-29"); // kabisat
      assert.equal(sanitizeDate("2025-02-29", now), null);
    });
  });

  describe("batas harian", () => {
    it("429 daily_limit_exceeded setelah batas harian, hari berikutnya bebas lagi", async () => {
      const { deps, usage } = makeDeps({ dailyLimit: 2, monthlyLimit: 100 });
      for (let i = 0; i < 2; i++) {
        assert.equal((await handleExtract(post(valid), deps)).status, 200);
      }
      const blocked = await handleExtract(post(valid), deps);
      assert.equal(blocked.status, 429);
      assert.deepEqual(await blocked.json(), { error: "daily_limit_exceeded", limit: 2 });
      assert.equal(usage.get(dailyUsageKey(USER, deps.now())), 2);

      const tomorrow = { ...deps, now: () => new Date("2026-09-30T00:00:01Z") };
      assert.equal((await handleExtract(post(valid), tomorrow)).status, 200);
    });

    it("batas bulanan tetap berlaku dan diperiksa lebih dulu", async () => {
      const { deps } = makeDeps({ dailyLimit: 10, monthlyLimit: 1 });
      assert.equal((await handleExtract(post(valid), deps)).status, 200);
      const blocked = await handleExtract(post(valid), deps);
      assert.equal(blocked.status, 429);
      assert.equal(((await blocked.json()) as { error: string }).error, "quota_exceeded");
    });

    it("tanpa dailyLimit tidak ada kunci harian", async () => {
      const { deps, usage } = makeDeps();
      await handleExtract(post(valid), deps);
      assert.equal([...usage.keys()].some((k) => k.startsWith("usage-day:")), false);
    });

    it("kunci harian kedaluwarsa dalam 2 hari, kunci bulanan 35 hari", async () => {
      const ttls = new Map<string, number>();
      const { deps } = makeDeps({
        dailyLimit: 5,
        setUsage: async (k, _n, ttl) => void ttls.set(k, ttl),
      });
      await handleExtract(post(valid), deps);
      assert.equal(ttls.get(usageKey(USER, deps.now())), 35 * 24 * 3600);
      assert.equal(ttls.get(dailyUsageKey(USER, deps.now())), 2 * 24 * 3600);
    });
  });

  describe("pembatas per IP", () => {
    const withIp = (ip: string) =>
      new Request("https://w.example/extract", {
        method: "POST",
        headers: { "cf-connecting-ip": ip },
        body: JSON.stringify(valid),
      });

    it("IP ditolak -> 429 rate_limited tanpa menyentuh RevenueCat atau model", async () => {
      let entitlementCalls = 0;
      const { deps, calls } = makeDeps({
        allowIp: async () => false,
        hasUltimate: async () => {
          entitlementCalls++;
          return true;
        },
      });
      const res = await handleExtract(withIp("203.0.113.9"), deps);
      assert.equal(res.status, 429);
      assert.equal(((await res.json()) as { error: string }).error, "rate_limited");
      assert.equal(entitlementCalls, 0);
      assert.equal(calls.length, 0);
    });

    it("IP diizinkan diteruskan; tanpa header IP atau tanpa pembatas dilewati", async () => {
      const seen: string[] = [];
      const { deps } = makeDeps({
        allowIp: async (ip) => {
          seen.push(ip);
          return true;
        },
      });
      assert.equal((await handleExtract(withIp("203.0.113.9"), deps)).status, 200);
      assert.deepEqual(seen, ["203.0.113.9"]);
      assert.equal((await handleExtract(post(valid), deps)).status, 200); // tanpa header
      assert.deepEqual(seen, ["203.0.113.9"]);

      const { deps: noLimiter } = makeDeps();
      assert.equal((await handleExtract(withIp("203.0.113.9"), noLimiter)).status, 200);
    });
  });
});
