#!/usr/bin/env bash
# Mengurus aplikasi probe Fase 0 (ANDROID_ID + entitlement RevenueCat). Jalankan dari Git Bash:
#
#   source /e/Developments/tools/dev-env.sh
#   export ADB_SERIAL=192.168.1.104:PORT      # port adb nirkabel terbaru; kosongkan bila hanya satu perangkat
#   bash tools/fase0-trial/run-probe.sh setup     # sekali: buat kerangka Android + flutter pub get
#   bash tools/fase0-trial/run-probe.sh build     # bangun APK debug dan tanda tangani dengan kunci khusus probe
#   bash tools/fase0-trial/run-probe.sh install   # pasang probe
#   bash tools/fase0-trial/run-probe.sh show      # buka probe, tampilkan ANDROID_ID, ID RevenueCat, entitlement
#   bash tools/fase0-trial/run-probe.sh reinstall # copot lalu pasang ulang, bandingkan dengan nilai sebelumnya
#   bash tools/fase0-trial/run-probe.sh remove    # copot probe dari perangkat
#
# Probe memakai paket SENDIRI (com.hardanti.fase0.fase0_probe) dan kunci tanda tangan SENDIRI, sehingga:
#  - tidak menyentuh data aplikasi LaciQ di perangkat,
#  - hasil ANDROID_ID mewakili pengguna sungguhan: tidak ada aplikasi lain dengan kunci yang sama
#    (kunci debug bersama akan membuat nilai tampak "bertahan" hanya karena LaciQ debug masih terpasang).

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROBE="$HERE/probe"
WORK="$PROBE/work"
PKG="com.hardanti.fase0.fase0_probe"
KS="$WORK/probe.keystore"
KS_PASS="fase0probe"   # kunci uji sekali pakai, bukan rahasia
SIGNED="$WORK/probe-signed.apk"
LAST="$WORK/last_android_id.txt"
CONFIG="$HERE/../../lib/features/subscription/revenuecat_config.dart"

adb_() {
  if [ -n "${ADB_SERIAL:-}" ]; then adb -s "$ADB_SERIAL" "$@"; else adb "$@"; fi
}

need() { command -v "$1" >/dev/null 2>&1 || { echo "✖ '$1' tidak ditemukan. Jalankan: source /e/Developments/tools/dev-env.sh"; exit 1; }; }

find_apksigner() {
  local sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-${LOCALAPPDATA:-}/Android/Sdk}}"
  local found
  found="$(ls -d "$sdk"/build-tools/*/apksigner* 2>/dev/null | sort -V | tail -1 || true)"
  [ -n "$found" ] || { echo "✖ apksigner tidak ditemukan di $sdk/build-tools (set ANDROID_HOME)"; exit 1; }
  echo "$found"
}

cmd_setup() {
  need flutter
  cd "$PROBE"
  mkdir -p "$WORK"
  if [ ! -d android ]; then
    flutter create --platforms=android --org com.hardanti.fase0 --project-name fase0_probe . >/dev/null
  fi
  # purchases_flutter butuh minSdk 24 (sama dengan aplikasi utama)
  for f in android/app/build.gradle.kts android/app/build.gradle; do
    [ -f "$f" ] && sed -i -E 's/minSdk(Version)? *=? *flutter\.minSdkVersion/minSdk = 24/' "$f"
  done
  # Sama dengan android/gradle.properties proyek utama: proyek di E:, cache di C: -> Kotlin incremental gagal.
  local gp=android/gradle.properties
  grep -q "^kotlin.incremental=false" "$gp" || printf '
kotlin.incremental=false
' >> "$gp"
  flutter pub get
  echo "✔ setup selesai"
}

cmd_build() {
  need flutter; need keytool
  cd "$PROBE"
  mkdir -p "$WORK"
  local key
  key="$(grep -E "kRevenueCatApiKey *=" "$CONFIG" | sed -E "s/.*'([^']+)'.*/\1/")"
  [ -n "$key" ] || { echo "✖ kRevenueCatApiKey tidak ditemukan di $CONFIG"; exit 1; }
  flutter build apk --debug --dart-define=RC_API_KEY="$key"
  if [ ! -f "$KS" ]; then
    keytool -genkeypair -keystore "$KS" -storepass "$KS_PASS" -keypass "$KS_PASS" \
      -alias probe -keyalg RSA -keysize 2048 -validity 3650 -dname "CN=fase0 probe" >/dev/null 2>&1
  fi
  local signer
  signer="$(find_apksigner)"
  "$signer" sign --ks "$KS" --ks-pass "pass:$KS_PASS" --key-pass "pass:$KS_PASS" \
    --out "$SIGNED" build/app/outputs/flutter-apk/app-debug.apk
  echo "✔ $SIGNED"
}

