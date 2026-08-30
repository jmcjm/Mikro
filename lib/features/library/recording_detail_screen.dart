import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/db/database.dart';
import '../../core/models/recording_status.dart';
import '../../core/providers.dart';
import '../../core/util/format.dart';
import 'library_styles.dart';

class RecordingDetailScreen extends ConsumerStatefulWidget {
  const RecordingDetailScreen({super.key, required this.recordingId});

  final String recordingId;

  @override
  ConsumerState<RecordingDetailScreen> createState() => _RecordingDetailScreenState();
}

class _RecordingDetailScreenState extends ConsumerState<RecordingDetailScreen> {
  final _player = AudioPlayer();
  Duration _position = Duration.zero;
  Duration _total = Duration.zero;
  final _subs = <StreamSubscription<dynamic>>[];

  /// Single source of truth for the transport button. `play(source)` re-sets the source and
  /// restarts from zero, so it may only be used when nothing is loaded yet or playback has
  /// finished; a paused player must be continued with `resume()`.
  PlayerState _playerState = PlayerState.stopped;

  /// Position being dragged on the slider. While non-null the slider follows the finger and
  /// ignores incoming position events; the actual seek happens once, on release.
  double? _dragMs;

  bool get _playing => _playerState == PlayerState.playing;

  @override
  void initState() {
    super.initState();
    _subs.add(_player.onPositionChanged.listen((p) {
      if (_dragMs != null) return; // przeciaganie ma pierwszenstwo nad strumieniem
      setState(() => _position = p);
    }));
    _subs.add(_player.onDurationChanged.listen((d) => setState(() => _total = d)));
    _subs.add(_player.onPlayerStateChanged.listen((s) => setState(() {
          _playerState = s;
          // Po zakonczeniu nagrania suwak wraca na poczatek, zeby stan wizualny zgadzal sie
          // z tym, co zrobi kolejne wcisniecie przycisku: odtworzenie od zera.
          if (s == PlayerState.completed) _position = Duration.zero;
        })));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  Future<void> _delete(Recording recording) async {
    // Zaleznosci z ref pobierane PRZED pierwszym awaitem. Gdyby widget zostal zutylizowany
    // w trakcie dialogu, pozniejsze ref.read rzucaloby "used after dispose" — i to jako
    // nieobsluzony wyjatek, bo nikt tego nie lapie.
    final db = ref.read(databaseProvider);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Usunąć nagranie?'),
        content: const Text('Plik audio i transkrypt zostaną trwale usunięte.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Anuluj')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Usuń')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await _player.stop();
    if (!mounted) return;

    try {
      await db.deleteRecording(recording.id);
      // Katalog kasujemy dopiero po udanym usunieciu z bazy. Gdy to zawiedzie, na dysku
      // zostaje osierocone audio — mniejsze zlo niz wpis w bazie bez pliku. Dlatego blad
      // sprzatania nie przerywa zamkniecia ekranu.
      try {
        final dir = File(recording.audioPath).parent;
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      } catch (_) {
        // Sprzatanie plikow jest best-effort.
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nie udało się usunąć nagrania.')),
      );
    }
  }

  Future<void> _copyTranscript(String transcript, {required String message}) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: transcript));
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final all = ref.watch(recordingsStreamProvider).value ?? [];
    final match = all.where((r) => r.recording.id == widget.recordingId).toList();
    if (match.isEmpty) return const Scaffold(body: Center(child: Text('Nagranie usunięte.')));
    final item = match.first;
    final r = item.recording;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: scheme.surface,
        leading: IconButton(
          icon: Icon(Symbols.arrow_back_rounded, fill: 1, color: scheme.onSurface),
          tooltip: 'Wstecz',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Nagranie',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
        actions: [
          IconButton(
            icon: Icon(Symbols.delete_rounded, fill: 1, color: scheme.onSurfaceVariant),
            tooltip: 'Usuń',
            onPressed: () => _delete(r),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _playerCard(r),
            if (item.tags.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [for (final t in item.tags) TagChip(label: t)],
              ),
            ],
            const SizedBox(height: 16),
            Expanded(child: _content(r)),
          ],
        ),
      ),
    );
  }

  /// Karta odtwarzania: data, status, przycisk transportu i suwak pozycji.
  ///
  /// Makieta ma nad transportem pasek 40 slupkow przebiegu. Aplikacja nie zapisuje obwiedni
  /// amplitudy, wiec nie ma z czego go narysowac — blok jest swiadomie pominiety i wchodzi
  /// tutaj, miedzy naglowek a transport, gdy nagrywanie zacznie te dane utrwalac.
  Widget _playerCard(Recording r) {
    final scheme = Theme.of(context).colorScheme;
    final position = _dragMs == null ? _position : Duration(milliseconds: _dragMs!.round());
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Jak na karcie w bibliotece: przy ciasnocie skraca sie data, nie odznaka.
              Expanded(
                child: Text(
                  formatDateTime(r.createdAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: monoStyle(size: 13, color: scheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(status: r.status, showIcon: false),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Material(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () async {
                    switch (_playerState) {
                      case PlayerState.playing:
                        await _player.pause();
                      case PlayerState.paused:
                        // Wznowienie od miejsca pauzy — play(source) wczytalby zrodlo od nowa.
                        await _player.resume();
                      case PlayerState.stopped:
                      case PlayerState.completed:
                      case PlayerState.disposed:
                        await _player.play(DeviceFileSource(r.audioPath));
                    }
                  },
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: Icon(
                      _playing ? Symbols.pause_rounded : Symbols.play_arrow_rounded,
                      fill: 1,
                      size: 32,
                      color: scheme.onPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 4,
                        activeTrackColor: scheme.primary,
                        inactiveTrackColor: scheme.outlineVariant,
                        thumbColor: scheme.primary,
                        thumbShape: _BarThumbShape(scheme.primary),
                        overlayShape: SliderComponentShape.noOverlay,
                        padding: EdgeInsets.zero,
                      ),
                      child: Slider(
                        max: _total.inMilliseconds.toDouble().clamp(1, double.infinity),
                        value: _dragMs ??
                            _position.inMilliseconds
                                .toDouble()
                                .clamp(0, _total.inMilliseconds.toDouble()),
                        onChanged: (v) => setState(() => _dragMs = v),
                        onChangeEnd: (v) async {
                          await _player.seek(Duration(milliseconds: v.round()));
                          if (mounted) {
                            setState(() {
                              _position = Duration(milliseconds: v.round());
                              _dragMs = null; // od teraz znowu prowadzi onPositionChanged
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(formatDuration(position),
                            style: tabularStyle(size: 12, color: scheme.onSurfaceVariant)),
                        Text(formatDuration(Duration(milliseconds: r.durationMs)),
                            style: tabularStyle(size: 12, color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Dolna czesc ekranu: banner bledu, oczekiwanie na transkrypcje albo gotowy transkrypt.
  Widget _content(Recording r) {
    if (r.status == RecordingStatus.error) return _errorBanner(r);
    return _transcriptCard(r);
  }

  Widget _errorBanner(Recording r) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Symbols.error_rounded, fill: 1, size: 24, color: scheme.error),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.errorMessage ?? 'Nieznany błąd',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: scheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ErrorActionButton(
                    label: 'Ponów przetwarzanie',
                    onPressed: () => ref.read(pipelineProvider).enqueue(r.id),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _transcriptCard(Recording r) {
    final scheme = Theme.of(context).colorScheme;
    final transcript = r.transcript;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'TRANSKRYPCJA',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              if (transcript != null)
                IconButton(
                  icon: Icon(Symbols.content_copy_rounded,
                      fill: 1, size: 20, color: scheme.onSurfaceVariant),
                  tooltip: 'Kopiuj transkrypt',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _copyTranscript(transcript, message: 'Skopiowano.'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: transcript == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          statusLabel(r.status),
                          style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    child: SelectableText(
                      transcript,
                      style: TextStyle(
                        fontSize: 16,
                        height: 26 / 16,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
          ),
          if (r.providerUsed != null) ...[
            const SizedBox(height: 12),
            Text('model: ${r.providerUsed}',
                style: monoStyle(size: 13, color: scheme.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}

/// Uchwyt suwaka z makiety: pionowy pasek 4x14 o zaokraglonych rogach, zamiast domyslnego
/// okraglego uchwytu Material.
class _BarThumbShape extends SliderComponentShape {
  const _BarThumbShape(this.color);

  /// Kolor wprost, a nie z `sliderTheme.thumbColor` — to pole jest nullowalne, a uchwyt nie ma
  /// sensownej wartosci awaryjnej poza rola schematu, ktora i tak podaje wolajacy.
  final Color color;

  static const _size = Size(4, 14);

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => _size;

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    context.canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: _size.width, height: _size.height),
        const Radius.circular(2),
      ),
      Paint()..color = color,
    );
  }
}
