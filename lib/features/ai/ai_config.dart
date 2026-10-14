/// URL Cloudflare Worker ekstraksi struk (lihat backend/receipt-extraction-worker/).
/// Nilai bawaan = Worker produksi, supaya build rilis TIDAK bisa lupa
/// menyalakan fitur AI (build 7 pernah dibuat tanpa `--dart-define` sehingga AI
/// mati diam-diam). Untuk menunjuk Worker lain atau mematikan fitur:
/// `--dart-define=AI_EXTRACTION_URL=https://.../extract` (kosong = mati).
const kAiExtractionUrl = String.fromEnvironment(
  'AI_EXTRACTION_URL',
  defaultValue: 'https://dompetku-api.hardan-ti.com/extract',
);

/// Alamat ringkasan laporan AI di Worker yang sama (`/extract` -> `/report-insight`).
/// Kosong bila `AI_EXTRACTION_URL` dikosongkan atau tidak berakhiran `/extract`.
String aiReportUrlFrom(String extractionUrl) =>
    extractionUrl.endsWith('/extract')
    ? '${extractionUrl.substring(0, extractionUrl.length - '/extract'.length)}/report-insight'
    : '';

final kAiReportUrl = aiReportUrlFrom(kAiExtractionUrl);

/// Alamat uji coba Ultimate di Worker yang sama (`/extract` -> `/trial/claim`
/// dan `/trial/status`). Kosong bila `AI_EXTRACTION_URL` dikosongkan atau tidak
/// berakhiran `/extract`: tanpa Worker, penawaran uji coba tidak ditampilkan.
String workerUrlFrom(String extractionUrl, String path) =>
    extractionUrl.endsWith('/extract')
    ? '${extractionUrl.substring(0, extractionUrl.length - '/extract'.length)}$path'
    : '';

final kTrialClaimUrl = workerUrlFrom(kAiExtractionUrl, '/trial/claim');
final kTrialStatusUrl = workerUrlFrom(kAiExtractionUrl, '/trial/status');
