import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/glass.dart';
import '../../core/money.dart';
import '../../core/theme_mode.dart';
import '../../data/backup.dart';
import '../../data/csv_export.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../cloud_backup/cloud_backup_page.dart';
import '../onboarding/onboarding_page.dart';
import '../onboarding/onboarding_providers.dart';
import '../security/lock_providers.dart';
import '../security/pin_screens.dart';
import '../subscription/trial_offer.dart';
import '../subscription/subscription_page.dart';
import '../subscription/subscription_plans.dart';
import '../subscription/trial_countdown.dart' show trialCountdownProvider;
import '../subscription/trial_service.dart' show TrialOffer;
import 'excel_export_flow.dart';
import 'restore_confirm.dart';
import 'share_file.dart';

const _maxBackupBytes = 20 * 1024 * 1024;

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lock = ref.watch(lockControllerProvider).value;
    final pinEnabled = lock?.pinEnabled ?? false;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            const _Section('Tampilan'),
            const _Group([_ThemePicker()]),
            const _Section('Langganan'),
            const _Group([_SubscriptionTile(), _TrialOfferTile()]),
            const _Section('Keamanan'),
            _Group([
              SwitchListTile(
                secondary: const Icon(Icons.lock_rounded),
                title: const Text('Kunci aplikasi dengan PIN'),
                subtitle: const Text(
                  'PIN 6 digit diminta saat aplikasi dibuka',
                ),
                value: pinEnabled,
                onChanged: (on) =>
                    on ? _enablePin(context) : _disablePin(context, ref),
              ),
              if (pinEnabled) ...[
                ListTile(
                  leading: const Icon(Icons.password_rounded),
                  title: const Text('Ubah PIN'),
                  onTap: () => _changePin(context),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.fingerprint_rounded),
                  title: const Text('Buka dengan sidik jari / wajah'),
                  value: lock?.biometricEnabled ?? false,
                  onChanged: (on) => _toggleBiometric(context, ref, on),
                ),
              ],
            ]),
            const _Section('Data'),
            _Group([
              ListTile(
                leading: const Icon(Icons.grid_on_rounded),
                title: const Text('Ekspor laporan (Excel)'),
                subtitle: Text(
                  (ref.watch(isPremiumProvider).value ?? false)
                      ? 'Ringkasan, transaksi, per kategori, per bulan, per dompet (.xlsx)'
                      : 'Fitur Premium',
                ),
                onTap: () => startExcelExport(context, ref),
              ),
              ListTile(
                leading: const Icon(Icons.table_chart_rounded),
                title: const Text('Ekspor transaksi (CSV)'),
                subtitle: const Text('Buka di Excel atau Google Sheets'),
                onTap: () => _exportCsv(context, ref),
              ),
              ListTile(
                leading: const Icon(Icons.backup_rounded),
                title: const Text('Backup data'),
                subtitle: const Text(
                  'Simpan seluruh data ke file. File tidak terenkripsi: simpan di tempat aman.',
                ),
                onTap: () => _backup(context, ref),
              ),
              ListTile(
                leading: const Icon(Icons.restore_rounded),
                title: const Text('Pulihkan dari backup'),
                subtitle: const Text('Mengganti seluruh data saat ini'),
                onTap: () => _restore(context, ref),
              ),
              const _CloudBackupTile(),
              ListTile(
                leading: Icon(
                  Icons.delete_forever_rounded,
                  color: scheme.error,
                ),
                title: Text(
                  'Hapus semua data',
                  style: TextStyle(color: scheme.error),
                ),
                subtitle: const Text(
                  'Reset total — seperti aplikasi baru dipasang',
                ),
                onTap: () => _eraseAllData(context, ref),
              ),
            ]),
            const _Section('Tentang'),
            _Group([
              const ListTile(
                leading: Icon(Icons.info_outline_rounded),
                title: Text('LaciQ'),
                subtitle: Text(
                  'Data tersimpan di perangkat ini. Bila ganti HP atau menghapus '
                  'aplikasi, data hilang kecuali kamu sudah membuat backup.',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.explore_outlined),
                title: const Text('Lihat panduan lagi'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const OnboardingPage(standalone: true),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.star_outline_rounded),
                title: const Text('Beri nilai LaciQ'),
                subtitle: const Text('Buka halaman aplikasi di Play Store'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () =>
                    ref.read(reviewPromptServiceProvider).openStoreListing(),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------ keamanan

  Future<void> _enablePin(BuildContext context) async {
    await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => const PinSetupPage()));
  }

  Future<void> _disablePin(BuildContext context, WidgetRef ref) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            const PinVerifyPage(title: 'Masukkan PIN untuk menonaktifkan'),
      ),
    );
    if (ok == true) {
      await ref.read(lockControllerProvider.notifier).disablePin();
    }
  }

  Future<void> _changePin(BuildContext context) async {
    final navigator = Navigator.of(context);
    final ok = await navigator.push<bool>(
      MaterialPageRoute(
        builder: (_) => const PinVerifyPage(title: 'Masukkan PIN saat ini'),
      ),
    );
    if (ok == true) {
      await navigator.push<bool>(
        MaterialPageRoute(
          builder: (_) => const PinSetupPage(title: 'PIN Baru'),
        ),
      );
    }
  }

  Future<void> _toggleBiometric(
    BuildContext context,
    WidgetRef ref,
    bool on,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(lockControllerProvider.notifier);
    if (!on) return controller.setBiometric(false);

    final bio = ref.read(biometricProvider);
    if (!await bio.isAvailable()) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Belum ada sidik jari atau wajah terdaftar di perangkat ini.',
          ),
        ),
      );
      return;
    }
    // Konfirmasi dulu agar pengaturan ini tidak bisa diaktifkan sembarang orang.
    if (await bio.authenticate('Konfirmasi untuk mengaktifkan')) {
      await controller.setBiometric(true);
    }
  }

  // ---------------------------------------------------------------- data

  Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final db = ref.read(databaseProvider);
    final month = ref.read(selectedMonthProvider);
    // Ekspor mengikuti buku kas yang sedang aktif (tidak mencampur semua buku).
    final ledgerId = ref.read(activeLedgerIdProvider);
    final monthLabel = DateFormat('MMMM yyyy', 'id_ID').format(month);

    final scope = await showDialog<_CsvScope>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Ekspor transaksi'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, _CsvScope.month),
            child: Text('Bulan $monthLabel'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, _CsvScope.all),
            child: const Text('Seluruh riwayat'),
          ),
        ],
      ),
    );
    if (scope == null) return;

    try {
      final items = scope == _CsvScope.month
          ? await db.getTransactions(
              from: AppDatabase.monthStart(month),
              to: AppDatabase.monthEnd(month),
              ledgerId: ledgerId,
            )
          : await db.getTransactions(ledgerId: ledgerId);
      if (items.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Tidak ada transaksi untuk diekspor.')),
        );
        return;
      }
      final suffix = scope == _CsvScope.month
          ? DateFormat('yyyy-MM').format(month)
          : 'semua';
      await shareTextFile(
        fileName: 'laciq-transaksi-$suffix.csv',
        content: buildTransactionsCsv(items),
        mimeType: 'text/csv',
        subject: 'Transaksi LaciQ',
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Ekspor gagal: $e')));
    }
  }

  Future<void> _backup(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final json = await BackupService(ref.read(databaseProvider)).export();
      await shareTextFile(
        fileName:
            'laciq-backup-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.json',
        content: json,
        mimeType: 'application/json',
        subject: 'Backup LaciQ',
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Backup gagal: $e')));
    }
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    void say(String m) => messenger.showSnackBar(SnackBar(content: Text(m)));

    final BackupData data;
    try {
      final file = await FilePicker.pickFile(dialogTitle: 'Pilih file backup');
      if (file == null) return;
      final size = await file.length();
      if (size != null && size > _maxBackupBytes) {
        say('File terlalu besar untuk sebuah backup.');
        return;
      }
      var text = utf8.decode(await file.readAsBytes());
      if (text.startsWith('﻿')) text = text.substring(1);
      data = BackupService.parse(text);
    } on BackupException catch (e) {
      say(e.message);
      return;
    } on FormatException {
      say('File bukan backup LaciQ yang valid.');
      return;
    } catch (e) {
      say('Tidak dapat membaca file: $e');
      return;
    }

    if (!context.mounted) return;
    await confirmAndRestore(context, ref, data);
  }

  /// Reset total: data keuangan DAN PIN/biometrik/tema/status onboarding.
  /// Kalau PIN aktif, minta verifikasi dulu — pola sama dengan
  /// `_disablePin`/`_changePin` untuk tindakan sensitif lainnya.
  Future<void> _eraseAllData(BuildContext context, WidgetRef ref) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final pinEnabled =
        ref.read(lockControllerProvider).value?.pinEnabled ?? false;
    if (pinEnabled) {
      final ok = await navigator.push<bool>(
        MaterialPageRoute(
          builder: (_) =>
              const PinVerifyPage(title: 'Masukkan PIN untuk menghapus data'),
        ),
      );
      if (ok != true) return;
    }

    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: const Text('Hapus semua data?'),
        content: const Text(
          'Seluruh transaksi, dompet, kategori, anggaran, target, dan tag akan '
          'dihapus PERMANEN. PIN, sidik jari, dan tema juga dicabut — aplikasi '
          'kembali seperti baru dipasang.\n\n'
          'Tindakan ini TIDAK BISA dibatalkan. Buat backup dulu lewat '
          '"Backup data" kalau kamu ingin menyimpannya.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus Semua'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(databaseProvider).eraseAllData();
      await ref.read(keyValueStoreProvider).clearAll();
      await _deleteReceiptPhotos();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal menghapus data: $e')),
      );
      return;
    }

    // Provider-provider ini baca KeyValueStore langsung di build()-nya
    // (bukan lewat databaseProvider), jadi harus di-invalidate agar tahu
    // store-nya baru saja dikosongkan.
    ref.invalidate(lockControllerProvider);
    ref.invalidate(themeModeProvider);
    ref.invalidate(onboardingControllerProvider);
    // _StartupGate (lib/app.dart) akan menampilkan OnboardingPage lagi begitu
    // onboardingControllerProvider selesai dibaca ulang (kosong = belum lihat).
    navigator.popUntil((r) => r.isFirst);
  }
}

