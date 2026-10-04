import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../data/insights.dart';
import '../subscription/subscription_status.dart';
import 'ai_config.dart';
import 'ai_extraction_service.dart' show AiQuotaExceeded;

class AiNarrative {
  const AiNarrative({required this.summary, this.remaining});
  final String summary;

  /// Sisa ringkasan AI bulan ini menurut server; null bila tidak dikirim.
  final int? remaining;
}

/// Ringkasan laporan bulanan dengan AI (fitur Ultimate). Hanya ANGKA agregat
/// yang dikirim (lihat [aiReportPayload]); gagal apa pun selain kuota
/// mengembalikan null supaya halaman laporan tetap berguna tanpa AI.
abstract interface class AiReportService {
  Future<AiNarrative?> narrate(MonthlyReport report);
}

const _maxCategories = 6;
const _maxBudgets = 5;

/// Isi permintaan ke server. SENGAJA tidak memuat catatan, nama toko, tanggal
/// transaksi, ID, atau foto: hanya total, nama kategori beserta totalnya, dan
/// persen anggaran. Dipisah agar mudah diuji bahwa tidak ada yang bocor.
Map<String, Object?> aiReportPayload(MonthlyReport r) {
  final month =
      '${r.month.year.toString().padLeft(4, '0')}-'
      '${r.month.month.toString().padLeft(2, '0')}';
  return {
    'month': month,
    'daysElapsed': r.daysElapsed,
    'daysInMonth': r.daysInMonth,
    'income': r.income,
    'expense': r.expense,
    'previousExpense': r.previousExpense,
    'projectedExpense': r.projectedExpense,
    'categories': [
      for (final c in r.categories.take(_maxCategories))
        {'name': c.name, 'total': c.total, 'previousTotal': c.previousTotal},
    ],
    'budgets': [
      for (final b in r.budgets.take(_maxBudgets))
        {'name': b.name, 'percent': b.percent},
    ],
  };
}

class HttpAiReportService implements AiReportService {
  HttpAiReportService(
    this._subscription, {
    http.Client? client,
    String? url,
    this._timeout = const Duration(seconds: 25),
  }) : _client = client ?? http.Client(),
       _url = url ?? kAiReportUrl;

  final SubscriptionStatus _subscription;
  final http.Client _client;
  final String _url;
  final Duration _timeout;

  static const _maxSummaryChars = 1200;

  @override
  Future<AiNarrative?> narrate(MonthlyReport report) async {
    if (_url.isEmpty || report.daysElapsed < 1) return null;
    try {
      final userId = await _subscription.appUserId();
      if (userId == null) return null;
      final response = await _client
          .post(
            Uri.parse(_url),
            headers: const {'content-type': 'application/json'},
            body: jsonEncode({
              'appUserId': userId,
              'report': aiReportPayload(report),
            }),
          )
          .timeout(_timeout);
      if (response.statusCode == 429) {
        final code = _errorCode(response.bodyBytes);
        // Pembatas laju per IP bukan kuota pengguna.
        if (code == 'rate_limited') return null;
        throw AiQuotaExceeded(daily: code == 'daily_limit_exceeded');
      }
      if (response.statusCode != 200) return null;
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      if (json is! Map<String, dynamic>) return null;
      final summary = json['summary'];
      if (summary is! String) return null;
      var text = summary.trim();
      if (text.isEmpty) return null;
      if (text.length > _maxSummaryChars) {
        text = text.substring(0, _maxSummaryChars);
      }
      final remaining = json['remaining'];
      return AiNarrative(
        summary: text,
        remaining: remaining is int ? remaining : null,
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
