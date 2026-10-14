#!/usr/bin/env node
// Fase 0 rencana trial Ultimate (docs/RENCANA-IMPLEMENTASI-TRIAL-ULTIMATE.md, bagian 9).
// Menguji ke API RevenueCat v1 (server ke server) pada SATU ID pengguna uji:
//   butir 1  hibah promosional per entitlement dengan end_time_ms
//   butir 3  bentuk product_identifier entitlement promosional
//   butir 5  secret key punya izin menulis (hibah) -- kunci yang sama dengan Worker
// dan memastikan keputusan yang akan diambil Worker (`hasUltimate`) benar.
//
// Pakai (kunci HANYA lewat variabel lingkungan, jangan ditempel di chat atau commit):
//   REVENUECAT_SECRET_KEY=sk_... node rc_promo_check.mjs '<appUserId>' [opsi]
//
// Opsi:
//   --minutes N      lama hibah uji (bawaan 10; minimal 3)
//   --hold           berhenti setelah hibah agar Anda memeriksa di probe/HP, lanjut dengan Enter
//   --wait-expiry    tunggu sampai hibah kedaluwarsa lalu periksa lagi (butuh --minutes kecil, mis. 3)
//   --keep           jangan cabut hibah di akhir (bawaan: dicabut)
//   --revoke-only    hanya cabut hibah promosional ID ini lalu keluar
//
// Gunakan ID uji (mis. dari aplikasi probe), BUKAN ID pengguna sungguhan.

import readline from "node:readline/promises";

const API = "https://api.revenuecat.com/v1";
const ENTITLEMENTS = ["ultimate", "premium"]; // Ultimate memegang keduanya (revenuecat_config.dart)
const ULTIMATE = "ultimate";

const args = process.argv.slice(2);
const flag = (name) => args.includes(name);
const opt = (name, fallback) => {
  const i = args.indexOf(name);
  return i >= 0 && args[i + 1] ? args[i + 1] : fallback;
};
const appUserId = args.find((a) => !a.startsWith("--") && args[args.indexOf(a) - 1] !== "--minutes");
const minutes = Math.max(3, Number(opt("--minutes", "10")));
const key = process.env.REVENUECAT_SECRET_KEY;

function die(msg) {
  console.error(`\n✖ ${msg}`);
  process.exit(1);
}

if (!key) die("Set REVENUECAT_SECRET_KEY di lingkungan shell (kunci secret V1, bukan kunci publik goog_...).");
if (key.startsWith("goog_") || key.startsWith("appl_")) {
  die("Itu kunci PUBLIK SDK. Butuh kunci SECRET (sk_...) dari RevenueCat > Project settings > API keys.");
}
if (!appUserId) die("Beri appUserId sebagai argumen pertama.");
if (!/^[\w$.:\-@]{3,200}$/.test(appUserId)) die("Format appUserId tidak dikenali.");

