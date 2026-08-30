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

/// Udaje `SettingsRepository`, ktorego magazyn kluczy jest chwilowo niedostepny —
/// na Linuksie libsecret przez D-Bus, na Androidzie Keystore. Oba potrafia rzucic.
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
  @override
  Future<List<String>> generateTags(
      {required String transcript, required ProviderConfig config}) async {
    if (error != null) throw error!;
    return ['praca', 'notatki'];
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

  test('szczesliwa sciezka: done, transkrypt i tagi zapisane', () async {
    await insert('a');
    pipeline.enqueue('a');
    await pipeline.idle;
    final r = await db.getRecording('a');
    expect(r!.status, RecordingStatus.done);
    expect(r.transcript, 'transkrypt testowy');
    expect(r.providerUsed, 's');
    final tags = (await db.watchAllWithTags().first).first.tags;
    expect(tags, containsAll(['praca', 'notatki']));
  });

  test('brak konfiguracji -> error z komunikatem o ustawieniach', () async {
    settings.config = null;
    await insert('a');
    pipeline.enqueue('a');
    await pipeline.idle;
    final r = await db.getRecording('a');
    expect(r!.status, RecordingStatus.error);
    expect(r.errorMessage, contains('Ustawieniach'));
  });

  test('plik ponad limit -> error bez wolania API', () async {
    final big = File('${Directory.systemTemp.createTempSync('mikro').path}/big.m4a');
    big.writeAsBytesSync(List.filled(maxUploadBytes + 1, 0));
    await db.insertRecording(
        id: 'a', createdAt: DateTime.utc(2026), durationMs: 1, audioPath: big.path);
    pipeline.enqueue('a');
    await pipeline.idle;
    expect((await db.getRecording('a'))!.status, RecordingStatus.error);
    expect(stt.calls, 0);
  });

  test('blad transkrypcji -> error z userMessage', () async {
    stt.error = MikroApiException(ApiErrorKind.auth, 'HTTP 401');
    await insert('a');
    pipeline.enqueue('a');
    await pipeline.idle;
    final r = await db.getRecording('a');
    expect(r!.status, RecordingStatus.error);
    expect(r.errorMessage, contains('klucz API'));
  });

  test('retry po bledzie tagowania nie powtarza transkrypcji', () async {
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
    expect(stt.calls, 1); // transkrypcja NIE poszla drugi raz
  });

  test('resumePending wrzuca niedokonczone do kolejki', () async {
    await insert('a');
    await insert('b');
    await db.updateStatus('b', RecordingStatus.done);
    await pipeline.resumePending();
    await pipeline.idle;
    expect((await db.getRecording('a'))!.status, RecordingStatus.done);
  });

  test('done nie jest przetwarzane ponownie', () async {
    await insert('a');
    pipeline.enqueue('a');
    await pipeline.idle;
    pipeline.enqueue('a');
    await pipeline.idle;
    expect(stt.calls, 1);
  });

  // --- Z1: odpornosc na wyjatki spoza bloku try (ruling koordynatora) ---

  test('awaria magazynu kluczy konczy sie statusem error, a idle nie rzuca', () async {
    final throwingSettings = ThrowingSettings();
    final resilient = ProcessingPipeline(
        db: db, transcriptionApi: stt, taggingApi: tagger, settings: throwingSettings);
    await insert('a');
    resilient.enqueue('a');

    await resilient.idle;

    final r = await db.getRecording('a');
    expect(r!.status, RecordingStatus.error,
        reason: 'awaria odczytu klucza to blad przetwarzania, nie cisza');
    expect(r.errorMessage, isNotNull, reason: 'uzytkownik musi zobaczyc powod');
    expect(r.errorMessage, isNotEmpty);
  });

  test('awaria jednego nagrania nie zatruwa kolejki dla nastepnych', () async {
    final flakySettings = ThrowingSettings();
    final resilient = ProcessingPipeline(
        db: db, transcriptionApi: stt, taggingApi: tagger, settings: flakySettings);
    await insert('a');
    resilient.enqueue('a');
    await resilient.idle;

    // Awaria minela, magazyn kluczy znow odpowiada.
    flakySettings.shouldThrow = false;
    await insert('b');
    resilient.enqueue('b');
    await resilient.idle;

    expect((await db.getRecording('b'))!.status, RecordingStatus.done,
        reason: 'kolejka musi przezyc wyjatek z poprzedniego nagrania');
  });
}
