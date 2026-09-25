import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mikro/core/api/api_errors.dart';
import 'package:mikro/core/api/transcription_api.dart';
import 'package:mikro/core/models/provider_config.dart';

void main() {
  const config = ServiceConfig(
    baseUrl: 'https://api.test/v1',
    apiKey: 'k',
    model: 'whisper-x',
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
    expect(formFields['model'], config.model,
        reason: 'multipart must carry the selected STT model in the model field');
    expect(form.files.map((f) => f.key), contains('file'),
        reason: 'multipart must carry the recording in the file field');
  });

  group('diarization', () {
    const diarizeConfig = ServiceConfig(
      baseUrl: 'https://api.test/v1',
      apiKey: 'k',
      model: 'gpt-4o-transcribe-diarize',
    );

    test('only models named "diarize" ask for speakers', () {
      expect(TranscriptionApi.supportsDiarization('gpt-4o-transcribe-diarize'), isTrue);
      expect(TranscriptionApi.supportsDiarization('whisper-large-v3-turbo'), isFalse);
      expect(TranscriptionApi.supportsDiarization('gpt-4o-transcribe'), isFalse);
    });

    test('diarizing model requests diarized_json and gets speaker-labelled turns', () async {
      FormData? sent;
      dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
        sent = options.data as FormData;
        handler.next(options);
      }));
      adapter.onPost('https://api.test/v1/audio/transcriptions',
          (server) => server.reply(200, {
                'text': 'Cześć. Jak leci? Dobrze.',
                'segments': [
                  {'speaker': 'A', 'text': 'Cześć.', 'start': 0.0, 'end': 1.0},
                  {'speaker': 'A', 'text': ' Jak leci?', 'start': 1.0, 'end': 2.0},
                  {'speaker': 'B', 'text': 'Dobrze.', 'start': 2.0, 'end': 3.0},
                ],
              }),
          data: Matchers.any);

      final text =
          await TranscriptionApi(dio).transcribe(audioPath: audioPath, config: diarizeConfig);

      expect(text, 'A: Cześć. Jak leci?\n\nB: Dobrze.',
          reason: 'consecutive segments of one speaker merge into a single turn');
      final fields = {for (final f in sent!.fields) f.key: f.value};
      expect(fields['response_format'], 'diarized_json');
      expect(fields['chunking_strategy'], 'auto');
    });

    test('whisper request carries no diarization fields', () async {
      FormData? sent;
      dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
        sent = options.data as FormData;
        handler.next(options);
      }));
      adapter.onPost('https://api.test/v1/audio/transcriptions',
          (server) => server.reply(200, {'text': 'ok'}),
          data: Matchers.any);

      await TranscriptionApi(dio).transcribe(audioPath: audioPath, config: config);

      final keys = sent!.fields.map((f) => f.key);
      expect(keys, isNot(contains('response_format')));
      expect(keys, isNot(contains('chunking_strategy')));
    });

    test('diarizing model without usable segments falls back to text', () async {
      adapter.onPost('https://api.test/v1/audio/transcriptions',
          (server) => server.reply(200, {'text': 'bez mówców', 'segments': []}),
          data: Matchers.any);
      expect(
        await TranscriptionApi(dio).transcribe(audioPath: audioPath, config: diarizeConfig),
        'bez mówców',
      );
    });

    test('segments without speaker or text are handled', () {
      expect(
        TranscriptionApi.formatDiarizedSegments([
          {'text': 'kto to?'},
          {'speaker': 'A', 'text': '   '},
          'śmieć',
        ]),
        'kto to?',
        reason: 'a single speaker gets no label',
      );
      expect(TranscriptionApi.formatDiarizedSegments('nie lista'), isNull);
    });
  });

  group('ElevenLabs', () {
    const eleven = ServiceConfig(
      baseUrl: 'https://api.elevenlabs.io/v1',
      apiKey: 'xi',
      model: 'scribe_v2',
    );

    Map<String, dynamic> word(String text, String speaker, [String type = 'word']) =>
        {'text': text, 'type': type, 'speaker_id': speaker, 'start': 0.0, 'end': 0.1};

    test('sends scribe request with diarization and xi-api-key', () async {
      RequestOptions? sent;
      dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
        sent = options;
        handler.next(options);
      }));
      adapter.onPost('https://api.elevenlabs.io/v1/speech-to-text',
          (server) => server.reply(200, {'text': 'hej', 'words': []}),
          data: Matchers.any);

      expect(await TranscriptionApi(dio).transcribe(audioPath: audioPath, config: eleven), 'hej',
          reason: 'no usable words -> plain text');

      expect(sent!.headers['xi-api-key'], 'xi');
      expect(sent!.headers.containsKey('Authorization'), isFalse,
          reason: 'ElevenLabs key must not go out as a Bearer token');
      final fields = {for (final f in (sent!.data as FormData).fields) f.key: f.value};
      expect(fields['model_id'], 'scribe_v2');
      expect(fields['diarize'], 'true');
      expect(fields['timestamps_granularity'], 'word');
    });

    test('words become labelled turns in order of appearance', () async {
      adapter.onPost('https://api.elevenlabs.io/v1/speech-to-text',
          (server) => server.reply(200, {
                'text': 'Cześć, jak leci? Dobrze.',
                'words': [
                  word('Cześć,', 'speaker_1'),
                  word(' ', 'speaker_1', 'spacing'),
                  word('jak', 'speaker_1'),
                  word(' ', 'speaker_1', 'spacing'),
                  word('leci?', 'speaker_1'),
                  word(' ', 'speaker_1', 'spacing'),
                  word('(śmiech)', 'speaker_1', 'audio_event'),
                  word('Dobrze.', 'speaker_0'),
                ],
              }),
          data: Matchers.any);

      expect(
        await TranscriptionApi(dio).transcribe(audioPath: audioPath, config: eleven),
        'A: Cześć, jak leci?\n\nB: Dobrze.',
        reason: 'speaker_1 spoke first, so it is A; audio events are dropped',
      );
    });

    test('single speaker is not labelled', () {
      expect(
        TranscriptionApi.formatElevenLabsWords([
          word('Kupić', 'speaker_0'),
          word(' ', 'speaker_0', 'spacing'),
          word('mleko.', 'speaker_0'),
        ]),
        'Kupić mleko.',
      );
    });
  });

  group('Gemini', () {
    const gemini = ServiceConfig(
      baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
      apiKey: 'AIza',
      model: 'gemini-3.8-flash',
    );
    const native =
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent';

    test('calls native generateContent with inline audio and goog key', () async {
      RequestOptions? sent;
      dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
        sent = options;
        handler.next(options);
      }));
      adapter.onPost(
          native,
          (server) => server.reply(200, {
                'candidates': [
                  {
                    'content': {
                      'parts': [
                        {'text': 'A: Cześć.\n\n'},
                        {'text': 'B: Hej.'},
                      ],
                    },
                  },
                ],
              }),
          data: Matchers.any);

      final text = await TranscriptionApi(dio).transcribe(audioPath: audioPath, config: gemini);

      expect(text, 'A: Cześć.\n\nB: Hej.');
      expect(sent!.headers['x-goog-api-key'], 'AIza');
      final parts = ((sent!.data as Map)['contents'] as List).single['parts'] as List;
      final inline = parts.last['inline_data'] as Map;
      expect(inline['mime_type'], 'audio/m4a');
      expect(base64Decode(inline['data'] as String), [1, 2, 3],
          reason: 'the recording itself travels base64-encoded in the request');
    });

    test('response without candidates -> noTranscript', () async {
      adapter.onPost(native, (server) => server.reply(200, {'candidates': []}),
          data: Matchers.any);
      await expectLater(
        TranscriptionApi(dio).transcribe(audioPath: audioPath, config: gemini),
        throwsA(isA<MikroApiException>()
            .having((e) => e.kind, 'kind', ApiErrorKind.noTranscript)),
      );
    });
  });

  test('upload limit follows the provider', () {
    ServiceConfig at(String url) => ServiceConfig(baseUrl: url, apiKey: 'k', model: 'm');
    expect(uploadLimitFor(at('https://api.groq.com/openai/v1')), maxUploadBytes);
    expect(uploadLimitFor(at('http://localhost:8000/v1')), maxUploadBytes);
    expect(uploadLimitFor(at('https://generativelanguage.googleapis.com/v1beta/openai')),
        geminiMaxUploadBytes);
    expect(uploadLimitFor(at('https://api.elevenlabs.io/v1')), greaterThan(maxUploadBytes));
  });
}
