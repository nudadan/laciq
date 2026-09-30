import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'lock_providers.dart';
import 'pin_screens.dart';

/// Membungkus seluruh aplikasi (di atas Navigator, sehingga dialog dan halaman
/// juga tertutup). Aplikasi tetap ter-mount di bawah layar kunci agar isian
/// form dan posisi navigasi tidak hilang.
class LockGate extends ConsumerStatefulWidget {
  const LockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LockGate> createState() => _LockGateState();
}

class _LockGateState extends ConsumerState<LockGate>
    with WidgetsBindingObserver {
  DateTime? _backgroundedAt;
  bool _covered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final pinEnabled =
        ref.read(lockControllerProvider).value?.pinEnabled ?? false;
    if (!pinEnabled) return;

    switch (state) {
      case AppLifecycleState.inactive:
        setState(() => _covered = true);
      case AppLifecycleState.hidden || AppLifecycleState.paused:
        _backgroundedAt ??= DateTime.now();
        setState(() => _covered = true);
      case AppLifecycleState.resumed:
        final since = _backgroundedAt;
        _backgroundedAt = null;
        if (since != null &&
            DateTime.now().difference(since) >= ref.read(lockGraceProvider)) {
          FocusManager.instance.primaryFocus?.unfocus();
          ref.read(lockControllerProvider.notifier).lock();
        }
        setState(() => _covered = false);
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lock = ref.watch(lockControllerProvider);
    final surface = Theme.of(context).colorScheme.surface;

    // Gagal membaca status kunci: tutup (fail closed), jangan buka aplikasi.
    if (lock.hasError && !lock.hasValue) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Tidak dapat memuat pengaturan keamanan.'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(lockControllerProvider),
                child: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      );
    }

    final hidden = !lock.hasValue || lock.value!.locked;
    return Stack(
      fit: StackFit.expand,
      children: [
        Offstage(
          offstage: hidden,
          child: TickerMode(enabled: !hidden, child: widget.child),
        ),
        if (!lock.hasValue) ColoredBox(color: surface),
        if (lock.hasValue && lock.value!.locked) const LockScreen(),
        // Menutupi isi di app switcher (thumbnail "recent apps").
        if (_covered && (lock.value?.pinEnabled ?? false))
          ColoredBox(
            color: surface,
            child: const Center(child: Icon(Icons.lock_outline, size: 48)),
          ),
      ],
    );
  }
}
