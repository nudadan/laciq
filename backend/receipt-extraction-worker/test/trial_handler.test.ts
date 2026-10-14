import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { handleExtract, type Deps } from "../src/handler.ts";
import {
  evaluateVerdict,
  parseIntegrityMode,
  type IntegrityVerdict,
} from "../src/integrity.ts";
import { makePromoBudget, promoBudgetKey, SCAN_COST_RP } from "../src/promo_budget.ts";
import { handleReportInsight, type ReportDeps } from "../src/report_handler.ts";
import { GrantIgnoredError, type EntitlementState } from "../src/revenuecat.ts";
import {
  handleTrialClaim,
  hmacHex,
  recordTtlSeconds,
  trialDayKey,
  trialKey,
  type TrialDeps,
} from "../src/trial_handler.ts";

const USER = "$RCAnonymousID:0123456789abcdef0123456789abcdef";
const USER2 = "$RCAnonymousID:fedcba9876543210fedcba9876543210";
const DEVICE = "99a02f40aeffec01";
const NOW = new Date("2026-10-14T04:00:00Z");
const DAY = 24 * 3600 * 1000;
const NONE: EntitlementState = { active: false, source: null, expiresAtMs: null };

function makeTrial(over: Partial<TrialDeps> = {}) {
  const kv = new Map<string, string>();
  const ttls = new Map<string, number>();
  const grants: { appUserId: string; endMs: number }[] = [];
  const invalidated: string[] = [];
  const budgetUsage = new Map<string, number>();
  const deps: TrialDeps = {
    enabled: true,
    days: 30,
    dailyClaimCap: 300,
    recordRetentionDays: 365,
    store: {
      get: async (k) => kv.get(k) ?? null,
      put: async (k, v, ttl) => {
        kv.set(k, v);
        if (ttl === undefined) ttls.delete(k);
        else ttls.set(k, ttl);
      },
    },
    hashDevice: (d) => hmacHex("rahasia-uji", d),
    getEntitlement: async () => NONE,
    grant: async (appUserId, endMs) => void grants.push({ appUserId, endMs }),
    invalidateEntitlement: async (id) => void invalidated.push(id),
    budget: makePromoBudget(
      1_350_000,
      async (k) => budgetUsage.get(k) ?? 0,
      async (k, n) => void budgetUsage.set(k, n),
    ),
    integrityMode: "off",
    now: () => NOW,
    ...over,
  };
  return { deps, kv, ttls, grants, invalidated, budgetUsage };
}

function claim(body: unknown, init: { method?: string; path?: string; ip?: string } = {}) {
  const method = init.method ?? "POST";
  return new Request(`https://w.example${init.path ?? "/trial/claim"}`, {
    method,
    headers: init.ip ? { "cf-connecting-ip": init.ip } : {},
    body: method === "POST" ? (typeof body === "string" ? body : JSON.stringify(body)) : undefined,
  });
}

const valid = { appUserId: USER, deviceId: DEVICE };

describe("handleTrialClaim: permintaan", () => {
  it("bukan POST /trial/claim ditolak", async () => {
    const { deps } = makeTrial();
    assert.equal((await handleTrialClaim(claim(valid, { method: "GET" }), deps)).status, 405);
    assert.equal((await handleTrialClaim(claim(valid, { path: "/x" }), deps)).status, 404);
  });

  it("badan tidak valid: 400 (JSON rusak, ID salah, pengenal perangkat salah)", async () => {
    const { deps } = makeTrial();
    for (const body of [
      "bukan json",
      { appUserId: "x", deviceId: DEVICE },
      { appUserId: USER, deviceId: "pendek" },
      { appUserId: USER, deviceId: "spasi dan simbol!!" },
      { appUserId: USER },
      { appUserId: USER, deviceId: DEVICE, integrityToken: 123 },
    ]) {
      const res = await handleTrialClaim(claim(body), deps);
      assert.equal(res.status, 400, JSON.stringify(body));
    }
  });

  it("pembatas IP menolak sebelum pekerjaan lain", async () => {
    const { deps, grants } = makeTrial({ allowIp: async () => false });
    const res = await handleTrialClaim(claim(valid, { ip: "1.2.3.4" }), deps);
    assert.equal(res.status, 429);
    assert.deepEqual(grants, []);
  });

  it("saklar mati: 503 trial_disabled tanpa menyentuh RevenueCat", async () => {
    const { deps, grants } = makeTrial({
      enabled: false,
      getEntitlement: async () => assert.fail("tidak boleh dipanggil"),
    });
    const res = await handleTrialClaim(claim(valid), deps);
    assert.equal(res.status, 503);
    assert.equal(((await res.json()) as { error: string }).error, "trial_disabled");
    assert.deepEqual(grants, []);
  });
});

