import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/glass.dart';
import '../../core/theme.dart';
import 'onboarding_providers.dart';

class _Slide {
  const _Slide(this.icon, this.title, this.body);
  final IconData icon;
  final String title;
  final String body;
}

const _slides = [
  _Slide(
    Icons.receipt_long_rounded,
    'Catat transaksi dengan cepat',
    'Kelola beberapa dompet sekaligus, kelompokkan lewat kategori dan '
        'sub-kategori, tandai dengan tag — semua dalam beberapa ketukan.',
  ),
  _Slide(
    Icons.donut_large_rounded,
    'Anggaran dan tren yang mudah dibaca',
    'Atur anggaran per kategori dan dapat notifikasi saat mendekati batas. '
        'Lihat tren 6 bulan terakhir untuk memahami arus kas Anda.',
  ),
  _Slide(
    Icons.lock_rounded,
    'Data Anda tetap di HP Anda',
    'DompetKu bekerja sepenuhnya offline, tanpa server. Kunci dengan PIN '
        'atau sidik jari, dan buat backup kapan saja lewat Pengaturan.',
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 150,
            height: 150,
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
                  blurRadius: 46,
                  spreadRadius: -6,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: Icon(slide.icon, size: 60, color: Colors.white),
          ),
          const SizedBox(height: 36),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: text.headlineSmall,
          ),
          const SizedBox(height: 14),
          Text(
            slide.body,
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
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
