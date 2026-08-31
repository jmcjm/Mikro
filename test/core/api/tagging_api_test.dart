import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mikro/core/api/api_errors.dart';
import 'package:mikro/core/api/tagging_api.dart';
import 'package:mikro/core/models/provider_config.dart';

void main() {
  const config = ProviderConfig(baseUrl: 'https://api.test/v1', apiKey: 'k', sttModel: 's', tagModel: 't');

  group('parseMeta', () {
    test('clean JSON object: title and tags', () {
      final meta = TaggingApi.parseMeta('{"title":"Standup i release","tags":["Praca","notatki"]}');
      expect(meta!.title, 'Standup i release');
      expect(meta.tags, ['praca', 'notatki']);
    });
    test('JSON in markdown code block', () {
      final meta = TaggingApi.parseMeta('```json\n{"title":"Zakupy","tags":["a","b"]}\n```');
      expect(meta!.title, 'Zakupy');
      expect(meta.tags, ['a', 'b']);
    });
    test('text surrounding the object', () {
      final meta = TaggingApi.parseMeta('Oto wynik: {"title":"X","tags":["x"]} mam nadzieje ze pomoglem');
      expect(meta!.title, 'X');
      expect(meta.tags, ['x']);
    });
    test('deduplicate, trim and hard cap at 5 tags', () {
      final meta = TaggingApi.parseMeta(
          '{"title":"T","tags":[" a ","a","b","c","d","e","f","g"]}');
      expect(meta!.tags, ['a', 'b', 'c', 'd', 'e']);
    });
    test('empty tags array is a valid response: transcript without specifics', () {
      // The prompt explicitly allows the model to return [] when there is nothing to tag. The title remains.
      final meta = TaggingApi.parseMeta('{"title":"Luzna mysl","tags":[]}');
      expect(meta!.tags, isEmpty);
      expect(meta.title, 'Luzna mysl');
    });
    test('list without any useful tags -> null, i.e. retry', () {
      // Pinning: [] is an intentional response from the model, but a list of garbage is broken output
      // and should get a second chance. These two paths must not be conflated.
      expect(TaggingApi.parseMeta('{"title":"T","tags":[1,2,3]}'), isNull);
      expect(TaggingApi.parseMeta('{"title":"T","tags":["","   "]}'), isNull);
    });
    test('missing tags field or invalid tags type -> null, i.e. retry', () {
      expect(TaggingApi.parseMeta('{"title":"T"}'), isNull);
      expect(TaggingApi.parseMeta('{"title":"T","tags":"praca"}'), isNull);
      expect(TaggingApi.parseMeta('{}'), isNull);
    });
    test('CONTRACT CHANGE: bare array of tags is no longer a valid response', () {
      // Prior to v4 the model returned a bare array. Now the contract is an object with title and tags,
      // so the old shape must trigger a retry instead of silently dropping the title.
      expect(TaggingApi.parseMeta('["praca","notatki"]'), isNull);
      expect(TaggingApi.parseMeta('[]'), isNull);
    });
    test('title empty, non-string or absent -> null, but tags pass through', () {
      // Title is an optional field: missing title must not invalidate the entire tagging result.
      for (final content in const [
        '{"title":"","tags":["praca"]}',
        '{"title":"   ","tags":["praca"]}',
        '{"title":42,"tags":["praca"]}',
        '{"title":null,"tags":["praca"]}',
        '{"tags":["praca"]}',
      ]) {
        final meta = TaggingApi.parseMeta(content);
        expect(meta, isNotNull, reason: content);
        expect(meta!.title, isNull, reason: content);
        expect(meta.tags, ['praca'], reason: content);
      }
    });
    test('title gets a hard length limit in code, not just in prompt', () {
      final long = 'a' * (TaggingApi.maxTitleChars + 40);
      final meta = TaggingApi.parseMeta('{"title":"$long","tags":["praca"]}');
      expect(meta!.title, hasLength(TaggingApi.maxTitleChars),
          reason: 'prompt is a request, truncation must exist in code');
    });
    test('title is collapsed into a single line', () {
      final meta = TaggingApi.parseMeta('{"title":"Standup\\n  i   release","tags":["praca"]}');
      expect(meta!.title, 'Standup i release',
          reason: 'the heading is single-line, so whitespace must not inflate it');
    });
    test('garbage -> null', () {
      expect(TaggingApi.parseMeta('nie mam tagow, przykro mi'), isNull);
      expect(TaggingApi.parseMeta('{"tags": "zly typ"}'), isNull);
    });
  });

  group('generateMeta', () {
    Map<String, dynamic> chatReply(String content) => {
          'choices': [
            {'message': {'content': content}}
          ]
        };

    test('happy path: title and tags from a single call', () async {
      final dio = Dio();
      DioAdapter(dio: dio).onPost('https://api.test/v1/chat/completions',
          (server) => server.reply(200, chatReply('{"title":"Standup","tags":["praca"]}')),
          data: Matchers.any);
      final meta = await TaggingApi(dio).generateMeta(transcript: 'tekst', config: config);
      expect(meta.title, 'Standup');
      expect(meta.tags, ['praca']);
    });

    test('garbage response -> retry once -> badTags, exactly 2 requests', () async {
      final dio = Dio();
      var calls = 0;
      dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
        calls++;
        h.next(o);
      }));
      DioAdapter(dio: dio).onPost('https://api.test/v1/chat/completions',
          (server) => server.reply(200, chatReply('nie ma tagow')),
          data: Matchers.any);
      final api = TaggingApi(dio);
      await expectLater(
        api.generateMeta(transcript: 'tekst', config: config),
        throwsA(isA<MikroApiException>().having((e) => e.kind, 'kind', ApiErrorKind.badTags)),
      );
      expect(calls, 2);
    });

    test('CONTRACT CHANGE: old array of tags ends in retry and badTags', () async {
      // Deliberately changed semantics: prior to v4 this response was valid.
      final dio = Dio();
      var calls = 0;
      dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
        calls++;
        h.next(o);
      }));
      DioAdapter(dio: dio).onPost('https://api.test/v1/chat/completions',
          (server) => server.reply(200, chatReply('["praca","notatki"]')),
          data: Matchers.any);
      await expectLater(
        TaggingApi(dio).generateMeta(transcript: 'tekst', config: config),
        throwsA(isA<MikroApiException>().having((e) => e.kind, 'kind', ApiErrorKind.badTags)),
      );
      expect(calls, 2, reason: 'invalid shape gets a second chance, just like any other');
    });

    // --- P1: classification and extraction guard (coordinator ruling) ---

    test('response body that is not a map -> badFormat, not network', () async {
      final dio = Dio();
      DioAdapter(dio: dio).onPost('https://api.test/v1/chat/completions',
          (server) => server.reply(200, [1, 2, 3]),
          data: Matchers.any);
      await expectLater(
        TaggingApi(dio).generateMeta(transcript: 'tekst', config: config),
        throwsA(isA<MikroApiException>().having((e) => e.kind, 'kind', ApiErrorKind.badFormat)),
      );
    });

    test('empty choices list -> noContent without raw error', () async {
      final dio = Dio();
      DioAdapter(dio: dio).onPost('https://api.test/v1/chat/completions',
          (server) => server.reply(200, {'choices': <dynamic>[]}),
          data: Matchers.any);
      await expectLater(
        TaggingApi(dio).generateMeta(transcript: 'tekst', config: config),
        throwsA(isA<MikroApiException>().having((e) => e.kind, 'kind', ApiErrorKind.noContent)),
      );
    });

    test('other non-conforming response shapes also return noContent', () async {
      // Ruling P1 lists four shapes that must not emit a raw error.
      // Two have their own tests above; these three complete the list.
      final shapes = <String, Map<String, dynamic>>{
        'missing choices field': {'usage': 1},
        'choices is not a list': {'choices': 'nope'},
        'message is not a map': {
          'choices': [
            {'message': 'nope'}
          ]
        },
      };
      for (final entry in shapes.entries) {
        final dio = Dio();
        DioAdapter(dio: dio).onPost('https://api.test/v1/chat/completions',
            (server) => server.reply(200, entry.value),
            data: Matchers.any);
        await expectLater(
          TaggingApi(dio).generateMeta(transcript: 'tekst', config: config),
          throwsA(isA<MikroApiException>().having((e) => e.kind, 'kind', ApiErrorKind.noContent)),
          reason: entry.key,
        );
      }
    });

    // --- P2: request guard (coordinator ruling) ---

    test('GUARD: request carries API key, model, temperature, and both messages', () async {
      // The mock matches `data: Matchers.any`, so on its own it verifies NOTHING from the request.
      final dio = Dio();
      RequestOptions? sentRequest;
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          sentRequest = options;
          handler.next(options);
        },
      ));
      DioAdapter(dio: dio).onPost('https://api.test/v1/chat/completions',
          (server) => server.reply(200, chatReply('{"title":"T","tags":["praca"]}')),
          data: Matchers.any);

      await TaggingApi(dio)
          .generateMeta(transcript: 'transkrypt do otagowania', config: config);

      expect(sentRequest, isNotNull, reason: 'interceptor must have seen the request');
      expect(sentRequest!.headers['Authorization'], 'Bearer k',
          reason: 'API key must be sent in the Authorization header');

      final body = sentRequest!.data as Map<String, dynamic>;
      expect(body['model'], config.tagModel, reason: 'request must carry the selected tagging model');
      expect(body['temperature'], 0, reason: 'tagging must be deterministic');

      final messages = body['messages'] as List<dynamic>;
      expect(messages, hasLength(2), reason: 'system prompt and user transcript');

      final systemMessage = messages[0] as Map<String, dynamic>;
      expect(systemMessage['role'], 'system');
      expect(systemMessage['content'], isA<String>(),
          reason: 'system prompt must be text');
      expect((systemMessage['content'] as String).isNotEmpty, isTrue,
          reason: 'system prompt cannot be empty');

      final userMessage = messages[1] as Map<String, dynamic>;
      expect(userMessage['role'], 'user');
      expect(userMessage['content'], 'transkrypt do otagowania',
          reason: 'transcript must reach the model in its entirety');
    });

    // --- Cap 5 tags: prompt is a request to the model, code is a guarantee ---

    test('CAP GUARD: model returns 8 tags -> exactly 5 on output', () async {
      // The model can ignore the limit in the prompt, so truncation must live in code.
      // Removing the cap from parseMeta fails this test.
      final dio = Dio();
      DioAdapter(dio: dio).onPost(
          'https://api.test/v1/chat/completions',
          (server) => server.reply(
              200,
              chatReply('{"title":"Rekrutacja","tags":["rekrutacja","onboarding","java",'
                  '"budzet q3","migracja","urlop","raport","deploy"]}')),
          data: Matchers.any);

      final meta = await TaggingApi(dio).generateMeta(transcript: 'tekst', config: config);

      expect(meta.tags, hasLength(5), reason: 'hard limit of 5 tags per recording');
      expect(meta.tags, ['rekrutacja', 'onboarding', 'java', 'budzet q3', 'migracja']);
    });

    test('TRIM GUARD: long title from API arrives truncated', () async {
      final dio = Dio();
      final long = 'z' * 200;
      DioAdapter(dio: dio).onPost('https://api.test/v1/chat/completions',
          (server) => server.reply(200, chatReply('{"title":"$long","tags":["praca"]}')),
          data: Matchers.any);

      final meta = await TaggingApi(dio).generateMeta(transcript: 'tekst', config: config);

      expect(meta.title, hasLength(TaggingApi.maxTitleChars));
    });

    test('empty array from API -> empty tags list, without retry and without exception', () async {
      final dio = Dio();
      var calls = 0;
      dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
        calls++;
        h.next(o);
      }));
      DioAdapter(dio: dio).onPost('https://api.test/v1/chat/completions',
          (server) => server.reply(200, chatReply('{"title":"Luzna mysl","tags":[]}')),
          data: Matchers.any);

      final meta = await TaggingApi(dio).generateMeta(transcript: 'tekst', config: config);

      expect(meta.tags, isEmpty);
      expect(calls, 1, reason: '[] is a valid response, not a reason to retry');
    });

    test('PROMPT GUARD: system prompt carries limit of 5, transcript language, and title',
        () async {
      // Deliberately do NOT assert exact phrasing for prohibiting generics — that is a semantic instruction
      // where any sensible rephrasing would break the test without proving anything about the model.
      // We safeguard what leads to real regression if omitted: the number 5, the rule
      // "in the transcript language" (EN l10n must not get Polish tags), both contract
      // keys, and the title length limit.
      final dio = Dio();
      RequestOptions? sentRequest;
      dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
        sentRequest = options;
        handler.next(options);
      }));
      DioAdapter(dio: dio).onPost('https://api.test/v1/chat/completions',
          (server) => server.reply(200, chatReply('{"title":"T","tags":["praca"]}')),
          data: Matchers.any);

      await TaggingApi(dio).generateMeta(transcript: 'tekst', config: config);

      final messages = (sentRequest!.data as Map<String, dynamic>)['messages'] as List<dynamic>;
      final systemPrompt = (messages[0] as Map<String, dynamic>)['content'] as String;

      expect(systemPrompt, matches(RegExp(r'\b(5|five|piec)\b', caseSensitive: false)),
          reason: 'prompt must request at most 5 tags from the model');
      expect(systemPrompt, matches(RegExp('language|jezyk', caseSensitive: false)),
          reason: 'prompt must bind title and tags language to transcript language');
      expect(systemPrompt, contains('"title"'),
          reason: 'model must know the contract is an object with a title');
      expect(systemPrompt, contains('"tags"'),
          reason: 'model must know the contract is an object with tags');
      expect(systemPrompt, contains('${TaggingApi.maxTitleChars}'),
          reason: 'title length limit must also be a request to the model, not just code truncation');
    });
  });
}
