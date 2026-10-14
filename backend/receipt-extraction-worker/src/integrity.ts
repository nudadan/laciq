/**
 * Kebijakan vonis Play Integrity (docs/RENCANA-IMPLEMENTASI-TRIAL-ULTIMATE.md
 * 10.2, opsi B: mode bayangan). Modul ini hanya MENILAI vonis yang sudah
 * didekode; pendekodean token ke Google membutuhkan kredensial akun layanan dan
 * belum dipasang (verifier opsional di handler; tanpa verifier, mode `shadow`
 * hanya mencatat bahwa vonis tidak tersedia).
 */

export type IntegrityMode = "off" | "shadow" | "lenient" | "strict";

export interface IntegrityVerdict {
  /** `appIntegrity.appRecognitionVerdict`, mis. PLAY_RECOGNIZED. */
  appRecognition?: string;
  /** `deviceIntegrity.deviceRecognitionVerdict`, mis. ["MEETS_DEVICE_INTEGRITY"]. */
  deviceRecognition?: string[];
  /** `accountDetails.appLicensingVerdict`, mis. LICENSED. */
  licensing?: string;
}

/** Pendekode token (opsional): melempar bila token tidak valid/tidak bisa diverifikasi. */
export interface IntegrityVerifier {
  verify(token: string, context: { appUserId: string }): Promise<IntegrityVerdict>;
}

export function parseIntegrityMode(value: string | undefined): IntegrityMode {
  switch (value) {
    case "shadow":
    case "lenient":
    case "strict":
      return value;
    default:
      return "off";
  }
}

/** Mode yang benar-benar menolak klaim. */
export const isEnforcing = (mode: IntegrityMode): boolean => mode === "lenient" || mode === "strict";

const BASIC = ["MEETS_BASIC_INTEGRITY", "MEETS_DEVICE_INTEGRITY", "MEETS_STRONG_INTEGRITY"];
const DEVICE = ["MEETS_DEVICE_INTEGRITY", "MEETS_STRONG_INTEGRITY"];

/**
 * Menilai vonis menurut [mode]. `off`/`shadow` menilai dengan aturan `lenient`
 * (hasilnya hanya dicatat), supaya data bayangan menunjukkan berapa pengguna
 * yang AKAN ditolak bila penegakan dinyalakan.
 */
export function evaluateVerdict(
  verdict: IntegrityVerdict,
  mode: IntegrityMode,
): { ok: boolean; reason?: string } {
  const strict = mode === "strict";
  if (verdict.appRecognition !== "PLAY_RECOGNIZED") return { ok: false, reason: "app_not_recognized" };
  if (verdict.licensing !== "LICENSED") return { ok: false, reason: "not_licensed" };
  const devices = verdict.deviceRecognition ?? [];
  const required = strict ? DEVICE : BASIC;
  if (!devices.some((d) => required.includes(d))) return { ok: false, reason: "device_integrity" };
  return { ok: true };
}
