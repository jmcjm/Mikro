import 'package:dio/dio.dart';

import '../models/provider_config.dart';
import 'api_errors.dart';

class TranscriptionApi {
  TranscriptionApi(this._dio);

  final Dio _dio;

  Future<String> transcribe({required String audioPath, required ProviderConfig config}) async {
    try {
      final form = FormData.fromMap({
        'model': config.sttModel,
        'file': await MultipartFile.fromFile(audioPath),
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
      final text = data['text'];
      if (text is! String) {
        throw MikroApiException(ApiErrorKind.noTranscript, 'no text field in response');
      }
      return text;
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }
}
