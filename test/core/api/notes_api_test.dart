import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mikro/core/api/api_errors.dart';
import 'package:mikro/core/api/notes_api.dart';
import 'package:mikro/core/models/provider_config.dart';

Map<String, dynamic> reply(String content) => {
  'choices': [
    {
      'message': {'content': content},
    },
  ],
};

void main() {
  const config = ServiceConfig(
    baseUrl: 'https://api.test/v1',
    apiKey: 'k',
    model: 'llm-x',
  );

  group('parseNote', () {
    test('leading H1 becomes the title and is removed from the body', () {
      final note = NotesApi.parseNote('# Standup 12.09\n\n## Ustalenia\n- deploy w piątek');
      expect(note!.title, 'Standup 12.09');
      expect(note.content, '## Ustalenia\n- deploy w piątek');
    });

    test('wrapping code fence is stripped', () {
      final note = NotesApi.parseNote('```markdown\n# Tytuł\n\ntreść\n```');
      expect(note!.title, 'Tytuł');
      expect(note.content, 'treść');
    });

    test('without a leading H1 the whole text is the body and title is null', () {
      final note = NotesApi.parseNote('Wstęp\n\n# Nie tytuł, bo nie na początku');
      expect(note!.title, isNull);
      expect(note.content, 'Wstęp\n\n# Nie tytuł, bo nie na początku');
    });

    test('closing hashes of an ATX heading are not part of the title', () {
      expect(NotesApi.parseNote('# Plan ##\nx')!.title, 'Plan');
    });

    test('empty output is unusable', () {
      expect(NotesApi.parseNote('   '), isNull);
      expect(NotesApi.parseNote('```\n```'), isNull);
    });
  });

  test('generate sends transcript with the tag model and parses the reply', () async {
    final dio = Dio();
    final adapter = DioAdapter(dio: dio);
    Object? sent;
    adapter.onPost('https://api.test/v1/chat/completions', (server) {
      server.reply(200, reply('# Zakupy\n\n- mleko'));
    }, data: Matchers.any);
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          sent = options.data;
          handler.next(options);
        },
      ),
    );

    final note = await NotesApi(dio).generate(transcript: 'kupić mleko', config: config);

    expect(note.title, 'Zakupy');
    expect(note.content, '- mleko');
    final body = sent! as Map<String, dynamic>;
    expect(body['model'], 'llm-x');
    expect((body['messages'] as List).last, {'role': 'user', 'content': 'kupić mleko'});
  });

  test('empty model reply -> noContent', () async {
    final dio = Dio();
    DioAdapter(dio: dio).onPost(
      'https://api.test/v1/chat/completions',
      (server) => server.reply(200, reply('')),
      data: Matchers.any,
    );
    await expectLater(
      NotesApi(dio).generate(transcript: 'x', config: config),
      throwsA(isA<MikroApiException>().having((e) => e.kind, 'kind', ApiErrorKind.noContent)),
    );
  });

  group('style', () {
    Future<String> systemPromptFor(NoteStyle style, [String custom = '']) async {
      final dio = Dio();
      Object? sent;
      dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
        sent = o.data;
        h.next(o);
      }));
      DioAdapter(dio: dio).onPost('https://api.test/v1/chat/completions',
          (server) => server.reply(200, reply('# T\n\nx')),
          data: Matchers.any);
      await NotesApi(dio)
          .generate(transcript: 't', config: config, style: style, customStyle: custom);
      return ((sent! as Map)['messages'] as List).first['content'] as String;
    }

    test('every style keeps the fixed format rules', () async {
      for (final style in NoteStyle.values) {
        final prompt = await systemPromptFor(style, 'Pisz wierszem.');
        expect(prompt, contains('level-1 heading'), reason: style.name);
        expect(prompt, contains('same language as the transcript'), reason: style.name);
      }
    });

    test('presets differ from each other', () async {
      final prompts = {for (final s in NoteStyle.values) await systemPromptFor(s, 'Własne.')};
      expect(prompts, hasLength(NoteStyle.values.length));
    });

    test('custom instructions are passed through verbatim', () async {
      final prompt = await systemPromptFor(NoteStyle.custom, '  Pisz jak do studenta.  ');
      expect(prompt, contains('Pisz jak do studenta.'));
    });

    test('empty custom instructions fall back to the detailed style', () {
      expect(NotesApi.styleInstructions(NoteStyle.custom, '   '),
          NotesApi.styleInstructions(NoteStyle.detailed, ''));
    });
  });
}
