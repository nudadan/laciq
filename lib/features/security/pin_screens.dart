import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/glass.dart';
import 'app_lock_service.dart';
import 'lock_providers.dart';
import 'pin_pad.dart';

String _mmss(Duration d) {
  final s =
      d.inSeconds + (d.inMilliseconds % 1000 > 0 ? 1 : 0); // bulatkan ke atas
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// Papan PIN yang memverifikasi ke [AppLockService], termasuk hitungan mundur
/// saat terkunci sementara dan (opsional) buka dengan biometrik.
class PinVerifyView extends ConsumerStatefulWidget {
  const PinVerifyView({
    super.key,
    required this.title,
    required this.onVerified,
    this.allowBiometric = false,
  });

  final String title;
  final VoidCallback onVerified;
  final bool allowBiometric;

  @override
  ConsumerState<PinVerifyView> createState() => _PinVerifyViewState();
}

class _PinVerifyViewState extends ConsumerState<PinVerifyView> {
  String? _message;
  bool _isError = false;
  Duration? _lockedFor;
  Timer? _ticker;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _startLockoutCountdownIfNeeded().then((locked) {
      final bio =
          ref.read(lockControllerProvider).value?.biometricEnabled ?? false;
      if (!locked && widget.allowBiometric && bio) _tryBiometric();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<bool> _startLockoutCountdownIfNeeded() async {
    final left = await ref.read(appLockServiceProvider).lockoutRemaining();
    if (!mounted) return false;
    _ticker?.cancel();
    if (left == null) {
      setState(() => _lockedFor = null);
      return false;
    }
    setState(() {
      _lockedFor = left;
      _isError = true;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) async {
      final remaining = await ref
          .read(appLockServiceProvider)
          .lockoutRemaining();
      if (!mounted) return;
      setState(() {
        _lockedFor = remaining;
        if (remaining == null) {
          _ticker?.cancel();
          _message = null;
          _isError = false;
        }
      });
    });
    return true;
  }

  Future<void> _tryBiometric() async {
    final ok = await ref.read(biometricProvider).authenticate('Buka LaciQ');
    if (ok && mounted) widget.onVerified();
  }

  Future<void> _onPin(String pin) async {
    if (_busy) return;
    _busy = true;
    try {
      final result = await ref.read(appLockServiceProvider).verifyPin(pin);
      if (!mounted) return;
      switch (result) {
        case PinOk():
          widget.onVerified();
        case PinWrong(:final attemptsLeft):
          setState(() {
            _isError = true;
            _message = 'PIN salah. Sisa percobaan: $attemptsLeft';
          });
        case PinLockedOut():
          await _startLockoutCountdownIfNeeded();
      }
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = _lockedFor;
    final bio =
        widget.allowBiometric &&
        (ref.watch(lockControllerProvider).value?.biometricEnabled ?? false);
    return PinPad(
      title: widget.title,
      enabled: locked == null,
      isError: _isError,
      message: locked != null
          ? 'Terlalu banyak percobaan.\nCoba lagi dalam ${_mmss(locked)}'
          : _message,
      onCompleted: _onPin,
      leading: bio && locked == null
          ? IconButton(
              iconSize: 32,
              icon: const Icon(Icons.fingerprint),
              onPressed: _tryBiometric,
            )
          : null,
    );
  }
}

/// Layar penuh yang menutup aplikasi selama terkunci.
class LockScreen extends ConsumerWidget {
  const LockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AmbientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_rounded,
                    size: 40,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  PinVerifyView(
                    title: 'Masukkan PIN',
                    allowBiometric: true,
                    onVerified: () =>
                        ref.read(lockControllerProvider.notifier).unlock(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Meminta PIN saat ini sebelum tindakan sensitif. Mengembalikan `true`
/// lewat Navigator jika berhasil.
class PinVerifyPage extends StatelessWidget {
  const PinVerifyPage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          child: PinVerifyView(
            title: title,
            onVerified: () => Navigator.of(context).pop(true),
          ),
        ),
      ),
    ),
  );
}

/// Membuat PIN baru: masukkan, lalu ulangi untuk konfirmasi.
class PinSetupPage extends ConsumerStatefulWidget {
  const PinSetupPage({super.key, this.title = 'Buat PIN'});

  final String title;

  @override
  ConsumerState<PinSetupPage> createState() => _PinSetupPageState();
}

class _PinSetupPageState extends ConsumerState<PinSetupPage> {
  String? _first;
  String? _message;
  bool _isError = false;

  Future<void> _onPin(String pin) async {
    final first = _first;
    if (first == null) {
      setState(() {
        _first = pin;
        _message = null;
        _isError = false;
      });
    } else if (first != pin) {
      setState(() {
        _first = null;
        _isError = true;
        _message = 'PIN tidak cocok. Ulangi dari awal.';
      });
    } else {
      await ref.read(lockControllerProvider.notifier).enablePin(pin);
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          child: PinPad(
            title: _first == null
                ? 'Masukkan ${AppLockService.pinLength} digit PIN'
                : 'Ulangi PIN untuk konfirmasi',
            message:
                _message ??
                (_first == null
                    ? 'PIN diminta saat aplikasi dibuka.\nJangan lupa PIN Anda: tidak bisa dipulihkan.'
                    : null),
            isError: _isError,
            onCompleted: _onPin,
          ),
        ),
      ),
    ),
  );
}
