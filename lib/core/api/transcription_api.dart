import 'package:dio/dio.dart';

import '../models/provider_config.dart';
import 'api_errors.dart';

class TranscriptionApi {
  TranscriptionApi(this._dio);

  final Dio _dio;

  /// Speaker diarization is a property of the model, not a switch on the endpoint: Whisper
  /// (OpenAI, Groq) has no notion of speakers at all, while OpenAI's `gpt-4o-transcribe-diarize`
  /// returns them only in the `diarized_json` format. Detecting it by name keeps the settings
  /// free of a toggle that would silently do nothing for every other model.
  static bool supportsDiarization(String model) => model.toLowerCase().contains('diarize');

  Future<String> transcribe({required String audioPath, required ProviderConfig config}) async {
    final diarize = supportsDiarization(config.sttModel);
    try {
      final form = FormData.fromMap({
        'model': config.sttModel,
        'file': await MultipartFile.fromFile(audioPath),
        if (diarize) ...{
          'response_format': 'diarized_json',
          // Required by the diarizing model for anything longer than 30 s.
          'chunking_strategy': 'auto',
        },
      });
      final response = await _dio.post<dynamic>(
        '${config.baseUrl}/audio/transcriptions',
        data: form,
        options: Options(headers: {'Authorization': 'Bearer ${config.apiKey}'}),
      );
      // Type casting to Map is done explicitly. If generic post<Map<String, dynamic>> did it,
      // dio would wrap _TypeError in a DioException without response, and mapDioError would classify it
      // as a network failure — the user would see "No network connection." instead of an API error.
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw MikroApiException(ApiErrorKind.badFormat, 'response body is not an object');
      }
      if (diarize) {
        final labelled = formatDiarizedSegments(data['segments']);
        if (labelled != null) return labelled;
      }
      final text = data['text'];
      if (text is! String) {
        throw MikroApiException(ApiErrorKind.noTranscript, 'no text field in response');
      }
      return text;
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  /// Turns `diarized_json` segments into readable plain text: one paragraph per speaker turn,
  /// prefixed with the label (`A:`, `B:` …). Consecutive segments of the same speaker are merged —
  /// the model splits on pauses, and a new label every sentence is noise. The result is ordinary
  /// transcript text, so renaming "A" to a real name is just editing the transcript.
  ///
  /// Returns `null` for anything that is not a usable segment list; the caller falls back to `text`.
  static String? formatDiarizedSegments(Object? segments) {
    if (segments is! List) return null;
    final turns = <(String, StringBuffer)>[];
    for (final segment in segments) {
      if (segment is! Map) continue;
      final text = segment['text'];
      if (text is! String || text.trim().isEmpty) continue;
      final speaker = '${segment['speaker'] ?? '?'}'.trim();
      if (turns.isNotEmpty && turns.last.$1 == speaker) {
        turns.last.$2.write(' ${text.trim()}');
      } else {
        turns.add((speaker, StringBuffer(text.trim())));
      }
    }
    if (turns.isEmpty) return null;
    return turns.map((t) => '${t.$1}: ${t.$2}').join('\n\n');
  }
}
