import 'dart:async';

import 'package:dompet_pintar/features/voice/voice_recognizer.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mesin palsu: menyimpan callback agar tes bisa memicu galat/status/hasil
/// persis seperti urutan yang terlihat di logcat perangkat nyata.
class _Engine implements SpeechEngine {
  _Engine({this.initOk = true, this.permission = true});

  bool initOk;
  bool permission;
  final listens = <({bool onDevice, String locale})>[];
  int cancels = 0;
  int stops = 0;
  late void Function(String) onError;
  late void Function(String) onStatus;
  void Function(String, bool)? onResult;

  /// Dipanggil tiap `listen`; tes memicu kejadian dari sini.
  void Function(int index, bool onDevice)? script;

  @override
  Future<bool> initialize({
    required void Function(String errorMsg) onError,
    required void Function(String status) onStatus,
  }) async {
    this.onError = onError;
    this.onStatus = onStatus;
    return initOk;
  }

  @override
  Future<bool> get hasPermission async => permission;

  @override
  Future<void> listen({
    required void Function(String words, bool isFinal) onResult,
    required bool onDevice,
    required String localeId,
  }) async {
    this.onResult = onResult;
    listens.add((onDevice: onDevice, locale: localeId));
    final i = listens.length - 1;
    // Seperti plugin: status "listening" lalu kejadian skenario, tidak sinkron.
    scheduleMicrotask(() {
      onStatus('listening');
      script?.call(i, onDevice);
    });
  }

  @override
  Future<void> stop() async => stops++;

  @override
  Future<void> cancel() async => cancels++;
}

SpeechToTextRecognizer _recognizer(_Engine e) => SpeechToTextRecognizer(
  engine: e,
  restartDelay: const Duration(milliseconds: 5),
);

Future<(List<VoiceUpdate>, Object?)> _collect(Stream<VoiceUpdate> s) {
  final updates = <VoiceUpdate>[];
  Object? error;
  final done = Completer<(List<VoiceUpdate>, Object?)>();
  s.listen(
    updates.add,
    onError: (Object e) => error = e,
    onDone: () => done.complete((updates, error)),
  );
  return done.future;
}

VoiceFailure? _failure(Object? e) => e is VoiceException ? e.failure : null;

