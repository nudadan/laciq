import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/glass.dart';
import '../../core/theme.dart';
import 'onboarding_providers.dart';

/// Paket yang membuka sebuah fitur; null = tersedia di semua paket.
enum _Plan {
  premium('Premium'),
  ultimate('Ultimate');

  const _Plan(this.label);
  final String label;
}

class _Feature {
  const _Feature(this.icon, this.title, this.body, [this.plan]);
  final IconData icon;
  final String title;
  final String body;
  final _Plan? plan;
}

class _PlanCard {
  const _PlanCard(this.name, this.summary, this.benefits);
  final String name;
  final String summary;
  final List<String> benefits;
}

class _Slide {
  const _Slide(
    this.icon,
    this.title,
    this.intro, {
    this.features = const [],
    this.plans = const [],
    this.footer,
  });
  final IconData icon;
  final String title;
  final String intro;
  final List<_Feature> features;
  final List<_PlanCard> plans;
  final String? footer;
}

// Isi panduan mengikuti `docs/MATRIKS-FITUR-PAKET.md`; ubah keduanya bersama
// bila ada fitur atau batas paket yang berubah.
const _slides = [
  _Slide(
    Icons.receipt_long_rounded,
    'Catat transaksi dengan cepat',
    'Semua catatan keuanganmu di satu tempat, tanpa perlu membuat akun.',
    features: [
      _Feature(
        Icons.swap_vert_rounded,
        'Pemasukan, pengeluaran, dan transfer',
        'Catat uang masuk, uang keluar, dan pindah saldo antar dompet '
            'dalam beberapa ketukan.',
      ),
      _Feature(
        Icons.account_balance_wallet_rounded,
        'Banyak dompet',
        'Tunai, rekening bank, dan e-wallet, masing-masing dengan saldonya '
            'sendiri. Kalau saldo di aplikasi berbeda dari kenyataan, pakai '
            '"Sesuaikan saldo": selisihnya dicatat sebagai transaksi '
            'penyesuaian, bukan mengubah saldo awal.',
      ),
      _Feature(
        Icons.category_rounded,
        'Kategori, sub-kategori, dan tag',
        'Kelompokkan sesuai kebutuhanmu; nama, ikon, dan warna bisa '
            'diatur sendiri.',
      ),
      _Feature(
        Icons.repeat_rounded,
        'Transaksi berulang',
        'Gaji, sewa, cicilan, dan langganan dibuat otomatis saat aplikasi '
            'dibuka.',
      ),
      _Feature(
        Icons.notifications_active_rounded,
        'Pengingat transaksi berulang',
        'Dapat pengingat sebelum tagihan atau cicilan jatuh tempo.',
        _Plan.premium,
      ),
      _Feature(
        Icons.document_scanner_rounded,
        'Scan struk',
        'Foto struk dibaca di HP-mu: nominal, toko, dan tanggal terisi '
            'otomatis. Foto tersimpan bersama transaksi dan tampil sebagai '
            'miniatur yang bisa dibuka kembali.',
        _Plan.premium,
      ),
      _Feature(
        Icons.mic_rounded,
        'Catat dengan suara',
        'Ucapkan, mis. "makan siang dua puluh lima ribu": jenis, nominal, '
            'catatan, tanggal, dan kategori terisi di formulir, tinggal kamu '
            'periksa lalu simpan. Pengenalan suara memakai layanan bawaan '
            'Android; LaciQ tidak menyimpan rekaman.',
        _Plan.premium,
      ),
    ],
  ),
  _Slide(
    Icons.donut_large_rounded,
    'Anggaran dan tren yang mudah dibaca',
    'Pahami ke mana uangmu pergi, dan tetap dalam batas yang kamu tetapkan.',
    features: [
      _Feature(
        Icons.dashboard_rounded,
        'Ringkasan',
        'Saldo total, arus kas bulan ini, dan grafik pengeluaran per '
            'kategori dalam sekali lihat.',
      ),
      _Feature(
        Icons.pie_chart_rounded,
        'Anggaran bulanan',
        'Tetapkan batas per kategori dan dapat notifikasi saat pengeluaran '
            'mendekati batas.',
      ),
      _Feature(
        Icons.insights_rounded,
        'Analisa Tren',
        'Pengeluaran per kategori dari waktu ke waktu. Gratis: 3 bulan '
            'terakhir. Premium: histori 6 dan 12 bulan.',
      ),
      _Feature(
        Icons.savings_rounded,
        'Target tabungan',
        'Dana darurat, liburan, atau HP baru: pantau progresnya hingga '
            'tercapai. Hanya penanda, saldo dompet tidak berubah (untuk '
            'tabungan yang memindahkan saldo, lihat Tabungan di Ultimate).',
      ),
      _Feature(
        Icons.summarize_rounded,
        'Laporan Bulanan',
        'Sorotan otomatis tiap bulan: naik atau turunnya pengeluaran '
            'dibanding bulan lalu, kategori terbesar, anggaran yang hampir '
            'habis, dan taksiran akhir bulan. Dihitung di HP-mu. Ada di '
            'menu Lainnya.',
        _Plan.premium,
      ),
      _Feature(
        Icons.grid_on_rounded,
        'Ekspor laporan ke Excel',
        'Berkas .xlsx berisi ringkasan, transaksi, serta rekap per kategori, '
            'bulan, dan dompet. Ada di Pengaturan > Data.',
        _Plan.premium,
      ),
      _Feature(
        Icons.file_download_rounded,
        'Ekspor CSV',
        'Bawa data transaksi ke spreadsheet kapan pun kamu perlu.',
      ),
    ],
  ),
  _Slide(
    Icons.event_note_rounded,
    'Rencanakan keuangan ke depan',
    'Siapkan dana untuk tagihan yang akan datang dan catat kewajibanmu.',
    features: [
      _Feature(
        Icons.event_note_rounded,
        'Agenda',
        'Servis kendaraan, servis AC, biaya pendidikan, dan tagihan tahunan. '
            'Gratis: 3 item aktif. Premium: tanpa batas, dengan pengingat '
            'untuk semua item.',
      ),
      _Feature(
        Icons.query_stats_rounded,
        'Proyeksi bulanan',
        'Perkiraan kebutuhan anggaran bulan ini dari Agenda dan transaksi '
            'berulang.',
        _Plan.premium,
      ),
      _Feature(
        Icons.timeline_rounded,
        'Simulasi arus kas',
        'Cek apakah danamu cukup sampai tanggal tertentu di akhir bulan.',
        _Plan.premium,
      ),
      _Feature(
        Icons.handshake_rounded,
        'Utang dan Piutang',
        'Catat siapa berutang ke siapa, lunas sebagian atau penuh, beserta '
            'cicilannya.',
        _Plan.premium,
      ),
    ],
  ),
  _Slide(
    Icons.lock_rounded,
    'Datamu tetap di HP-mu',
    'Catatan keuangan disimpan di HP-mu sendiri, tanpa akun dan tanpa '
        'server penyimpanan.',
    features: [
      _Feature(
        Icons.fingerprint_rounded,
        'Kunci PIN dan sidik jari',
        'Lindungi aplikasi dengan PIN atau biometrik dari Pengaturan.',
      ),
      _Feature(
        Icons.save_alt_rounded,
        'Backup ke berkas',
        'Buat cadangan lalu pulihkan kapan saja lewat Pengaturan.',
      ),
      _Feature(
        Icons.cloud_upload_rounded,
        'Backup Cloud terenkripsi',
        'Cadangan dienkripsi lalu disimpan di Google Drive-mu sendiri, '
            'bisa dipulihkan di HP baru dengan akun yang sama.',
        _Plan.premium,
      ),
      _Feature(
        Icons.delete_forever_rounded,
        'Hapus semua data',
        'Bersihkan seluruh data dan pengaturan kapan saja dari Pengaturan.',
      ),
    ],
  ),
  _Slide(
    Icons.workspace_premium_rounded,
    'Ultimate untuk pembukuan serius',
    'Semua fitur Premium, ditambah empat fitur khusus.',
    features: [
      _Feature(
        Icons.savings_outlined,
        'Tabungan',
        'Simpan uang di tabungan yang saldonya terpisah dari dompet. Saat '
            'Kamu menyetor, nominalnya tercatat sebagai pengeluaran dan '
            'mengurangi saldo dompet asal. Saat kamu menarik, tercatat '
            'sebagai pemasukan dan menambah saldo dompet tujuan. Buat '
            'beberapa tabungan sekaligus, mis. dana darurat dan liburan. '
            'Ada di menu Lainnya.',
        _Plan.ultimate,
      ),
      _Feature(
        Icons.menu_book_rounded,
        'Multi buku kas',
        'Pisahkan pembukuan pribadi dan bisnis, sampai 5 buku. Tiap buku '
            'punya dompet, kategori, anggaran, transaksi berulang, agenda, '
            'utang piutang, dan target sendiri. Ganti buku dengan sekali '
            'ketuk.',
        _Plan.ultimate,
      ),
      _Feature(
        Icons.auto_awesome_rounded,
        'Scan struk dengan AI',
        'Nama toko, kategori, total, dan tanggal terisi otomatis (300 scan '
            'per bulan). Hanya teks hasil scan, bukan foto, yang dikirim ke '
            'server AI dan tidak disimpan. Kamu diminta menyetujuinya '
            'sebelum pertama kali dipakai.',
        _Plan.ultimate,
      ),
      _Feature(
        Icons.auto_awesome_motion_rounded,
        'Ringkasan AI untuk Laporan Bulanan',
        'Rangkuman beberapa kalimat dari angka bulan ini (30 per bulan). '
            'Hanya total dan nama kategori yang dikirim, bukan catatan atau '
            'foto. Dibuat AI dan bisa keliru; kamu bisa melaporkannya. Kamu '
            'diminta menyetujuinya sebelum pertama kali dipakai.',
        _Plan.ultimate,
      ),
    ],
  ),
  _Slide(
    Icons.stars_rounded,
    'Pilih paket yang cocok',
    'Mulai gratis, tingkatkan kapan pun kamu butuh.',
    plans: [
      _PlanCard('Gratis', 'Semua yang kamu butuhkan untuk mencatat keuangan.', [
        'Transaksi, dompet, kategori, tag, dan transaksi berulang',
        'Anggaran, ringkasan, target tabungan, dan ekspor CSV',
        'Kunci PIN dan sidik jari, backup ke berkas',
        'Analisa Tren 3 bulan dan Agenda 3 item',
        'Menampilkan iklan banner setelah masa bebas iklan 30 hari',
      ]),
      _PlanCard(
        'Premium',
        'Tanpa iklan, dengan perencanaan dan perlindungan data.',
        [
          'Semua fitur Gratis, tanpa iklan',
          'Backup Cloud terenkripsi ke Google Drive-mu',
          'Analisa Tren 6 dan 12 bulan, Agenda tanpa batas',
          'Proyeksi bulanan dan simulasi arus kas',
          'Utang dan Piutang beserta cicilan',
          'Scan struk dengan foto tersimpan, pengingat transaksi berulang',
          'Catat dengan suara, Laporan Bulanan, dan ekspor Excel',
        ],
      ),
      _PlanCard('Ultimate', 'Untuk yang mengelola lebih dari satu pembukuan.', [
        'Semua fitur Premium',
        'Multi buku kas, sampai 5 buku',
        'Tabungan dengan saldo terpisah dari dompet',
        'Scan struk dengan AI: toko, kategori, total, dan tanggal',
        'Ringkasan AI untuk Laporan Bulanan',
      ]),
    ],
    footer:
        'Langganan lewat Google Play dan bisa dibatalkan kapan saja. Lihat '
        'dan kelola paketmu di Pengaturan.',
  ),
];

