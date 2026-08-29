import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mikro/core/api/api_errors.dart';
import 'package:mikro/core/api/transcription_api.dart';
import 'package:mikro/core/models/provider_config.dart';

void main() {
  const config = ProviderConfig(
    baseUrl: 'https://api.test/v1',
    apiKey: 'k',
    sttModel: 'whisper-x',
    tagModel: 'llm-x',
  );
  late Dio dio;
  late DioAdapter adapter;
  late String audioPath;

  setUp(() {
    dio = Dio();
    adapter = DioAdapter(dio: dio);
    final f = File('${Directory.systemTemp.createTempSync('mikro').path}/a.m4a')
      ..writeAsBytesSync([1, 2, 3]);
    audioPath = f.path;
  });

  test('zwraca text z odpowiedzi', () async {
    adapter.onPost('https://api.test/v1/audio/transcriptions',
        (server) => server.reply(200, {'text': 'ala ma kota'}),
        data: Matchers.any);
    final api = TranscriptionApi(dio);
    expect(await api.transcribe(audioPath: audioPath, config: config), 'ala ma kota');
  });

  test('401 -> MikroApiException auth', () async {
    adapter.onPost('https://api.test/v1/audio/transcriptions',
        (server) => server.reply(401, {'error': 'bad key'}),
        data: Matchers.any);
    final api = TranscriptionApi(dio);
    await expectLater(
      api.transcribe(audioPath: audioPath, config: config),
      throwsA(isA<MikroApiException>().having((e) => e.kind, 'kind', ApiErrorKind.auth)),
    );
  });

  test('odpowiedz bez pola text -> badResponse', () async {
    adapter.onPost('https://api.test/v1/audio/transcriptions',
        (server) => server.reply(200, {'nope': 1}),
        data: Matchers.any);
    final api = TranscriptionApi(dio);
    await expectLater(
      api.transcribe(audioPath: audioPath, config: config),
      throwsA(isA<MikroApiException>().having((e) => e.kind, 'kind', ApiErrorKind.badResponse)),
    );
  });

  test('cialo odpowiedzi nie bedace mapa -> badResponse, nie network', () async {
    // Generyk post<Map<String, dynamic>> wymuszal rzutowanie; przy tablicy JSON dio lapalo
    // _TypeError i pakowalo je w DioException bez odpowiedzi, wiec mapDioError klasyfikowalo
    // to jako awarie sieci i uzytkownik dostawal "Brak polaczenia z siecia."
    adapter.onPost('https://api.test/v1/audio/transcriptions',
        (server) => server.reply(200, [1, 2, 3]),
        data: Matchers.any);
    final api = TranscriptionApi(dio);
    await expectLater(
      api.transcribe(audioPath: audioPath, config: config),
      throwsA(isA<MikroApiException>().having((e) => e.kind, 'kind', ApiErrorKind.badResponse)),
    );
  });

  test('STRAZNIK: zadanie niesie klucz API, wybrany model i plik audio', () async {
    // Mock dopasowuje `data: Matchers.any`, wiec sam w sobie nie sprawdza NICZEGO z zadania.
    // Bez tego straznika klient moglby przestac wysylac naglowek Authorization, pole model
    // albo caly plik audio i zestaw nadal swiecilby na zielono.
    RequestOptions? sentRequest;
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        sentRequest = options;
        handler.next(options);
      },
    ));
    adapter.onPost('https://api.test/v1/audio/transcriptions',
        (server) => server.reply(200, {'text': 'ok'}),
        data: Matchers.any);

    await TranscriptionApi(dio).transcribe(audioPath: audioPath, config: config);

    expect(sentRequest, isNotNull, reason: 'interceptor musial zobaczyc zadanie');
    expect(sentRequest!.headers['Authorization'], 'Bearer k',
        reason: 'klucz API musi jechac w naglowku Authorization');

    final form = sentRequest!.data as FormData;
    final formFields = {for (final f in form.fields) f.key: f.value};
    expect(formFields['model'], config.sttModel,
        reason: 'multipart musi niesc wybrany model STT w polu model');
    expect(form.files.map((f) => f.key), contains('file'),
        reason: 'multipart musi niesc nagranie w polu file');
  });
}
