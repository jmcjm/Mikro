import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikro/core/audio/mikro_recorder.dart';
import 'package:mikro/core/db/database.dart';
import 'package:mikro/core/models/recording_status.dart';
import 'package:mikro/core/pipeline/processing_pipeline.dart';
import 'package:mikro/core/providers.dart';
import 'package:mikro/features/recorder/recorder_controller.dart';

class FakeRecorder implements MikroRecorder {
  bool permission = true;
  String? startedPath;
  bool stopped = false;
  @override
  String get fileExtension => 'm4a';
  @override
  Future<bool> hasPermission() async => permission;
  @override
  Future<void> start(String path) async {
    startedPath = path;
    File(path).createSync(recursive: true);
  }

  @override
  Future<void> stop() async => stopped = true;
  @override
  Stream<double> amplitude() => const Stream.empty();
  // P1: kontrakt MikroRecorder ma dispose() od rulingu z Taska 8.
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
    db.close();
  });

  test('start ustawia isRecording i sciezke w katalogu recordings', () async {
    final controller = container.read(recorderControllerProvider.notifier);
    await controller.startRecording();
    expect(container.read(recorderControllerProvider).isRecording, isTrue);
    expect(recorder.startedPath, contains('/recordings/'));
    expect(recorder.startedPath, endsWith('.m4a'));
  });

  test('stop zapisuje rekord i enqueue`uje pipeline', () async {
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
  });

  test('brak permission -> lastError, bez startu', () async {
    recorder.permission = false;
    final controller = container.read(recorderControllerProvider.notifier);
    await controller.startRecording();
    expect(container.read(recorderControllerProvider).isRecording, isFalse);
    expect(container.read(recorderControllerProvider).lastError, isNotNull);
  });
}
