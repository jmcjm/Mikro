import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mikro/core/api/api_errors.dart';
import 'package:mikro/core/api/tagging_api.dart';
import 'package:mikro/core/models/provider_config.dart';

void main() {
  const config = ProviderConfig(baseUrl: 'https://api.test/v1', apiKey: 'k', sttModel: 's', tagModel: 't');

  group('parseMeta', () {
    test('czysty obiekt JSON: tytul i tagi', () {
      final meta = TaggingApi.parseMeta('{"title":"Standup i release","tags":["Praca","notatki"]}');
      expect(meta!.title, 'Standup i release');
      expect(meta.tags, ['praca', 'notatki']);
    });
    test('JSON w plocie markdown', () {
      final meta = TaggingApi.parseMeta('```json\n{"title":"Zakupy","tags":["a","b"]}\n```');
      expect(meta!.title, 'Zakupy');
      expect(meta.tags, ['a', 'b']);
    });
    test('tekst dookola obiektu', () {
      final meta = TaggingApi.parseMeta('Oto wynik: {"title":"X","tags":["x"]} mam nadzieje ze pomoglem');
      expect(meta!.title, 'X');
      expect(meta.tags, ['x']);
    });
    test('dedupe, trim i twardy cap na 5 tagach', () {
      final meta = TaggingApi.parseMeta(
          '{"title":"T","tags":[" a ","a","b","c","d","e","f","g"]}');
      expect(meta!.tags, ['a', 'b', 'c', 'd', 'e']);
    });
    test('pusta tablica tagow to poprawna odpowiedz: transkrypt bez konkretow', () {
      // Prompt wprost pozwala modelowi oddac [], gdy nie ma czego otagowac. Tytul zostaje.
      final meta = TaggingApi.parseMeta('{"title":"Luzna mysl","tags":[]}');
      expect(meta!.tags, isEmpty);
      expect(meta.title, 'Luzna mysl');
    });
    test('lista bez ani jednego uzytecznego tagu -> null, czyli retry', () {
      // Pinning: [] to swiadoma odpowiedz modelu, ale lista samych smieci to zepsuty output
      // i ma dostac druga szanse. Te dwie sciezki nie moga sie skleic.
      expect(TaggingApi.parseMeta('{"title":"T","tags":[1,2,3]}'), isNull);
      expect(TaggingApi.parseMeta('{"title":"T","tags":["","   "]}'), isNull);
    });
    test('brak pola tags albo zly typ tags -> null, czyli retry', () {
      expect(TaggingApi.parseMeta('{"title":"T"}'), isNull);
      expect(TaggingApi.parseMeta('{"title":"T","tags":"praca"}'), isNull);
      expect(TaggingApi.parseMeta('{}'), isNull);
    });
    test('ZMIANA KONTRAKTU: gola tablica tagow to juz nie jest poprawna odpowiedz', () {
      // Do v4 model oddawal sama tablice. Teraz kontrakt to obiekt z tytulem i tagami,
      // wiec stary ksztalt musi isc w ponowienie zamiast po cichu gubic tytul.
      expect(TaggingApi.parseMeta('["praca","notatki"]'), isNull);
      expect(TaggingApi.parseMeta('[]'), isNull);
    });
    test('tytul pusty, nie-string albo nieobecny -> null, ale tagi przechodza', () {
      // Tytul jest polem miekkim: brak tytulu nie moze kosztowac calego wyniku tagowania.
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
    test('tytul dostaje twardy limit dlugosci w kodzie, nie tylko w prompcie', () {
      final long = 'a' * (TaggingApi.maxTitleChars + 40);
      final meta = TaggingApi.parseMeta('{"title":"$long","tags":["praca"]}');
      expect(meta!.title, hasLength(TaggingApi.maxTitleChars),
          reason: 'prompt to prosba, przyciecie musi zyc w kodzie');
    });
    test('tytul jest skladany do jednej linii', () {
      final meta = TaggingApi.parseMeta('{"title":"Standup\\n  i   release","tags":["praca"]}');
      expect(meta!.title, 'Standup i release',
          reason: 'naglowek jest jednoliniowy, wiec bialy znak nie moze go rozpychac');
    });
    test('smieci -> null', () {
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

    test('szczesliwa sciezka: tytul i tagi z jednego wywolania', () async {
      final dio = Dio();
      DioAdapter(dio: dio).onPost('https://api.test/v1/chat/completions',
          (server) => server.reply(200, chatReply('{"title":"Standup","tags":["praca"]}')),
          data: Matchers.any);
      final meta = await TaggingApi(dio).generateMeta(transcript: 'tekst', config: config);
      expect(meta.title, 'Standup');
      expect(meta.tags, ['praca']);
    });

    test('smieciowa odpowiedz -> retry raz -> badTags, dokladnie 2 requesty', () async {
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

    test('ZMIANA KONTRAKTU: stara tablica tagow konczy retry i badTags', () async {
      // Swiadomie zmieniona semantyka: przed v4 ta odpowiedz byla poprawna.
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
      expect(calls, 2, reason: 'zly ksztalt dostaje druga szanse, tak jak kazdy inny');
    });

    // --- P1: klasyfikacja i osloniecie ekstrakcji (ruling koordynatora) ---

    test('cialo odpowiedzi nie bedace mapa -> badFormat, nie network', () async {
      final dio = Dio();
      DioAdapter(dio: dio).onPost('https://api.test/v1/chat/completions',
          (server) => server.reply(200, [1, 2, 3]),
          data: Matchers.any);
      await expectLater(
        TaggingApi(dio).generateMeta(transcript: 'tekst', config: config),
        throwsA(isA<MikroApiException>().having((e) => e.kind, 'kind', ApiErrorKind.badFormat)),
      );
    });

    test('pusta lista choices -> noContent bez surowego bledu', () async {
      final dio = Dio();
      DioAdapter(dio: dio).onPost('https://api.test/v1/chat/completions',
          (server) => server.reply(200, {'choices': <dynamic>[]}),
          data: Matchers.any);
      await expectLater(
        TaggingApi(dio).generateMeta(transcript: 'tekst', config: config),
        throwsA(isA<MikroApiException>().having((e) => e.kind, 'kind', ApiErrorKind.noContent)),
      );
    });

    test('pozostale niekonformne ksztalty odpowiedzi tez daja noContent', () async {
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
          TaggingApi(dio).generateMeta(transcript: 'tekst', config: config),
          throwsA(isA<MikroApiException>().having((e) => e.kind, 'kind', ApiErrorKind.noContent)),
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
          (server) => server.reply(200, chatReply('{"title":"T","tags":["praca"]}')),
          data: Matchers.any);

      await TaggingApi(dio)
          .generateMeta(transcript: 'transkrypt do otagowania', config: config);

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
      // Zdjecie cap-a z parseMeta pali ten test.
      final dio = Dio();
      DioAdapter(dio: dio).onPost(
          'https://api.test/v1/chat/completions',
          (server) => server.reply(
              200,
              chatReply('{"title":"Rekrutacja","tags":["rekrutacja","onboarding","java",'
                  '"budzet q3","migracja","urlop","raport","deploy"]}')),
          data: Matchers.any);

      final meta = await TaggingApi(dio).generateMeta(transcript: 'tekst', config: config);

      expect(meta.tags, hasLength(5), reason: 'twardy limit 5 tagow na nagranie');
      expect(meta.tags, ['rekrutacja', 'onboarding', 'java', 'budzet q3', 'migracja']);
    });

    test('STRAZNIK TRIMA: dlugi tytul z API dojezdza przyciety', () async {
      final dio = Dio();
      final long = 'z' * 200;
      DioAdapter(dio: dio).onPost('https://api.test/v1/chat/completions',
          (server) => server.reply(200, chatReply('{"title":"$long","tags":["praca"]}')),
          data: Matchers.any);

      final meta = await TaggingApi(dio).generateMeta(transcript: 'tekst', config: config);

      expect(meta.title, hasLength(TaggingApi.maxTitleChars));
    });

    test('pusta tablica z API -> pusta lista tagow, bez retry i bez wyjatku', () async {
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
      expect(calls, 1, reason: '[] to poprawna odpowiedz, nie powod do ponowienia');
    });

    test('STRAZNIK PROMPTU: system prompt niesie limit 5, jezyk transkryptu i tytul',
        () async {
      // Celowo NIE asercjonujemy brzmienia zakazu generykow — to instrukcja semantyczna,
      // ktorej kazde sensowne przeformulowanie paliloby test, nie dowodzac niczego o modelu.
      // Pilnujemy tego, czego zniknieciu towarzyszy realna regresja: liczby 5, reguly
      // "w jezyku transkryptu" (l10n EN nie moze dostac polskich tagow), obu kluczy
      // kontraktu oraz limitu dlugosci tytulu.
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
          reason: 'prompt musi prosic model o co najwyzej 5 tagow');
      expect(systemPrompt, matches(RegExp('language|jezyk', caseSensitive: false)),
          reason: 'prompt musi wiazac jezyk tytulu i tagow z jezykiem transkryptu');
      expect(systemPrompt, contains('"title"'),
          reason: 'model musi wiedziec, ze kontrakt to obiekt z tytulem');
      expect(systemPrompt, contains('"tags"'),
          reason: 'model musi wiedziec, ze kontrakt to obiekt z tagami');
      expect(systemPrompt, contains('${TaggingApi.maxTitleChars}'),
          reason: 'limit dlugosci tytulu ma byc tez prosba do modelu, nie tylko cieciem w kodzie');
    });
  });
}
