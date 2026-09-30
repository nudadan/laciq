// Backup cloud (lib/features/cloud_backup/) pakai Google Drive milik
// pengguna sendiri (folder tersembunyi `appDataFolder`, pola sama WhatsApp)
// lewat Sign in with Google.
//
// Google Sign-In di Android divalidasi lewat package name + SHA-1
// sertifikat penandatanganan yang didaftarkan di Google Cloud Console
// (Google Drive API diaktifkan, OAuth consent screen, OAuth client ID tipe
// Android untuk keystore rilis DAN keystore debug). Tanpa itu terdaftar,
// `GoogleDriveCloudBackupService.signIn()` gagal dengan pesan jelas (lihat
// cloud_backup_service.dart), bukan crash.
//
// `kGoogleServerClientId` di bawah BUKAN untuk server kami (kami tidak
// punya server) — Android Credential Manager (dipakai google_sign_in v7)
// tetap mewajibkan satu client ID bertipe "Web application" sebagai
// "audience" permintaan kredensial, meski hanya dipakai untuk sign-in lokal
// di HP. Ini ID publik (bukan client secret), aman ditaruh di kode.
const kGoogleServerClientId =
    '979979579481-f1p8l6gu75gr32lo67ahajmk49cg7mfm.apps.googleusercontent.com';
