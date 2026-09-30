import 'package:flutter/material.dart';

import '../data/database.dart';
import 'theme.dart';

/// Kategori menyimpan kunci ikon berupa string, dipetakan ke IconData di sini.
const categoryIcons = <String, IconData>{
  'food': Icons.restaurant,
  'transport': Icons.directions_bus,
  'shopping': Icons.shopping_bag,
  'bills': Icons.receipt_long,
  'home': Icons.home,
  'health': Icons.medical_services,
  'education': Icons.school,
  'fun': Icons.movie,
  'charity': Icons.volunteer_activism,
  'installment': Icons.credit_score,
  'salary': Icons.payments,
  'bonus': Icons.card_giftcard,
  'business': Icons.storefront,
  'gift': Icons.redeem,
  'other': Icons.category,
  'coffee': Icons.local_cafe,
  'pets': Icons.pets,
  'fitness': Icons.fitness_center,
  'travel': Icons.flight,
  'phone': Icons.smartphone,
  'subscription': Icons.subscriptions,
  'savings': Icons.savings,
  'family': Icons.family_restroom,
  'beauty': Icons.spa,
  'car': Icons.directions_car,
  'electronics': Icons.devices,
  'gaming': Icons.sports_esports,
  'book': Icons.menu_book,
  'baby': Icons.child_care,
  'tax': Icons.account_balance,
  'investment': Icons.trending_up,
  'debt': Icons.handshake_rounded,
};

/// Ikon yang ditawarkan untuk target tabungan (subset dari [categoryIcons]).
const goalIconKeys = <String>[
  'savings',
  'home',
  'car',
  'travel',
  'phone',
  'electronics',
  'education',
  'family',
  'baby',
  'gift',
  'health',
  'fitness',
  'investment',
  'tax',
  'other',
];

/// Pilihan warna untuk kategori buatan pengguna (ARGB).
const categoryColors = <int>[
  0xFFEF6C00,
  0xFFE53935,
  0xFFD81B60,
  0xFF8E24AA,
  0xFF3949AB,
  0xFF1E88E5,
  0xFF00ACC1,
  0xFF00897B,
  0xFF43A047,
  0xFF7CB342,
  0xFFF9A825,
  0xFF6D4C41,
  0xFF546E7A,
  0xFF757575,
];

IconData categoryIcon(String key) => categoryIcons[key] ?? Icons.category;

IconData accountKindIcon(AccountKind kind) => switch (kind) {
  AccountKind.cash => Icons.account_balance_wallet,
  AccountKind.bank => Icons.account_balance,
  AccountKind.ewallet => Icons.phone_android,
  AccountKind.card => Icons.credit_card,
};

/// Warna per jenis dompet, agar mudah dibedakan sekilas. Di mode terang ikon
/// berada di atas ubin pastel dari warna yang sama, jadi harus lebih gelap
/// (kontras ikon >= 3:1, lihat test/theme_test.dart).
Color accountKindColor(AccountKind kind, Brightness b, AppPalette palette) {
  final dark = b == Brightness.dark;
  return switch (kind) {
    AccountKind.cash => palette.income,
    AccountKind.bank => Color(dark ? 0xFF60A5FA : 0xFF1D4ED8),
    AccountKind.ewallet => Color(dark ? 0xFFA78BFA : 0xFF6D28D9),
    AccountKind.card => Color(dark ? 0xFFF472B6 : 0xFFBE185D),
  };
}

String accountKindLabel(AccountKind kind) => switch (kind) {
  AccountKind.cash => 'Tunai',
  AccountKind.bank => 'Rekening Bank',
  AccountKind.ewallet => 'E-Wallet',
  AccountKind.card => 'Kartu',
};

String txTypeLabel(TxType type) => switch (type) {
  TxType.income => 'Pemasukan',
  TxType.expense => 'Pengeluaran',
  TxType.transfer => 'Transfer',
};
