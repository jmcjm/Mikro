import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikro/core/api/api_errors.dart';
import 'package:mikro/core/api/tagging_api.dart';
import 'package:mikro/core/api/transcription_api.dart';
import 'package:mikro/core/db/database.dart';
import 'package:mikro/core/models/provider_config.dart';
import 'package:mikro/core/models/recording_status.dart';
import 'package:mikro/core/pipeline/processing_pipeline.dart';
import 'package:mikro/core/settings/settings_repository.dart';

const _config = ProviderConfig(baseUrl: 'https://x', apiKey: 'k', sttModel: 's', tagModel: 't');

class FakeSettings implements SettingsRepository {
  FakeSettings(this.config);
  ProviderConfig? config;
  @override
  Future<ProviderConfig?> load() async => config;
  @override
  Future<void> save(ProviderConfig config) async {}
}

/// Fakes `SettingsRepository` whose key store is temporarily unavailable —
/// libsecret via D-Bus on Linux, Keystore on Android. Both can throw.
class ThrowingSettings implements SettingsRepository {
  bool shouldThrow = true;
  @override
  Future<ProviderConfig?> load() async {
    if (shouldThrow) throw StateError('magazyn kluczy niedostepny');
    return _config;
  }
  @override
  Future<void> save(ProviderConfig config) async {}
}

class FakeTranscription implements TranscriptionApi {
  Object? error;
  int calls = 0;
  @override
  Future<String> transcribe({required String audioPath, required ProviderConfig config}) async {
    calls++;
    if (error != null) throw error!;
    return 'transkrypt testowy';
  }
}

class FakeTagging implements TaggingApi {
  Object? error;
  String? title = 'Standup i release';
  @override
  Future<RecordingMeta> generateMeta(
      {required String transcript, required ProviderConfig config}) async {
    if (error != null) throw error!;
    return RecordingMeta(title: title, tags: const ['praca', 'notatki']);
  }
}


/// Delays transcription on a gate so a second enqueue can enter DURING
/// processing — otherwise in-flight dedup is never exercised.
class DelayedTranscription implements TranscriptionApi {
  final started = Completer<void>();
  final gate = Completer<void>();
  int calls = 0;
  @override
  Future<String> transcribe({required String audioPath, required ProviderConfig config}) async {
    calls++;
    if (!started.isCompleted) started.complete();
    await gate.future;
    return 'transkrypt testowy';
  }
}

/// Counts calls and always fails so recording ends in error status — only then
/// does an eventual second run have work to do and becomes countable.
class CountingFailingTagging implements TaggingApi {
  int calls = 0;
  @override
  Future<RecordingMeta> generateMeta(
      {required String transcript, required ProviderConfig config}) async {
    calls++;
    throw MikroApiException(ApiErrorKind.server, 'HTTP 500');
  }
}

/// Probes status directly from database when pipeline is in the middle of a given step.
class StatusProbingTranscription implements TranscriptionApi {
  StatusProbingTranscription(this.db, this.recordingId);
  final AppDatabase db;
  final String recordingId;
  RecordingStatus? statusDuringCall;
  @override
  Future<String> transcribe({required String audioPath, required ProviderConfig config}) async {
    statusDuringCall = (await db.getRecording(recordingId))?.status;
    return 'transkrypt testowy';
  }
}

class StatusProbingTagging implements TaggingApi {
  StatusProbingTagging(this.db, this.recordingId);
  final AppDatabase db;
  final String recordingId;
  RecordingStatus? statusDuringCall;
  @override
  Future<RecordingMeta> generateMeta(
      {required String transcript, required ProviderConfig config}) async {
    statusDuringCall = (await db.getRecording(recordingId))?.status;
    return const RecordingMeta(title: 'Standup', tags: ['praca']);
  }
}

/// Measures how many transcriptions run concurrently. Delay forces overlap if pipeline
/// stops being sequential.
class ConcurrencyTrackingTranscription implements TranscriptionApi {
  int active = 0;
  int maxActive = 0;
  int calls = 0;
  @override
  Future<String> transcribe({required String audioPath, required ProviderConfig config}) async {
    calls++;
    active++;
    if (active > maxActive) maxActive = active;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    active--;
    return 'transkrypt testowy';
  }
}

