import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../core/providers.dart';

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
  final String? lastError;

  RecorderState copyWith({bool? isRecording, Duration? elapsed, double? amplitude, String? lastError}) =>
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
  StreamSubscription<double>? _ampSub;
  String? _currentId;
  String? _currentPath;

  @override
  RecorderState build() {
    ref.onDispose(_cleanup);
    return const RecorderState();
  }

  Future<void> startRecording() async {
    if (state.isRecording) return;
    final recorder = ref.read(recorderProvider);
    if (!await recorder.hasPermission()) {
      state = state.copyWith(lastError: 'Brak uprawnień do mikrofonu.');
      return;
    }
    final id = const Uuid().v4();
    final path = p.join(
        ref.read(baseDirProvider).path, 'recordings', id, 'audio.${recorder.fileExtension}');
    await Directory(p.dirname(path)).create(recursive: true);
    try {
      await recorder.start(path);
    } catch (e) {
      state = state.copyWith(lastError: 'Nie udało się uruchomić nagrywania: $e');
      return;
    }
    _currentId = id;
    _currentPath = path;
    _stopwatch
      ..reset()
      ..start();
    _ticker = Timer.periodic(const Duration(milliseconds: 250),
        (_) => state = state.copyWith(isRecording: true, elapsed: _stopwatch.elapsed));
    _ampSub = recorder.amplitude().listen((a) => state = state.copyWith(
        isRecording: true, elapsed: _stopwatch.elapsed, amplitude: a));
    state = const RecorderState(isRecording: true);
  }

  Future<void> stopRecording() async {
    if (!state.isRecording) return;
    _cleanup();
    await ref.read(recorderProvider).stop();
    final id = _currentId!;
    await ref.read(databaseProvider).insertRecording(
          id: id,
          createdAt: DateTime.now().toUtc(),
          durationMs: _stopwatch.elapsedMilliseconds,
          audioPath: _currentPath!,
        );
    ref.read(pipelineProvider).enqueue(id);
    _currentId = null;
    _currentPath = null;
    state = const RecorderState();
  }

  void _cleanup() {
    _stopwatch.stop();
    _ticker?.cancel();
    _ticker = null;
    _ampSub?.cancel();
    _ampSub = null;
  }
}
