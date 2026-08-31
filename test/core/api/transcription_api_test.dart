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

  test('returns text from response', () async {
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

  test('response without text field -> noTranscript', () async {
    adapter.onPost('https://api.test/v1/audio/transcriptions',
        (server) => server.reply(200, {'nope': 1}),
        data: Matchers.any);
    final api = TranscriptionApi(dio);
    await expectLater(
      api.transcribe(audioPath: audioPath, config: config),
      throwsA(isA<MikroApiException>().having((e) => e.kind, 'kind', ApiErrorKind.noTranscript)),
    );
  });

  test('response body that is not a map -> badFormat, not network', () async {
    // The post<Map<String, dynamic>> generic forced casting; with a JSON array dio caught
    // _TypeError and wrapped it in a DioException without response, so mapDioError classified
    // this as a network failure and the user received "No network connection."
    adapter.onPost('https://api.test/v1/audio/transcriptions',
        (server) => server.reply(200, [1, 2, 3]),
        data: Matchers.any);
    final api = TranscriptionApi(dio);
    await expectLater(
      api.transcribe(audioPath: audioPath, config: config),
      throwsA(isA<MikroApiException>().having((e) => e.kind, 'kind', ApiErrorKind.badFormat)),
    );
  });

  test('GUARD: request carries API key, selected model, and audio file', () async {
    // The mock matches `data: Matchers.any`, so on its own it verifies NOTHING from the request.
    // Without this guard the client could stop sending the Authorization header, model field,
    // or the entire audio file and the test suite would still pass.
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

    expect(sentRequest, isNotNull, reason: 'interceptor must have seen the request');
    expect(sentRequest!.headers['Authorization'], 'Bearer k',
        reason: 'API key must be sent in the Authorization header');

    final form = sentRequest!.data as FormData;
    final formFields = {for (final f in form.fields) f.key: f.value};
    expect(formFields['model'], config.sttModel,
        reason: 'multipart must carry the selected STT model in the model field');
    expect(form.files.map((f) => f.key), contains('file'),
        reason: 'multipart must carry the recording in the file field');
  });
}
