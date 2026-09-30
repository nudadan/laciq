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
  const AiReceiptExtraction({this.merchant, this.categoryId});
  final String? merchant;
  final String? categoryId;
}

/// Kuota scan AI bulan ini habis (server membalas 429).
class AiQuotaExceeded implements Exception {
  const AiQuotaExceeded();
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
              'categories': [
                for (final c in categories) {'id': c.id, 'name': c.label},
              ],
            }),
          )
          .timeout(_timeout);
      if (response.statusCode == 429) throw const AiQuotaExceeded();
      if (response.statusCode != 200) return null;
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      if (json is! Map<String, dynamic>) return null;

      final rawMerchant = json['merchant'];
      var merchant = rawMerchant is String ? rawMerchant.trim() : '';
      if (merchant.length > _maxMerchantChars) {
        merchant = merchant.substring(0, _maxMerchantChars);
      }
      final categoryId = json['categoryId'];
      return AiReceiptExtraction(
        merchant: merchant.isEmpty ? null : merchant,
        categoryId:
            categoryId is String && categories.any((c) => c.id == categoryId)
            ? categoryId
            : null,
      );
    } on AiQuotaExceeded {
      rethrow;
    } catch (_) {
      return null;
    }
  }
}
