/// URL Cloudflare Worker ekstraksi struk (lihat backend/receipt-extraction-worker/).
/// Nilai bawaan = Worker produksi, supaya build rilis TIDAK bisa lupa
/// menyalakan fitur AI (build 7 pernah dibuat tanpa `--dart-define` sehingga AI
/// mati diam-diam). Untuk menunjuk Worker lain atau mematikan fitur:
/// `--dart-define=AI_EXTRACTION_URL=https://.../extract` (kosong = mati).
const kAiExtractionUrl = String.fromEnvironment(
  'AI_EXTRACTION_URL',
  defaultValue: 'https://dompetku-api.hardan-ti.com/extract',
);
