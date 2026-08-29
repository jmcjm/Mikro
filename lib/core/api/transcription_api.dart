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
      final response = await _dio.post<Map<String, dynamic>>(
        '${config.baseUrl}/audio/transcriptions',
        data: form,
        options: Options(headers: {'Authorization': 'Bearer ${config.apiKey}'}),
      );
      final text = response.data?['text'];
      if (text is! String) {
        throw MikroApiException(ApiErrorKind.badResponse, 'Odpowiedź API bez pola text.');
      }
      return text;
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }
}
