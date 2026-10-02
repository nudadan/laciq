import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../subscription/subscription_status.dart';
import 'ai_config.dart';

class AiCategoryOption {
  const AiCategoryOption({required this.id, required this.label});
  final String id;
  final String label;
}

class AiReceiptExtraction {
  const AiReceiptExtraction({
    this.merchant,
    this.categoryId,
    this.total,
    this.date,
    this.remaining,
  });
  final String? merchant;
  final String? categoryId;

  /// Total yang dibayar (Rupiah bulat), sudah divalidasi server; null bila tidak yakin.
  final int? total;

  /// Tanggal transaksi (hanya tanggal); null bila tidak yakin.
  final DateTime? date;

  /// Sisa kuota scan AI bulan ini menurut server; null bila tidak dikirim.
  final int? remaining;
}

/// Kuota scan AI habis (server membalas 429): bulanan, atau batas harian bila
/// [daily] true.
class AiQuotaExceeded implements Exception {
  const AiQuotaExceeded({this.daily = false});
  final bool daily;
}

/// Ekstraksi pintar (fitur Ultimate): teks OCR → nama toko + kategori. Semua
/// kegagalan lain (offline, timeout, server error) mengembalikan null supaya
/// alur scan jatuh kembali ke hasil heuristik on-device.
abstract interface class AiExtractionService {
  Future<AiReceiptExtraction?> extract({
    required String rawText,
    required List<AiCategoryOption> categories,
  });
}

class HttpAiExtractionService implements AiExtractionService {
  HttpAiExtractionService(
    this._subscription, {
    http.Client? client,
    this._url = kAiExtractionUrl,
    this._timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client();

  final SubscriptionStatus _subscription;
  final http.Client _client;
  final String _url;
  final Duration _timeout;

  static const _maxTextChars = 4000;
  static const _maxMerchantChars = 60;

  @override
  Future<AiReceiptExtraction?> extract({
    required String rawText,
    required List<AiCategoryOption> categories,
  }) async {
    if (_url.isEmpty) return null;
    try {
      final userId = await _subscription.appUserId();
      if (userId == null) return null;
      final text = rawText.length > _maxTextChars
          ? rawText.substring(0, _maxTextChars)
          : rawText;
      final response = await _client
          .post(
            Uri.parse(_url),
            headers: const {'content-type': 'application/json'},
            body: jsonEncode({
              'appUserId': userId,
              'rawText': text,
              // ID asli bisa panjang (`ledger-<uuid>:cat-exp-...`, 40+ karakter):
              // boros token dan sempat ditolak Worker (batas 64). Kirim alias
              // pendek "c0", "c1", ... lalu petakan balasan ke ID asli.
              'categories': [
                for (final (i, c) in categories.indexed)
                  {'id': 'c$i', 'name': c.label},
              ],
            }),
          )
          .timeout(_timeout);
      if (response.statusCode == 429) {
        // 429 juga dipakai pembatas laju per IP ("rate_limited"): itu bukan
        // kuota pengguna, jadi diam saja (heuristik tetap dipakai). Kode lain
        // atau tanpa kode dianggap kuota bulanan (server versi lama).
        final code = _errorCode(response.bodyBytes);
        if (code == 'rate_limited') return null;
        throw AiQuotaExceeded(daily: code == 'daily_limit_exceeded');
      }
      if (response.statusCode != 200) return null;
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      if (json is! Map<String, dynamic>) return null;

      final rawMerchant = json['merchant'];
      var merchant = rawMerchant is String ? rawMerchant.trim() : '';
      if (merchant.length > _maxMerchantChars) {
        merchant = merchant.substring(0, _maxMerchantChars);
      }
      final categoryId = json['categoryId'];
      final remaining = json['remaining'];
      final total = json['total'];
      return AiReceiptExtraction(
        remaining: remaining is int ? remaining : null,
        total: total is int && total > 0 ? total : null,
        date: _parseDate(json['date']),
        merchant: merchant.isEmpty ? null : merchant,
        categoryId: _resolveCategory(categoryId, categories),
      );
    } on AiQuotaExceeded {
      rethrow;
    } catch (_) {
      return null;
    }
  }
}

String? _errorCode(List<int> body) {
  try {
    final json = jsonDecode(utf8.decode(body));
    if (json is Map<String, dynamic> && json['error'] is String) {
      return json['error'] as String;
    }
  } catch (_) {}
  return null;
}

/// `YYYY-MM-DD` yang benar-benar ada di kalender; selain itu null. Server sudah
/// memvalidasi, ini sabuk pengaman kedua.
DateTime? _parseDate(Object? value) {
  if (value is! String) return null;
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (m == null) return null;
  final (y, mo, d) = (int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  final date = DateTime(y, mo, d);
  return date.year == y && date.month == mo && date.day == d ? date : null;
}

/// Memetakan alias balasan server ("c3") kembali ke ID kategori asli; alias di
/// luar daftar (karangan model) menjadi null.
String? _resolveCategory(Object? alias, List<AiCategoryOption> categories) {
  if (alias is! String || !alias.startsWith('c')) return null;
  final i = int.tryParse(alias.substring(1));
  if (i == null || i < 0 || i >= categories.length || 'c$i' != alias) {
    return null;
  }
  return categories[i].id;
}
