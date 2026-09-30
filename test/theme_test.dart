import 'dart:math' as math;

import 'package:dompet_pintar/core/category_style.dart';
import 'package:dompet_pintar/data/database.dart';
import 'package:dompet_pintar/core/theme.dart';
import 'package:dompet_pintar/core/theme_mode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/harness.dart';

/// Rasio kontras WCAG 2.x antara dua warna (1..21).
double contrast(Color a, Color b) {
  double lum(Color c) {
    double ch(double v) => v <= 0.03928
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
  }

  final l1 = lum(a), l2 = lum(b);
  final hi = math.max(l1, l2), lo = math.min(l1, l2);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  // Ikon jenis dompet digambar di atas ubin pastel dari warna yang sama
  // (CategoryBadge: alpha 0.16). Ikon harus terbaca (>= 3:1, WCAG 1.4.11).
  test('ikon jenis dompet terbaca di atas ubinnya di kedua tema', () {
    for (final b in Brightness.values) {
      final theme = buildTheme(b);
      final palette = theme.extension<AppPalette>()!;
      for (final kind in AccountKind.values) {
        final icon = accountKindColor(kind, b, palette);
        for (final surface in [
          theme.colorScheme.surface,
          theme.colorScheme.surfaceContainerLow,
        ]) {
          final tile = Color.alphaBlend(icon.withValues(alpha: 0.16), surface);
          expect(
            contrast(icon, tile),
            greaterThanOrEqualTo(3),
            reason: '${kind.name} di tema ${b.name}',
          );
        }
      }
    }
  });

  // AppBar bertransparan menebak latar "gelap" dan memasang ikon putih, yang
  // tak terbaca di mode terang; ikon harus ditentukan eksplisit oleh tema.
  test('ikon bilah status kontras dengan tema di AppBar', () {
    final light = buildTheme(Brightness.light).appBarTheme.systemOverlayStyle;
    final dark = buildTheme(Brightness.dark).appBarTheme.systemOverlayStyle;
    expect(light?.statusBarIconBrightness, Brightness.dark);
    expect(dark?.statusBarIconBrightness, Brightness.light);
    expect(light?.systemNavigationBarIconBrightness, Brightness.dark);
    expect(dark?.systemNavigationBarIconBrightness, Brightness.light);
  });

  group('keterbacaan warna (WCAG)', () {
    for (final brightness in Brightness.values) {
      group(brightness.name, () {
        final theme = buildTheme(brightness);
        final s = theme.colorScheme;
        final p = theme.extension<AppPalette>()!;

        test('teks utama dan sekunder terbaca di latar halaman', () {
          expect(contrast(s.onSurface, s.surface), greaterThanOrEqualTo(7));
          expect(
            contrast(s.onSurfaceVariant, s.surface),
            greaterThanOrEqualTo(4.5),
          );
        });

        test('teks di atas kartu (permukaan bertingkat)', () {
          for (final surface in [
            s.surfaceContainerLow,
            s.surfaceContainer,
            s.surfaceContainerHigh,
          ]) {
            expect(contrast(s.onSurface, surface), greaterThanOrEqualTo(7));
            expect(
              contrast(s.onSurfaceVariant, surface),
              greaterThanOrEqualTo(4.5),
            );
          }
        });

        test(
          'warna makna keuangan terbaca sebagai teks kecil di atas kartu',
          () {
            for (final (name, color) in [
              ('pemasukan', p.income),
              ('pengeluaran', p.expense),
              ('transfer', p.transfer),
              ('peringatan', p.warning),
            ]) {
              expect(
                contrast(color, s.surfaceContainerLow),
                greaterThanOrEqualTo(4.5),
                reason: '$name di ${brightness.name}',
              );
              expect(
                contrast(color, s.surface),
                greaterThanOrEqualTo(4.5),
                reason: '$name di atas latar halaman, ${brightness.name}',
              );
            }
          },
        );

        test('aksen dan hint cukup terlihat untuk elemen UI (>= 3)', () {
          expect(contrast(s.primary, s.surface), greaterThanOrEqualTo(3));
          expect(
            contrast(s.outline, s.surfaceContainerHigh),
            greaterThanOrEqualTo(3),
            reason: 'hint di dalam kolom isian',
          );
        });

        test('teks di atas tombol utama', () {
          expect(contrast(s.onPrimary, s.primary), greaterThanOrEqualTo(4.5));
          expect(contrast(s.onError, s.error), greaterThanOrEqualTo(4.5));
        });
      });
    }

    test(
      'teks putih di atas kartu saldo bergradien terbaca di seluruh gradien',
      () {
        final p = buildTheme(Brightness.dark).extension<AppPalette>()!;
        for (final c in p.heroGradient) {
          expect(
            contrast(Colors.white, c),
            greaterThanOrEqualTo(3),
            reason:
                'teks besar/tebal di atas ${c.toARGB32().toRadixString(16)}',
          );
        }
      },
    );
  });

  group('mode tema', () {
    test(
      'parseThemeMode: bawaan gelap untuk nilai kosong atau tak dikenal',
      () {
        expect(parseThemeMode(null), ThemeMode.dark);
        expect(parseThemeMode('ngawur'), ThemeMode.dark);
        expect(parseThemeMode('light'), ThemeMode.light);
        expect(parseThemeMode('system'), ThemeMode.system);
      },
    );

    appTest('bawaan gelap; memilih Terang mengubah tema dan tersimpan', (
      tester,
      h,
    ) async {
      ThemeMode mode() =>
          tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode!;
      expect(mode(), ThemeMode.dark);

      await tester.tap(find.byTooltip('Pengaturan'));
      await settle(tester);
      await tester.tap(find.text('Terang'));
      await settle(tester);

      expect(mode(), ThemeMode.light);
      expect(await h.store.read('theme_mode'), 'light');

      await tester.tap(find.text('Sistem'));
      await settle(tester);
      expect(mode(), ThemeMode.system);
      expect(await h.store.read('theme_mode'), 'system');
    });
  });
}