/// Closes database and only then throws. Pipeline will catch this exception, but updateStatus in
/// catch block has nowhere to write — then exception escapes from _process itself and without .catchError
/// rejected future propagates to every subsequent queue link.
class DatabaseKillingTagging implements TaggingApi {
  DatabaseKillingTagging(this.db);
  final AppDatabase db;
  @override
  Future<RecordingMeta> generateMeta(
      {required String transcript, required ProviderConfig config}) async {
    await db.close();
    throw MikroApiException(ApiErrorKind.server, 'HTTP 500');
  }
}

void main() {
  late AppDatabase db;
  late FakeTranscription stt;
  late FakeTagging tagger;
  late FakeSettings settings;
  late ProcessingPipeline pipeline;
  late String audioPath;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    stt = FakeTranscription();
    tagger = FakeTagging();
    settings = FakeSettings(_config);
    pipeline = ProcessingPipeline(db: db, transcriptionApi: stt, taggingApi: tagger, settings: settings);
    final f = File('${Directory.systemTemp.createTempSync('mikro').path}/a.m4a')
      ..writeAsBytesSync(List.filled(100, 0));
    audioPath = f.path;
  });
  tearDown(() => db.close());

  Future<void> insert(String id) => db.insertRecording(
      id: id, createdAt: DateTime.utc(2026), durationMs: 1000, audioPath: audioPath);

  test('happy path: done, transcript and tags saved', () async {
    await insert('a');
    pipeline.enqueue('a');
    await pipeline.idle;
    final r = await db.getRecording('a');
    expect(r!.status, RecordingStatus.done);
    expect(r.transcript, 'transkrypt testowy');
    expect(r.providerUsed, 's');
    expect(r.title, 'Standup i release',
        reason: 'title from the same call as tags must land in database');
    final tags = (await db.watchAllWithTags().first).first.tags;
    expect(tags, containsAll(['praca', 'notatki']));
  });

  test('model without title: tags saved, title remains NULL', () async {
    // Missing title is a valid result — it must not block saving tags or status.
    tagger.title = null;
    await insert('a');
    pipeline.enqueue('a');
    await pipeline.idle;
    final r = await db.getRecording('a');
    expect(r!.status, RecordingStatus.done);
    expect(r.title, isNull);
    expect((await db.watchAllWithTags().first).first.tags, containsAll(['praca', 'notatki']));
  });

  test('missing config -> error with noConfig kind', () async {
    settings.config = null;
    await insert('a');
    pipeline.enqueue('a');
    await pipeline.idle;
    final r = await db.getRecording('a');
    expect(r!.status, RecordingStatus.error);
    expect(r.errorKind, errorKindNoConfig,
        reason: 'user-facing sentence is composed by UI, database stores only error kind');
  });

  test('file exceeding limit -> error without calling API', () async {
    final big = File('${Directory.systemTemp.createTempSync('mikro').path}/big.m4a');
    big.writeAsBytesSync(List.filled(maxUploadBytes + 1, 0));
    await db.insertRecording(
        id: 'a', createdAt: DateTime.utc(2026), durationMs: 1, audioPath: big.path);
    pipeline.enqueue('a');
    await pipeline.idle;
    expect((await db.getRecording('a'))!.status, RecordingStatus.error);
    expect((await db.getRecording('a'))!.errorKind, errorKindSizeLimit);
    expect(stt.calls, 0);
  });

  test('transcription failure -> error with auth kind', () async {
    stt.error = MikroApiException(ApiErrorKind.auth, 'HTTP 401');
    await insert('a');
    pipeline.enqueue('a');
    await pipeline.idle;
    final r = await db.getRecording('a');
    expect(r!.status, RecordingStatus.error);
    expect(r.errorKind, ApiErrorKind.auth.name);
    expect(r.errorMessage, 'HTTP 401');
  });

  test('retry after tagging failure does not repeat transcription', () async {
    tagger.error = MikroApiException(ApiErrorKind.server, 'HTTP 500');
    await insert('a');
    pipeline.enqueue('a');
    await pipeline.idle;
    expect((await db.getRecording('a'))!.status, RecordingStatus.error);
    expect((await db.getRecording('a'))!.transcript, 'transkrypt testowy');
    expect(stt.calls, 1);
    tagger.error = null;
    pipeline.enqueue('a');
    await pipeline.idle;
    expect((await db.getRecording('a'))!.status, RecordingStatus.done);
    expect(stt.calls, 1); // transcription was NOT run a second time
  });

  test('resumePending enqueues unfinished recordings', () async {
    await insert('a');
    await insert('b');
    await db.updateStatus('b', RecordingStatus.done);
    await pipeline.resumePending();
    await pipeline.idle;
    expect((await db.getRecording('a'))!.status, RecordingStatus.done);
  });

  test('done recording is not processed again', () async {
    await insert('a');
    pipeline.enqueue('a');
    await pipeline.idle;
    pipeline.enqueue('a');
    await pipeline.idle;
    expect(stt.calls, 1);
  });

  // --- Z1: resilience to exceptions outside try block (coordinator ruling) ---

  test('key store failure ends in error status, and idle does not throw', () async {
    final throwingSettings = ThrowingSettings();
    final resilient = ProcessingPipeline(
        db: db, transcriptionApi: stt, taggingApi: tagger, settings: throwingSettings);
    await insert('a');
    resilient.enqueue('a');

    await resilient.idle;

    final r = await db.getRecording('a');
    expect(r!.status, RecordingStatus.error,
        reason: 'key read failure is a processing error, not silence');
    expect(r.errorKind, errorKindUnknown, reason: 'user must see reason');
    expect(r.errorMessage, isNotEmpty);
  });

  test('failure of one recording does not poison queue for subsequent ones', () async {
    final flakySettings = ThrowingSettings();
    final resilient = ProcessingPipeline(
        db: db, transcriptionApi: stt, taggingApi: tagger, settings: flakySettings);
    await insert('a');
    resilient.enqueue('a');
    await resilient.idle;

    // Failure resolved, key store responds again.
    flakySettings.shouldThrow = false;
    await insert('b');
    resilient.enqueue('b');
    await resilient.idle;

    expect((await db.getRecording('b'))!.status, RecordingStatus.done,
        reason: 'queue must survive exception from previous recording');
  });

  // --- Z2: test coverage guards (coordinator ruling) ---

  test('GUARD: repeated enqueue DURING processing does not trigger second run',
      () async {
    final delayed = DelayedTranscription();
    final failingTagger = CountingFailingTagging();
    final guarded = ProcessingPipeline(
        db: db, transcriptionApi: delayed, taggingApi: failingTagger, settings: settings);
    await insert('a');

    guarded.enqueue('a');
    await delayed.started.future; // transcription already in progress, recording is in-flight
    guarded.enqueue('a'); // duplicate
    delayed.gate.complete();
    await guarded.idle;

    expect(delayed.calls, 1, reason: 'transcription only once');
    expect(failingTagger.calls, 1,
        reason: 'duplicate must not trigger a second _process run');
  });

  test('GUARD: database status is transcribing during transcription and tagging during tagging',
      () async {
    final probingStt = StatusProbingTranscription(db, 'a');
    final probingTagger = StatusProbingTagging(db, 'a');
    final observed = ProcessingPipeline(
        db: db, transcriptionApi: probingStt, taggingApi: probingTagger, settings: settings);
    await insert('a');

    observed.enqueue('a');
    await observed.idle;

    expect(probingStt.statusDuringCall, RecordingStatus.transcribing,
        reason: 'UI must show "transcribing" during transcription');
    expect(probingTagger.statusDuringCall, RecordingStatus.tagging,
        reason: 'UI must show "tagging" during tagging');
  });

  test('GUARD: two recordings are processed sequentially, not in parallel', () async {
    final tracking = ConcurrencyTrackingTranscription();
    final sequential = ProcessingPipeline(
        db: db, transcriptionApi: tracking, taggingApi: tagger, settings: settings);
    await insert('a');
    await insert('b');

    sequential.enqueue('a');
    sequential.enqueue('b');
    await sequential.idle;

    expect(tracking.calls, 2, reason: 'both recordings must be processed');
    expect(tracking.maxActive, 1,
        reason: 'at any given moment exactly one transcription can be active');
    expect((await db.getRecording('a'))!.status, RecordingStatus.done);
    expect((await db.getRecording('b'))!.status, RecordingStatus.done);
  });

  test('GUARD: database failure during error handling does not poison queue', () async {
    final killer = DatabaseKillingTagging(db);
    final resilient = ProcessingPipeline(
        db: db, transcriptionApi: stt, taggingApi: killer, settings: settings);
    await insert('a');

    resilient.enqueue('a');
    await expectLater(resilient.idle, completes,
        reason: 'exception from updateStatus in catch block must not escape via idle');

    // Database is already closed, so second recording cannot be written — but queue chain
    // must accept the task and complete normally, rather than indefinitely
    // propagating the rejected future from the previous link.
    resilient.enqueue('b');
    await expectLater(resilient.idle, completes,
        reason: 'queue must accept subsequent tasks after error handling failure');
  });

  test('resumePending on dead database does not throw and does not block startup', () async {
    // main() calls resumePending() without await and without error handler, so an exception here would be
    // an unhandled asynchronous error on every app launch.
    //
    // Writing BEFORE closing is necessary: drift opens database lazily, so close() on
    // a database that has not been queried yet kills nothing — subsequent query simply
    // reopens it and returns empty result. Only closing an ALREADY OPEN database yields
    // StateError, which is the condition this test is meant to cover.
    await insert('a');
    await db.close();

    await expectLater(pipeline.resumePending(), completes,
        reason: 'startup resume is best-effort, must not crash bootstrap');
    await expectLater(pipeline.idle, completes,
        reason: 'dead database has nothing to resume, so queue remains empty');
  });

  test('error records kind which later decides on resumption', () async {
    stt.error = MikroApiException(ApiErrorKind.network, 'brak sieci');
    await insert('a');
    pipeline.enqueue('a');
    await pipeline.idle;
    expect((await db.getRecording('a'))!.errorKind, 'network');

    tagger.error = null;
    stt.error = StateError('cos zupelnie innego');
    await insert('b');
    pipeline.enqueue('b');
    await pipeline.idle;
    expect((await db.getRecording('b'))!.errorKind, 'unknown',
        reason: 'non-domain exception has no kind, but must be distinguished from missing data');
  });

  // --- auto-resume on network recovery (D2c) ---

  /// Recording stuck on error of given kind.
  Future<void> insertFailed(String id, String kind) async {
    await insert(id);
    await db.updateStatus(id, RecordingStatus.error,
        errorMessage: 'padlo', errorKind: kind);
  }

  /// Connectivity stream events arrive asynchronously, and idle only describes queue
  /// state. Without pumping event loop test would read "queue empty" before
  /// resumption has a chance to enqueue anything.
  Future<void> settleConnectivity() async {
    await pumpEventQueue();
    await pipeline.idle;
  }

  /// Connects pipeline to mock connectivity stream and returns controller so test can
  /// supply subsequent states. `startOnline` reflects what plugin will return on startup —
  /// this determines whether existing network errors are resumed by startup reconciliation.
  Future<StreamController<bool>> watch({required bool startOnline}) async {
    final connectivity = StreamController<bool>();
    addTearDown(connectivity.close);
    await pipeline.watchConnectivity(
        onlineChanges: connectivity.stream, isOnline: () async => startOnline);
    return connectivity;
  }

  test('network recovery resumes network errors and pending queue', () async {
    await insertFailed('siec', 'network');
    await insert('wkolejce');
    final connectivity = await watch(startOnline: false);

    connectivity.add(false);
    connectivity.add(true);
    await settleConnectivity();

    expect((await db.getRecording('siec'))!.status, RecordingStatus.done);
    expect((await db.getRecording('wkolejce'))!.status, RecordingStatus.done);
  });

  test('network recovery DOES NOT resume auth error', () async {
    await insertFailed('auth', 'auth');
    final connectivity = await watch(startOnline: false);

    connectivity.add(false);
    connectivity.add(true);
    await settleConnectivity();

    expect((await db.getRecording('auth'))!.status, RecordingStatus.error,
        reason: 'invalid API key will fail the same way — resuming only repeats the error');
    expect(stt.calls, 0);
  });

  test('two network recoveries do not process recording twice', () async {
    await insertFailed('siec', 'network');
    final connectivity = await watch(startOnline: false);

    connectivity.add(false);
    connectivity.add(true);
    await settleConnectivity();
    connectivity.add(false);
    connectivity.add(true);
    await settleConnectivity();

    expect(stt.calls, 1, reason: 'recording is already done, second run has nothing to do');
  });

  test('remaining online without offline->online transition does not resume anything', () async {
    final connectivity = await watch(startOnline: true);
    // Row appears only AFTER startup reconciliation, so the only candidate for
    // resumption is the stream — and it emits only "online".
    await insertFailed('siec', 'network');

    connectivity.add(true);
    connectivity.add(true);
    await settleConnectivity();

    expect((await db.getRecording('siec'))!.status, RecordingStatus.error,
        reason: 'we resume on RISING EDGE of network recovery, not on every stream emission');
    expect(stt.calls, 0);
  });

  // --- startup reconciliation (D2c, fix round 1) ---

  test('starting already-online resumes existing network error', () async {
    await insertFailed('siec', 'network');
    // Session that starts with network will not see any offline->online rising edge. Without
    // reconciliation the recording would hang forever or until manual "Retry".
    await watch(startOnline: true);
    await settleConnectivity();

    expect((await db.getRecording('siec'))!.status, RecordingStatus.done);
    expect(stt.calls, 1,
        reason: 'design promises resumption on network recovery even when network returned '
            'while app was terminated');
  });

  test('starting offline does not resume; only network recovery resumes', () async {
    await insertFailed('siec', 'network');
    final connectivity = await watch(startOnline: false);
    await settleConnectivity();

    expect(stt.calls, 0, reason: 'without network retry would only repeat the same error');

    // No "add(false)" needed — offline state was established by startup reconciliation, so first
    // "online" from stream is a valid rising edge.
    connectivity.add(true);
    await settleConnectivity();

    expect((await db.getRecording('siec'))!.status, RecordingStatus.done);
    expect(stt.calls, 1);
  });

  test('fast edge right after starting online does not resume twice', () async {
    await insertFailed('siec', 'network');
    final connectivity = await watch(startOnline: true);

    connectivity.add(false);
    connectivity.add(true);
    await settleConnectivity();

    expect(stt.calls, 1,
        reason: 'startup reconciliation and rising edge share one path, protected by flag and dedup');
  });

  test('failing connectivity probe does not crash startup or listener', () async {
    await insertFailed('siec', 'network');
    final connectivity = StreamController<bool>();
    addTearDown(connectivity.close);

    await expectLater(
        pipeline.watchConnectivity(
            onlineChanges: connectivity.stream,
            isOnline: () async => throw StateError('plugin lacznosci niedostepny')),
        completes,
        reason: 'main fires this unawaited — throwing here would be an unhandled error on startup');

    connectivity.add(false);
    connectivity.add(true);
    await settleConnectivity();

    expect(stt.calls, 1, reason: 'listener connects before read, so rising edge still works');
  });

  test('stream state wins over stale startup read', () async {
    final connectivity = StreamController<bool>();
    addTearDown(connectivity.close);
    final readFuture = Completer<bool>();

    final start = pipeline.watchConnectivity(
        onlineChanges: connectivity.stream, isOnline: () => readFuture.future);
    // Network drops DURING startup read: stream knows more than earlier-issued query,
    // so its response must not be overwritten by stale result.
    await pumpEventQueue();
    connectivity.add(false);
    await pumpEventQueue();
    readFuture.complete(true);
    await start;
    await settleConnectivity();

    await insertFailed('siec', 'network');
    connectivity.add(true);
    await settleConnectivity();

    expect(stt.calls, 1,
        reason: 'if stale read had set state to online, network recovery would not be a rising edge');
  });

  test('re-attaching discards previous connectivity source', () async {
    await insertFailed('siec', 'network');
    final previous = await watch(startOnline: false);
    final current = await watch(startOnline: false);

    previous.add(true);
    await settleConnectivity();
    expect(stt.calls, 0, reason: 'discarded subscription no longer controls pipeline');

    current.add(true);
    await settleConnectivity();
    expect(stt.calls, 1);
  });
}
