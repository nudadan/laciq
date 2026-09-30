import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import 'app_lock_service.dart';

/// Indikator titik + keypad angka. Memakai keypad sendiri (bukan keyboard
/// sistem) agar PIN tidak lewat keyboard pihak ketiga.
///
/// Begitu [AppLockService.pinLength] digit terisi, [onCompleted] dipanggil dan
/// input langsung dikosongkan; induk menentukan hasilnya lewat [message].
class PinPad extends StatefulWidget {
  const PinPad({
    super.key,
    required this.title,
    required this.onCompleted,
    this.message,
    this.isError = false,
    this.enabled = true,
    this.leading,
  });

  final String title;
  final ValueChanged<String> onCompleted;
  final String? message;
  final bool isError;
  final bool enabled;

  /// Tombol di kiri bawah (mis. sidik jari).
  final Widget? leading;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _digits = '';

  void _tap(String d) {
    if (!widget.enabled || _digits.length >= AppLockService.pinLength) return;
    HapticFeedback.selectionClick();
    setState(() => _digits += d);
    if (_digits.length == AppLockService.pinLength) {
      final pin = _digits;
      // Kosongkan setelah frame agar titik terakhir sempat terlihat terisi.
      Future<void>.delayed(const Duration(milliseconds: 120), () {
        if (!mounted) return;
        setState(() => _digits = '');
        widget.onCompleted(pin);
      });
    }
  }

  void _backspace() {
    if (!widget.enabled ||
        _digits.isEmpty ||
        _digits.length == AppLockService.pinLength) {
      return;
    }
    setState(() => _digits = _digits.substring(0, _digits.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    Widget key(String d) => _Key(
      onTap: widget.enabled ? () => _tap(d) : null,
      child: Text(d, style: text.headlineSmall),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.title, style: text.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < AppLockService.pinLength; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                width: 16,
                height: 16,
                margin: const EdgeInsets.symmetric(horizontal: 9),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _digits.length
                      ? (widget.isError ? scheme.error : scheme.primary)
                      : Colors.transparent,
                  border: Border.all(
                    color: widget.isError ? scheme.error : scheme.outline,
                    width: 2,
                  ),
                  boxShadow: i < _digits.length
                      ? [
                          BoxShadow(
                            color:
                                (widget.isError
                                        ? scheme.error
                                        : context.palette.glow)
                                    .withValues(alpha: 0.55),
                            blurRadius: 12,
                          ),
                        ]
                      : null,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 44,
          child: Text(
            widget.message ?? '',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: widget.isError ? scheme.error : scheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [for (final d in row) key(d)],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Key(
              onTap: null,
              plain: true,
              child: widget.leading ?? const SizedBox.shrink(),
            ),
            key('0'),
            _Key(
              onTap: widget.enabled ? _backspace : null,
              plain: true,
              child: const Icon(Icons.backspace_outlined),
            ),
          ],
        ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.child, required this.onTap, this.plain = false});

  final Widget child;
  final VoidCallback? onTap;

  /// Tanpa lingkaran (tombol kosong/hapus).
  final bool plain;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(7),
      child: SizedBox(
        width: 72,
        height: 72,
        child: Material(
          color: plain
              ? Colors.transparent
              : scheme.surfaceContainerHigh.withValues(alpha: 0.7),
          shape: CircleBorder(
            side: plain
                ? BorderSide.none
                : BorderSide(color: scheme.outlineVariant),
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
