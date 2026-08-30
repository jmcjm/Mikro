import 'dart:async';
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
  int startCalls = 0;

  /// Strumien dlugozyjacy, jak u prawdziwego pluginu: jest broadcastem, wspoldzielonym
  /// i NIE konczy sie po stop(). Stream.empty() konczyl sie natychmiast, wiec subskrypcja
  /// byla martwa zanim _cleanup zdazyl ja anulowac — i test nie odroznial jednego od drugiego.
  final amplitudeController = StreamController<double>.broadcast();

  @override
  String get fileExtension => 'm4a';
  /// Gdy ustawiona, hasPermission() czeka na jej domkniecie. Pozwala wejsc drugim wywolaniem
  /// startRecording dokladnie w luke miedzy awaitami — tam, gdzie synchroniczny guard na
  /// wejsciu jeszcze nie widzi zadnego nagrania w toku.
  Completer<void>? permissionGate;

  @override
  Future<bool> hasPermission() async {
    if (permissionGate != null) await permissionGate!.future;
    return permission;
  }
  @override
  Future<void> start(String path) async {
    startCalls++;
    startedPath = path;
    File(path).createSync(recursive: true);
  }

  @override
  Future<void> stop() async => stopped = true;
  @override
  Stream<double> amplitude() => amplitudeController.stream;
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
    recorder.amplitudeController.close();
    db.close();
  });

  test('start ustawia isRecording i sciezke w katalogu recordings', () async {
    final controller = container.read(recorderControllerProvider.notifier);
    await controller.startRecording();
    expect(container.read(recorderControllerProvider).isRecording, isTrue);
    expect(recorder.startedPath, contains('/recordings/'));
    expect(recorder.startedPath, endsWith('.m4a'));

    // Drugie wcisniecie przycisku w trakcie nagrania nie moze zaczac nagrania od nowa.
    await controller.startRecording();
    expect(recorder.startCalls, 1,
        reason: 'powtorny start przed stopem musi byc zignorowany');
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

    // Czas nagrania trafia do bazy i to jego pokazuje biblioteka (T11), wiec musi pochodzic
    // ze stopera, a nie byc dowolna liczba.
    final durationMs = all.first.recording.durationMs;
    expect(durationMs, greaterThanOrEqualTo(0));
    expect(durationMs, lessThan(10000),
        reason: 'przebieg testowy trwa milisekundy, nie sekundy');
  });

  test('brak permission -> lastError, bez startu', () async {
    recorder.permission = false;
    final controller = container.read(recorderControllerProvider.notifier);
    await controller.startRecording();
    expect(container.read(recorderControllerProvider).isRecording, isFalse);
    expect(container.read(recorderControllerProvider).lastError, isNotNull);
  });

  test('STRAZNIK: subskrypcja amplitudy zyje w trakcie nagrania i znika po stopie', () async {
    final controller = container.read(recorderControllerProvider.notifier);
    expect(recorder.amplitudeController.hasListener, isFalse,
        reason: 'przed startem nikt nie slucha amplitudy');

    await controller.startRecording();
    expect(recorder.amplitudeController.hasListener, isTrue,
        reason: 'w trakcie nagrania kontroler musi sluchac amplitudy');

    await controller.stopRecording();
    expect(recorder.amplitudeController.hasListener, isFalse,
        reason: 'strumien pluginu jest wspoldzielony i nie konczy sie sam, '
            'wiec subskrypcje trzeba anulowac jawnie');
  });

  test('STRAZNIK: dwa starty w luce miedzy awaitami nie dubluja nagrania', () async {
    recorder.permissionGate = Completer<void>();
    final controller = container.read(recorderControllerProvider.notifier);

    // Oba wejscia zdarzaja sie ZANIM pierwsze zdazy ustawic isRecording — flaga flipuje sie
    // dopiero po awaitach, wiec sam guard na stanie tego nie lapie.
    final firstStart = controller.startRecording();
    final secondStart = controller.startRecording();
    recorder.permissionGate!.complete();
    await Future.wait([firstStart, secondStart]);

    expect(recorder.startCalls, 1,
        reason: 'drugie wejscie w luke async musi zostac odrzucone, inaczej pierwszy timer, '
            'subskrypcja i plik zostaja osierocone');
  });
}
