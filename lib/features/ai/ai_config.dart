/// URL Cloudflare Worker ekstraksi struk (lihat backend/receipt-extraction-worker/).
/// Diisi saat build: `--dart-define=AI_EXTRACTION_URL=https://.../extract`.
/// Kosong = fitur AI mati diam-diam (scan struk tetap jalan dengan heuristik).
const kAiExtractionUrl = String.fromEnvironment(
  'AI_EXTRACTION_URL',
  defaultValue: '',
);