void main() {
  test(
    'jalur normal: hasil sementara lalu akhir, mode di perangkat dipakai',
    () async {
      final e = _Engine();
      e.script = (i, _) {
        e.onResult!('makan', false);
        e.onResult!('makan siang dua puluh lima ribu', true);
        e.onStatus('done'); // status susulan tidak boleh menggandakan hasil
      };
      final (updates, error) = await _collect(_recognizer(e).listen());
      expect(error, isNull);
      expect(updates.map((u) => (u.text, u.isFinal)), [
        ('makan', false),
        ('makan siang dua puluh lima ribu', true),
      ]);
      expect(e.listens.single, (onDevice: true, locale: 'id_ID'));
    },
  );

  test('REGRESI Xiaomi Pad: galat paket bahasa di perangkat -> ulangi tanpa onDevice, '
      'status "done" dari sesi gagal tidak dianggap "tidak ada suara"', () async {
    final e = _Engine();
    e.script = (i, onDevice) {
      if (onDevice) {
        // Urutan nyata: error 13, lalu plugin menutup sesi lama dengan "done".
        e.onError('error_language_unavailable');
        e.onStatus('notListening');
        e.onStatus('done');
      } else {
        e.onResult!('gajian lima juta', false);
        e.onResult!('gajian lima juta', true);
      }
    };
    final (updates, error) = await _collect(_recognizer(e).listen());
    expect(error, isNull);
    expect(updates.last.text, 'gajian lima juta');
    expect(updates.last.isFinal, isTrue);
    expect(e.listens.map((l) => l.onDevice), [true, false]);
    expect(e.cancels, greaterThan(0)); // sesi lama dibereskan dulu
  });

  test('setelah paket bahasa terbukti tidak ada, sesi berikutnya langsung tanpa onDevice', () async {
    final e = _Engine();
    e.script = (i, onDevice) {
      if (onDevice) {
        e.onError('error_language_not_supported');
      } else {
        e.onResult!('kopi', true);
      }
    };
    final r = _recognizer(e);
    await _collect(r.listen());
    await _collect(r.listen());
    expect(e.listens.map((l) => l.onDevice), [true, false, false]);
  });

  test(
    'galat bahasa juga di mode biasa: tidak tersedia (tidak berputar terus)',
    () async {
      final e = _Engine();
      e.script = (i, onDevice) => e.onError('error_language_unavailable');
      final (updates, error) = await _collect(_recognizer(e).listen());
      expect(updates, isEmpty);
      expect(_failure(error), VoiceFailure.unavailable);
      expect(e.listens.length, 2);
    },
  );

  test('tidak ada kecocokan / timeout bicara = noSpeech', () async {
    for (final msg in ['error_no_match', 'error_speech_timeout']) {
      final e = _Engine();
      e.script = (_, _) => e.onError(msg);
      final (_, error) = await _collect(_recognizer(e).listen());
      expect(_failure(error), VoiceFailure.noSpeech, reason: msg);
    }
  });

  test(
    '"done" tanpa teks = noSpeech; dengan teks sementara = hasil akhir',
    () async {
      final empty = _Engine();
      empty.script = (_, _) => empty.onStatus('done');
      expect(
        _failure((await _collect(_recognizer(empty).listen())).$2),
        VoiceFailure.noSpeech,
      );

      final partial = _Engine();
      partial.script = (_, _) {
        partial.onResult!('beli bensin lima puluh ribu', false);
        partial.onStatus('done');
      };
      final (updates, error) = await _collect(_recognizer(partial).listen());
      expect(error, isNull);
      expect(updates.last.text, 'beli bensin lima puluh ribu');
      expect(updates.last.isFinal, isTrue);
    },
  );

  test('galat setelah ada teks yang terdengar: teks itu dipakai', () async {
    final e = _Engine();
    e.script = (_, _) {
      e.onResult!('kopi dua puluh ribu', false);
      e.onError('error_no_match');
    };
    final (updates, error) = await _collect(_recognizer(e).listen());
    expect(error, isNull);
    expect(
      updates.last,
      isA<VoiceUpdate>().having((u) => u.isFinal, 'isFinal', true),
    );
  });

  test('izin ditolak vs layanan tidak ada', () async {
    final denied = _Engine(initOk: false, permission: false);
    expect(
      _failure((await _collect(_recognizer(denied).listen())).$2),
      VoiceFailure.permissionDenied,
    );
    final missing = _Engine(initOk: false, permission: true);
    expect(
      _failure((await _collect(_recognizer(missing).listen())).$2),
      VoiceFailure.unavailable,
    );
    final perm = _Engine();
    perm.script = (_, _) => perm.onError('error_permission');
    expect(
      _failure((await _collect(_recognizer(perm).listen())).$2),
      VoiceFailure.permissionDenied,
    );
  });

  test('galat jaringan / tak dikenal dipetakan', () async {
    final net = _Engine();
    net.script = (_, _) => net.onError('error_network');
    expect(
      _failure((await _collect(_recognizer(net).listen())).$2),
      VoiceFailure.unavailable,
    );
    final odd = _Engine();
    odd.script = (_, _) => odd.onError('error_unknown (99)');
    expect(
      _failure((await _collect(_recognizer(odd).listen())).$2),
      VoiceFailure.other,
    );
  });

  test(
    'stop() mengakhiri dengan teks yang sudah ada; tanpa teks = noSpeech',
    () async {
      final e = _Engine();
      e.script = (_, _) => e.onResult!('gajian lima juta', false);
      final r = _recognizer(e);
      final done = _collect(r.listen());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await r.stop();
      final (updates, error) = await done;
      expect(error, isNull);
      expect(updates.last.isFinal, isTrue);
      expect(e.stops, 1);

      final silent = _Engine();
      final r2 = _recognizer(silent);
      final done2 = _collect(r2.listen());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await r2.stop();
      expect(_failure((await done2).$2), VoiceFailure.noSpeech);
    },
  );

  test('cancel() menutup tanpa hasil atau galat', () async {
    final e = _Engine();
    final r = _recognizer(e);
    final done = _collect(r.listen());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await r.cancel();
    final (updates, error) = await done;
    expect(updates, isEmpty);
    expect(error, isNull);
    expect(e.cancels, 1);
  });
}
