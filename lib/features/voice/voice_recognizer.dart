import 'dart:async';

import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Pengenalan suara memakai layanan bawaan Android (lewat `speech_to_text`).
/// LaciQ tidak merekam, menyimpan, atau mengirim audio ke server kami: audio
/// hanya diterima layanan suara sistem, dan hanya teks hasilnya yang kembali.
/// Dibungkus antarmuka agar tes tidak menyentuh mikrofon sungguhan.

enum VoiceFailure { permissionDenied, unavailable, noSpeech, other }

class VoiceException implements Exception {
  const VoiceException(this.failure);
  final VoiceFailure failure;

  @override
  String toString() => 'VoiceException($failure)';
}

class VoiceUpdate {
  const VoiceUpdate(this.text, {required this.isFinal});
  final String text;
  final bool isFinal;
}

abstract interface class VoiceRecognizer {
  /// Mulai mendengarkan. Stream mengirim hasil sementara lalu satu hasil akhir,
  /// kemudian ditutup. Kegagalan datang sebagai [VoiceException] di stream.
  Stream<VoiceUpdate> listen({String localeId = 'id_ID'});

  /// Berhenti mendengarkan dan mengakhiri dengan teks yang sudah terdengar.
  Future<void> stop();

  /// Membatalkan tanpa hasil.
  Future<void> cancel();
}

/// Lapisan tipis di atas plugin `speech_to_text`, agar mesin status
/// [SpeechToTextRecognizer] bisa diuji dengan mesin palsu.
abstract interface class SpeechEngine {
  /// Menyiapkan layanan; false bila tidak ada layanan atau izin ditolak.
  Future<bool> initialize({
    required void Function(String errorMsg) onError,
    required void Function(String status) onStatus,
  });

  Future<bool> get hasPermission;

  Future<void> listen({
    required void Function(String words, bool isFinal) onResult,
    required bool onDevice,
    required String localeId,
  });

  Future<void> stop();
  Future<void> cancel();
}

class PluginSpeechEngine implements SpeechEngine {
  PluginSpeechEngine({SpeechToText? speech})
    : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;

  @override
  Future<bool> initialize({
    required void Function(String errorMsg) onError,
    required void Function(String status) onStatus,
  }) => _speech.initialize(
    onError: (SpeechRecognitionError e) => onError(e.errorMsg),
    onStatus: onStatus,
    options: [SpeechToText.androidNoBluetooth],
  );

  @override
  Future<bool> get hasPermission => _speech.hasPermission;

  @override
  Future<void> listen({
    required void Function(String words, bool isFinal) onResult,
    required bool onDevice,
    required String localeId,
  }) => _speech.listen(
    onResult: (SpeechRecognitionResult r) =>
        onResult(r.recognizedWords, r.finalResult),
    listenOptions: SpeechListenOptions(
      partialResults: true,
      onDevice: onDevice,
      cancelOnError: true,
      listenMode: ListenMode.confirmation,
      localeId: localeId,
      listenFor: const Duration(seconds: 20),
      pauseFor: const Duration(seconds: 3),
    ),
  );

  @override
  Future<void> stop() => _speech.stop();

  @override
  Future<void> cancel() => _speech.cancel();
}

class SpeechToTextRecognizer implements VoiceRecognizer {
  SpeechToTextRecognizer({
    SpeechEngine? engine,
    this.restartDelay = const Duration(milliseconds: 500),
  }) : _engine = engine ?? PluginSpeechEngine();

  final SpeechEngine _engine;

  /// Jeda sebelum mengulang tanpa mode di perangkat. Sesi yang gagal masih
  /// dibereskan oleh plugin (`cancelOnError`); memulai sesi baru terlalu cepat
  /// ikut dibatalkan olehnya dan hasilnya salah dikira "tidak ada suara"
  /// (terbukti di Xiaomi Pad, 2026-10-04).
  final Duration restartDelay;

  StreamController<VoiceUpdate>? _out;
  String _locale = 'id_ID';
  String _last = '';
  bool _finalSent = false;

  /// Layanan di perangkat tidak punya paket bahasa: lewati mode di perangkat
  /// untuk sisa umur objek ini, supaya "Coba lagi" tidak gagal dulu tiap kali.
  bool _onDeviceUnavailable = false;

  /// Sedang berpindah dari mode di perangkat ke mode biasa: status dan galat
  /// dari sesi lama diabaikan sampai sesi baru benar-benar mendengarkan.
  bool _restarting = false;

