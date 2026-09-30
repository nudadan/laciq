import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/glass.dart';
import 'core/theme.dart' show buildTheme, systemBarsStyle;
import 'core/theme_mode.dart';
import 'core/widgets.dart';
import 'data/database.dart' show AgendaView;
import 'data/providers.dart';
import 'features/accounts/accounts_page.dart';
import 'features/ads/banner_ad_widget.dart';
import 'features/budget/budget_page.dart';
import 'features/dashboard/dashboard_page.dart';
import 'features/ledgers/ledgers_page.dart' show LedgerChip;
import 'features/more/more_page.dart';
import 'features/onboarding/onboarding_page.dart';
import 'features/onboarding/onboarding_providers.dart';
import 'features/security/lock_gate.dart';
import 'features/settings/settings_page.dart';
import 'features/transactions/transaction_form_page.dart';
import 'features/transactions/transactions_page.dart';

class DompetPintarApp extends ConsumerWidget {
  const DompetPintarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'DompetKu',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ref.watch(themeModeProvider),
      locale: const Locale('id', 'ID'),
      supportedLocales: const [Locale('id', 'ID')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Di atas Navigator: layar kunci menutup semua halaman dan dialog.
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: systemBarsStyle(Theme.of(context).brightness),
        child: LockGate(child: child ?? const SizedBox()),
      ),
      home: const _StartupGate(),
    );
  }
}

