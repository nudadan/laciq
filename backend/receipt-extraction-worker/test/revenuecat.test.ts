import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  GrantIgnoredError,
  entitlementStateOf,
  makeEntitlementLookup,
  makeTrialGranter,
  type RcSubscriber,
} from "../src/revenuecat.ts";
import { withEntitlementStateCache, type KvLike } from "../src/entitlement_cache.ts";

const NOW = Date.parse("2026-10-14T04:00:00Z");
const FUTURE = "2026-11-13T04:00:00Z";
const PAST = "2026-10-14T03:00:00Z";

describe("entitlementStateOf", () => {
  it("tidak ada entitlement: tidak aktif", () => {
    assert.deepEqual(entitlementStateOf({}, "ultimate", NOW), {
      active: false,
      source: null,
      expiresAtMs: null,
    });
  });

  it("hibah promosional aktif: sumber promo, kedaluwarsa terbaca", () => {
    const sub: RcSubscriber = {
      entitlements: {
        ultimate: { expires_date: FUTURE, product_identifier: "rc_promo_ultimate_custom" },
      },
      subscriptions: { rc_promo_ultimate_custom: { store: "promotional", expires_date: FUTURE } },
    };
    assert.deepEqual(entitlementStateOf(sub, "ultimate", NOW), {
      active: true,
      source: "promo",
      expiresAtMs: Date.parse(FUTURE),
    });
  });

  it("hibah yang sudah dicabut/kedaluwarsa tetap tercantum tetapi tidak aktif", () => {
    const sub: RcSubscriber = {
      entitlements: {
        ultimate: { expires_date: PAST, product_identifier: "rc_promo_ultimate_custom" },
      },
    };
    const s = entitlementStateOf(sub, "ultimate", NOW);
    assert.equal(s.active, false);
    assert.equal(s.source, null);
  });

  it("langganan berbayar aktif: sumber store", () => {
    const sub: RcSubscriber = {
      entitlements: { ultimate: { expires_date: FUTURE, product_identifier: "dompetku_ultimate:monthly" } },
      subscriptions: { "dompetku_ultimate:monthly": { store: "play_store", expires_date: FUTURE } },
    };
    assert.equal(entitlementStateOf(sub, "ultimate", NOW).source, "store");
  });

  it("langganan berbayar DAN hibah berjalan bersamaan: dianggap berbayar (bukan kuota uji coba)", () => {
    const sub: RcSubscriber = {
      entitlements: {
        // entitlement menunjuk produk promo karena kedaluwarsanya lebih panjang
        ultimate: { expires_date: FUTURE, product_identifier: "rc_promo_ultimate_custom" },
      },
      subscriptions: {
        rc_promo_ultimate_custom: { store: "promotional", expires_date: FUTURE },
        "dompetku_premium:monthly": { store: "play_store", expires_date: "2026-10-20T00:00:00Z" },
      },
    };
    assert.equal(entitlementStateOf(sub, "ultimate", NOW).source, "store");
  });

  it("langganan berbayar yang sudah berakhir tidak membuat hibah dianggap berbayar", () => {
    const sub: RcSubscriber = {
      entitlements: {
        ultimate: { expires_date: FUTURE, product_identifier: "rc_promo_ultimate_custom" },
      },
      subscriptions: {
        rc_promo_ultimate_custom: { store: "promotional", expires_date: FUTURE },
        "dompetku_premium:monthly": { store: "play_store", expires_date: PAST },
      },
    };
    assert.equal(entitlementStateOf(sub, "ultimate", NOW).source, "promo");
  });

  it("entitlement tanpa batas waktu (seumur hidup): aktif sebagai store", () => {
    const sub: RcSubscriber = {
      entitlements: { ultimate: { expires_date: null, product_identifier: "lifetime" } },
    };
    assert.deepEqual(entitlementStateOf(sub, "ultimate", NOW), {
      active: true,
      source: "store",
      expiresAtMs: null,
    });
  });
});

function fakeRevenueCat(initial: RcSubscriber = {}) {
  const calls: { method: string; url: string; body?: unknown }[] = [];
  let subscriber: RcSubscriber = initial;
  let grantStatus = 201;
  let ignoreGrants = false;
  const doFetch = async (input: string, init?: RequestInit): Promise<Response> => {
    const method = init?.method ?? "GET";
    const body = init?.body ? JSON.parse(String(init.body)) : undefined;
    calls.push({ method, url: input, body });
    if (method === "POST") {
      if (grantStatus === 201 && !ignoreGrants) {
        const entitlement = decodeURIComponent(input.split("/entitlements/")[1].split("/")[0]);
        subscriber = {
          ...subscriber,
          entitlements: {
            ...subscriber.entitlements,
            [entitlement]: {
              expires_date: new Date(body.end_time_ms).toISOString(),
              product_identifier: `rc_promo_${entitlement}_custom`,
            },
          },
        };
      }
      return new Response("{}", { status: grantStatus });
    }
    return new Response(JSON.stringify({ subscriber }), { status: 200 });
  };
  return {
    doFetch,
    calls,
    setGrantStatus: (s: number) => (grantStatus = s),
    ignoreGrants: () => (ignoreGrants = true),
  };
}