describe("handleTrialClaim: klaim baru", () => {
  it("memberi trial 30 hari, mencatat perangkat (ber-hash), menghitung klaim harian, dan membuang cache", async () => {
    const { deps, kv, grants, invalidated } = makeTrial();
    const res = await handleTrialClaim(claim(valid), deps);
    assert.equal(res.status, 201);
    const body = (await res.json()) as { status: string; endsAt: string };
    assert.equal(body.status, "granted");
    const endMs = NOW.getTime() + 30 * DAY;
    assert.equal(body.endsAt, new Date(endMs).toISOString());
    assert.deepEqual(grants, [{ appUserId: USER, endMs }]);
    assert.deepEqual(invalidated, [USER]);

    const hash = await hmacHex("rahasia-uji", DEVICE);
    const record = JSON.parse(kv.get(trialKey(hash))!);
    assert.equal(record.endsAt, endMs);
    assert.equal(record.appUserId, USER);
    // pengenal perangkat mentah tidak pernah disimpan
    for (const [k, v] of kv) assert.ok(!k.includes(DEVICE) && !v.includes(DEVICE));
    assert.equal(kv.get(trialDayKey(NOW)), "1");
  });

  it("hash bergantung pada rahasia: rahasia lain menghasilkan kunci lain", async () => {
    assert.notEqual(await hmacHex("a", DEVICE), await hmacHex("b", DEVICE));
    assert.equal(await hmacHex("a", DEVICE), await hmacHex("a", DEVICE));
  });

  it("pelanggan Premium berbayar (entitlement ultimate belum aktif) boleh mendapat trial", async () => {
    const { deps, grants } = makeTrial({ getEntitlement: async () => NONE });
    assert.equal((await handleTrialClaim(claim(valid), deps)).status, 201);
    assert.equal(grants.length, 1);
  });

  it("pelanggan Ultimate berbayar ditolak: already_ultimate, tidak menghabiskan hak perangkat", async () => {
    const { deps, kv, grants } = makeTrial({
      getEntitlement: async () => ({ active: true, source: "store", expiresAtMs: null }),
    });
    const res = await handleTrialClaim(claim(valid), deps);
    assert.equal(res.status, 409);
    assert.equal(((await res.json()) as { error: string }).error, "already_ultimate");
    assert.deepEqual(grants, []);
    assert.equal(kv.size, 0);
  });

  it("hibah diabaikan RevenueCat: 502 grant_ignored dan hak perangkat TIDAK terpakai", async () => {
    const { deps, kv } = makeTrial({
      grant: async () => {
        throw new GrantIgnoredError("ultimate");
      },
    });
    const res = await handleTrialClaim(claim(valid), deps);
    assert.equal(res.status, 502);
    assert.equal(((await res.json()) as { error: string }).error, "grant_ignored");
    assert.equal(kv.size, 0);
  });

  it("hibah gagal (izin/jaringan): 502 grant_failed, hak perangkat tidak terpakai", async () => {
    const { deps, kv } = makeTrial({
      grant: async () => {
        throw new Error("RevenueCat grant ultimate 403");
      },
    });
    const res = await handleTrialClaim(claim(valid), deps);
    assert.equal(res.status, 502);
    assert.equal(((await res.json()) as { error: string }).error, "grant_failed");
    assert.equal(kv.size, 0);
  });

  it("pengecekan entitlement gagal: 502 entitlement_check_failed", async () => {
    const { deps } = makeTrial({
      getEntitlement: async () => {
        throw new Error("RevenueCat 500");
      },
    });
    assert.equal((await handleTrialClaim(claim(valid), deps)).status, 502);
  });
});

