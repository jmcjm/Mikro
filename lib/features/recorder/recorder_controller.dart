import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../core/audio/waveform.dart';
import '../../core/providers.dart';

/// Reason why recording could not start. The controller does not know the UI language or
/// BuildContext, so it yields an error kind, which the UI converts into localized text.
enum RecorderErrorKind { micPermission, startFailed }

class RecorderError {
  const RecorderError(this.kind, [this.detail]);

  final RecorderErrorKind kind;

  /// Technical exception description for [RecorderErrorKind.startFailed]; not localized.
  final String? detail;
}

class RecorderState {
  const RecorderState({
    this.isRecording = false,
    this.elapsed = Duration.zero,
    this.amplitude = 0,
    this.lastError,
  });

  final bool isRecording;
  final Duration elapsed;
  final double amplitude;
  final RecorderError? lastError;

  /// Note the deliberate asymmetry: [lastError] is NOT preserved when omitted, unlike every
  /// other field. Any state change that is not itself an error clears the previous one, so a
  /// stale message never outlives the situation that produced it.
  RecorderState copyWith({
    bool? isRecording,
    Duration? elapsed,
    double? amplitude,
    RecorderError? lastError,
  }) =>
      RecorderState(
        isRecording: isRecording ?? this.isRecording,
        elapsed: elapsed ?? this.elapsed,
        amplitude: amplitude ?? this.amplitude,
        lastError: lastError,
      );
}

final recorderControllerProvider =
    NotifierProvider<RecorderController, RecorderState>(RecorderController.new);

class RecorderController extends Notifier<RecorderState> {
  final _stopwatch = Stopwatch();
  Timer? _ticker;

  /// Held from the synchronous entry of [startRecording] until it finishes. The [state] flag
  /// alone is not enough: it only flips after several awaits, so two calls landing in that gap
  /// would both pass the check and race.
  bool _starting = false;

  /// Symmetrical to [_starting], held from synchronous entry into [stopRecording].
  /// The state flag alone is not sufficient: it only clears after the database write,
  /// so two taps in the await window could both proceed and insert the same id twice —
  /// and since no caller awaits this write, a primary key violation would escape as an unhandled exception.
  bool _stopping = false;
  StreamSubscription<double>? _ampSub;
  String? _currentId;
  String? _currentPath;

  /// Successive amplitude readings (0..1) from current recording, one per ~200 ms. On stop,
  /// they are reduced to a waveform saved alongside the recording. An hour of recording is under
  /// 18k numbers, so keeping them in memory is cheaper than writing to disk incrementally.
  final _amplitudeSamples = <double>[];

  @override
  RecorderState build() {
    ref.onDispose(_cleanup);
    return const RecorderState();
  }

  Future<void> startRecording() async {
    if (state.isRecording || _starting) return;
    _starting = true;
    try {
      final recorder = ref.read(recorderProvider);
      if (!await recorder.hasPermission()) {
        state = state.copyWith(
            lastError: const RecorderError(RecorderErrorKind.micPermission));
        return;
      }
      final id = const Uuid().v4();
      final path = p.join(
          ref.read(baseDirProvider).path, 'recordings', id, 'audio.${recorder.fileExtension}');
      await Directory(p.dirname(path)).create(recursive: true);
      try {
        await recorder.start(path);
      } catch (e) {
        // Recording never began, so the directory we just made would stay behind empty.
        try {
          await Directory(p.dirname(path)).delete(recursive: true);
        } catch (_) {
          // Cleanup is best-effort; a leftover directory must not mask the real error.
        }
        state = state.copyWith(
            lastError: RecorderError(RecorderErrorKind.startFailed, '$e'));
        return;
      }
      _currentId = id;
      _currentPath = path;
      _stopwatch
        ..reset()
        ..start();
      _ticker = Timer.periodic(const Duration(milliseconds: 250),
          (_) => state = state.copyWith(isRecording: true, elapsed: _stopwatch.elapsed));
      _amplitudeSamples.clear();
      _ampSub = recorder.amplitude().listen((a) {
        _amplitudeSamples.add(a);
        state = state.copyWith(
            isRecording: true, elapsed: _stopwatch.elapsed, amplitude: a);
      });
      state = const RecorderState(isRecording: true);
    } finally {
      _starting = false;
    }
  }

  Future<void> stopRecording() async {
    if (!state.isRecording || _stopping) return;
    _stopping = true;
    try {
      _cleanup();
      await ref.read(recorderProvider).stop();
      final id = _currentId!;
      // An empty sample list is saved as NULL rather than 44 zeros: a microphone that yielded
      // no samples indicates missing measurements, not measured silence. The details screen distinguishes
      // these two situations and skips waveform bars on NULL.
      final buckets = reduceToBuckets(_amplitudeSamples);
      _amplitudeSamples.clear();
      await ref.read(databaseProvider).insertRecording(
            id: id,
            createdAt: DateTime.now().toUtc(),
            durationMs: _stopwatch.elapsedMilliseconds,
            audioPath: _currentPath!,
            waveform: buckets.isEmpty ? null : encodeWaveform(buckets),
          );
      ref.read(pipelineProvider).enqueue(id);
      _currentId = null;
      _currentPath = null;
      state = const RecorderState();
    } finally {
      _stopping = false;
    }
  }

  void _cleanup() {
    _stopwatch.stop();
    _ticker?.cancel();
    _ticker = null;
    _ampSub?.cancel();
    _ampSub = null;
  }
}
