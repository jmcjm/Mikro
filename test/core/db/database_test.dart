import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikro/core/db/database.dart';
import 'package:mikro/core/models/recording_status.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> insert(String id) => db.insertRecording(
        id: id,
        createdAt: DateTime.utc(2026, 8, 29),
        durationMs: 1000,
        audioPath: '/tmp/$id.m4a',
      );

  test('insert ustawia status recorded', () async {
    await insert('a');
    final r = await db.getRecording('a');
    expect(r!.status, RecordingStatus.recorded);
    expect(r.transcript, isNull);
  });

  test('updateStatus z errorMessage i czyszczenie bledu', () async {
    await insert('a');
    await db.updateStatus('a', RecordingStatus.error, errorMessage: 'pad');
    expect((await db.getRecording('a'))!.errorMessage, 'pad');
    await db.updateStatus('a', RecordingStatus.transcribing);
    expect((await db.getRecording('a'))!.errorMessage, isNull);
  });

  test('setTranscript zapisuje tekst i providera', () async {
    await insert('a');
    await db.setTranscript('a', 'ala ma kota', 'whisper-1');
    final r = await db.getRecording('a');
    expect(r!.transcript, 'ala ma kota');
    expect(r.providerUsed, 'whisper-1');
  });

  test('setTags deduplikuje globalnie i linkuje', () async {
    await insert('a');
    await insert('b');
    await db.setTags('a', ['praca', 'notatki']);
    await db.setTags('b', ['praca']);
    final all = await db.watchAllWithTags().first;
    final tagsA = all.firstWhere((r) => r.recording.id == 'a').tags;
    final tagsB = all.firstWhere((r) => r.recording.id == 'b').tags;
    expect(tagsA, containsAll(['praca', 'notatki']));
    expect(tagsB, ['praca']);
  });

  test('deleteRecording kasuje powiazania i osierocone tagi', () async {
    await insert('a');
    await insert('b');
    await db.setTags('a', ['tylko-a', 'wspolny']);
    await db.setTags('b', ['wspolny']);
    await db.deleteRecording('a');
    final all = await db.watchAllWithTags().first;
    expect(all.map((r) => r.recording.id), ['b']);
    expect(all.first.tags, ['wspolny']); // 'tylko-a' sprzatniete
  });

  test('pendingRecordings zwraca stany niedokonczone', () async {
    await insert('a');
    await insert('b');
    await insert('c');
    await db.updateStatus('b', RecordingStatus.done);
    await db.updateStatus('c', RecordingStatus.tagging);
    final pending = (await db.pendingRecordings()).map((r) => r.id).toList();
    expect(pending, containsAll(['a', 'c']));
    expect(pending, isNot(contains('b')));
  });

  test('watchAllWithTags sortuje malejaco po dacie', () async {
    await db.insertRecording(id: 'old', createdAt: DateTime.utc(2026, 1, 1), durationMs: 1, audioPath: '/x');
    await db.insertRecording(id: 'new', createdAt: DateTime.utc(2026, 8, 1), durationMs: 1, audioPath: '/y');
    final all = await db.watchAllWithTags().first;
    expect(all.map((r) => r.recording.id), ['new', 'old']);
  });

  // --- Straznicy regresji (Task 3, uzupelnienie) ---
  // Testy z planu weryfikuja kaskade i sprzatanie osieroconych wylacznie przez
  // watchAllWithTags(), a ta kwerenda joinuje OD tabeli recordings — osierocone wiersze
  // sa dla niej niewidoczne i przechodzi nawet przy calkowicie wylaczonych obu
  // mechanizmach. Ponizsze testy siegaja po stan bazy bezposrednim SQL-em.

  test('STRAZNIK: PRAGMA foreign_keys jest wlaczona', () async {
    // SQLite ignoruje te pragme wykonana wewnatrz transakcji, wiec beforeOpen moze byc
    // cichym no-opem. Bez tego 1 kaskada z KeyAction.cascade nigdy nie zadziala.
    final row = await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(row.data.values.first, 1, reason: 'kaskady FK wymagaja PRAGMA foreign_keys = ON');
  });

  test('STRAZNIK: deleteRecording nie zostawia sierot w recording_tags ani w tags', () async {
    await insert('a');
    await insert('b');
    await db.setTags('a', ['tylko-a', 'wspolny']);
    await db.setTags('b', ['wspolny']);

    final before = await db.customSelect('SELECT COUNT(*) c FROM recording_tags').getSingle();
    expect(before.data['c'], 3, reason: 'scenariusz wyjsciowy: 2 powiazania dla a, 1 dla b');

    await db.deleteRecording('a');

    final linksForA = await db
        .customSelect("SELECT COUNT(*) c FROM recording_tags WHERE recording_id = 'a'")
        .getSingle();
    expect(linksForA.data['c'], 0, reason: 'kaskada FK musi skasowac powiazania nagrania a');

    final orphanLinks = await db.customSelect(
      'SELECT COUNT(*) c FROM recording_tags rt '
      'WHERE rt.recording_id NOT IN (SELECT id FROM recordings) '
      'OR rt.tag_id NOT IN (SELECT id FROM tags)',
    ).getSingle();
    expect(orphanLinks.data['c'], 0, reason: 'zaden wiersz recording_tags nie moze wisiec w prozni');

    final tagNames = await db.customSelect('SELECT name FROM tags ORDER BY name').get();
    expect(
      tagNames.map((r) => r.data['name']).toList(),
      ['wspolny'],
      reason: 'tag tylko-a stracil ostatnie powiazanie i musi zniknac z tabeli tags',
    );
  });

  // --- schemat v2: errorKind (D2c) ---

  test('swieza baza jest w wersji 4 i ma kolumny error_kind, waveform oraz title', () async {
    await insert('a');
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.first, 4);

    final columns = await db.customSelect('PRAGMA table_info(recordings)').get();
    expect(columns.map((c) => c.data['name']),
        containsAll(['error_kind', 'waveform', 'title']));
  });

  test('migracja z v1 doklada kolumny i nie gubi istniejacych nagran', () async {
    // Ten test nie korzysta z bazy z setUp, a drift ostrzega, gdy dwie instancje AppDatabase
    // zyja rownoczesnie. Zamykamy ja, zeby log testow zostal czysty — tearDown zniesie
    // powtorne close().
    await db.close();

    // Baza zalozona recznie w ksztalcie v1 (bez error_kind, user_version = 1), zeby drift
    // musial faktycznie przejsc sciezka onUpgrade zamiast tworzyc schemat od zera.
    final legacy = AppDatabase.forTesting(NativeDatabase.memory(setup: (rawDb) {
      rawDb.execute('CREATE TABLE "recordings" ("id" TEXT NOT NULL, "created_at" INTEGER NOT NULL, '
          '"duration_ms" INTEGER NOT NULL, "audio_path" TEXT NOT NULL, "status" TEXT NOT NULL, '
          '"transcript" TEXT NULL, "provider_used" TEXT NULL, "error_message" TEXT NULL, '
          'PRIMARY KEY ("id"))');
      rawDb.execute('CREATE TABLE "tags" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
          '"name" TEXT NOT NULL UNIQUE)');
      rawDb.execute('CREATE TABLE "recording_tags" ("recording_id" TEXT NOT NULL '
          'REFERENCES recordings (id) ON DELETE CASCADE, "tag_id" INTEGER NOT NULL '
          'REFERENCES tags (id) ON DELETE CASCADE, PRIMARY KEY ("recording_id", "tag_id"))');
      rawDb.execute("INSERT INTO recordings (id, created_at, duration_ms, audio_path, status, "
          "error_message) VALUES ('stare', 0, 1000, '/stare.m4a', 'error', 'cos padlo')");
      rawDb.execute('PRAGMA user_version = 1');
    }));
    addTearDown(legacy.close);

    final migrated = await legacy.getRecording('stare');

    expect(migrated, isNotNull, reason: 'migracja nie moze zgubic istniejacych nagran');
    expect(migrated!.errorMessage, 'cos padlo');
    expect(migrated.errorKind, isNull,
        reason: 'nie wiemy jakiego rodzaju byl stary blad, wiec zostaje nierozpoznany');

    final version = await legacy.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.first, 4,
        reason: 'baza z v1 dochodzi jednym otwarciem do biezacego schematu');
  });

  test('updateStatus zapisuje errorKind i czysci go przy przejsciu na stan nie-bledowy',
      () async {
    await insert('a');

    await db.updateStatus('a', RecordingStatus.error,
        errorMessage: 'brak sieci', errorKind: 'network');
    expect((await db.getRecording('a'))!.errorKind, 'network');

    await db.updateStatus('a', RecordingStatus.transcribing);
    expect((await db.getRecording('a'))!.errorKind, isNull,
        reason: 'stary rodzaj bledu nie moze przezyc sytuacji, ktora go wywolala');
  });

  test('networkFailedRecordings zwraca tylko bledy sieciowe', () async {
    await insert('siec');
    await insert('auth');
    await insert('wkolejce');
    await db.updateStatus('siec', RecordingStatus.error, errorKind: 'network');
    await db.updateStatus('auth', RecordingStatus.error, errorKind: 'auth');

    final ids = (await db.networkFailedRecordings()).map((r) => r.id);

    expect(ids, ['siec'],
        reason: 'blad autoryzacji ponowi sie tak samo, wiec nie wznawiamy go po powrocie sieci');
  });

  test('watchQueueLength liczy niedokonczone razem z bledami sieci', () async {
    await insert('wkolejce');
    await insert('siec');
    await insert('auth');
    await insert('gotowe');
    await db.updateStatus('siec', RecordingStatus.error, errorKind: 'network');
    await db.updateStatus('auth', RecordingStatus.error, errorKind: 'auth');
    await db.updateStatus('gotowe', RecordingStatus.done);

    expect(await db.watchQueueLength().first, 2,
        reason: 'jedno czeka w kolejce, jedno wisi na sieci; auth i done sie nie licza');
  });

  // --- schemat v3: waveform (D2f) ---

  test('migracja v2 -> v3 doklada waveform, stare nagrania maja NULL', () async {
    // Jak przy tescie v1 -> v2: zamykamy baze z setUp, zeby dwie instancje nie zyly naraz.
    await db.close();

    // Baza w ksztalcie v2 (jest error_kind, nie ma waveform, user_version = 2), zeby drift
    // musial przejsc sciezka onUpgrade zamiast zbudowac schemat od zera.
    final legacy = AppDatabase.forTesting(NativeDatabase.memory(setup: (rawDb) {
      rawDb.execute('CREATE TABLE "recordings" ("id" TEXT NOT NULL, "created_at" INTEGER NOT NULL, '
          '"duration_ms" INTEGER NOT NULL, "audio_path" TEXT NOT NULL, "status" TEXT NOT NULL, '
          '"transcript" TEXT NULL, "provider_used" TEXT NULL, "error_message" TEXT NULL, '
          '"error_kind" TEXT NULL, PRIMARY KEY ("id"))');
      rawDb.execute('CREATE TABLE "tags" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
          '"name" TEXT NOT NULL UNIQUE)');
      rawDb.execute('CREATE TABLE "recording_tags" ("recording_id" TEXT NOT NULL '
          'REFERENCES recordings (id) ON DELETE CASCADE, "tag_id" INTEGER NOT NULL '
          'REFERENCES tags (id) ON DELETE CASCADE, PRIMARY KEY ("recording_id", "tag_id"))');
      rawDb.execute("INSERT INTO recordings (id, created_at, duration_ms, audio_path, status, "
          "transcript) VALUES ('stare', 0, 1000, '/stare.m4a', 'done', 'stara notatka')");
      rawDb.execute('PRAGMA user_version = 2');
    }));
    addTearDown(legacy.close);

    final migrated = await legacy.getRecording('stare');

    expect(migrated, isNotNull, reason: 'migracja nie moze zgubic istniejacych nagran');
    expect(migrated!.transcript, 'stara notatka');
    expect(migrated.waveform, isNull,
        reason: 'nagran sprzed v3 nikt nie mierzyl, wiec nie ma czego narysowac');

    final version = await legacy.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.first, 4);

    final columns = await legacy.customSelect('PRAGMA table_info(recordings)').get();
    expect(columns.map((c) => c.data['name']), contains('waveform'));
  });

  // --- schemat v4: title (tytuly z AI) ---

  test('migracja v3 -> v4 doklada title, stare nagrania maja NULL', () async {
    // Jak przy poprzednich migracjach: zamykamy baze z setUp, zeby dwie instancje nie zyly
    // naraz, i zakladamy baze recznie w ksztalcie v3, zeby drift musial przejsc onUpgrade.
    await db.close();

    final legacy = AppDatabase.forTesting(NativeDatabase.memory(setup: (rawDb) {
      rawDb.execute('CREATE TABLE "recordings" ("id" TEXT NOT NULL, "created_at" INTEGER NOT NULL, '
          '"duration_ms" INTEGER NOT NULL, "audio_path" TEXT NOT NULL, "status" TEXT NOT NULL, '
          '"transcript" TEXT NULL, "provider_used" TEXT NULL, "error_message" TEXT NULL, '
          '"error_kind" TEXT NULL, "waveform" TEXT NULL, PRIMARY KEY ("id"))');
      rawDb.execute('CREATE TABLE "tags" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
          '"name" TEXT NOT NULL UNIQUE)');
      rawDb.execute('CREATE TABLE "recording_tags" ("recording_id" TEXT NOT NULL '
          'REFERENCES recordings (id) ON DELETE CASCADE, "tag_id" INTEGER NOT NULL '
          'REFERENCES tags (id) ON DELETE CASCADE, PRIMARY KEY ("recording_id", "tag_id"))');
      rawDb.execute("INSERT INTO recordings (id, created_at, duration_ms, audio_path, status, "
          "transcript, waveform) VALUES ('stare', 0, 1000, '/stare.m4a', 'done', "
          "'stara notatka', '[0.1,0.5]')");
      rawDb.execute('PRAGMA user_version = 3');
    }));
    addTearDown(legacy.close);

    final migrated = await legacy.getRecording('stare');

    expect(migrated, isNotNull, reason: 'migracja nie moze zgubic istniejacych nagran');
    expect(migrated!.transcript, 'stara notatka');
    expect(migrated.waveform, '[0.1,0.5]',
        reason: 'dolozenie kolumny nie moze ruszyc danych z poprzednich schematow');
    expect(migrated.title, isNull,
        reason: 'nagran sprzed v4 nikt nie tytulowal, a z transkryptu tytulu nie zgadniemy');

    final version = await legacy.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.first, 4);

    final columns = await legacy.customSelect('PRAGMA table_info(recordings)').get();
    expect(columns.map((c) => c.data['name']), contains('title'));
  });

  test('setTitle zapisuje tytul i pozwala go wyczyscic', () async {
    await insert('a');
    expect((await db.getRecording('a'))!.title, isNull);

    await db.setTitle('a', 'Standup — przesuniecie release');
    expect((await db.getRecording('a'))!.title, 'Standup — przesuniecie release');

    await db.setTitle('a', null);
    expect((await db.getRecording('a'))!.title, isNull,
        reason: 'null musi trafic do bazy jako NULL, a nie zostac pominiety w UPDATE');
  });

  test('insertRecording zapisuje przebieg, a bez niego zostawia NULL', () async {
    await db.insertRecording(
      id: 'z-przebiegiem',
      createdAt: DateTime.utc(2026, 8, 29),
      durationMs: 1000,
      audioPath: '/a.m4a',
      waveform: '[0.1,0.5]',
    );
    await insert('bez-przebiegu');

    expect((await db.getRecording('z-przebiegiem'))!.waveform, '[0.1,0.5]');
    expect((await db.getRecording('bez-przebiegu'))!.waveform, isNull);
  });
}