describe("handleTrialClaim: perangkat yang sama", () => {
  it("klaim ulang dengan ID yang sama saat hibah aktif: idempoten, tanpa hibah kedua", async () => {
    const first = makeTrial();
    await handleTrialClaim(claim(valid), first.deps);
    const endMs = NOW.getTime() + 30 * DAY;
    const again = makeTrial({
      store: first.deps.store,
      getEntitlement: async () => ({ active: true, source: "promo", expiresAtMs: endMs }),
    });
    const res = await handleTrialClaim(claim(valid), again.deps);
    assert.equal(res.status, 200);
    assert.equal(((await res.json()) as { status: string }).status, "active");
    assert.deepEqual(again.grants, []);
  });

  it("pasang ulang di masa trial (ID RevenueCat baru): mendapat SISA hari, bukan 30 hari baru", async () => {
    const first = makeTrial();
    await handleTrialClaim(claim(valid), first.deps);
    const endMs = NOW.getTime() + 30 * DAY;

    const later = new Date(NOW.getTime() + 10 * DAY);
    const reinstall = makeTrial({ store: first.deps.store, now: () => later });
    const res = await handleTrialClaim(claim({ appUserId: USER2, deviceId: DEVICE }), reinstall.deps);
    assert.equal(res.status, 200);
    const body = (await res.json()) as { status: string; endsAt: string };
    assert.equal(body.status, "resumed");
    assert.equal(body.endsAt, new Date(endMs).toISOString()); // tanggal akhir tidak bergeser
    assert.deepEqual(reinstall.grants, [{ appUserId: USER2, endMs }]);
    assert.deepEqual(reinstall.invalidated, [USER2]);

    // Catatan perangkat kini menunjuk ID yang baru.
    const hash = await hmacHex("rahasia-uji", DEVICE);
    const record = JSON.parse((await first.deps.store.get(trialKey(hash)))!);
    assert.equal(record.appUserId, USER2);
    assert.equal(record.endsAt, endMs);
  });

  it("setelah trial habis, pasang ulang + pulihkan backup TIDAK mendapat trial baru (already_used)", async () => {
    const first = makeTrial();
    await handleTrialClaim(claim(valid), first.deps);

    const afterEnd = new Date(NOW.getTime() + 31 * DAY);
    const reinstall = makeTrial({ store: first.deps.store, now: () => afterEnd });
    const res = await handleTrialClaim(claim({ appUserId: USER2, deviceId: DEVICE }), reinstall.deps);
    assert.equal(res.status, 409);
    const body = (await res.json()) as { error: string; endsAt: string };
    assert.equal(body.error, "already_used");
    assert.equal(body.endsAt, new Date(NOW.getTime() + 30 * DAY).toISOString());
    assert.deepEqual(reinstall.grants, []);
  });

  it("perangkat lain mendapat trial sendiri (perilaku yang diterima)", async () => {
    const first = makeTrial();
    await handleTrialClaim(claim(valid), first.deps);
    const other = makeTrial({ store: first.deps.store });
    const res = await handleTrialClaim(claim({ appUserId: USER2, deviceId: "ffffffffeeeeeeee" }), other.deps);
    assert.equal(res.status, 201);
  });

  it("hibah sudah aktif tetapi catatan perangkat hilang: dipulihkan dari kedaluwarsa hibah", async () => {
    const endMs = NOW.getTime() + 20 * DAY;
    const t = makeTrial({
      getEntitlement: async () => ({ active: true, source: "promo", expiresAtMs: endMs }),
    });
    const res = await handleTrialClaim(claim(valid), t.deps);
    assert.equal(res.status, 200);
    const hash = await hmacHex("rahasia-uji", DEVICE);
    assert.equal(JSON.parse(t.kv.get(trialKey(hash))!).endsAt, endMs);
    assert.deepEqual(t.grants, []);
  });
});

