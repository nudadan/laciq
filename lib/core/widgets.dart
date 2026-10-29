import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/providers.dart';
import 'theme.dart';

class MonthSelector extends ConsumerWidget {
  const MonthSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final notifier = ref.read(selectedMonthProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: StadiumBorder(
            side: BorderSide(
              color: context.isDark
                  ? Colors.white.withValues(alpha: 0.10)
                  : scheme.outlineVariant,
            ),
          ),
          color: scheme.surfaceContainerHigh.withValues(alpha: 0.7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Bulan sebelumnya',
              onPressed: () => notifier.shift(-1),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            SizedBox(
              width: 150,
              child: Text(
                DateFormat('MMMM yyyy', 'id_ID').format(month),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            IconButton(
              tooltip: 'Bulan berikutnya',
              onPressed: () => notifier.shift(1),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

/// Menampilkan [AsyncValue] dengan state loading/error yang seragam.
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({super.key, required this.value, required this.builder});

  final AsyncValue<T> value;
  final Widget Function(T data) builder;

  @override
  Widget build(BuildContext context) => value.when(
    data: builder,
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (e, _) => Center(child: Text('Terjadi kesalahan: $e')),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;

  /// Tombol langkah pertama di bawah pesan; tampil hanya bila keduanya diisi.
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    context.palette.glow.withValues(alpha: 0.28),
                    context.palette.glow.withValues(alpha: 0.04),
                  ],
                ),
                border: Border.all(
                  color: context.palette.glow.withValues(alpha: 0.30),
                ),
              ),
              child: Icon(icon, size: 38, color: scheme.primary),
            ),
            const SizedBox(height: 18),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant, height: 1.5),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Lingkaran pilihan untuk ikon atau warna (dipakai di editor kategori dan target).
class SwatchButton extends StatelessWidget {
  const SwatchButton({
    super.key,
    required this.selected,
    required this.onTap,
    this.child,
    this.fill,
  });

  final bool selected;
  final VoidCallback? onTap;
  final Widget? child;
  final Color? fill;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkResponse(
      onTap: onTap,
      radius: 26,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: fill ?? (selected ? scheme.primaryContainer : null),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2.5 : 1,
          ),
        ),
        child: child,
      ),
    );
  }
}

/// Menampilkan pesan singkat dan langsung menggantikan pesan sebelumnya.
/// showSnackBar biasa mengantre: pesan aksi kedua baru muncul setelah pesan
/// lama habis (4 detik), sehingga terasa seperti tidak ada respons.
void notify(
  ScaffoldMessengerState messenger,
  String message, {
  SnackBarAction? action,
}) {
  messenger
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(message), action: action));
}

/// Baris bergaya kolom isian (tanggal, pilihan) agar serasi dengan TextField.
class FieldTile extends StatelessWidget {
  const FieldTile({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.leadingWidget,
  });

  /// Menggantikan ikon [leading] bila diisi (mis. miniatur foto struk).
  final Widget? leadingWidget;

  final IconData leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: leadingWidget ?? Icon(leading, color: scheme.primary),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}

/// Bilah progres bergradien yang terisi dengan animasi.
class GradientBar extends StatelessWidget {
  const GradientBar({
    super.key,
    required this.value,
    required this.color,
    this.height = 10,
  });

  final double value; // 0..1
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final track = Theme.of(context).colorScheme.surfaceContainerHighest;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: track),
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: v,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(height),
                    gradient: LinearGradient(
                      colors: [color, Color.lerp(color, Colors.white, 0.28)!],
                    ),
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
