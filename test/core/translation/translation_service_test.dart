import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mikro/core/api/api_errors.dart';
import 'package:mikro/core/api/translation_api.dart';
import 'package:mikro/core/db/database.dart';
import 'package:mikro/core/models/provider_config.dart';
import 'package:mikro/core/models/translation_language.dart';
import 'package:mikro/core/notes/note_service.dart';
import 'package:mikro/core/settings/settings_repository.dart';
import 'package:mikro/core/translation/translation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Settings implements SettingsRepository {
  _Settings(this.config);
  final ServiceConfig? config;
  ApiTask? asked;
  @override
  Future<ServiceConfig?> load(ApiTask task) async {
    asked = task;
    return config;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

const _config = ServiceConfig(baseUrl: 'https://api.test/v1', apiKey: 'k', model: 'llm');

void main() {
  late AppDatabase db;
  late Dio dio;
  late DioAdapter adapter;
  late SharedPreferences prefs;
  late List<Map<String, dynamic>> sent;
  final now = DateTime.utc(2026, 9, 25);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dio = Dio();
    sent = [];
    dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
      sent.add(o.data as Map<String, dynamic>);
      h.next(o);
    }));
    adapter = DioAdapter(dio: dio);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await db.insertRecording(
        id: 'r', createdAt: DateTime.utc(2026), durationMs: 1000, audioPath: '/r.m4a');
  });
  tearDown(() => db.close());

  TranslationService service({ServiceConfig? config = _config, _Settings? settings}) =>
      TranslationService(
        db: db,
        api: TranslationApi(dio),
        settings: settings ?? _Settings(config),
        prefs: prefs,
        clock: () => now,
      );

  void modelReplies(String content) => adapter.onPost(
        'https://api.test/v1/chat/completions',
        (server) => server.reply(200, {
          'choices': [
            {'message': {'content': content}},
          ],
        }),
        data: Matchers.any,
      );

  String userMessage() => (sent.single['messages'] as List).last['content'] as String;
  String systemMessage() => (sent.single['messages'] as List).first['content'] as String;

  test('translates the current transcript with the translation settings and stores it',
      () async {
    await db.setTranscript('r', 'surowy', 'w');
    await db.updateTranscript('r', 'poprawiony');
    modelReplies('```\ncorrected\n```');
    final settings = _Settings(_config);

    await service(settings: settings).translateRecording('r', 'en');

    expect(settings.asked, ApiTask.translate);
    expect(userMessage(), 'poprawiony');
    expect(systemMessage(), contains('into English'));
    final stored = await db.watchTranslations(recordingId: 'r').first;
    expect(stored.single.content, 'corrected', reason: 'code fence stripped');
    expect(stored.single.language, 'en');
    expect(service().lastLanguage, 'en');
  });

  test('a note is translated with its title as the heading', () async {
    await db.insertNote(id: 'n', recordingId: null, title: 'Plan', content: '- a', now: now);
    modelReplies('# Plan\n\n- a');

    await service().translateNote('n', 'de');

    expect(userMessage(), '# Plan\n\n- a');
    expect(systemMessage(), contains('into German'));
    expect((await db.watchTranslations(noteId: 'n').first).single.language, 'de');
  });

  test('no configuration -> NoConfigException, nothing stored', () async {
    await db.setTranscript('r', 'tekst', 'w');
    await expectLater(
        service(config: null).translateRecording('r', 'en'), throwsA(isA<NoConfigException>()));
    expect(await db.watchTranslations(recordingId: 'r').first, isEmpty);
  });

  test('empty model answer is an error, not an empty translation', () async {
    await db.setTranscript('r', 'tekst', 'w');
    modelReplies('   ');
    await expectLater(
      service().translateRecording('r', 'en'),
      throwsA(isA<MikroApiException>().having((e) => e.kind, 'kind', ApiErrorKind.noContent)),
    );
  });

  test('unknown stored language code still resolves', () {
    expect(TranslationLanguage.of('xx').nativeName, 'xx');
    expect(TranslationLanguage.of('pl').nativeName, 'Polski');
  });
}
