import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { handleExtract, usageKey, type Deps } from "../src/handler.ts";

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
      return { merchant: "Indomaret", categoryId: "cat-exp-makan" };
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
      extract: async () => ({ merchant: "  Toko X  ", categoryId: "cat-karangan" }),
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
});