Future<void> _deleteReceiptPhotos() async {
  try {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/receipts');
    if (await dir.exists()) await dir.delete(recursive: true);
  } catch (_) {
    // Tidak ada folder/akses (mis. lingkungan uji) — data utama sudah terhapus.
  }
}

enum _CsvScope { month, all }

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(6, 22, 6, 8),
    child: Text(
      title.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        letterSpacing: 1.2,
      ),
    ),
  );
}

/// Sekelompok baris pengaturan dalam satu kartu kaca, dipisah garis tipis.
class _Group extends StatelessWidget {
  const _Group(this.children);

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final divider = Divider(
      height: 1,
      indent: 60,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
    return GlassCard(
      padding: EdgeInsets.zero,
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) divider,
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Baris penawaran uji coba Ultimate (hanya bila perangkat layak). Selain di sini,
/// penawaran muncul di Dashboard dan saat pengguna menyentuh fitur terkunci.
class _TrialOfferTile extends ConsumerWidget {
  const _TrialOfferTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countdown = ref.watch(trialCountdownProvider).value;
    if (countdown != null && countdown.running) {
      return ListTile(
        leading: const Icon(Icons.hourglass_bottom_rounded),
        title: Text('Uji coba Ultimate: ${countdown.daysLeft} hari lagi'),
        subtitle: const Text('Semua fitur Premium dan Ultimate terbuka.'),
      );
    }
    final status = ref.watch(trialStatusProvider).value;
    if (status == null || !status.canStart) return const SizedBox.shrink();
    return ListTile(
      leading: const Icon(Icons.workspace_premium_rounded),
      title: Text(
        status.offer == TrialOffer.resumable
            ? 'Lanjutkan uji coba Ultimate'
            : 'Coba Ultimate gratis 30 hari',
      ),
      subtitle: const Text('Tanpa kartu. Semua fitur Premium dan Ultimate.'),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => showTrialOfferSheet(
        context,
        ref,
        status: status,
        upgradeOnly: ref.read(subscriptionTierProvider) == ActiveTier.premium,
      ),
    );
  }
}

class _SubscriptionTile extends ConsumerWidget {
  const _SubscriptionTile();