/// Onboarding sekali di instalasi baru, lalu langsung ke [HomeShell].
/// [LockGate] membungkus di atas ini (lewat `builder:` MaterialApp) — aman
/// karena instalasi baru belum punya PIN, jadi tidak pernah terkunci di sini.
class _StartupGate extends ConsumerWidget {
  const _StartupGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seen = ref.watch(onboardingControllerProvider);
    return seen.when(
      data: (done) => done ? const HomeShell() : const OnboardingPage(),
      loading: () => const ColoredBox(color: Colors.transparent),
      // Gagal baca flag: JANGAN blokir pemakaian aplikasi, ini bukan fitur
      // keamanan seperti PIN — anggap saja sudah dilihat.
      error: (_, _) => const HomeShell(),
    );
  }
}

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell>
    with WidgetsBindingObserver {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _generateRecurring();
    _checkBudgetNotifications();
    _checkBackupReminder();
    _recordFirstUse();
    _rescheduleReminders();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Aplikasi bisa terbuka berhari-hari di latar belakang: cek lagi saat kembali.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _generateRecurring();
      _checkBudgetNotifications();
      _checkBackupReminder();
      _recordFirstUse();
      _rescheduleReminders();
    } else if (state == AppLifecycleState.paused) {
      // Timer auto-hide SnackBar bisa "membeku" selama layar mati/app di
      // latar belakang (ticker-nya nonaktif), lalu baru lanjut menghitung
      // begitu app aktif lagi — hasilnya pesan lama (mis. "Transaksi
      // dihapus") masih nongkrong lama setelah dibuka ulang. Bersihkan saat
      // masuk ke latar belakang supaya tidak pernah muncul basi lagi.
      //
      // removeCurrentSnackBar() dipakai, BUKAN clearSnackBars(): clearSnackBars
      // memicu animasi keluar via ticker (hideCurrentSnackBar -> .reverse()),
      // yang justru bisa ikut macet karena ticker dinonaktifkan tepat saat
      // app berpindah ke paused — persis kondisi yang mau dihindari di sini.
      // removeCurrentSnackBar() men-set value controller langsung (bukan
      // lewat animasi berjalan), jadi selalu langsung hilang.
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
    }
  }

  /// Mencatat transaksi berulang yang sudah jatuh tempo. Idempoten.
  Future<void> _generateRecurring() async {
    try {
      final n = await ref.read(recurringGeneratorProvider)();
      if (n > 0 && mounted) {
        notify(ScaffoldMessenger.of(context), '$n transaksi berulang dicatat');
      }
    } catch (e) {
      debugPrint('Gagal mencatat transaksi berulang: $e');
    }
  }

  /// Memberi tahu (notifikasi sistem) kategori yang mendekati/melebihi
  /// anggaran bulan berjalan. Idempoten (dedup per kategori/bulan/ambang).
  Future<void> _checkBudgetNotifications() async {
    try {
      final db = ref.read(databaseProvider);
      final ultimate = await ref.read(isUltimateProvider.future);
      final ledgers = await db.watchLedgers().first;
      final locked = lockedLedgerIds(ledgers, ultimate: ultimate);
      // Nama buku hanya disebut di notifikasi bila ada lebih dari satu buku aktif.
      final usable = ledgers.where((l) => !locked.contains(l.id)).toList();
      await ref
          .read(budgetNotificationServiceProvider)
          .checkAndNotify(
            db,
            lockedLedgerIds: locked,
            ledgerNames: usable.length > 1
                ? {for (final l in usable) l.id: l.name}
                : const {},
          );
    } catch (e) {
      debugPrint('Gagal memeriksa notifikasi anggaran: $e');
    }
  }

  /// Mengingatkan pengguna yang sudah masuk Backup Cloud kalau backup
  /// terakhir sudah melewati interval pilihan mereka. Layanan sendiri yang
  /// men-throttle panggilan jaringan (maks 1x/hari) — aman dipanggil di
  /// setiap resume seperti pengecekan lain di sini.
  ///
  /// Pakai `cachedSignedIn()` (baca lokal murni), BUKAN `watchSignedIn()`
  /// atau provider yang membungkusnya — `watchSignedIn()` bisa memicu dialog
  /// "Login dengan Google" yang TERLIHAT (ditemukan langsung di HP: dialog
  /// itu muncul di Ringkasan, bukan cuma di halaman Backup Cloud, karena
  /// pengecekan ini jalan di SETIAP buka app). `cachedSignedIn()` tidak
  /// pernah menyentuh jaringan/akun sama sekali, jadi aman dipanggil di sini.
  Future<void> _checkBackupReminder() async {
    try {
      final signedIn = await ref
          .read(cloudBackupServiceProvider)
          .cachedSignedIn();
      if (!signedIn) return;
      await ref.read(cloudBackupReminderServiceProvider).checkAndNotify();
    } catch (e) {
      debugPrint('Gagal memeriksa pengingat backup cloud: $e');
    }
  }

  /// Mencatat waktu pemakaian pertama (untuk masa tenggang iklan 30 hari,
  /// idempoten) dan memaksa [shouldShowAdsProvider] dihitung ulang — perlu
  /// invalidate manual karena provider ini bukan stream.
  Future<void> _recordFirstUse() async {
    try {
      await ref.read(adEligibilityServiceProvider).recordFirstUseIfAbsent();
      ref.invalidate(shouldShowAdsProvider);
    } catch (e) {
      debugPrint('Gagal mencatat first-use iklan: $e');
    }
  }

  /// Menjadwalkan ulang notifikasi pengingat supaya selalu mengikuti jadwal
  /// terbaru. Agenda gratis (dibatasi `kFreeAgendaLimit` item, lihat
  /// `AgendaReminderService`) jadi jalan untuk SEMUA pengguna; pengingat
  /// transaksi berulang tetap murni premium seperti sebelumnya.
  Future<void> _rescheduleReminders() async {
    try {
      final premium = await ref.read(isPremiumProvider.future);
      final ultimate = await ref.read(isUltimateProvider.future);
      final db = ref.read(databaseProvider);
      await db.advancePastAgenda();
      // Pengingat bekerja lintas buku (bukan hanya buku aktif); buku terkunci
      // tidak mendapat pengingat. Nama buku disebut hanya bila ada >1 buku aktif.
      final ledgers = await db.watchLedgers().first;
      final locked = lockedLedgerIds(ledgers, ultimate: ultimate);
      final usable = ledgers.where((l) => !locked.contains(l.id)).toList();
      final names = usable.length > 1
          ? {for (final l in usable) l.id: l.name}
          : const <String, String>{};

      final agenda = (await db.watchAgendaReminders(ledgerId: null).first)
          .where((a) => !locked.contains(a.ledgerId));
      await ref
          .read(agendaReminderServiceProvider)
          .reschedule(
            agenda.map(AgendaView.new).toList(),
            premium: premium,
            ledgerNames: names,
          );

      if (!premium) return;
      final rules = (await db.watchRecurringRules(ledgerId: null).first)
          .where((r) => !locked.contains(r.account.ledgerId))
          .toList();
      await ref
          .read(recurringReminderServiceProvider)
          .reschedule(rules, ledgerNames: names);
    } catch (e) {
      debugPrint('Gagal menjadwalkan pengingat: $e');
    }
  }

  static const _titles = [
    'Ringkasan',
    'Transaksi',
    'Anggaran',
    'Dompet',
    'Lainnya',
  ];
  static const _pages = [
    DashboardPage(),
    TransactionsPage(),
    BudgetPage(),
    AccountsPage(),
    MorePage(),
  ];

  Future<void> _openForm(Widget page) async {
    final messenger = ScaffoldMessenger.of(context);
    final message = await Navigator.of(context)
        .push<String>(MaterialPageRoute(builder: (_) => page));
    if (message != null) notify(messenger, message);
  }

  @override
  Widget build(BuildContext context) {
    // Jaga stream Ultimate tetap hidup sejak awal sesi: form Catat membacanya
    // sekali (ref.read) saat scan struk, dan nilai pertama stream selalu false.
    ref.watch(isUltimateProvider);
    return AmbientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        appBar: AppBar(
          title: Text(_titles[_index]),
          actions: [
            const LedgerChip(),
            IconButton(
              tooltip: 'Pengaturan',
              icon: const Icon(Icons.tune_rounded),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: SafeArea(
          bottom: false,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            // Fade-through: halaman lama hilang di separuh pertama, baru
            // halaman baru muncul di separuh kedua (tidak tumpang-tindih).
            switchOutCurve: const Interval(0.5, 1.0),
            switchInCurve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, 0.02),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: KeyedSubtree(key: ValueKey(_index), child: _pages[_index]),
          ),
        ),
        floatingActionButton: GradientFab(
          icon: Icons.add_rounded,
          tooltip: 'Catat',
          onPressed: () => _openForm(const TransactionFormPage()),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const HomeAdSlot(),
                GlassBar(
                  child: NavigationBar(
                    selectedIndex: _index,
                    onDestinationSelected: (i) => setState(() => _index = i),
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.grid_view_rounded),
                        selectedIcon: Icon(Icons.grid_view_rounded),
                        label: 'Ringkasan',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.receipt_long_outlined),
                        selectedIcon: Icon(Icons.receipt_long_rounded),
                        label: 'Transaksi',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.donut_large_outlined),
                        selectedIcon: Icon(Icons.donut_large_rounded),
                        label: 'Anggaran',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.account_balance_wallet_outlined),
                        selectedIcon: Icon(
                          Icons.account_balance_wallet_rounded,
                        ),
                        label: 'Dompet',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.more_horiz_rounded),
                        selectedIcon: Icon(Icons.more_horiz_rounded),
                        label: 'Lainnya',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
