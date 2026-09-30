import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import 'money.dart';
import 'theme.dart';

/// Ruang kosong di bawah daftar agar baris terakhir tidak tertutup navigasi
/// melayang maupun tombol "Catat" yang duduk di atasnya (bilah sistem + navigasi
/// + tombol + jarak). Di HP uji 150 hanya melewati navigasi: tombol masih
/// menutupi ikon di baris terakhir.
const kBottomPad = 210.0;

/// Latar dengan dua pendar cahaya lembut di sudut atas. Statis, jadi dibungkus
/// RepaintBoundary agar tidak ikut digambar ulang saat isi bergulir.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = context.isDark;
    return ColoredBox(
      color: scheme.surface,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: IgnorePointer(
              child: Stack(
                children: [
                  Positioned(
                    top: -140,
                    left: -110,
                    child: _Glow(context.palette.glow, 420, dark ? 0.30 : 0.16),
                  ),
                  Positioned(
                    top: 90,
                    right: -170,
                    child: _Glow(scheme.secondary, 380, dark ? 0.16 : 0.09),
                  ),
                ],
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow(this.color, this.size, this.alpha);

  final Color color;
  final double size;
  final double alpha;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    ),
  );
}

/// Kartu berkaca tipis: gradien putih transparan, tepi bercahaya halus. Di mode
/// terang menjadi kartu putih dengan bayangan lembut.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin = const EdgeInsets.symmetric(vertical: 6),
    this.radius = 24,
    this.onTap,
    this.gradient,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double radius;
  final VoidCallback? onTap;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = context.isDark;
    final borderRadius = BorderRadius.circular(radius);
    return Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          gradient:
              gradient ??
              LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: dark
                    ? [
                        Colors.white.withValues(alpha: 0.085),
                        Colors.white.withValues(alpha: 0.03),
                      ]
                    : [Colors.white, Colors.white.withValues(alpha: 0.86)],
              ),
          border: Border.all(
            color: dark
                ? Colors.white.withValues(alpha: 0.10)
                : scheme.outlineVariant,
          ),
          boxShadow: dark
              ? null
              : [
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: 0.07),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: borderRadius,
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// Bilah melayang dengan latar buram (untuk navigasi bawah).
class GlassBar extends StatelessWidget {
  const GlassBar({super.key, required this.child, this.radius = 30});

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = context.isDark;
    final borderRadius = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.45 : 0.10),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainer.withValues(
                alpha: dark ? 0.72 : 0.86,
              ),
              borderRadius: borderRadius,
              border: Border.all(
                color: dark
                    ? Colors.white.withValues(alpha: 0.10)
                    : scheme.outlineVariant,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Tombol aksi utama: lingkaran bergradien dengan cahaya di bawahnya.
/// Ikon saja agar ringkas; [tooltip] menjaga aksesibilitas dan dipakai tes.
class GradientFab extends StatelessWidget {
  const GradientFab({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 62,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Tooltip(
      message: tooltip,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [p.heroGradient[0], p.heroGradient[1]],
          ),
          boxShadow: [
            BoxShadow(
              color: p.glow.withValues(alpha: 0.50),
              blurRadius: 26,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Semantics(
              button: true,
              label: tooltip,
              child: SizedBox(
                width: size,
                height: size,
                child: Icon(icon, color: Colors.white, size: 28),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Nominal Rupiah yang berhitung naik dari 0 saat pertama tampil dan meluncur
/// ke nilai baru saat berubah. "Rp" dikecilkan agar angkanya menonjol.
class AnimatedAmount extends StatelessWidget {
  const AnimatedAmount(
    this.value, {
    super.key,
    required this.style,
    this.duration = const Duration(milliseconds: 800),
  });

  final int value;
  final TextStyle style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final size = style.fontSize ?? 16;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        final n = v.round();
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${n < 0 ? '-' : ''}Rp ',
                  style: style.copyWith(fontSize: size * 0.55),
                ),
                TextSpan(text: groupedNumber(n.abs())),
              ],
            ),
            style: style,
            maxLines: 1,
          ),
        );
      },
    );
  }
}

/// Lingkaran progres bergradien yang terisi dengan animasi.
class RingProgress extends StatelessWidget {
  const RingProgress({
    super.key,
    required this.value,
    required this.colors,
    this.size = 64,
    this.stroke = 8,
    this.child,
  });

  final double value; // 0..1
  final List<Color> colors;
  final double size;
  final double stroke;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final track = Theme.of(context).colorScheme.surfaceContainerHighest;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(v, colors, track, stroke),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.colors, this.track, this.stroke);

  final double value;
  final List<Color> colors;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arc, 0, math.pi * 2, false, base..color = track);
    if (value <= 0) return;
    final shader = SweepGradient(
      colors: colors.length == 1 ? [colors[0], colors[0]] : colors,
      transform: const GradientRotation(-math.pi / 2),
    ).createShader(rect);
    canvas.drawArc(
      arc,
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      base..shader = shader,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.colors != colors || old.track != track;
}

/// Ikon kategori: kotak membulat dengan warna kategori yang ditipiskan.
class CategoryBadge extends StatelessWidget {
  const CategoryBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 44,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(size * 0.34),
      border: Border.all(color: color.withValues(alpha: 0.30)),
    ),
    child: Icon(icon, color: color, size: size * 0.5),
  );
}
