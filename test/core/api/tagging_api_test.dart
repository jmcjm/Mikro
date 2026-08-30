import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mikro/core/api/api_errors.dart';
import 'package:mikro/core/api/tagging_api.dart';
import 'package:mikro/core/models/provider_config.dart';

void main() {
  const config = ProviderConfig(baseUrl: 'https://api.test/v1', apiKey: 'k', sttModel: 's', tagModel: 't');

  group('parseTags', () {
    test('czysty JSON array', () {
      expect(TaggingApi.parseTags('["Praca", "notatki"]'), ['praca', 'notatki']);
    });
    test('JSON w plocie markdown', () {
      expect(TaggingApi.parseTags('```json\n["a","b"]\n```'), ['a', 'b']);
    });
    test('tekst dookola arraya', () {
      expect(TaggingApi.parseTags('Oto tagi: ["x"] mam nadzieje ze pomoglem'), ['x']);
    });
    test('dedupe, trim i twardy cap na 5 tagach', () {
      expect(
        TaggingApi.parseTags('[" a ","a","b","c","d","e","f","g"]'),
        ['a', 'b', 'c', 'd', 'e'],
      );
    });
    test('pusta tablica to poprawna odpowiedz: transkrypt bez konkretow', () {
      // Prompt wprost pozwala modelowi oddac [], gdy nie ma czego otagowac.
      // Gdyby to nadal bylo null, taka odpowiedz szlaby w retry i konczyla sie badResponse.
      expect(TaggingApi.parseTags('[]'), isEmpty);
    });
    test('lista bez ani jednego uzytecznego tagu -> null, czyli retry', () {
      // Pinning: [] to swiadoma odpowiedz modelu, ale lista samych smieci to zepsuty output
      // i ma dostac druga szanse. Te dwie sciezki nie moga sie skleic.
      expect(TaggingApi.parseTags('[1, 2, 3]'), isNull);
      expect(TaggingApi.parseTags('["", "   "]'), isNull);
    });
    test('smieci -> null', () {
      expect(TaggingApi.parseTags('nie mam tagow, przykro mi'), isNull);
      expect(TaggingApi.parseTags('{"tags": "zly typ"}'), isNull);
    });
  });

  group('generateTags', () {
    Map<String, dynamic> chatReply(String content) => {
          'choices': [
            {'message': {'content': content}}
          ]
        };

    test('szczesliwa sciezka', () async {
      final dio = Dio();
      DioAdapter(dio: dio).onPost('https://api.test/v1/chat/completions',
          (server) => server.reply(200, chatReply('["praca"]')),
          data: Matchers.any);
      final api = TaggingApi(dio);
      expect(await api.generateTags(transcript: 'tekst', config: config), ['praca']);
    });

    test('smieciowa odpowiedz -> retry raz -> badResponse, dokladnie 2 requesty', () async {
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
        api.generateTags(transcript: 'tekst', config: config),
        throwsA(isA<MikroApiException>().having((e) => e.kind, 'kind', ApiErrorKind.badResponse)),
      );
      expect(calls, 2);
    });

    // --- P1: klasyfikacja i osloniecie ekstrakcji (ruling koordynatora) ---

    test('cialo odpowiedzi nie bedace mapa -> badResponse, nie network', () async {
      final dio = Dio();
      DioAdapter(dio: dio).onPost('https://api.test/v1/chat/completions',
          (server) => server.reply(200, [1, 2, 3]),
          data: Matchers.any);
      await expectLater(
        TaggingApi(dio).generateTags(transcript: 'tekst', config: config),
        throwsA(isA<MikroApiException>().having((e) => e.kind, 'kind', ApiErrorKind.badResponse)),
      );
    });

    test('pusta lista choices -> badResponse bez surowego bledu', () async {
      final dio = Dio();
      DioAdapter(dio: dio).onPost('https://api.test/v1/chat/completions',
          (server) => server.reply(200, {'choices': <dynamic>[]}),
          data: Matchers.any);
      await expectLater(
        TaggingApi(dio).generateTags(transcript: 'tekst', config: config),
        throwsA(isA<MikroApiException>().having((e) => e.kind, 'kind', ApiErrorKind.badResponse)),
      );
    });

    test('pozostale niekonformne ksztalty odpowiedzi tez daja badResponse', () async {
      // Ruling P1 wymienia cztery ksztalty, ktore nie moga wypuscic surowego bledu.
      // Dwa maja wlasne testy wyzej; te trzy domykaja liste.
      final shapes = <String, Map<String, dynamic>>{
        'brak pola choices': {'usage': 1},
        'choices nie jest lista': {'choices': 'nope'},
        'message nie jest mapa': {
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
          TaggingApi(dio).generateTags(transcript: 'tekst', config: config),
          throwsA(isA<MikroApiException>().having((e) => e.kind, 'kind', ApiErrorKind.badResponse)),
          reason: entry.key,
        );
      }
    });

    // --- P2: straznik zadania (ruling koordynatora) ---

    test('STRAZNIK: zadanie niesie klucz API, model, temperature i oba komunikaty', () async {
      // Mock dopasowuje `data: Matchers.any`, wiec sam z siebie nie sprawdza NICZEGO z zadania.
      final dio = Dio();
      RequestOptions? sentRequest;
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          sentRequest = options;
          handler.next(options);
        },
      ));
      DioAdapter(dio: dio).onPost('https://api.test/v1/chat/completions',
          (server) => server.reply(200, chatReply('["praca"]')),
          data: Matchers.any);

      await TaggingApi(dio)
          .generateTags(transcript: 'transkrypt do otagowania', config: config);

      expect(sentRequest, isNotNull, reason: 'interceptor musial zobaczyc zadanie');
      expect(sentRequest!.headers['Authorization'], 'Bearer k',
          reason: 'klucz API musi jechac w naglowku Authorization');

      final body = sentRequest!.data as Map<String, dynamic>;
      expect(body['model'], config.tagModel, reason: 'zadanie musi niesc wybrany model tagujacy');
      expect(body['temperature'], 0, reason: 'tagowanie ma byc deterministyczne');

      final messages = body['messages'] as List<dynamic>;
      expect(messages, hasLength(2), reason: 'system prompt oraz transkrypt uzytkownika');

      final systemMessage = messages[0] as Map<String, dynamic>;
      expect(systemMessage['role'], 'system');
      expect(systemMessage['content'], isA<String>(),
          reason: 'system prompt musi byc tekstem');
      expect((systemMessage['content'] as String).isNotEmpty, isTrue,
          reason: 'system prompt nie moze byc pusty');

      final userMessage = messages[1] as Map<String, dynamic>;
      expect(userMessage['role'], 'user');
      expect(userMessage['content'], 'transkrypt do otagowania',
          reason: 'transkrypt musi dojechac do modelu w calosci');
    });

    // --- Cap 5 tagow: prompt to prosba do modelu, kod to gwarancja ---

    test('STRAZNIK CAPA: model oddaje 8 tagow -> na wyjsciu dokladnie 5', () async {
      // Model potrafi zignorowac limit z promptu, wiec przyciecie musi zyc w kodzie.
      // Zdjecie cap-a z parseTags pali ten test.
      final dio = Dio();
      DioAdapter(dio: dio).onPost(
          'https://api.test/v1/chat/completions',
          (server) => server.reply(
              200,
              chatReply(
                  '["rekrutacja","onboarding","java","budzet q3","migracja","urlop","raport","deploy"]')),
          data: Matchers.any);

      final tags = await TaggingApi(dio).generateTags(transcript: 'tekst', config: config);

      expect(tags, hasLength(5), reason: 'twardy limit 5 tagow na nagranie');
      expect(tags, ['rekrutacja', 'onboarding', 'java', 'budzet q3', 'migracja']);
    });

    test('pusta tablica z API -> pusta lista tagow, bez retry i bez wyjatku', () async {
      final dio = Dio();
      var calls = 0;
      dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
        calls++;
        h.next(o);
      }));
      DioAdapter(dio: dio).onPost('https://api.test/v1/chat/completions',
          (server) => server.reply(200, chatReply('[]')),
          data: Matchers.any);

      expect(await TaggingApi(dio).generateTags(transcript: 'tekst', config: config), isEmpty);
      expect(calls, 1, reason: '[] to poprawna odpowiedz, nie powod do ponowienia');
    });

    test('STRAZNIK PROMPTU: system prompt niesie limit 5 i regule jezyka transkryptu', () async {
      // Celowo NIE asercjonujemy brzmienia zakazu generykow — to instrukcja semantyczna,
      // ktorej kazde sensowne przeformulowanie paliloby test, nie dowodzac niczego o modelu.
      // Pilnujemy dwoch rzeczy, ktorych zniknieciu towarzyszy realna regresja:
      // liczby 5 oraz reguly "tagi w jezyku transkryptu" (l10n EN nie moze dostac polskich tagow).
      final dio = Dio();
      RequestOptions? sentRequest;
      dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
        sentRequest = options;
        handler.next(options);
      }));
      DioAdapter(dio: dio).onPost('https://api.test/v1/chat/completions',
          (server) => server.reply(200, chatReply('["praca"]')),
          data: Matchers.any);

      await TaggingApi(dio).generateTags(transcript: 'tekst', config: config);

      final messages = (sentRequest!.data as Map<String, dynamic>)['messages'] as List<dynamic>;
      final systemPrompt = (messages[0] as Map<String, dynamic>)['content'] as String;

      expect(systemPrompt, matches(RegExp(r'\b(5|five|piec)\b', caseSensitive: false)),
          reason: 'prompt musi prosic model o co najwyzej 5 tagow');
      expect(systemPrompt, matches(RegExp('language|jezyk', caseSensitive: false)),
          reason: 'prompt musi wiazac jezyk tagow z jezykiem transkryptu, a nie z polskim');
    });
  });
}