describe("makeTrialGranter", () => {
  const END = Date.parse("2026-11-13T04:00:00Z");

  it("menghibahkan ultimate dan premium dengan end_time_ms lalu membaca ulang", async () => {
    const rc = fakeRevenueCat();
    await makeTrialGranter("sk_test", ["ultimate", "premium"], rc.doFetch)("u-1", END);
    const posts = rc.calls.filter((c) => c.method === "POST");
    assert.equal(posts.length, 2);
    assert.match(posts[0].url, /\/subscribers\/u-1\/entitlements\/ultimate\/promotional$/);
    assert.match(posts[1].url, /\/entitlements\/premium\/promotional$/);
    assert.deepEqual(posts[0].body, { end_time_ms: END });
    assert.equal(rc.calls.at(-1)?.method, "GET"); // pembacaan ulang
  });

  it("201 tetapi hibah diabaikan (duplikat): GrantIgnoredError", async () => {
    const rc = fakeRevenueCat({
      entitlements: {
        ultimate: { expires_date: "2026-10-14T03:46:52Z", product_identifier: "rc_promo_ultimate_custom" },
        premium: { expires_date: "2026-10-14T03:46:52Z", product_identifier: "rc_promo_premium_custom" },
      },
    });
    rc.ignoreGrants();
    await assert.rejects(
      makeTrialGranter("sk_test", ["ultimate", "premium"], rc.doFetch)("u-1", END),
      GrantIgnoredError,
    );
  });

  it("izin ditolak (403) melempar galat biasa, bukan GrantIgnoredError", async () => {
    const rc = fakeRevenueCat();
    rc.setGrantStatus(403);
    await assert.rejects(
      makeTrialGranter("sk_test", ["ultimate"], rc.doFetch)("u-1", END),
      (e: Error) => !(e instanceof GrantIgnoredError) && /403/.test(e.message),
    );
  });
});

describe("withEntitlementStateCache", () => {
  function memoryKv() {
    const store = new Map<string, string>();
    const ttls = new Map<string, number>();
    const kv: KvLike = {
      get: async (k) => store.get(k) ?? null,
      put: async (k, v, o) => {
        store.set(k, v);
        ttls.set(k, o.expirationTtl);
      },
    };
    return { kv, store, ttls };
  }

  it("menyimpan sumber dan kedaluwarsa; hibah promo di-cache 60 dtk, berbayar 300 dtk", async () => {
    const { kv, ttls } = memoryKv();
    let calls = 0;
    const promo = withEntitlementStateCache(async () => {
      calls++;
      return { active: true, source: "promo" as const, expiresAtMs: 1234 };
    }, kv);
    assert.deepEqual(await promo("p1"), { active: true, source: "promo", expiresAtMs: 1234 });
    assert.deepEqual(await promo("p1"), { active: true, source: "promo", expiresAtMs: 1234 });
    assert.equal(calls, 1);
    assert.equal(ttls.get("ent:p1"), 60);

    const paid = withEntitlementStateCache(
      async () => ({ active: true, source: "store" as const, expiresAtMs: null }),
      kv,
    );
    await paid("s1");
    assert.equal(ttls.get("ent:s1"), 300);
  });

  it("membaca format lama '1' sebagai berbayar dan '0' sebagai tidak aktif", async () => {
    const { kv, store } = memoryKv();
    store.set("ent:old", "1");
    store.set("ent:none", "0");
    const check = withEntitlementStateCache(async () => assert.fail("tidak boleh dipanggil"), kv);
    assert.deepEqual(await check("old"), { active: true, source: "store", expiresAtMs: null });
    assert.equal((await check("none")).active, false);
  });

  it("nilai cache rusak diabaikan dan dicari ulang", async () => {
    const { kv, store } = memoryKv();
    store.set("ent:x", "sampah");
    const check = withEntitlementStateCache(
      async () => ({ active: false, source: null, expiresAtMs: null }),
      kv,
    );
    assert.equal((await check("x")).active, false);
    assert.equal(store.get("ent:x"), "0");
  });
});

describe("makeEntitlementLookup", () => {
  it("memanggil RevenueCat dengan secret key dan mengembalikan keadaan", async () => {
    const rc = fakeRevenueCat({
      entitlements: { ultimate: { expires_date: FUTURE, product_identifier: "rc_promo_ultimate_custom" } },
    });
    const lookup = makeEntitlementLookup("sk_test", "ultimate", rc.doFetch, () => NOW);
    assert.equal((await lookup("u-1")).source, "promo");
    assert.match(rc.calls[0].url, /\/subscribers\/u-1$/);
  });
});
