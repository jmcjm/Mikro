import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikro/core/audio/mikro_recorder.dart';
import 'package:mikro/core/audio/waveform.dart';
import 'package:mikro/core/db/database.dart';
import 'package:mikro/core/models/recording_status.dart';
import 'package:mikro/core/pipeline/processing_pipeline.dart';
import 'package:mikro/core/providers.dart';
import 'package:mikro/features/recorder/recorder_controller.dart';

class FakeRecorder implements MikroRecorder {
  bool permission = true;
  String? startedPath;
  bool stopped = false;
  int startCalls = 0;

  /// Long-lived stream, like real plugin: broadcast, shared,
  /// and DOES NOT end after stop(). Stream.empty() ended immediately, so subscription
  /// was dead before _cleanup could cancel it — and test could not tell one from another.
  final amplitudeController = StreamController<double>.broadcast();

  @override
  String get fileExtension => 'm4a';
  /// When set, hasPermission() waits for its completion. Allows a second startRecording call
  /// to enter precisely into the gap between awaits — where synchronous guard at entry
  /// does not yet see any recording in progress.
  Completer<void>? permissionGate;

  @override
  Future<bool> hasPermission() async {
    if (permissionGate != null) await permissionGate!.future;
    return permission;
  }
  /// When set, start() throws instead of starting recording. Path is remembered
  /// despite error, so test has something to look for on disk.
  Object? startError;

  @override
  Future<void> start(String path) async {
    startCalls++;
    startedPath = path;
    if (startError != null) throw startError!;
    File(path).createSync(recursive: true);
  }

  /// When set, stop() waits for its completion — equivalent of [permissionGate] on stop side.
  /// Allows a second stopRecording call to enter the gap between awaits.
  Completer<void>? stopGate;

  @override
  Future<void> stop() async {
    if (stopGate != null) await stopGate!.future;
    stopped = true;
  }
  @override
  Stream<double> amplitude() => amplitudeController.stream;
  // P1: MikroRecorder contract has dispose() since ruling in Task 8.
  @override
  Future<void> dispose() async {}
}