const rc = async (method, path, body) => {
  const res = await fetch(`${API}${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${key}`,
      "Content-Type": "application/json",
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  let json = null;
  try {
    json = await res.json();
  } catch {
    // tubuh kosong
  }
  return { status: res.status, ok: res.ok, json };
};

const subscriberOf = (json) => json?.value?.subscriber ?? json?.subscriber ?? null;
const uid = encodeURIComponent(appUserId);
const results = [];
const record = (id, label, pass, detail) => results.push({ id, label, pass, detail });

function showEntitlements(sub, title) {
  console.log(`\n— ${title}`);
  const ents = sub?.entitlements ?? {};
  const names = Object.keys(ents);
  if (names.length === 0) console.log("  (tidak ada entitlement)");
  for (const n of names) {
    const e = ents[n];
    console.log(
      `  ${n}: product_identifier=${e.product_identifier} expires_date=${e.expires_date} purchase_date=${e.purchase_date}`,
    );
  }
  const subs = sub?.subscriptions ?? {};
  for (const [p, s] of Object.entries(subs)) {
    console.log(`  subscriptions[${p}]: store=${s.store} expires_date=${s.expires_date}`);
  }
}

// Sama persis dengan makeEntitlementChecker di backend/receipt-extraction-worker/src/revenuecat.ts.
function workerDecision(sub) {
  const ent = sub?.entitlements?.[ULTIMATE];
  if (!ent) return false;
  return ent.expires_date === null || new Date(ent.expires_date).getTime() > Date.now();
}

async function revokeAll() {
  for (const e of ENTITLEMENTS) {
    const r = await rc("POST", `/subscribers/${uid}/entitlements/${e}/revoke_promotionals`);
    console.log(
      `  cabut ${e}: HTTP ${r.status}` +
        (r.status === 404 ? " (tidak ada hibah aktif untuk dicabut)" : ""),
    );
  }
}

console.log(`ID uji: ${appUserId}`);
console.log(`Lama hibah: ${minutes} menit`);

if (flag("--revoke-only")) {
  await revokeAll();
  process.exit(0);
}

// 0. Baseline
const base = await rc("GET", `/subscribers/${uid}`);
if (base.status === 401 || base.status === 403) {
  die(`Baca pelanggan ditolak (HTTP ${base.status}). Kunci salah atau tidak berizin.`);
}
if (!base.ok) die(`Baca pelanggan gagal (HTTP ${base.status}).`);
showEntitlements(subscriberOf(base.json), "Sebelum hibah");
const priorPromo = Object.values(subscriberOf(base.json)?.entitlements ?? {}).some((e) =>
  e.product_identifier?.startsWith("rc_promo_"),
);
if (priorPromo) {
  console.log(
    "\n⚠ ID ini SUDAH pernah menerima hibah promosional. RevenueCat menganggap hibah baru dalam 2 jam dari hibah\n" +
      "  sebelumnya sebagai duplikat: API tetap menjawab 201 tetapi hibah TIDAK berlaku. Hasil uji ini tidak sahih;\n" +
      "  pakai ID baru (pasang ulang probe: run-probe.sh reinstall) atau tunggu lebih dari 2 jam.",
  );
}

// 1. Hibah dengan end_time_ms
const endMs = Date.now() + minutes * 60_000;
console.log(`\n— Hibah promosional (end_time_ms=${endMs}, ${new Date(endMs).toISOString()})`);
let grantOk = true;
let status5 = null;
for (const e of ENTITLEMENTS) {
  const r = await rc("POST", `/subscribers/${uid}/entitlements/${e}/promotional`, { end_time_ms: endMs });
  console.log(`  ${e}: HTTP ${r.status}`);
  if (r.status === 401 || r.status === 403) status5 = r.status;
  if (r.status !== 201 && r.status !== 200) {
    grantOk = false;
    console.log(`  tubuh: ${JSON.stringify(r.json)?.slice(0, 300)}`);
  }
}
record(
  5,
  "Kunci secret boleh menulis (hibah)",
  status5 === null && grantOk,
  status5 ? `HTTP ${status5}: buat kunci V1 dengan izin tulis` : grantOk ? "201" : "gagal selain 401/403 (lihat tubuh di atas)",
);
record(1, "Hibah dengan end_time_ms diterima", grantOk, grantOk ? "dua entitlement" : "gagal");

// 2. Baca ulang
const after = await rc("GET", `/subscribers/${uid}`);
const subAfter = subscriberOf(after.json);
showEntitlements(subAfter, "Sesudah hibah");

const ent = subAfter?.entitlements?.[ULTIMATE];
const entPremium = subAfter?.entitlements?.premium;
const diffMs = ent?.expires_date ? Math.abs(new Date(ent.expires_date).getTime() - endMs) : null;
record(1, "expires_date sesuai end_time_ms (±1 menit)", diffMs !== null && diffMs < 60_000, `selisih=${diffMs}ms`);
if (diffMs === null || diffMs >= 60_000) {
  console.log(
    "\n⚠ Hibah menjawab sukses tetapi expires_date TIDAK sesuai end_time_ms: hibah kemungkinan diabaikan sebagai duplikat.\n" +
      "  Pelajaran untuk Worker: jangan percaya HTTP 201; baca ulang entitlement dan pastikan expires_date benar.",
  );
}
record(3, "product_identifier berawalan rc_promo_", !!ent?.product_identifier?.startsWith("rc_promo_"), `nilai=${ent?.product_identifier}`);
record(1, "kedua entitlement (ultimate, premium) aktif", !!ent && !!entPremium, `ultimate=${!!ent} premium=${!!entPremium}`);
const decision = workerDecision(subAfter);
record("W", "Keputusan Worker (hasUltimate) = true", decision === true, `hasUltimate=${decision}`);

// 3. Perilaku hibah ulang (informasional)
const again = await rc("POST", `/subscribers/${uid}/entitlements/${ULTIMATE}/promotional`, { end_time_ms: endMs + 30 * 60_000 });
const afterAgain = subscriberOf((await rc("GET", `/subscribers/${uid}`)).json);
const exp2 = afterAgain?.entitlements?.[ULTIMATE]?.expires_date;
console.log(
  `\n— Hibah ulang +30 menit di atas hibah aktif: HTTP ${again.status}, expires_date sekarang=${exp2}` +
    `\n  (dokumentasi: end_time_ms dalam 2 jam dari hibah aktif dianggap duplikat dan tidak memperpanjang)`,
);
record("i", "Info: hibah ulang <2 jam", true, exp2 === ent?.expires_date ? "TIDAK memperpanjang (sesuai dokumentasi)" : "memperpanjang");

// 4. Titik jeda untuk butir 2 (perangkat)
if (flag("--hold")) {
  console.log(
    "\n— JEDA untuk butir 2: di probe/HP tekan 'Muat ulang' lalu lihat entitlement ultimate/premium:\n" +
      "  harus aktif dengan store=PROMOTIONAL dan tanggal kedaluwarsa yang sama.",
  );
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  await rl.question("Tekan Enter bila sudah dicatat... ");
  rl.close();
}

// 5. Menunggu kedaluwarsa
if (flag("--wait-expiry")) {
  const waitMs = endMs + 5_000 - Date.now();
  if (waitMs > 0) {
    console.log(`\nMenunggu ${Math.ceil(waitMs / 1000)} dtk sampai hibah kedaluwarsa...`);
    await new Promise((r) => setTimeout(r, waitMs));
  }
  // hibah ulang +30 menit tadi menggeser kedaluwarsa bila memperpanjang; periksa nilai sebenarnya
  const expired = subscriberOf((await rc("GET", `/subscribers/${uid}`)).json);
  showEntitlements(expired, "Setelah kedaluwarsa");
  const d = workerDecision(expired);
  record("E", "Keputusan Worker setelah kedaluwarsa = false", d === false, `hasUltimate=${d}`);
}

// 6. Bersihkan
if (!flag("--keep")) {
  console.log("\n— Mencabut hibah uji");
  await revokeAll();
  const cleaned = subscriberOf((await rc("GET", `/subscribers/${uid}`)).json);
  record("C", "Setelah dicabut Worker menganggap bukan Ultimate", workerDecision(cleaned) === false, `hasUltimate=${workerDecision(cleaned)}`);
} else {
  console.log("\n(--keep) hibah TIDAK dicabut; cabut nanti dengan --revoke-only.");
}

console.log("\n===== RINGKASAN =====");
for (const r of results) {
  console.log(`${r.pass ? "LULUS" : "GAGAL"}  [${r.id}] ${r.label}  — ${r.detail}`);
}
console.log(
  "\nButir 2 (CustomerInfo di aplikasi) dan 4 (ANDROID_ID) diuji di perangkat: lihat README.md.",
);
process.exit(results.some((r) => !r.pass && r.id !== "i") ? 2 : 0);