  static final _manageSubsUrl = Uri.parse(
    'https://play.google.com/store/account/subscriptions',
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tier = ref.watch(subscriptionTierProvider);
    // Ajakan upgrade hanya bila paket Ultimate benar-benar ada di toko.
    final ultimateOnSale = ref.watch(ultimateAvailableProvider).value ?? false;
    void openPage({bool upgradeOnly = false}) => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SubscriptionPage(upgradeOnly: upgradeOnly),
      ),
    );

    switch (tier) {
      case ActiveTier.ultimate:
        return _ActiveSubscriptionTile(
          title: 'LaciQ Ultimate aktif',
          subtitle: 'Tanpa iklan · Ekstraksi struk AI · Multi buku kas',
          onManage: () => launchUrl(_manageSubsUrl),
        );
      case ActiveTier.premium:
        return _ActiveSubscriptionTile(
          title: 'LaciQ Premium aktif',
          subtitle: ultimateOnSale
              ? 'Tanpa iklan · Upgrade ke Ultimate untuk AI, multi buku kas, dan tabungan'
              : 'Tanpa iklan',
          onUpgrade: ultimateOnSale ? () => openPage(upgradeOnly: true) : null,
          onManage: () => launchUrl(_manageSubsUrl),
        );
      case ActiveTier.free:
        return ListTile(
          leading: const Icon(Icons.star_rounded),
          title: const Text('Upgrade ke Premium'),
          subtitle: Text(
            'Hilangkan iklan mulai ${rupiah(kReferencePrices[(SubscriptionTier.premium, SubscriptionPeriod.monthly)]!)}/bulan',
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: openPage,
        );
    }
  }
}

