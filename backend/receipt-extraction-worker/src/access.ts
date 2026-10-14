import type { TrialQuota } from "./promo_budget.ts";
import type { EntitlementState } from "./revenuecat.ts";

/** Bagian Deps yang dibutuhkan untuk menentukan hak akses dan batas kuota. */
export interface AccessDeps {
  hasUltimate(appUserId: string): Promise<boolean>;
  /** Keadaan lengkap (sumber entitlement). Bila ada, dipakai menggantikan [hasUltimate]. */
  getEntitlement?(appUserId: string): Promise<EntitlementState>;
  /**
   * Kuota dan anggaran untuk pengguna uji coba (hibah promosional). Tanpa ini,
   * pengguna uji coba memakai kuota biasa (perilaku sebelum fitur trial).
   */
  trial?: TrialQuota;
  monthlyLimit: number;
  dailyLimit?: number;
}

export interface Access {
  active: boolean;
  /** Non-null bila pengguna sedang uji coba dan kuota uji coba berlaku. */
  trial: TrialQuota | null;
  monthlyLimit: number;
  dailyLimit?: number;
}

/** Melempar bila pengecekan entitlement gagal (pemanggil menjawab 502). */
export async function resolveAccess(deps: AccessDeps, appUserId: string): Promise<Access> {
  if (deps.getEntitlement) {
    const state = await deps.getEntitlement(appUserId);
    const trial = state.active && state.source === "promo" ? (deps.trial ?? null) : null;
    return {
      active: state.active,
      trial,
      monthlyLimit: trial ? trial.monthlyLimit : deps.monthlyLimit,
      dailyLimit: trial ? trial.dailyLimit : deps.dailyLimit,
    };
  }
  return {
    active: await deps.hasUltimate(appUserId),
    trial: null,
    monthlyLimit: deps.monthlyLimit,
    dailyLimit: deps.dailyLimit,
  };
}
