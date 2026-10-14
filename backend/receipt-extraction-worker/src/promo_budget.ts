/**
 * Anggaran AI promo global: atap total biaya AI yang boleh dihabiskan pengguna
 * uji coba dalam satu bulan (docs/RENCANA-IMPLEMENTASI-TRIAL-ULTIMATE.md 10.1).
 * Kuota per pengguna membatasi satu trial; anggaran ini membatasi JUMLAH trial.
 *
 * Penghitung berupa perkiraan biaya dalam Rupiah di KV. KV tidak atomik, jadi
 * pada lalu lintas bersamaan bisa kurang menghitung sedikit; batas penegakan
 * sengaja dipasang di bawah plafon yang benar-benar direlakan.
 */

/** Perkiraan biaya per panggilan berhasil (Rupiah, dibulatkan ke atas). */
export const SCAN_COST_RP = 5; // terukur ≈ Rp4,6
export const REPORT_COST_RP = 30; // perkiraan, belum terukur

const MONTH_TTL_SECONDS = 35 * 24 * 3600;

export function promoBudgetKey(now: Date): string {
  const month = `${now.getUTCFullYear()}-${String(now.getUTCMonth() + 1).padStart(2, "0")}`;
  return `promo-cost:${month}`;
}

export interface PromoBudget {
  /** Batas penegakan (Rupiah/bulan). 0 atau kosong = habis (gagal aman). */
  capRp: number;
  used(now: Date): Promise<number>;
  add(now: Date, costRp: number): Promise<void>;
  exhausted(now: Date): Promise<boolean>;
}

export function makePromoBudget(
  capRp: number,
  getUsage: (key: string) => Promise<number>,
  setUsage: (key: string, count: number, ttlSeconds: number) => Promise<void>,
): PromoBudget {
  const cap = Number.isFinite(capRp) && capRp > 0 ? Math.floor(capRp) : 0;
  return {
    capRp: cap,
    used: (now) => getUsage(promoBudgetKey(now)),
    async add(now, costRp) {
      const key = promoBudgetKey(now);
      const used = await getUsage(key);
      await setUsage(key, used + Math.max(0, Math.ceil(costRp)), MONTH_TTL_SECONDS);
    },
    async exhausted(now) {
      return (await getUsage(promoBudgetKey(now))) >= cap;
    },
  };
}

/** Kebijakan kuota uji coba untuk satu endpoint AI. */
export interface TrialQuota {
  monthlyLimit: number;
  dailyLimit?: number;
  /** Perkiraan biaya satu panggilan berhasil, dicatat ke anggaran. */
  costRp: number;
  budget: PromoBudget;
}