cmd_install() {
  need adb
  [ -f "$SIGNED" ] || { echo "✖ Belum ada APK; jalankan 'build' dulu."; exit 1; }
  adb_ install -r "$SIGNED"
}

# Membuka probe lalu membaca baris FASE0| dari logcat.
cmd_show() {
  need adb
  adb_ logcat -c
  adb_ shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
  echo "Menunggu probe memuat (8 dtk)..."
  sleep 8
  local out
  out="$(adb_ logcat -d | grep "FASE0|" || true)"
  echo "$out" | sed -E 's/^.*FASE0\|/  /'
  local id
  id="$(echo "$out" | grep -o 'ANDROID_ID=[0-9a-f]*' | tail -1 | cut -d= -f2 || true)"
  local rcid
  rcid="$(echo "$out" | grep -o 'APP_USER_ID=.*' | tail -1 | cut -d= -f2- || true)"
  mkdir -p "$WORK"
  if [ -n "$id" ]; then
    echo "$id" > "$WORK/current_android_id.txt"
    echo "$rcid" > "$WORK/current_app_user_id.txt"
    echo
    echo "ANDROID_ID      : $id"
    echo "ID RevenueCat   : ${rcid:-(belum terbaca)}"
  else
    echo "✖ ANDROID_ID belum terbaca; buka layar probe di perangkat lalu ulangi 'show'."
  fi
}

cmd_reinstall() {
  need adb
  [ -f "$SIGNED" ] || { echo "✖ Belum ada APK; jalankan 'build' dulu."; exit 1; }
  # Simpan nilai sebelum copot. Bila belum pernah 'show', ambil dulu.
  if [ ! -f "$WORK/current_android_id.txt" ]; then
    echo "Belum ada nilai awal; mengambilnya dulu..."
    cmd_show
  fi
  local before_id before_rc
  before_id="$(cat "$WORK/current_android_id.txt")"
  before_rc="$(cat "$WORK/current_app_user_id.txt" 2>/dev/null || true)"
  echo "$before_id" > "$LAST"
  echo
  echo "Mencopot $PKG (hanya probe; LaciQ tidak tersentuh)..."
  adb_ uninstall "$PKG" >/dev/null
  echo "Memasang ulang..."
  adb_ install "$SIGNED" >/dev/null
  cmd_show
  local after_id after_rc
  after_id="$(cat "$WORK/current_android_id.txt")"
  after_rc="$(cat "$WORK/current_app_user_id.txt" 2>/dev/null || true)"
  echo
  echo "===== HASIL (butir 4) ====="
  if [ "$before_id" = "$after_id" ]; then
    echo "LULUS  ANDROID_ID SAMA setelah pasang ulang ($after_id)"
  else
    echo "GAGAL  ANDROID_ID BERBEDA: sebelum=$before_id sesudah=$after_id"
    echo "       Kunci trial tidak boleh memakai ANDROID_ID; lihat alternatif L7 di dokumen rencana."
  fi
  if [ -n "$before_rc" ] && [ "$before_rc" != "$after_rc" ]; then
    echo "INFO   ID RevenueCat BERUBAH (sebelum=$before_rc sesudah=$after_rc): terbukti tidak bisa dipakai sebagai kunci."
  elif [ -n "$before_rc" ]; then
    echo "INFO   ID RevenueCat sama setelah pasang ulang (tidak terduga; periksa)."
  fi
}

cmd_remove() {
  need adb
  adb_ uninstall "$PKG" || true
}

case "${1:-}" in
  setup) cmd_setup ;;
  build) cmd_build ;;
  install) cmd_install ;;
  show) cmd_show ;;
  reinstall) cmd_reinstall ;;
  remove) cmd_remove ;;
  *) sed -n '2,17p' "$0"; exit 1 ;;
esac