  @override
  Stream<VoiceUpdate> listen({String localeId = 'id_ID'}) {
    _out?.close();
    final out = StreamController<VoiceUpdate>();
    _out = out;
    _locale = localeId;
    _last = '';
    _finalSent = false;
    _restarting = false;
    unawaited(_begin(out));
    return out.stream;
  }

  Future<void> _begin(StreamController<VoiceUpdate> out) async {
    try {
      final ok = await _engine.initialize(
        onError: _onError,
        onStatus: _onStatus,
      );
      if (out.isClosed) return;
      if (!ok) {
        final granted = await _engine.hasPermission;
        _finish(
          failure: granted
              ? VoiceFailure.unavailable
              : VoiceFailure.permissionDenied,
        );
        return;
      }
      await _startListening(onDevice: !_onDeviceUnavailable);
    } catch (_) {
      _finish(failure: VoiceFailure.other);
    }
  }

  /// Utamakan pengenalan di perangkat (audio tidak keluar dari HP). Bila
  /// layanan tidak punya paket bahasa Indonesia offline (galat bahasa),
  /// [_onError] mengulang sekali tanpa `onDevice`; pengguna sudah diberi tahu
  /// hal itu di dialog izin.
  Future<void> _startListening({required bool onDevice}) {
    return _engine.listen(
      onResult: _onResult,
      onDevice: onDevice,
      localeId: _locale,
    );
  }

  void _onResult(String words, bool isFinal) {
    final out = _out;
    if (out == null || out.isClosed) return;
    _restarting = false; // sesi baru sudah menghasilkan teks
    _last = words;
    out.add(VoiceUpdate(_last, isFinal: isFinal));
    if (isFinal) {
      _finalSent = true;
      _finish();
    }
  }

  void _onStatus(String status) {
    if (status == SpeechToText.listeningStatus) {
      _restarting = false;
      return;
    }
    if (_restarting) return;
    // 'done' tanpa hasil akhir: pakai teks terakhir bila ada.
    if (status != SpeechToText.doneStatus) return;
    _finish(failure: _last.trim().isEmpty ? VoiceFailure.noSpeech : null);
  }

  void _onError(String msg) {
    if (_restarting) return;
    final languageProblem =
        msg == 'error_language_unavailable' ||
        msg == 'error_language_not_supported';
    if (languageProblem && !_onDeviceUnavailable) {
      _onDeviceUnavailable = true;
      _restarting = true;
      unawaited(_restartOnline());
      return;
    }
    if (_last.trim().isNotEmpty) {
      _finish(); // ada teks yang sudah terdengar: pakai itu
      return;
    }
    _finish(
      failure: switch (msg) {
        'error_no_match' || 'error_speech_timeout' => VoiceFailure.noSpeech,
        'error_permission' => VoiceFailure.permissionDenied,
        'error_network' ||
        'error_network_timeout' ||
        'error_server' ||
        'error_language_unavailable' ||
        'error_language_not_supported' => VoiceFailure.unavailable,
        _ => VoiceFailure.other,
      },
    );
  }

  Future<void> _restartOnline() async {
    try {
      await _engine.cancel();
      await Future<void>.delayed(restartDelay);
      final out = _out;
      if (out == null || out.isClosed) return;
      await _startListening(onDevice: false);
    } catch (_) {
      _restarting = false;
      _finish(failure: VoiceFailure.other);
    }
  }

  /// Menutup stream sekali saja; [failure] null = selesai normal (menyerahkan
  /// teks terakhir sebagai hasil akhir bila belum dikirim).
  void _finish({VoiceFailure? failure}) {
    final out = _out;
    if (out == null || out.isClosed) return;
    if (failure != null) {
      out.addError(VoiceException(failure));
    } else if (!_finalSent && _last.trim().isNotEmpty) {
      out.add(VoiceUpdate(_last, isFinal: true));
    }
    _out = null;
    out.close();
  }

  @override
  Future<void> stop() async {
    try {
      await _engine.stop();
    } catch (_) {}
    _finish(failure: _last.trim().isEmpty ? VoiceFailure.noSpeech : null);
  }

  @override
  Future<void> cancel() async {
    final out = _out;
    _out = null;
    _restarting = false;
    if (out != null && !out.isClosed) await out.close();
    try {
      await _engine.cancel();
    } catch (_) {}
  }
}
