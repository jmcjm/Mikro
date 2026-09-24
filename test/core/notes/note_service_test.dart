import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mikro/core/api/api_errors.dart';
import 'package:mikro/core/api/notes_api.dart';
import 'package:mikro/core/db/database.dart';
import 'package:mikro/core/models/provider_config.dart';
import 'package:mikro/core/notes/note_service.dart';
import 'package:mikro/core/settings/settings_repository.dart';

class _Settings implements SettingsRepository {
  _Settings(this.config);
  final ProviderConfig? config;
  @override
  Future<ProviderConfig?> load() async => config;
  @override
  Future<void> save(ProviderConfig config) async {}
}

const _config = ProviderConfig(
  baseUrl: 'https://api.test/v1',
  apiKey: 'k',
  sttModel: 'whisper-x',
  tagModel: 'llm-x',
);

void main() {
  late AppDatabase db;
  late Dio dio;
  late DioAdapter adapter;
  final now = DateTime.utc(2026, 9, 24, 12);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dio = Dio();
    adapter = DioAdapter(dio: dio);
    await db.insertRecording(
      id: 'r',
      createdAt: DateTime.utc(2026),
      durationMs: 1000,
      audioPath: '/r.m4a',
    );
  });
  tearDown(() => db.close());

  NoteService service({ProviderConfig? config = _config}) =>
      NoteService(db: db, notesApi: NotesApi(dio), settings: _Settings(config), clock: () => now);

  void modelReplies(String content) => adapter.onPost(
    'https://api.test/v1/chat/completions',
    (server) => server.reply(200, {
      'choices': [
        {
          'message': {'content': content},
        },
      ],
    }),
    data: Matchers.any,
  );

  test('creates a linked note from the current transcript', () async {
    await db.setTranscript('r', 'surowy', 'whisper-x');
    await db.updateTranscript('r', 'poprawiony ręcznie');
    Object? sent;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          sent = o.data;
          h.next(o);
        },
      ),
    );
    modelReplies('# Spotkanie\n\n- punkt');

    final id = await service().createFromRecording('r');

    final note = await db.getNote(id);
    expect(note!.recordingId, 'r');
    expect(note.title, 'Spotkanie');
    expect(note.content, '- punkt');
    expect(note.createdAt.toUtc(), now);
    expect(
      ((sent! as Map)['messages'] as List).last['content'],
      'poprawiony ręcznie',
      reason: 'manual transcript corrections must reach the note',
    );
  });

  test('falls back to the recording title when the model gives none', () async {
    await db.setTranscript('r', 'tekst', 'whisper-x');
    await db.setTitle('r', 'Tytuł nagrania');
    modelReplies('- sam punkt');

    final id = await service().createFromRecording('r');
    expect((await db.getNote(id))!.title, 'Tytuł nagrania');
  });

  test('no provider configured -> NoConfigException, nothing saved', () async {
    await db.setTranscript('r', 'tekst', 'whisper-x');
    await expectLater(
      service(config: null).createFromRecording('r'),
      throwsA(isA<NoConfigException>()),
    );
    expect(await db.watchNotes().first, isEmpty);
  });

  test('recording without transcript is rejected before any API call', () async {
    await expectLater(service().createFromRecording('r'), throwsA(isA<MikroApiException>()));
  });

  test('regenerate rewrites content in place, keeping id and link', () async {
    await db.setTranscript('r', 'tekst', 'whisper-x');
    await db.insertNote(
      id: 'n',
      recordingId: 'r',
      title: 'stary',
      content: 'stara treść',
      now: DateTime.utc(2026),
    );
    modelReplies('# Nowy\n\nnowa treść');

    await service().regenerate('n');

    final note = await db.getNote('n');
    expect(note!.title, 'Nowy');
    expect(note.content, 'nowa treść');
    expect(note.recordingId, 'r');
    expect(note.updatedAt.toUtc(), now);
  });

  test('regenerate of an unlinked note fails without touching it', () async {
    await db.insertNote(
      id: 'n',
      recordingId: null,
      title: 't',
      content: 'c',
      now: DateTime.utc(2026),
    );
    await expectLater(service().regenerate('n'), throwsA(isA<MikroApiException>()));
    expect((await db.getNote('n'))!.content, 'c');
  });
}
