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
  String? title = 'Standup i release';
  @override
  Future<RecordingMeta> generateMeta(
      {required String transcript, required ProviderConfig config}) async {
    if (error != null) throw error!;
    return RecordingMeta(title: title, tags: const ['praca', 'notatki']);
  }
}


/// Wstrzymuje transkrypcje na bramce, zeby dalo sie wejsc z drugim enqueue W TRAKCIE
/// przetwarzania — inaczej dedup in-flight nigdy nie jest wykonywany.
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

/// Liczy wywolania i zawsze zawodzi, zeby nagranie skonczylo w stanie error — dopiero wtedy
/// ewentualny drugi przebieg ma co robic i jest policzalny.
class CountingFailingTagging implements TaggingApi {
  int calls = 0;
  @override
  Future<RecordingMeta> generateMeta(
      {required String transcript, required ProviderConfig config}) async {
    calls++;
    throw MikroApiException(ApiErrorKind.server, 'HTTP 500');
  }
}

/// Odczytuje status prosto z bazy w chwili, gdy pipeline jest w srodku danego kroku.
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

/// Mierzy, ile transkrypcji trwa jednoczesnie. Opoznienie wymusza nakladke, gdyby pipeline
/// przestal byc sekwencyjny.
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

/// Zamyka baze i dopiero potem rzuca. Pipeline zlapie ten wyjatek, ale updateStatus w bloku
/// catch nie ma juz dokad pisac — wtedy wyjatek ucieka z samego _process i bez .catchError
/// odrzucona przyszlosc propaguje sie na kazde kolejne ogniwo kolejki.
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

  test('szczesliwa sciezka: done, transkrypt i tagi zapisane', () async {
    await insert('a');
    pipeline.enqueue('a');
    await pipeline.idle;
    final r = await db.getRecording('a');
    expect(r!.status, RecordingStatus.done);
    expect(r.transcript, 'transkrypt testowy');
    expect(r.providerUsed, 's');
    expect(r.title, 'Standup i release',
        reason: 'tytul z tego samego wywolania co tagi ma wyladowac w bazie');
    final tags = (await db.watchAllWithTags().first).first.tags;
    expect(tags, containsAll(['praca', 'notatki']));
  });

  test('model bez tytulu: tagi zapisane, tytul zostaje NULL', () async {
    // Brak tytulu jest poprawnym wynikiem — nie moze zablokowac zapisu tagow ani statusu.
    tagger.title = null;
    await insert('a');
    pipeline.enqueue('a');
    await pipeline.idle;
    final r = await db.getRecording('a');
    expect(r!.status, RecordingStatus.done);
    expect(r.title, isNull);
    expect((await db.watchAllWithTags().first).first.tags, containsAll(['praca', 'notatki']));
  });

  test('brak konfiguracji -> error z rodzajem noConfig', () async {
    settings.config = null;
    await insert('a');
    pipeline.enqueue('a');
    await pipeline.idle;
    final r = await db.getRecording('a');
    expect(r!.status, RecordingStatus.error);
    expect(r.errorKind, errorKindNoConfig,
        reason: 'zdanie dla uzytkownika sklada UI, baza trzyma sam rodzaj bledu');
  });

  test('plik ponad limit -> error bez wolania API', () async {
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

  test('blad transkrypcji -> error z rodzajem auth', () async {
    stt.error = MikroApiException(ApiErrorKind.auth, 'HTTP 401');
    await insert('a');
    pipeline.enqueue('a');
    await pipeline.idle;
    final r = await db.getRecording('a');
    expect(r!.status, RecordingStatus.error);
    expect(r.errorKind, ApiErrorKind.auth.name);
    expect(r.errorMessage, 'HTTP 401');
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
    expect(r.errorKind, errorKindUnknown, reason: 'uzytkownik musi zobaczyc powod');
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

  // --- Z2: straznicy pokrycia (ruling koordynatora) ---

  test('STRAZNIK: powtorny enqueue W TRAKCIE przetwarzania nie uruchamia drugiego przebiegu',
      () async {
    final delayed = DelayedTranscription();
    final failingTagger = CountingFailingTagging();
    final guarded = ProcessingPipeline(
        db: db, transcriptionApi: delayed, taggingApi: failingTagger, settings: settings);
    await insert('a');

    guarded.enqueue('a');
    await delayed.started.future; // transkrypcja juz trwa, nagranie jest in-flight
    guarded.enqueue('a'); // duplikat
    delayed.gate.complete();
    await guarded.idle;

    expect(delayed.calls, 1, reason: 'transkrypcja tylko raz');
    expect(failingTagger.calls, 1,
        reason: 'duplikat nie moze uruchomic drugiego przebiegu _process');
  });

  test('STRAZNIK: status w bazie to transcribing w trakcie transkrypcji i tagging w trakcie tagowania',
      () async {
    final probingStt = StatusProbingTranscription(db, 'a');
    final probingTagger = StatusProbingTagging(db, 'a');
    final observed = ProcessingPipeline(
        db: db, transcriptionApi: probingStt, taggingApi: probingTagger, settings: settings);
    await insert('a');

    observed.enqueue('a');
    await observed.idle;

    expect(probingStt.statusDuringCall, RecordingStatus.transcribing,
        reason: 'UI ma pokazywac "transkrybuje" w trakcie transkrypcji');
    expect(probingTagger.statusDuringCall, RecordingStatus.tagging,
        reason: 'UI ma pokazywac "taguje" w trakcie tagowania');
  });

  test('STRAZNIK: dwa nagrania sa przetwarzane sekwencyjnie, nie rownolegle', () async {
    final tracking = ConcurrencyTrackingTranscription();
    final sequential = ProcessingPipeline(
        db: db, transcriptionApi: tracking, taggingApi: tagger, settings: settings);
    await insert('a');
    await insert('b');

    sequential.enqueue('a');
    sequential.enqueue('b');
    await sequential.idle;

    expect(tracking.calls, 2, reason: 'oba nagrania musza zostac przetworzone');
    expect(tracking.maxActive, 1,
        reason: 'w danej chwili moze trwac dokladnie jedna transkrypcja');
    expect((await db.getRecording('a'))!.status, RecordingStatus.done);
    expect((await db.getRecording('b'))!.status, RecordingStatus.done);
  });

  test('STRAZNIK: awaria bazy w trakcie obslugi bledu nie zatruwa kolejki', () async {
    final killer = DatabaseKillingTagging(db);
    final resilient = ProcessingPipeline(
        db: db, transcriptionApi: stt, taggingApi: killer, settings: settings);
    await insert('a');

    resilient.enqueue('a');
    await expectLater(resilient.idle, completes,
        reason: 'wyjatek z updateStatus w bloku catch nie moze wyplynac przez idle');

    // Baza jest juz zamknieta, wiec drugie nagranie nie ma sie gdzie zapisac — ale lancuch
    // kolejki musi przyjac zadanie i domknac je normalnie, zamiast w nieskonczonosc
    // propagowac odrzucona przyszlosc z poprzedniego ogniwa.
    resilient.enqueue('b');
    await expectLater(resilient.idle, completes,
        reason: 'kolejka musi przyjmowac kolejne zadania po awarii obslugi bledu');
  });

  test('resumePending przy martwej bazie nie rzuca i nie blokuje startu', () async {
    // main() wola resumePending() bez await i bez obslugi bledu, wiec wyjatek stad bylby
    // nieobsluzonym bledem asynchronicznym przy kazdym uruchomieniu aplikacji.
    //
    // Zapis PRZED zamknieciem jest konieczny: drift otwiera baze leniwie, wiec close() na
    // bazie, ktorej nikt jeszcze nie odpytal, niczego nie zabija — kolejne zapytanie po prostu
    // otwiera ja na nowo i zwraca pusty wynik. Dopiero zamkniecie JUZ OTWARTEJ bazy daje
    // StateError, czyli warunek, ktory ten test ma pokrywac.
    await insert('a');
    await db.close();

    await expectLater(pipeline.resumePending(), completes,
        reason: 'wznawianie przy starcie jest best-effort, nie moze wywracac bootstrapu');
    await expectLater(pipeline.idle, completes,
        reason: 'martwa baza nie ma czego wznowic, wiec kolejka zostaje pusta');
  });

  test('blad zapisuje rodzaj, ktory pozniej decyduje o wznowieniu', () async {
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
        reason: 'wyjatek spoza domeny nie ma rodzaju, ale musi byc odrozniony od braku danych');
  });

  // --- auto-wznowienie po powrocie sieci (D2c) ---

  /// Nagranie, ktore utknelo na bledzie danego rodzaju.
  Future<void> insertFailed(String id, String kind) async {
    await insert(id);
    await db.updateStatus(id, RecordingStatus.error,
        errorMessage: 'padlo', errorKind: kind);
  }


  /// Zdarzenia ze strumienia lacznosci docieraja asynchronicznie, a `idle` opisuje tylko stan
  /// kolejki. Bez przepompowania petli zdarzen test odczytalby "kolejka pusta" jeszcze zanim
  /// wznowienie zdazy cokolwiek do niej wrzucic.
  Future<void> settleConnectivity() async {
    await pumpEventQueue();
    await pipeline.idle;
  }

  /// Podpina pipeline do sztucznego strumienia lacznosci i oddaje kontroler, zeby test mogl
  /// podawac kolejne stany. `startOnline` odwzorowuje to, co plugin odpowie przy starcie —
  /// od tego zalezy, czy zastane bledy sieciowe wznawia rekoncyliacja startowa.
  Future<StreamController<bool>> watch({required bool startOnline}) async {
    final connectivity = StreamController<bool>();
    addTearDown(connectivity.close);
    await pipeline.watchConnectivity(
        onlineChanges: connectivity.stream, isOnline: () async => startOnline);
    return connectivity;
  }

  test('powrot sieci wznawia bledy sieciowe i zalegla kolejke', () async {
    await insertFailed('siec', 'network');
    await insert('wkolejce');
    final connectivity = await watch(startOnline: false);

    connectivity.add(false);
    connectivity.add(true);
    await settleConnectivity();

    expect((await db.getRecording('siec'))!.status, RecordingStatus.done);
    expect((await db.getRecording('wkolejce'))!.status, RecordingStatus.done);
  });

  test('powrot sieci NIE wznawia bledu autoryzacji', () async {
    await insertFailed('auth', 'auth');
    final connectivity = await watch(startOnline: false);

    connectivity.add(false);
    connectivity.add(true);
    await settleConnectivity();

    expect((await db.getRecording('auth'))!.status, RecordingStatus.error,
        reason: 'zly klucz API ponowi sie tak samo — wznawianie tylko powtorzy blad');
    expect(stt.calls, 0);
  });

  test('dwa powroty sieci nie przetwarzaja nagrania dwa razy', () async {
    await insertFailed('siec', 'network');
    final connectivity = await watch(startOnline: false);

    connectivity.add(false);
    connectivity.add(true);
    await settleConnectivity();
    connectivity.add(false);
    connectivity.add(true);
    await settleConnectivity();

    expect(stt.calls, 1, reason: 'nagranie jest juz done, drugi przebieg nie ma czego robic');
  });

  test('samo trwanie online, bez przejscia offline->online, niczego nie wznawia', () async {
    final connectivity = await watch(startOnline: true);
    // Wiersz pojawia sie dopiero PO rekoncyliacji startowej, wiec jedynym kandydatem na
    // wznowienie zostaje strumien — a ten emituje wylacznie "online".
    await insertFailed('siec', 'network');

    connectivity.add(true);
    connectivity.add(true);
    await settleConnectivity();

    expect((await db.getRecording('siec'))!.status, RecordingStatus.error,
        reason: 'wznawiamy na ZBOCZU powrotu sieci, nie przy kazdej emisji strumienia');
    expect(stt.calls, 0);
  });

  // --- rekoncyliacja startowa (D2c, runda fix 1) ---

  test('start juz-online wznawia zastany blad sieciowy', () async {
    await insertFailed('siec', 'network');
    // Sesja, ktora startuje z siecia, nie zobaczy zadnego zbocza offline->online. Bez
    // rekoncyliacji nagranie wisialoby do konca swiata albo do recznego "Ponow".
    await watch(startOnline: true);
    await settleConnectivity();

    expect((await db.getRecording('siec'))!.status, RecordingStatus.done);
    expect(stt.calls, 1,
        reason: 'design obiecuje wznowienie po powrocie sieci takze wtedy, gdy siec wrocila '
            'przy wylaczonej aplikacji');
  });

  test('start offline nie wznawia; wznawia dopiero powrot sieci', () async {
    await insertFailed('siec', 'network');
    final connectivity = await watch(startOnline: false);
    await settleConnectivity();

    expect(stt.calls, 0, reason: 'bez sieci ponowienie tylko powtorzyloby ten sam blad');

    // Zadnego "add(false)" — stan offline ustalila juz rekoncyliacja startowa, wiec pierwsze
    // "online" ze strumienia jest pelnoprawnym zboczem.
    connectivity.add(true);
    await settleConnectivity();

    expect((await db.getRecording('siec'))!.status, RecordingStatus.done);
    expect(stt.calls, 1);
  });

  test('szybkie zbocze tuz po starcie online nie wznawia dwa razy', () async {
    await insertFailed('siec', 'network');
    final connectivity = await watch(startOnline: true);

    connectivity.add(false);
    connectivity.add(true);
    await settleConnectivity();

    expect(stt.calls, 1,
        reason: 'rekoncyliacja startowa i zbocze to jedna sciezka, chroniona flaga i dedupem');
  });

  test('bledny odczyt stanu lacznosci nie wywraca startu ani nasluchu', () async {
    await insertFailed('siec', 'network');
    final connectivity = StreamController<bool>();
    addTearDown(connectivity.close);

    await expectLater(
        pipeline.watchConnectivity(
            onlineChanges: connectivity.stream,
            isOnline: () async => throw StateError('plugin lacznosci niedostepny')),
        completes,
        reason: 'main odpala to bez await — rzut tutaj bylby nieobsluzonym bledem przy starcie');

    connectivity.add(false);
    connectivity.add(true);
    await settleConnectivity();

    expect(stt.calls, 1, reason: 'nasluch podpina sie przed odczytem, wiec zbocze i tak dziala');
  });

  test('stan ze strumienia wygrywa ze starszym odczytem startowym', () async {
    final connectivity = StreamController<bool>();
    addTearDown(connectivity.close);
    final odczyt = Completer<bool>();

    final start = pipeline.watchConnectivity(
        onlineChanges: connectivity.stream, isOnline: () => odczyt.future);
    // Siec pada w TRAKCIE odczytu startowego: strumien wie wiecej niz zapytanie zadane
    // wczesniej, wiec jego odpowiedz nie moze zostac nadpisana przestarzalym wynikiem.
    await pumpEventQueue();
    connectivity.add(false);
    await pumpEventQueue();
    odczyt.complete(true);
    await start;
    await settleConnectivity();

    await insertFailed('siec', 'network');
    connectivity.add(true);
    await settleConnectivity();

    expect(stt.calls, 1,
        reason: 'gdyby przestarzaly odczyt ustawil stan na online, powrot sieci nie bylby zboczem');
  });

  test('ponowne podpiecie porzuca poprzednie zrodlo lacznosci', () async {
    await insertFailed('siec', 'network');
    final stare = await watch(startOnline: false);
    final nowe = await watch(startOnline: false);

    stare.add(true);
    await settleConnectivity();
    expect(stt.calls, 0, reason: 'porzucona subskrypcja nie steruje juz pipelinem');

    nowe.add(true);
    await settleConnectivity();
    expect(stt.calls, 1);
  });
}