/// Kartu langganan aktif: judul dan keterangan memakai lebar penuh, tombol
/// berada di baris sendiri di bawahnya. (Tombol sebagai `trailing` ListTile
/// menyempitkan judul sampai terpotong per huruf di layar sempit.)
class _ActiveSubscriptionTile extends StatelessWidget {
  const _ActiveSubscriptionTile({
    required this.title,
    required this.subtitle,
    required this.onManage,
    this.onUpgrade,
  });

  final String title;
  final String subtitle;
  final VoidCallback onManage;
  final VoidCallback? onUpgrade;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.workspace_premium_rounded, color: scheme.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 8,
              children: [
                if (onUpgrade != null)
                  FilledButton.tonal(
                    onPressed: onUpgrade,
                    child: const Text('Upgrade'),
                  ),
                TextButton(onPressed: onManage, child: const Text('Kelola')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CloudBackupTile extends ConsumerWidget {
  const _CloudBackupTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final premium = ref.watch(isPremiumProvider).value ?? false;
    if (!premium) {
      return ListTile(
        leading: const Icon(Icons.cloud_upload_rounded),
        title: const Text('Backup cloud terenkripsi'),
        subtitle: const Text('Fitur Premium'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => openUpgradeOrTrial(context, ref),
      );
    }
    return ListTile(
      leading: const Icon(Icons.cloud_upload_rounded),
      title: const Text('Backup cloud terenkripsi'),
      subtitle: const Text('Simpan otomatis lewat akun emailmu'),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const CloudBackupPage())),
    );
  }
}

class _ThemePicker extends ConsumerWidget {
  const _ThemePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return Padding(
      padding: const EdgeInsets.all(14),
      child: SegmentedButton<ThemeMode>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
            value: ThemeMode.system,
            icon: Icon(Icons.brightness_auto_rounded, size: 18),
            label: Text('Sistem'),
          ),
          ButtonSegment(
            value: ThemeMode.light,
            icon: Icon(Icons.light_mode_rounded, size: 18),
            label: Text('Terang'),
          ),
          ButtonSegment(
            value: ThemeMode.dark,
            icon: Icon(Icons.dark_mode_rounded, size: 18),
            label: Text('Gelap'),
          ),
        ],
        selected: {mode},
        onSelectionChanged: (s) =>
            ref.read(themeModeProvider.notifier).set(s.first),
      ),
    );
  }
}
