import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  NEGATIVE_TTL_SECONDS,
  POSITIVE_TTL_SECONDS,
  withEntitlementCache,
  type KvLike,
} from "../src/entitlement_cache.ts";

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

describe("withEntitlementCache", () => {
  it("hasil true disimpan 5 menit dan tidak memanggil RevenueCat lagi", async () => {
    const { kv, ttls } = memoryKv();
    let calls = 0;
    const check = withEntitlementCache(async () => {
      calls++;
      return true;
    }, kv);
    assert.equal(await check("u1"), true);
    assert.equal(await check("u1"), true);
    assert.equal(calls, 1);
    assert.equal(ttls.get("ent:u1"), POSITIVE_TTL_SECONDS);
  });

  it("hasil false disimpan lebih singkat (1 menit, batas minimal KV)", async () => {
    const { kv, ttls } = memoryKv();
    let calls = 0;
    const check = withEntitlementCache(async () => {
      calls++;
      return false;
    }, kv);
    assert.equal(await check("u1"), false);
    assert.equal(await check("u1"), false);
    assert.equal(calls, 1);
    assert.equal(ttls.get("ent:u1"), NEGATIVE_TTL_SECONDS);
    assert.ok(NEGATIVE_TTL_SECONDS >= 60);
  });

  it("galat pengecekan tidak di-cache dan diteruskan (handler menjawab 502)", async () => {
    const { kv, store } = memoryKv();
    let fail = true;
    const check = withEntitlementCache(async () => {
      if (fail) throw new Error("RevenueCat 500");
      return true;
    }, kv);
    await assert.rejects(() => check("u1"), /RevenueCat 500/);
    assert.equal(store.size, 0);
    fail = false;
    assert.equal(await check("u1"), true);
  });

  it("pengguna berbeda punya cache sendiri-sendiri", async () => {
    const { kv } = memoryKv();
    const check = withEntitlementCache(async (id) => id === "ultimate-user", kv);
    assert.equal(await check("ultimate-user"), true);
    assert.equal(await check("free-user"), false);
    assert.equal(await check("ultimate-user"), true);
  });
});
