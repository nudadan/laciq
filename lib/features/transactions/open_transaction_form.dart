import 'package:flutter/material.dart';

import '../../core/widgets.dart';
import 'transaction_form_page.dart';

/// Membuka formulir Catat dan menampilkan pesan hasilnya di halaman pemanggil
/// (sama seperti tombol Catat di bilah bawah, dipakai tombol di keadaan kosong).
Future<void> openTransactionForm(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final message = await Navigator.of(context).push<String>(
    MaterialPageRoute(builder: (_) => const TransactionFormPage()),
  );
  if (message != null) notify(messenger, message);
}
