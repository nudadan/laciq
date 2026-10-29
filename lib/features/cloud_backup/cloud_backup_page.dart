import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/widgets.dart';
import '../../data/backup.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../dashboard/quick_start.dart';
import '../settings/restore_confirm.dart';
import '../transactions/receipt_storage.dart';
import 'cloud_backup_reminder_service.dart';
import 'cloud_backup_service.dart';

/// Nama file Drive untuk foto struk dari `Transactions.receiptPath` (format
/// relatif `receipts/<nama-file>`) — dipakai simetris saat unggah dan unduh.
String _receiptDriveName(String relativePath) =>
    'receipt_${relativePath.split('/').last}.enc';

class CloudBackupPage extends ConsumerStatefulWidget {
  const CloudBackupPage({super.key});

  @override
  ConsumerState<CloudBackupPage> createState() => _CloudBackupPageState();
}

class _CloudBackupPageState extends ConsumerState<CloudBackupPage> {
  bool _busy = false;
  bool _reminderEnabled = true;
  bool _includePhotos = true;
  int _reminderIntervalDays = CloudBackupReminderService.defaultIntervalDays;

  @override
  void initState() {
    super.initState();
    _loadReminderSettings();
  }

  Future<void> _loadReminderSettings() async {
    final service = ref.read(cloudBackupReminderServiceProvider);
    final enabled = await service.enabled();
    final interval = await service.intervalDays();
    final includePhotos = await ref
        .read(cloudBackupOptionsProvider)
        .includePhotos();
    if (mounted) {
      setState(() {
        _reminderEnabled = enabled;
        _reminderIntervalDays = interval;
        _includePhotos = includePhotos;
      });
    }
  }