describe("handleTrialClaim: pagar global", () => {
  it("batas klaim harian tercapai: 429 trial_paused, hak perangkat tidak terpakai", async () => {
    const t = makeTrial({ dailyClaimCap: 2 });
    t.kv.set(trialDayKey(NOW), "2");
    const res = await handleTrialClaim(claim(valid), t.deps);
    assert.equal(res.status, 429);
    assert.equal(((await res.json()) as { error: string }).error, "trial_paused");
    assert.equal(t.kv.size, 1); // hanya penghitung harian lama
    assert.deepEqual(t.grants, []);
  });

  it("anggaran AI promo habis: 429 promo_budget_exhausted, hak perangkat tidak terpakai", async () => {
    const t = makeTrial();
    t.budgetUsage.set(promoBudgetKey(NOW), 1_350_000);
    const res = await handleTrialClaim(claim(valid), t.deps);
    assert.equal(res.status, 429);
    assert.equal(((await res.json()) as { error: string }).error, "promo_budget_exhausted");
    assert.deepEqual(t.grants, []);
    const hash = await hmacHex("rahasia-uji", DEVICE);
    assert.equal(t.kv.get(trialKey(hash)), undefined);
  });

  it("anggaran habis tidak menghalangi pasang ulang di masa trial (hak sudah ada)", async () => {
    const first = makeTrial();
    await handleTrialClaim(claim(valid), first.deps);
    const t = makeTrial({ store: first.deps.store });
    t.budgetUsage.set(promoBudgetKey(NOW), 9_999_999);
    const res = await handleTrialClaim(claim({ appUserId: USER2, deviceId: DEVICE }), t.deps);
    assert.equal(res.status, 200);
  });
});

describe("handleTrialClaim: Play Integrity", () => {
  const good: IntegrityVerdict = {
    appRecognition: "PLAY_RECOGNIZED",
    licensing: "LICENSED",
    deviceRecognition: ["MEETS_DEVICE_INTEGRITY"],
  };
  const withToken = { ...valid, integrityToken: "token" };

  it("mode bayangan tanpa pendekode: klaim tetap berhasil (hanya dicatat)", async () => {
    const t = makeTrial({ integrityMode: "shadow" });
    assert.equal((await handleTrialClaim(claim(valid), t.deps)).status, 201);
  });

  it("mode bayangan dengan vonis buruk: tetap berhasil", async () => {
    const t = makeTrial({
      integrityMode: "shadow",
      integrity: { verify: async () => ({ appRecognition: "UNRECOGNIZED_VERSION" }) },
    });
    assert.equal((await handleTrialClaim(claim(withToken), t.deps)).status, 201);
  });

  it("mode penegakan: vonis baik lolos, vonis buruk 403 tanpa menghabiskan hak perangkat", async () => {
    const ok = makeTrial({ integrityMode: "lenient", integrity: { verify: async () => good } });
    assert.equal((await handleTrialClaim(claim(withToken), ok.deps)).status, 201);

    const bad = makeTrial({
      integrityMode: "lenient",
      integrity: { verify: async () => ({ ...good, deviceRecognition: [] }) },
    });
    const res = await handleTrialClaim(claim(withToken), bad.deps);
    assert.equal(res.status, 403);
    assert.equal(((await res.json()) as { error: string }).error, "integrity_failed");
    assert.equal(bad.kv.size, 0);
    assert.deepEqual(bad.grants, []);
  });

  it("mode penegakan: token tidak ada atau tidak bisa diverifikasi ditolak; tanpa pendekode 503", async () => {
    const missing = makeTrial({ integrityMode: "strict", integrity: { verify: async () => good } });
    assert.equal((await handleTrialClaim(claim(valid), missing.deps)).status, 403);

    const broken = makeTrial({
      integrityMode: "strict",
      integrity: {
        verify: async () => {
          throw new Error("token tidak valid");
        },
      },
    });
    assert.equal((await handleTrialClaim(claim(withToken), broken.deps)).status, 403);

    const noVerifier = makeTrial({ integrityMode: "strict" });
    assert.equal((await handleTrialClaim(claim(withToken), noVerifier.deps)).status, 503);
  });
});

