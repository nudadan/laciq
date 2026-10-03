import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:path_provider/path_provider.dart';

import 'receipt_storage.dart';

/// Memuat file foto struk dari path relatif. Dipisah jadi provider agar tes
/// bisa mengganti dengan file/hasil palsu tanpa menyentuh penyimpanan asli.
final receiptFileLoaderProvider =
    Provider<Future<File?> Function(String relativePath)>(
      (ref) => existingReceiptFile,
    );

/// Direktori dokumen aplikasi, dibaca sekali lalu dipakai ulang oleh semua
/// miniatur (daftar transaksi bisa memuat puluhan baris).
final receiptDocsDirProvider = FutureProvider<String>(
  (ref) async => (await getApplicationDocumentsDirectory()).path,
);

/// Miniatur foto struk. Gambar diperkecil saat didekode (`cacheWidth`) supaya
/// daftar panjang tetap ringan. Bila direktori/berkas tidak tersedia, jatuh ke
/// ikon struk (bukan layar kosong), sehingga tetap bisa diketuk.
class ReceiptThumbnail extends ConsumerWidget {
  const ReceiptThumbnail({
    super.key,
    required this.relativePath,
    this.size = 40,
  });

  final String relativePath;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = Container(
      width: size,
      height: size,
      color: scheme.surfaceContainerHighest,
      child: Icon(
        Icons.receipt_long_rounded,
        size: size * 0.5,
        color: scheme.primary,
      ),
    );
    final dir = ref.watch(receiptDocsDirProvider).value;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.25),
      child: dir == null
          ? fallback
          : Image.file(
              File('$dir/$relativePath'),
              width: size,
              height: size,
              fit: BoxFit.cover,
              cacheWidth: (size * 3).round(),
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}

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
