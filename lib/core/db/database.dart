import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../models/recording_status.dart';

part 'database.g.dart';

class Recordings extends Table {
  TextColumn get id => text()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get durationMs => integer()();
  TextColumn get audioPath => text()();
  TextColumn get status => textEnum<RecordingStatus>()();
  TextColumn get transcript => text().nullable()();
  TextColumn get providerUsed => text().nullable()();
  TextColumn get errorMessage => text().nullable()();

  /// Rodzaj bledu (`MikroApiException.kind.name`, albo `unknown` dla wyjatkow spoza domeny).
  /// Sluzy do rozroznienia bledow, ktore warto ponowic po powrocie sieci, od tych ktore
  /// ponawianie tylko powtorzy — np. bledny klucz API.
  TextColumn get errorKind => text().nullable()();

  /// Obwiednia amplitudy nagrania: tablica JSON z 44 wartosciami 0..1 (patrz
  /// `core/audio/waveform.dart`). NULL dla nagran sprzed schematu v3 oraz dla takich,
  /// przy ktorych mikrofon nie oddal ani jednej probki — ekran szczegolow rysuje wtedy
  /// karte bez slupkow zamiast zmyslac ksztalt.
  TextColumn get waveform => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
}

class RecordingTags extends Table {
  TextColumn get recordingId =>
      text().references(Recordings, #id, onDelete: KeyAction.cascade)();
  IntColumn get tagId => integer().references(Tags, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {recordingId, tagId};
}

class RecordingWithTags {
  RecordingWithTags({required this.recording, required this.tags});

  final Recording recording;
  final List<String> tags;
}

@DriftDatabase(tables: [Recordings, Tags, RecordingTags])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'mikro'));
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          // v1 -> v2: doklada errorKind. Istniejace wiersze dostaja NULL, wiec stare bledy
          // nie beda automatycznie wznawiane — nie wiemy, czy byly sieciowe.
          if (from < 2) {
            await m.addColumn(recordings, recordings.errorKind);
          }
          // v2 -> v3: doklada waveform. Istniejace nagrania dostaja NULL, bo obwiedni nikt
          // wtedy nie mierzyl, a z gotowego m4a nie odtworzymy jej bez dekodowania audio.
          if (from < 3) {
            await m.addColumn(recordings, recordings.waveform);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  Future<void> insertRecording({
    required String id,
    required DateTime createdAt,
    required int durationMs,
    required String audioPath,
    String? waveform,
  }) =>
      into(recordings).insert(RecordingsCompanion.insert(
        id: id,
        createdAt: createdAt,
        durationMs: durationMs,
        audioPath: audioPath,
        status: RecordingStatus.recorded,
        waveform: Value(waveform),
      ));

  Future<Recording?> getRecording(String id) =>
      (select(recordings)..where((r) => r.id.equals(id))).getSingleOrNull();

  /// Zapisuje status. Jak `errorMessage`, tak i `errorKind` jest ZAWSZE nadpisywany — przejscie
  /// na stan nie-bledowy czysci oba, zeby stary blad nie przezyl sytuacji, ktora go wywolala.
  Future<void> updateStatus(
    String id,
    RecordingStatus status, {
    String? errorMessage,
    String? errorKind,
  }) =>
      (update(recordings)..where((r) => r.id.equals(id))).write(
        RecordingsCompanion(
          status: Value(status),
          errorMessage: Value(errorMessage),
          errorKind: Value(errorKind),
        ),
      );

  Future<void> setTranscript(String id, String transcript, String providerUsed) =>
      (update(recordings)..where((r) => r.id.equals(id))).write(
        RecordingsCompanion(transcript: Value(transcript), providerUsed: Value(providerUsed)),
      );

  Future<void> setTags(String recordingId, List<String> names) => transaction(() async {
        for (final name in names) {
          await into(tags).insert(TagsCompanion.insert(name: name), mode: InsertMode.insertOrIgnore);
          final tag = await (select(tags)..where((t) => t.name.equals(name))).getSingle();
          await into(recordingTags).insert(
            RecordingTagsCompanion.insert(recordingId: recordingId, tagId: tag.id),
            mode: InsertMode.insertOrIgnore,
          );
        }
      });

  Future<void> deleteRecording(String id) => transaction(() async {
        await (delete(recordings)..where((r) => r.id.equals(id))).go();
        await customStatement(
            'DELETE FROM tags WHERE id NOT IN (SELECT DISTINCT tag_id FROM recording_tags)');
      });

  /// Nagrania, ktore utknely na bledzie sieci — jedyne, ktore ma sens wznawiac po powrocie
  /// lacznosci. Blad autoryzacji czy zbyt duzy plik ponowi sie tak samo.
  Future<List<Recording>> networkFailedRecordings() => (select(recordings)
        ..where((r) =>
            r.status.equalsValue(RecordingStatus.error) & r.errorKind.equals('network')))
      .get();

  /// Ile nagran czeka na przetworzenie: niedokonczone plus te wstrzymane brakiem sieci.
  Stream<int> watchQueueLength() {
    final pending = [
      RecordingStatus.recorded,
      RecordingStatus.transcribing,
      RecordingStatus.tagging,
    ];
    final query = selectOnly(recordings)
      ..addColumns([recordings.id.count()])
      ..where(recordings.status.isInValues(pending) |
          (recordings.status.equalsValue(RecordingStatus.error) &
              recordings.errorKind.equals('network')));
    return query.map((row) => row.read(recordings.id.count()) ?? 0).watchSingle();
  }

  Future<List<Recording>> pendingRecordings() => (select(recordings)
        ..where((r) => r.status.isInValues(
            [RecordingStatus.recorded, RecordingStatus.transcribing, RecordingStatus.tagging])))
      .get();

  Stream<List<RecordingWithTags>> watchAllWithTags() {
    final query = select(recordings).join([
      leftOuterJoin(recordingTags, recordingTags.recordingId.equalsExp(recordings.id)),
      leftOuterJoin(tags, tags.id.equalsExp(recordingTags.tagId)),
    ])
      ..orderBy([OrderingTerm.desc(recordings.createdAt)]);
    return query.watch().map((rows) {
      final byId = <String, RecordingWithTags>{};
      final order = <String>[];
      for (final row in rows) {
        final rec = row.readTable(recordings);
        final tag = row.readTableOrNull(tags);
        final entry = byId.putIfAbsent(rec.id, () {
          order.add(rec.id);
          return RecordingWithTags(recording: rec, tags: []);
        });
        if (tag != null) entry.tags.add(tag.name);
      }
      return [for (final id in order) byId[id]!];
    });
  }
}