describe("evaluateVerdict", () => {
  const base: IntegrityVerdict = {
    appRecognition: "PLAY_RECOGNIZED",
    licensing: "LICENSED",
    deviceRecognition: ["MEETS_BASIC_INTEGRITY"],
  };

  it("longgar menerima BASIC, ketat butuh DEVICE atau STRONG", () => {
    assert.equal(evaluateVerdict(base, "lenient").ok, true);
    assert.deepEqual(evaluateVerdict(base, "strict"), { ok: false, reason: "device_integrity" });
    assert.equal(
      evaluateVerdict({ ...base, deviceRecognition: ["MEETS_STRONG_INTEGRITY"] }, "strict").ok,
      true,
    );
  });

  it("aplikasi tidak dikenali atau tidak berlisensi ditolak", () => {
    assert.deepEqual(evaluateVerdict({ ...base, appRecognition: "UNEVALUATED" }, "lenient"), {
      ok: false,
      reason: "app_not_recognized",
    });
    assert.deepEqual(evaluateVerdict({ ...base, licensing: "UNLICENSED" }, "lenient"), {
      ok: false,
      reason: "not_licensed",
    });
  });

  it("parseIntegrityMode: nilai tak dikenal = off", () => {
    assert.equal(parseIntegrityMode(undefined), "off");
    assert.equal(parseIntegrityMode("aneh"), "off");
    assert.equal(parseIntegrityMode("shadow"), "shadow");
    assert.equal(parseIntegrityMode("strict"), "strict");
  });
});

describe("makePromoBudget", () => {
  const mk = (cap: number) => {
    const usage = new Map<string, number>();
    return makePromoBudget(
      cap,
      async (k) => usage.get(k) ?? 0,
      async (k, n) => void usage.set(k, n),
    );
  };

  it("menambah dan menyatakan habis tepat di batas", async () => {
    const b = mk(10);
    assert.equal(await b.exhausted(NOW), false);
    await b.add(NOW, 5);
    await b.add(NOW, 5);
    assert.equal(await b.used(NOW), 10);
    assert.equal(await b.exhausted(NOW), true);
  });

  it("anggaran 0 atau tidak valid = habis (gagal aman)", async () => {
    assert.equal(await mk(0).exhausted(NOW), true);
    assert.equal(await mk(Number.NaN).exhausted(NOW), true);
  });

  it("bulan baru memakai penghitung baru", async () => {
    const b = mk(10);
    await b.add(NOW, 10);
    assert.equal(await b.exhausted(new Date("2026-11-01T00:00:00Z")), false);
  });
});

// ---- kuota uji coba di dua endpoint AI ----

function aiUsage() {
  const usage = new Map<string, number>();
  return {
    usage,
    getUsage: async (k: string) => usage.get(k) ?? 0,
    setUsage: async (k: string, n: number) => void usage.set(k, n),
  };
}

function trialQuota(over: { monthly?: number; daily?: number; cap?: number; used?: number } = {}) {
  const budgetUsage = new Map<string, number>();
  if (over.used !== undefined) budgetUsage.set(promoBudgetKey(NOW), over.used);
  const budget = makePromoBudget(
    over.cap ?? 1000,
    async (k) => budgetUsage.get(k) ?? 0,
    async (k, n) => void budgetUsage.set(k, n),
  );
  return {
    budgetUsage,
    quota: {
      monthlyLimit: over.monthly ?? 2,
      dailyLimit: over.daily ?? 0,
      costRp: SCAN_COST_RP,
      budget,
    },
  };
}

const PROMO: EntitlementState = { active: true, source: "promo", expiresAtMs: NOW.getTime() + DAY };
const PAID: EntitlementState = { active: true, source: "store", expiresAtMs: null };

function extractDeps(state: EntitlementState, trial?: ReturnType<typeof trialQuota>["quota"]): Deps {
  const u = aiUsage();
  return {
    hasUltimate: async () => state.active,
    getEntitlement: async () => state,
    trial,
    getUsage: u.getUsage,
    setUsage: u.setUsage,
    extract: async () => ({ merchant: "Toko", categoryId: "c1", total: 1000, date: null }),
    now: () => NOW,
    monthlyLimit: 300,
    dailyLimit: 15,
  };
}

