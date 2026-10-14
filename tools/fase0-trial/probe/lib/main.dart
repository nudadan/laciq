// Probe Fase 0 trial Ultimate: menampilkan (dan mencatat ke logcat dengan awalan FASE0|)
//  - ANDROID_ID perangkat (butir 4: bertahan setelah uninstall/reinstall?)
//  - ID pengguna anonim RevenueCat (berubah setelah reinstall: bukti mengapa kunci trial
//    tidak boleh memakai ID ini)
//  - entitlement aktif beserta store dan kedaluwarsanya (butir 2: hibah promosional terlihat?)
// Kunci publik SDK diberikan lewat --dart-define=RC_API_KEY=... oleh run-probe.sh.
import 'package:android_id/android_id.dart';
import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

const _apiKey = String.fromEnvironment('RC_API_KEY');

void log(String s) => debugPrint('FASE0|$s');

void main() => runApp(const MaterialApp(home: ProbePage()));

class ProbePage extends StatefulWidget {
  const ProbePage({super.key});

  @override
  State<ProbePage> createState() => _ProbePageState();
}

class _ProbePageState extends State<ProbePage> {
  String _androidId = '...';
  String _appUserId = '...';
  String _entitlements = '(belum dimuat)';
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final id = await const AndroidId().getId();
      setState(() => _androidId = id ?? '(null)');
      log('ANDROID_ID=$id');
    } catch (e) {
      setState(() => _error = 'android_id: $e');
      log('ANDROID_ID_ERROR=$e');
    }
    try {
      if (_apiKey.isEmpty) throw StateError('RC_API_KEY kosong');
      await Purchases.configure(PurchasesConfiguration(_apiKey));
      final uid = await Purchases.appUserID;
      setState(() => _appUserId = uid);
      log('APP_USER_ID=$uid');
      await _reload();
    } catch (e) {
      setState(() => _error = 'RevenueCat: $e');
      log('REVENUECAT_ERROR=$e');
    }
  }

  Future<void> _reload() async {
    try {
      await Purchases.invalidateCustomerInfoCache();
      final info = await Purchases.getCustomerInfo();
      final lines = <String>[];
      for (final e in info.entitlements.all.values) {
        lines.add(
          '${e.identifier}: aktif=${e.isActive} store=${e.store.name} '
          'produk=${e.productIdentifier} berakhir=${e.expirationDate}',
        );
      }
      final text = lines.isEmpty ? '(tidak ada entitlement)' : lines.join('\n');
      setState(() {
        _entitlements = text;
        _error = null;
      });
      log('ENTITLEMENTS_BEGIN');
      for (final l in lines) {
        log('ENT|$l');
      }
      log('ENTITLEMENTS_END count=${lines.length}');
    } catch (e) {
      setState(() => _error = 'getCustomerInfo: $e');
      log('CUSTOMERINFO_ERROR=$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Probe Fase 0')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('ANDROID_ID', style: TextStyle(fontWeight: FontWeight.bold)),
          SelectableText(_androidId),
          const SizedBox(height: 16),
          const Text('ID pengguna RevenueCat', style: TextStyle(fontWeight: FontWeight.bold)),
          SelectableText(_appUserId),
          const SizedBox(height: 16),
          const Text('Entitlement', style: TextStyle(fontWeight: FontWeight.bold)),
          SelectableText(_entitlements),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 24),
          FilledButton(onPressed: _reload, child: const Text('Muat ulang')),
        ],
      ),
    );
  }
}