  Future<void> _signIn() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(cloudBackupServiceProvider).signIn();
    } on CloudBackupCancelled {
      // Dibatalkan pengguna sendiri lewat dialog pemilihan akun.
    } on CloudBackupException catch (e) {
      notify(messenger, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _backupNow() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final db = ref.read(databaseProvider);
      final json = await BackupService(db).export();
      await ref.read(cloudBackupServiceProvider).uploadBackup(json);
      if (await ref.read(cloudBackupOptionsProvider).includePhotos()) {
        await _uploadReceiptPhotos(db);
      }
      ref.read(quickStartPrefsProvider.notifier).markBackupDone();
      if (mounted) setState(() {}); // refresh baris "terakhir backup"
      notify(messenger, 'Backup cloud tersimpan.');
    } on CloudBackupException catch (e) {
      notify(messenger, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Foto struk (fitur Premium) diunggah TERPISAH dari blob JSON utama, satu
  /// file per transaksi yang punya `receiptPath`. Kegagalan satu foto (mis.
  /// jaringan putus di tengah) tidak boleh menggagalkan backup JSON yang
  /// sudah berhasil — dilewati saja, dicoba lagi di backup berikutnya.
  Future<void> _uploadReceiptPhotos(AppDatabase db) async {
    final cloud = ref.read(cloudBackupServiceProvider);
    final transactions = await db.select(db.transactions).get();
    for (final tx in transactions) {
      final path = tx.receiptPath;
      if (path == null) continue;
      try {
        final file = File(await resolveReceiptPath(path));
        if (!await file.exists()) continue; // foto sudah hilang lokal
        await cloud.uploadFile(
          _receiptDriveName(path),
          await file.readAsBytes(),
        );
      } on CloudBackupException {
        continue;
      }
    }
  }

  Future<void> _restoreFromCloud() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final json = await ref.read(cloudBackupServiceProvider).downloadBackup();
      final data = BackupService.parse(json);
      if (mounted) {
        final restored = await confirmAndRestore(context, ref, data);
        if (restored &&
            await ref.read(cloudBackupOptionsProvider).includePhotos()) {
          await _downloadReceiptPhotos(data);
        }
      }
    } on CloudBackupException catch (e) {
      notify(messenger, e.message);
    } on BackupException catch (e) {
      notify(messenger, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Kebalikan [_uploadReceiptPhotos]: untuk tiap transaksi hasil restore yang
  /// punya `receiptPath`, unduh foto dari Drive dan tulis ke path yang SAMA
  /// secara lokal (path relatif tidak berubah antar perangkat, cuma filenya
  /// yang perlu ditulis ulang). Satu foto gagal diunduh tidak menggagalkan
  /// data keuangan yang sudah dipulihkan — dilewati, cuma foto itu yang hilang.
  Future<void> _downloadReceiptPhotos(BackupData data) async {
    final cloud = ref.read(cloudBackupServiceProvider);
    for (final tx in data.transactions) {
      final path = tx.receiptPath;
      if (path == null) continue;
      try {
        final bytes = await cloud.downloadFile(_receiptDriveName(path));
        if (bytes != null) await writeReceiptFile(path, bytes);
      } on CloudBackupException {
        continue;
      }
    }
  }

  Future<void> _signOut() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(cloudBackupServiceProvider).signOut();
    } on CloudBackupException catch (e) {
      notify(messenger, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(cloudSignedInProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Backup Cloud')),
      body: SafeArea(
        child: signedIn.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Terjadi kesalahan: $e')),
          data: (isSignedIn) => Padding(
            padding: const EdgeInsets.all(20),
            child: isSignedIn ? _signedInBody() : _signInBody(),
          ),
        ),
      ),
    );
  }

  Widget _signInBody() {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      children: [
        Text(
          'Simpan backup terenkripsi ke Google Drive-mu sendiri, bisa '
          'dipulihkan lagi kapan saja lewat akun Google yang sama di HP mana '
          'pun. Kami tidak pernah menyimpan salinannya.',
          style: textTheme.titleMedium,
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _busy ? null : _signIn,
          icon: const Icon(Icons.account_circle_rounded),
          label: const Text('Masuk dengan Google'),
        ),
      ],
    );
  }

  Widget _signedInBody() {
    final email = ref.read(cloudBackupServiceProvider).currentEmail ?? '-';
    return ListView(
      children: [
        Text('Masuk sebagai $email'),
        const SizedBox(height: 4),
        FutureBuilder<DateTime?>(
          future: ref.read(cloudBackupServiceProvider).lastBackupAt(),
          builder: (context, snapshot) {
            final at = snapshot.data;
            final text = at == null
                ? 'Terakhir backup: belum pernah'
                : 'Terakhir backup: '
                      '${DateFormat('d MMMM yyyy, HH:mm', 'id_ID').format(at)}';
            return Text(text, style: Theme.of(context).textTheme.bodyMedium);
          },
        ),
        const SizedBox(height: 20),
        Material(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: SwitchListTile(
            secondary: const Icon(Icons.notifications_active_rounded),
            title: const Text('Ingatkan saya backup berkala'),
            value: _reminderEnabled,
            onChanged: (v) async {
              setState(() => _reminderEnabled = v);
              await ref.read(cloudBackupReminderServiceProvider).setEnabled(v);
            },
          ),
        ),
        if (_reminderEnabled) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _reminderIntervalDays,
            decoration: const InputDecoration(labelText: 'Seberapa sering'),
            items: const [
              DropdownMenuItem(value: 7, child: Text('Mingguan')),
              DropdownMenuItem(value: 30, child: Text('Bulanan')),
            ],
            onChanged: (v) async {
              if (v == null) return;
              setState(() => _reminderIntervalDays = v);
              await ref
                  .read(cloudBackupReminderServiceProvider)
                  .setIntervalDays(v);
            },
          ),
        ],
        const SizedBox(height: 12),
        Material(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: SwitchListTile(
            secondary: const Icon(Icons.receipt_long_rounded),
            title: const Text('Sertakan foto struk'),
            subtitle: const Text(
              'Foto ikut dicadangkan terenkripsi ke Google Drive-mu dan '
              'kembali saat kamu memulihkan. Matikan bila foto tidak boleh '
              'keluar dari HP ini. Foto yang sudah terunggah tetap ada di '
              'Drive-mu sampai kamu menghapusnya.',
            ),
            value: _includePhotos,
            onChanged: (v) async {
              setState(() => _includePhotos = v);
              await ref.read(cloudBackupOptionsProvider).setIncludePhotos(v);
            },
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _busy ? null : _backupNow,
          icon: const Icon(Icons.cloud_upload_rounded),
          label: const Text('Backup sekarang'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _busy ? null : _restoreFromCloud,
          icon: const Icon(Icons.cloud_download_rounded),
          label: const Text('Pulihkan dari cloud'),
        ),
        const SizedBox(height: 20),
        Center(
          child: TextButton(
            onPressed: _busy ? null : _signOut,
            child: const Text('Keluar'),
          ),
        ),
      ],
    );
  }
}