const extractReq = () =>
  new Request("https://w.example/extract", {
    method: "POST",
    body: JSON.stringify({
      appUserId: USER,
      rawText: "TOTAL 1.000",
      categories: [{ id: "c1", name: "Makan" }],
    }),
  });

describe("kuota uji coba pada /extract", () => {
  it("pengguna uji coba memakai kuota uji coba dan menambah anggaran promo", async () => {
    const { quota, budgetUsage } = trialQuota({ monthly: 2 });
    const deps = extractDeps(PROMO, quota);
    for (let i = 0; i < 2; i++) assert.equal((await handleExtract(extractReq(), deps)).status, 200);
    const res = await handleExtract(extractReq(), deps);
    assert.equal(res.status, 429);
    assert.equal(((await res.json()) as { error: string; limit: number }).limit, 2);
    assert.equal(budgetUsage.get(promoBudgetKey(NOW)), 2 * SCAN_COST_RP);
  });

  it("sisa kuota di respons mengikuti batas uji coba", async () => {
    const { quota } = trialQuota({ monthly: 60 });
    const res = await handleExtract(extractReq(), extractDeps(PROMO, quota));
    assert.equal(((await res.json()) as { remaining: number }).remaining, 59);
  });

  it("pelanggan berbayar memakai kuota penuh dan tidak menyentuh anggaran promo", async () => {
    const { quota, budgetUsage } = trialQuota({ monthly: 2 });
    const deps = extractDeps(PAID, quota);
    for (let i = 0; i < 5; i++) assert.equal((await handleExtract(extractReq(), deps)).status, 200);
    assert.equal(budgetUsage.size, 0);
  });

  it("anggaran promo habis: 429 promo_budget_exhausted untuk uji coba, tidak untuk berbayar", async () => {
    const trial = trialQuota({ used: 1000, cap: 1000 });
    const res = await handleExtract(extractReq(), extractDeps(PROMO, trial.quota));
    assert.equal(res.status, 429);
    assert.equal(((await res.json()) as { error: string }).error, "promo_budget_exhausted");

    const paid = await handleExtract(extractReq(), extractDeps(PAID, trial.quota));
    assert.equal(paid.status, 200);
  });

  it("uji coba tanpa konfigurasi kuota uji coba: memakai kuota biasa (perilaku lama)", async () => {
    const res = await handleExtract(extractReq(), extractDeps(PROMO, undefined));
    assert.equal(res.status, 200);
  });
});

describe("kuota uji coba pada /report-insight", () => {
  const reportBody = {
    appUserId: USER,
    report: {
      month: "2026-10",
      daysElapsed: 14,
      daysInMonth: 31,
      income: 5_000_000,
      expense: 2_000_000,
      previousExpense: 1_500_000,
      projectedExpense: null,
      categories: [],
      budgets: [],
    },
  };
  const reportReq = () =>
    new Request("https://w.example/report-insight", {
      method: "POST",
      body: JSON.stringify(reportBody),
    });

  function reportDeps(state: EntitlementState, trial?: ReturnType<typeof trialQuota>["quota"]): ReportDeps {
    const u = aiUsage();
    return {
      hasUltimate: async () => state.active,
      getEntitlement: async () => state,
      trial,
      getUsage: u.getUsage,
      setUsage: u.setUsage,
      narrate: async () => "Ringkasan.",
      now: () => NOW,
      monthlyLimit: 30,
      dailyLimit: 5,
    };
  }

  it("batas ringkasan uji coba dan biaya Rp30 ke anggaran promo", async () => {
    const { quota, budgetUsage } = trialQuota({ monthly: 1 });
    quota.costRp = 30;
    const deps = reportDeps(PROMO, quota);
    assert.equal((await handleReportInsight(reportReq(), deps)).status, 200);
    assert.equal((await handleReportInsight(reportReq(), deps)).status, 429);
    assert.equal(budgetUsage.get(promoBudgetKey(NOW)), 30);
  });

  it("anggaran habis menolak ringkasan uji coba", async () => {
    const trial = trialQuota({ used: 5, cap: 5 });
    const res = await handleReportInsight(reportReq(), reportDeps(PROMO, trial.quota));
    assert.equal(res.status, 429);
    assert.equal(((await res.json()) as { error: string }).error, "promo_budget_exhausted");
  });
});