class FakePipeline implements ProcessingPipeline {
  final enqueued = <String>[];
  @override
  void enqueue(String recordingId) => enqueued.add(recordingId);
  @override
  Future<void> resumePending() async {}
  @override
  Future<void> get idle async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FakeRecorder recorder;
  late FakePipeline pipeline;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    recorder = FakeRecorder();
    pipeline = FakePipeline();
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      recorderProvider.overrideWithValue(recorder),
      pipelineProvider.overrideWithValue(pipeline),
      baseDirProvider.overrideWithValue(Directory.systemTemp.createTempSync('mikro')),
    ]);
  });
  tearDown(() {
    container.dispose();
    recorder.amplitudeController.close();
    db.close();
  });

  test('start sets isRecording and path in recordings directory', () async {
    final controller = container.read(recorderControllerProvider.notifier);
    await controller.startRecording();
    expect(container.read(recorderControllerProvider).isRecording, isTrue);
    expect(recorder.startedPath, contains('/recordings/'));
    expect(recorder.startedPath, endsWith('.m4a'));

    // Second button press during recording must not restart recording.
    await controller.startRecording();
    expect(recorder.startCalls, 1,
        reason: 'repeated start before stop must be ignored');
  });

  test('stop saves record and enqueues pipeline', () async {
    final controller = container.read(recorderControllerProvider.notifier);
    await controller.startRecording();
    await controller.stopRecording();
    expect(container.read(recorderControllerProvider).isRecording, isFalse);
    expect(recorder.stopped, isTrue);
    final all = await db.watchAllWithTags().first;
    expect(all, hasLength(1));
    expect(all.first.recording.status, RecordingStatus.recorded);
    expect(all.first.recording.audioPath, recorder.startedPath);
    expect(pipeline.enqueued, [all.first.recording.id]);

    // Recording duration goes to database and is displayed by library (T11), so it must originate
    // from stopwatch rather than being an arbitrary number.
    final durationMs = all.first.recording.durationMs;
    expect(durationMs, greaterThanOrEqualTo(0));
    expect(durationMs, lessThan(10000),
        reason: 'test run lasts milliseconds, not seconds');
  });

  test('missing permission -> lastError, without start', () async {
    recorder.permission = false;
    final controller = container.read(recorderControllerProvider.notifier);
    await controller.startRecording();
    expect(container.read(recorderControllerProvider).isRecording, isFalse);
    expect(container.read(recorderControllerProvider).lastError, isNotNull);

    // Denial must not permanently lock controller: _starting flag must be released
    // on error path as well. Otherwise a user who grants permission later
    // would never be able to record anything.
    recorder.permission = true;
    await controller.startRecording();
    expect(container.read(recorderControllerProvider).isRecording, isTrue,
        reason: 'after granting permission recording must start');
    expect(recorder.startCalls, 1,
        reason: 'first attempt was rejected by permissions and did not reach start()');
  });

  test('GUARD: amplitude subscription is active during recording and disappears after stop', () async {
    final controller = container.read(recorderControllerProvider.notifier);
    expect(recorder.amplitudeController.hasListener, isFalse,
        reason: 'before start nobody is listening to amplitude');

    await controller.startRecording();
    expect(recorder.amplitudeController.hasListener, isTrue,
        reason: 'during recording controller must listen to amplitude');

    await controller.stopRecording();
    expect(recorder.amplitudeController.hasListener, isFalse,
        reason: 'plugin stream is shared and does not end automatically, '
            'so subscription must be cancelled explicitly');
  });

  test('GUARD: two starts in gap between awaits do not duplicate recording', () async {
    recorder.permissionGate = Completer<void>();
    final controller = container.read(recorderControllerProvider.notifier);

    // Both entries happen BEFORE first one sets isRecording — flag flips
    // only after awaits, so state guard alone does not catch it.
    final firstStart = controller.startRecording();
    final secondStart = controller.startRecording();
    recorder.permissionGate!.complete();
    await Future.wait([firstStart, secondStart]);

    expect(recorder.startCalls, 1,
        reason: 'second entry in async gap must be rejected, otherwise first timer, '
            'subscription and file are orphaned');
  });

  test('GUARD: two stops in gap between awaits do not duplicate recording', () async {
    final controller = container.read(recorderControllerProvider.notifier);
    await controller.startRecording();
    recorder.stopGate = Completer<void>();

    // Both entries happen BEFORE first one clears isRecording — flag clears only
    // after saving to database, so state guard alone does not catch it. Without guard second entry
    // inserts the same ID again and crashes on primary key, inside an unhandled zone.
    final firstStop = controller.stopRecording();
    final secondStop = controller.stopRecording();
    recorder.stopGate!.complete();
    await Future.wait([firstStop, secondStop]);

    expect(await db.pendingRecordings(), hasLength(1),
        reason: 'second entry in async gap must be rejected, otherwise the same entry '
            'goes to database twice');
    expect(pipeline.enqueued, hasLength(1),
        reason: 'pipeline must not receive the same recording twice');
  });

  test('GUARD: failed start leaves neither orphaned directory nor locked controller',
      () async {
    recorder.startError = StateError('mikrofon zajety');
    final controller = container.read(recorderControllerProvider.notifier);

    await controller.startRecording();

    final failedPath = recorder.startedPath!;
    expect(container.read(recorderControllerProvider).isRecording, isFalse);
    expect(container.read(recorderControllerProvider).lastError, isNotNull);
    expect(File(failedPath).parent.existsSync(), isFalse,
        reason: 'directory created for recording must disappear if recording failed to start');

    // Failed start must also not leave controller in locked state.
    recorder.startError = null;
    await controller.startRecording();
    expect(container.read(recorderControllerProvider).isRecording, isTrue,
        reason: 'after failure resolves recording must proceed');
  });

  // --- amplitude envelope (D2f) ---

  /// Samples travel via stream, so after `add()` we must yield to event loop
  /// before controller can observe them.
  Future<void> pushAmplitudes(List<double> values) async {
    for (final v in values) {
      recorder.amplitudeController.add(v);
    }
    await Future<void>.delayed(Duration.zero);
  }

  test('stop saves envelope collected from amplitude samples', () async {
    final controller = container.read(recorderControllerProvider.notifier);
    await controller.startRecording();

    // Quiet first half, loud second — after reduction this must remain visible
    // in bucket shapes rather than blurring into a single value.
    await pushAmplitudes([...List.filled(22, 0.2), ...List.filled(22, 0.8)]);
    await controller.stopRecording();

    final saved = (await db.pendingRecordings()).single;
    final buckets = decodeWaveform(saved.waveform);

    expect(buckets, hasLength(kWaveformBuckets));
    expect(buckets!.first, 0.2);
    expect(buckets.last, 0.8);
    expect(buckets.where((b) => b == 0.2), hasLength(22));
    expect(buckets.where((b) => b == 0.8), hasLength(22));
  });

  test('recording without any samples saves NULL rather than flat line', () async {
    final controller = container.read(recorderControllerProvider.notifier);
    await controller.startRecording();
    await controller.stopRecording();

    final saved = (await db.pendingRecordings()).single;
    expect(saved.waveform, isNull,
        reason: 'no measurement means no waveform — screen should show empty state');
  });

  test('GUARD: subsequent recording does not inherit samples from previous one', () async {
    final controller = container.read(recorderControllerProvider.notifier);

    await controller.startRecording();
    await pushAmplitudes(List.filled(10, 0.9));
    await controller.stopRecording();
    final firstId = (await db.pendingRecordings()).single.id;

    await controller.startRecording();
    await pushAmplitudes(List.filled(10, 0.1));
    await controller.stopRecording();

    final second =
        (await db.pendingRecordings()).firstWhere((r) => r.id != firstId);
    expect(decodeWaveform(second.waveform)!.every((b) => b == 0.1), isTrue,
        reason: 'loud samples from first recording must not leak into second');
  });
}
