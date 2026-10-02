import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'receipt_storage.dart';

/// Memuat file foto struk dari path relatif. Dipisah jadi provider agar tes
/// bisa mengganti dengan file/hasil palsu tanpa menyentuh penyimpanan asli.
final receiptFileLoaderProvider =
    Provider<Future<File?> Function(String relativePath)>(
      (ref) => existingReceiptFile,
    );

/// Menampilkan foto struk yang tersimpan bersama transaksi, layar penuh,
/// dengan zoom dan geser. Tidak mengecek paket langganan: foto itu milik
/// pengguna dan tetap bisa dilihat walau paket sudah turun ke Gratis.
class ReceiptViewerPage extends ConsumerWidget {
  const ReceiptViewerPage({super.key, required this.relativePath});

  final String relativePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final load = ref.watch(receiptFileLoaderProvider);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Foto struk'),
      ),
      body: FutureBuilder<File?>(
        future: load(relativePath),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final file = snapshot.data;
          if (file == null) return const _MissingReceipt();
          return InteractiveViewer(
            minScale: 1,
            maxScale: 6,
            child: Center(
              child: Image.file(
                file,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const _MissingReceipt(),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MissingReceipt extends StatelessWidget {
  const _MissingReceipt();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_outlined, size: 56, color: Colors.white54),
            SizedBox(height: 16),
            Text(
              'Foto struk tidak ditemukan di perangkat ini.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Bila Anda baru memulihkan data, pulihkan dari Backup Cloud '
              'agar foto ikut kembali.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