// ---- /trial/status ----

import { handleTrialStatus } from "../src/trial_handler.ts";

describe("handleTrialStatus", () => {
  const status = (body: unknown, init: { method?: string; ip?: string } = {}) =>
    new Request("https://w.example/trial/status", {
      method: init.method ?? "POST",
      headers: init.ip ? { "cf-connecting-ip": init.ip } : {},
      body: (init.method ?? "POST") === "POST" ? JSON.stringify(body) : undefined,
    });
  const stateOf = async (res: Response) => ((await res.json()) as { state: string }).state;

  it("tersedia untuk perangkat baru, tanpa efek samping", async () => {
    const t = makeTrial();
    const res = await handleTrialStatus(status(valid), t.deps);
    assert.equal(res.status, 200);
    assert.equal(await stateOf(res), "available");
    assert.equal(t.kv.size, 0);
    assert.deepEqual(t.grants, []);
  });

  it("saklar mati: disabled", async () => {
    const t = makeTrial({ enabled: false });
    assert.equal(await stateOf(await handleTrialStatus(status(valid), t.deps)), "disabled");
  });

  it("pelanggan Ultimate berbayar: ultimate; hibah aktif: active + endsAt", async () => {
    const paid = makeTrial({
      getEntitlement: async () => ({ active: true, source: "store", expiresAtMs: null }),
    });
    assert.equal(await stateOf(await handleTrialStatus(status(valid), paid.deps)), "ultimate");

    const end = NOW.getTime() + 5 * DAY;
    const promo = makeTrial({
      getEntitlement: async () => ({ active: true, source: "promo", expiresAtMs: end }),
    });
    const body = (await (await handleTrialStatus(status(valid), promo.deps)).json()) as {
      state: string;
      endsAt: string;
    };
    assert.equal(body.state, "active");
    assert.equal(body.endsAt, new Date(end).toISOString());
  });

  it("perangkat sudah memakai trial: used (pasang ulang setelah habis); masih berjalan: resumable", async () => {
    const first = makeTrial();
    await handleTrialClaim(claim(valid), first.deps);

    const reinstallDuring = makeTrial({
      store: first.deps.store,
      now: () => new Date(NOW.getTime() + 10 * DAY),
    });
    const during = (await (
      await handleTrialStatus(status({ appUserId: USER2, deviceId: DEVICE }), reinstallDuring.deps)
    ).json()) as { state: string; endsAt: string };
    assert.equal(during.state, "resumable");
    assert.equal(during.endsAt, new Date(NOW.getTime() + 30 * DAY).toISOString());

    const reinstallAfter = makeTrial({
      store: first.deps.store,
      now: () => new Date(NOW.getTime() + 31 * DAY),
    });
    assert.equal(
      await stateOf(await handleTrialStatus(status({ appUserId: USER2, deviceId: DEVICE }), reinstallAfter.deps)),
      "used",
    );
  });

  it("pagar global penuh: paused (tanpa menyentuh hak perangkat)", async () => {
    const t = makeTrial({ dailyClaimCap: 1 });
    t.kv.set(trialDayKey(NOW), "1");
    assert.equal(await stateOf(await handleTrialStatus(status(valid), t.deps)), "paused");

    const b = makeTrial();
    b.budgetUsage.set(promoBudgetKey(NOW), 1_350_000);
    assert.equal(await stateOf(await handleTrialStatus(status(valid), b.deps)), "paused");
  });

  it("permintaan salah: 400/405/404, pembatas IP: 429", async () => {
    const t = makeTrial();
    assert.equal((await handleTrialStatus(status({ appUserId: "x" }), t.deps)).status, 400);
    assert.equal((await handleTrialStatus(status(valid, { method: "GET" }), t.deps)).status, 405);
    assert.equal(
      (await handleTrialStatus(status(valid, { ip: "1.1.1.1" }), makeTrial({ allowIp: async () => false }).deps))
        .status,
      429,
    );
  });
});