/// Ditampilkan sekali di instalasi baru (lewat `_StartupGate` di app.dart),
/// atau dibuka ulang dari Pengaturan ("Lihat panduan lagi") — [standalone]
/// membedakan keduanya: bila true, tombol menutup halaman (pop) alih-alih
/// menandai onboarding selesai.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key, this.standalone = false});

  final bool standalone;

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLast => _page == _slides.length - 1;

  Future<void> _finish() async {
    if (widget.standalone) {
      Navigator.of(context).pop();
      return;
    }
    await ref.read(onboardingControllerProvider.notifier).complete();
  }

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return AmbientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8, top: 4),
                  child: TextButton(
                    onPressed: _finish,
                    child: const Text('Lewati'),
                  ),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _controller,
                  onPageChanged: (i) => setState(() => _page = i),
                  children: [
                    for (final s in _slides)
                      _SlideView(slide: s, gradient: palette.heroGradient),
                  ],
                ),
              ),
              _PageDots(count: _slides.length, index: _page),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _next,
                    child: Text(_isLast ? 'Mulai' : 'Lanjut'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide, required this.gradient});

  final _Slide slide;
  final List<Color> gradient;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      children: [
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [gradient[0], gradient[1]],
              ),
              boxShadow: [
                BoxShadow(
                  color: context.palette.glow.withValues(alpha: 0.45),
                  blurRadius: 34,
                  spreadRadius: -6,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Icon(slide.icon, size: 40, color: Colors.white),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          slide.title,
          textAlign: TextAlign.center,
          style: text.headlineSmall,
        ),
        const SizedBox(height: 10),
        Text(
          slide.intro,
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 14),
        for (final f in slide.features) _FeatureRow(feature: f),
        for (final p in slide.plans) _PlanCardView(plan: p),
        if (slide.footer != null) ...[
          const SizedBox(height: 10),
          Text(
            slide.footer!,
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.feature});

  final _Feature feature;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final plan = feature.plan;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: scheme.primary.withValues(alpha: 0.12),
            ),
            child: Icon(feature.icon, size: 22, color: scheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 2,
                  children: [
                    Text(
                      feature.title,
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (plan != null) _PlanBadge(plan: plan),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  feature.body,
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanBadge extends StatelessWidget {
  const _PlanBadge({required this.plan});

  final _Plan plan;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ultimate = plan == _Plan.ultimate;
    final color = ultimate ? scheme.tertiary : scheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: color.withValues(alpha: 0.14),
      ),
      child: Text(
        plan.label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _PlanCardView extends StatelessWidget {
  const _PlanCardView({required this.plan});

  final _PlanCard plan;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            plan.name,
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            plan.summary,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          for (final b in plan.benefits)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_rounded, size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(b, style: text.bodySmall)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == index ? 22 : 7,
            height: 7,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: i == index
                  ? scheme.primary
                  : scheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
          ),
      ],
    );
  }
}
