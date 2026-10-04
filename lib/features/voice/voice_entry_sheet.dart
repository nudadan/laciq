import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/database.dart' show TxType;
import '../../data/providers.dart';
import '../security/app_lock_service.dart' show KeyValueStore;
import 'voice_parser.dart';
import 'voice_recognizer.dart';

const voiceConsentKey = 'voice_input_consent';

/// Penjelasan sebelum izin mikrofon diminta (hanya sekali, diingat). Isinya
/// harus sama dengan kebijakan privasi bagian "Input suara".
Future<bool> ensureVoiceConsent(
  BuildContext context,
  KeyValueStore store,
) async {
  if (await store.read(voiceConsentKey) == 'granted') return true;
  if (!context.mounted) return false;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Catat dengan suara'),
      content: const Text(
        'Suara Anda diubah menjadi teks oleh layanan pengenalan suara bawaan '
        'Android. LaciQ tidak merekam, menyimpan, atau mengirim suara Anda '
        'ke server kami; hanya teks hasilnya yang dipakai untuk mengisi '
        'formulir.\n\n'
        'Bila HP Anda tidak punya model suara offline untuk bahasa '
        'Indonesia, Android dapat mengirim suara ke layanan pengenalan suara '
        'Google untuk dikenali, sesuai pengaturan suara di HP Anda.\n\n'
        'Mikrofon hanya aktif saat Anda menekan tombol mikrofon.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Lanjut'),
        ),
      ],
    ),
  );
  if (ok != true) return false;
  await store.write(voiceConsentKey, 'granted');
  return true;
}

/// Membuka lembar suara; mengembalikan hasil tafsiran bila pengguna memilih
/// "Pakai", atau null bila dibatalkan.
Future<VoiceEntry?> showVoiceEntrySheet(
  BuildContext context, {
  required List<VoiceCategory> Function(TxType type) categoriesFor,
  required List<VoiceHistoryItem> history,
  required String Function(String categoryId) categoryName,
}) {
  return showModalBottomSheet<VoiceEntry>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _VoiceSheet(
      categoriesFor: categoriesFor,
      history: history,
      categoryName: categoryName,
    ),
  );
}

enum _Phase { listening, result, error }

class _VoiceSheet extends ConsumerStatefulWidget {
  const _VoiceSheet({
    required this.categoriesFor,
    required this.history,
    required this.categoryName,
  });

  final List<VoiceCategory> Function(TxType type) categoriesFor;
  final List<VoiceHistoryItem> history;
  final String Function(String categoryId) categoryName;

  @override
  ConsumerState<_VoiceSheet> createState() => _VoiceSheetState();
}

class _VoiceSheetState extends ConsumerState<_VoiceSheet> {
  late final VoiceRecognizer _recognizer = ref.read(voiceRecognizerProvider);
  StreamSubscription<VoiceUpdate>? _sub;
  _Phase _phase = _Phase.listening;
  String _transcript = '';
  VoiceFailure? _failure;
  VoiceEntry? _entry;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _sub?.cancel();
    unawaited(_recognizer.cancel());
    super.dispose();
  }

  void _start() {
    _sub?.cancel();
    setState(() {
      _phase = _Phase.listening;
      _transcript = '';
      _failure = null;
      _entry = null;
    });
    _sub = _recognizer.listen().listen(
      (u) {
        if (!mounted) return;
        setState(() => _transcript = u.text);
        if (u.isFinal) _finishWith(u.text);
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          _phase = _Phase.error;
          _failure = e is VoiceException ? e.failure : VoiceFailure.other;
        });
      },
      onDone: () {
        // Stream selesai tanpa hasil akhir: pakai teks terakhir bila ada.
        if (mounted && _phase == _Phase.listening && _transcript.isNotEmpty) {
          _finishWith(_transcript);
        }
      },
    );
  }

  void _finishWith(String text) {
    if (_phase == _Phase.result) return;
    final entry = parseVoiceEntry(
      text,
      now: DateTime.now(),
      categoriesFor: widget.categoriesFor,
      history: widget.history,
    );
    setState(() {
      _transcript = text;
      _entry = entry;
      _phase = _Phase.result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: switch (_phase) {
            _Phase.listening => _listening(context),
            _Phase.result => _result(context),
            _Phase.error => _error(context),
          },
        ),
      ),
    );
  }

  List<Widget> _listening(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return [
      Icon(Icons.mic_rounded, size: 56, color: scheme.primary),
      const SizedBox(height: 12),
      Text(
        'Mendengarkan…',
        style: text.titleMedium,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 8),
      Text(
        _transcript.isEmpty
            ? 'Ucapkan transaksi Anda, mis. "makan siang dua puluh lima ribu" '
                  'atau "gajian lima juta".'
            : _transcript,
        key: const Key('voice-transcript'),
        style: _transcript.isEmpty ? text.bodyMedium : text.titleLarge,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 20),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: () => unawaited(_recognizer.stop()),
              child: const Text('Selesai'),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _result(BuildContext context) {
    final e = _entry!;
    final text = Theme.of(context).textTheme;
    final palette = context.palette;
    final color = e.type == TxType.income ? palette.income : palette.expense;
    final category = e.categoryId == null
        ? null
        : widget.categoryName(e.categoryId!);
    final date = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(e.date);
    return [
      Text(
        '"$_transcript"',
        key: const Key('voice-transcript'),
        style: text.bodyMedium,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 16),
      Text(
        e.type == TxType.income ? 'Pemasukan' : 'Pengeluaran',
        style: text.labelLarge?.copyWith(color: color),
        textAlign: TextAlign.center,
      ),
      Text(
        e.amount == null ? 'Nominal belum terdengar' : rupiah(e.amount!),
        key: const Key('voice-amount'),
        style: text.headlineMedium?.copyWith(color: color),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 8),
      if (e.note.isNotEmpty) Text(e.note, textAlign: TextAlign.center),
      if (category != null)
        Text(
          'Kategori: $category',
          style: text.bodySmall,
          textAlign: TextAlign.center,
        ),
      Text(date, style: text.bodySmall, textAlign: TextAlign.center),
      if (e.assumedThousands)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'Nominal tanpa satuan dianggap ribuan. Ubah di formulir bila keliru.',
            style: text.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
      const SizedBox(height: 20),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _start,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Ulangi'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(e),
              child: const Text('Pakai'),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _error(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final message = switch (_failure) {
      VoiceFailure.permissionDenied =>
        'Izin mikrofon ditolak. Aktifkan izin Mikrofon untuk LaciQ di '
            'Pengaturan HP > Aplikasi > LaciQ > Izin.',
      VoiceFailure.unavailable =>
        'Pengenalan suara tidak tersedia di HP ini, atau butuh koneksi '
            'internet. Coba lagi nanti.',
      VoiceFailure.noSpeech =>
        'Tidak ada suara yang terdengar. Coba lagi lebih dekat ke mikrofon.',
      _ => 'Pengenalan suara gagal. Coba lagi.',
    };
    return [
      Icon(
        Icons.mic_off_rounded,
        size: 48,
        color: Theme.of(context).colorScheme.error,
      ),
      const SizedBox(height: 12),
      Text(
        message,
        key: const Key('voice-error'),
        style: text.bodyMedium,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 20),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tutup'),
            ),
          ),
          if (_failure != VoiceFailure.permissionDenied) ...[
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _start,
                child: const Text('Coba lagi'),
              ),
            ),
          ],
        ],
      ),
    ];
  }
}