// ---- masa simpan catatan perangkat (12 bulan setelah uji coba berakhir) ----

describe("masa simpan catatan perangkat", () => {
  const RETENTION = 365 * 24 * 3600;
  const TRIAL = 30 * 24 * 3600;

  it("recordTtlSeconds: sisa trial ditambah retensi, minimal 60 detik", () => {
    const now = NOW.getTime();
    assert.equal(recordTtlSeconds(now + 30 * DAY, now, 365), TRIAL + RETENTION);
    assert.equal(recordTtlSeconds(now + 5 * DAY, now, 365), 5 * 24 * 3600 + RETENTION);
    // Trial sudah berakhir: hanya retensi.
    assert.equal(recordTtlSeconds(now - DAY, now, 365), RETENTION);
    // Tanpa retensi dan sudah berakhir: dipotong ke batas minimal KV.
    assert.equal(recordTtlSeconds(now - DAY, now, 0), 60);
  });

  it("klaim baru: catatan perangkat berkedaluwarsa 365 hari setelah trial berakhir", async () => {
    const t = makeTrial();
    await handleTrialClaim(claim(valid), t.deps);
    const hash = await hmacHex("rahasia-uji", DEVICE);
    assert.equal(t.ttls.get(trialKey(hash)), TRIAL + RETENTION);
  });

  it("pasang ulang di masa trial: TTL dihitung dari akhir trial yang sama, tidak memanjang", async () => {
    const first = makeTrial();
    await handleTrialClaim(claim(valid), first.deps);

    const later = new Date(NOW.getTime() + 10 * DAY);
    const reinstall = makeTrial({ store: first.deps.store, now: () => later });
    await handleTrialClaim(claim({ appUserId: USER2, deviceId: DEVICE }), reinstall.deps);

    // Sisa 20 hari + 365 hari = tanggal habis yang SAMA seperti klaim awal (hari ke-30 + 365).
    const hash = await hmacHex("rahasia-uji", DEVICE);
    const expiryFirst = NOW.getTime() + 1000 * (TRIAL + RETENTION);
    const expiryResumed = later.getTime() + 1000 * first.ttls.get(trialKey(hash))!;
    assert.equal(expiryResumed, expiryFirst);
  });

  it("catatan yang hilang dipulihkan dengan TTL dari kedaluwarsa hibah", async () => {
    const endMs = NOW.getTime() + 20 * DAY;
    const t = makeTrial({
      getEntitlement: async () => ({ active: true, source: "promo", expiresAtMs: endMs }),
    });
    await handleTrialClaim(claim(valid), t.deps);
    const hash = await hmacHex("rahasia-uji", DEVICE);
    assert.equal(t.ttls.get(trialKey(hash)), 20 * 24 * 3600 + RETENTION);
  });

  it("retensi dapat diatur (mis. 24 bulan)", async () => {
    const t = makeTrial({ recordRetentionDays: 730 });
    await handleTrialClaim(claim(valid), t.deps);
    const hash = await hmacHex("rahasia-uji", DEVICE);
    assert.equal(t.ttls.get(trialKey(hash)), TRIAL + 730 * 24 * 3600);
  });

  it("setelah catatan kedaluwarsa, perangkat boleh mencoba lagi (win-back)", async () => {
    const first = makeTrial();
    await handleTrialClaim(claim(valid), first.deps);
    const hash = await hmacHex("rahasia-uji", DEVICE);

    // Simulasi kedaluwarsa KV: catatan hilang.
    first.kv.delete(trialKey(hash));
    const comeback = makeTrial({
      store: first.deps.store,
      now: () => new Date(NOW.getTime() + 400 * DAY),
    });
    const res = await handleTrialClaim(
      claim({ appUserId: USER2, deviceId: DEVICE }),
      comeback.deps,
    );
    assert.equal(res.status, 201);
    assert.equal(((await res.json()) as { status: string }).status, "granted");
  });
});
