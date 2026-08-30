import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/models/recording_status.dart';
import '../../core/providers.dart';
import '../../core/util/format.dart';

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
    await ref.read(databaseProvider).deleteRecording(recording.id);
    final dir = File(recording.audioPath).parent;
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(recordingsStreamProvider).value ?? [];
    final match = all.where((r) => r.recording.id == widget.recordingId).toList();
    if (match.isEmpty) return const Scaffold(body: Center(child: Text('Nagranie usunięte.')));
    final item = match.first;
    final r = item.recording;
    return Scaffold(
      appBar: AppBar(
        title: Text(formatDateTime(r.createdAt)),
        actions: [
          if (r.transcript != null)
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: 'Kopiuj transkrypt',
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: r.transcript!));
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('Skopiowano.')));
                }
              },
            ),
          IconButton(
              icon: const Icon(Icons.delete), tooltip: 'Usuń', onPressed: () => _delete(r)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            IconButton.filled(
              iconSize: 36,
              icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
              onPressed: () async {
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
            ),
            Expanded(
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
            Text('${formatDuration(_dragMs == null ? _position : Duration(milliseconds: _dragMs!.round()))}'
                ' / ${formatDuration(Duration(milliseconds: r.durationMs))}'),
          ]),
          const SizedBox(height: 8),
          if (item.tags.isNotEmpty)
            Wrap(spacing: 4, children: [for (final t in item.tags) Chip(label: Text(t))]),
          const SizedBox(height: 16),
          if (r.status == RecordingStatus.error) ...[
            Text(r.errorMessage ?? 'Nieznany błąd',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 8),
            FilledButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Ponów przetwarzanie'),
              onPressed: () => ref.read(pipelineProvider).enqueue(r.id),
            ),
          ] else if (r.transcript == null)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else
            SelectableText(r.transcript!, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
