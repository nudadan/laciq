import 'package:dompet_pintar/data/database.dart';
import 'package:dompet_pintar/features/security/app_lock_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/harness.dart';

const _pin = '123456';

Future<void> _setPin(AppLockService lock) => lock.setPin(_pin);

Future<void> _openSettingsAndTapErase(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Pengaturan'));
  await settle(tester);
  // Dengan PIN aktif, grup Keamanan lebih panjang (Ubah PIN + sidik jari)
  // dan mendorong "Hapus semua data" ke luar jangkauan awal ListView.
  await tester.dragUntilVisible(
    find.text('Hapus semua data'),
    find.byType(ListView),
    const Offset(0, -200),
  );
  await settle(tester);
  await tester.tap(find.text('Hapus semua data'));
  await settle(tester);
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  appTest('tanpa PIN: langsung ke dialog peringatan', (tester, h) async {
    await _openSettingsAndTapErase(tester);
    expect(find.text('Hapus semua data?'), findsOneWidget);

    // Tutup dialog sebelum tes berakhir — showDialog yang menggantung
    // (tidak pernah di-pop) merusak isolasi tes berikutnya di file ini.
    await tester.tap(find.text('Batal'));
    await settle(tester);
  });

  appTest('batal di dialog peringatan tidak mengubah apa pun', (
    tester,
    h,
  ) async {
    await _openSettingsAndTapErase(tester);
    await tester.tap(find.text('Batal'));
    await settle(tester);

    expect(find.text('Pengaturan'), findsOneWidget);
    final categories = await tester.runAsync(
      () => h.db.watchCategories(TxType.expense).first,
    );
    expect(categories!.isNotEmpty, isTrue);
  });

  appTest('konfirmasi menghapus data dan kembali ke onboarding (reset total)', (
    tester,
    h,
  ) async {
    await h.db.addAccount(name: 'BCA', kind: AccountKind.bank);
    await _openSettingsAndTapErase(tester);
    await tester.tap(find.text('Hapus Semua'));
    await settle(tester);

    // Kembali ke onboarding (bukan dashboard) — reset total.
    expect(find.text('Catat transaksi dengan cepat'), findsOneWidget);

    final accounts = await tester.runAsync(
      () => h.db.watchAccountBalances().first,
    );
    expect(accounts!.map((a) => a.name), ['Tunai']);
    expect(await h.store.read('onboarding_seen'), isNull);
  });

  appTest(
    'dengan PIN aktif: harus verifikasi PIN dulu sebelum dialog peringatan',
    (tester, h) async {
      await typePin(tester, _pin); // buka kunci aplikasi dulu
      await _openSettingsAndTapErase(tester);
      // Layar verifikasi PIN muncul duluan, bukan dialog peringatan.
      expect(find.text('Masukkan PIN untuk menghapus data'), findsOneWidget);
      expect(find.text('Hapus semua data?'), findsNothing);

      await typePin(tester, _pin);
      expect(find.text('Hapus semua data?'), findsOneWidget);

      await tester.tap(find.text('Hapus Semua'));
      await settle(tester);

      // PIN ikut tercabut: onboarding tampil tanpa diminta PIN dulu.
      expect(find.text('Catat transaksi dengan cepat'), findsOneWidget);
    },
    preset: _setPin,
  );

  appTest('PIN salah tidak lanjut ke dialog peringatan, data tidak berubah', (
    tester,
    h,
  ) async {
    await typePin(tester, _pin); // buka kunci aplikasi dulu
    await _openSettingsAndTapErase(tester);
    // PIN salah kali ini untuk layar verifikasi "Hapus semua data".
    await typePin(tester, '000000');
    await settle(tester);

    expect(find.text('Hapus semua data?'), findsNothing);
    expect(await h.lock.hasPin, isTrue);

    // Tutup layar verifikasi PIN (masih terbuka, menunggu percobaan lagi)
    // sebelum tes berakhir — Navigator.push yang menggantung (tidak pernah
    // di-pop) merusak isolasi tes berikutnya di file ini.
    await tester.tap(find.byType(BackButton).last);
    await settle(tester);
  }, preset: _setPin);
}
