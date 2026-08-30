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
      // Rzutowanie na mape robimy sami. Gdyby robil je generyk post<Map<String, dynamic>>,
      // dio opakowaloby _TypeError w DioException bez odpowiedzi, a mapDioError uznaloby to
      // za awarie sieci — uzytkownik zobaczylby "Brak polaczenia z siecia." zamiast bledu API.
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
