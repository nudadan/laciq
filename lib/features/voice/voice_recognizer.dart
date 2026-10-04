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

class SpeechToTextRecognizer implements VoiceRecognizer {
  SpeechToTextRecognizer({SpeechToText? speech})
    : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;
  StreamController<VoiceUpdate>? _out;
  String _locale = 'id_ID';
  String _last = '';
  bool _retriedOnline = false;
  bool _finalSent = false;

  @override
  Stream<VoiceUpdate> listen({String localeId = 'id_ID'}) {
    _out?.close();
    final out = StreamController<VoiceUpdate>();
    _out = out;
    _locale = localeId;
    _last = '';
    _retriedOnline = false;
    _finalSent = false;
    unawaited(_begin(out));
    return out.stream;
  }

  Future<void> _begin(StreamController<VoiceUpdate> out) async {
    try {
      final ok = await _speech.initialize(
        onError: _onError,
        onStatus: _onStatus,
        options: [SpeechToText.androidNoBluetooth],
      );
      if (out.isClosed) return;
      if (!ok) {
        final granted = await _speech.hasPermission;
        _finish(
          failure: granted
              ? VoiceFailure.unavailable
              : VoiceFailure.permissionDenied,
        );
        return;
      }
      await _startListening(onDevice: true);
    } catch (_) {
      _finish(failure: VoiceFailure.other);
    }
  }

  /// Utamakan pengenalan di perangkat (audio tidak keluar dari HP). Bila HP
  /// tidak punya model offline untuk bahasa ini, [_onError] mengulang sekali
  /// tanpa `onDevice`; pengguna sudah diberi tahu hal itu di dialog izin.
  Future<void> _startListening({required bool onDevice}) {
    return _speech.listen(
      onResult: _onResult,
      listenOptions: SpeechListenOptions(
        partialResults: true,
        onDevice: onDevice,
        cancelOnError: true,
        listenMode: ListenMode.confirmation,
        localeId: _locale,
        listenFor: const Duration(seconds: 20),
        pauseFor: const Duration(seconds: 3),
      ),
    );
  }

  void _onResult(SpeechRecognitionResult r) {
    final out = _out;
    if (out == null || out.isClosed) return;
    _last = r.recognizedWords;
    out.add(VoiceUpdate(_last, isFinal: r.finalResult));
    if (r.finalResult) {
      _finalSent = true;
      _finish();
    }
  }

  void _onStatus(String status) {
    // 'done' tanpa hasil akhir: pakai teks terakhir bila ada.
    if (status != SpeechToText.doneStatus) return;
    _finish(failure: _last.trim().isEmpty ? VoiceFailure.noSpeech : null);
  }

  void _onError(SpeechRecognitionError e) {
    final msg = e.errorMsg;
    if (!_retriedOnline && msg.contains('language')) {
      _retriedOnline = true;
      unawaited(_startListening(onDevice: false));
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
        'error_server' => VoiceFailure.unavailable,
        _ => VoiceFailure.other,
      },
    );
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
      await _speech.stop();
    } catch (_) {}
    _finish(failure: _last.trim().isEmpty ? VoiceFailure.noSpeech : null);
  }

  @override
  Future<void> cancel() async {
    final out = _out;
    _out = null;
    if (out != null && !out.isClosed) await out.close();
    try {
      await _speech.cancel();
    } catch (_) {}
  }
}
