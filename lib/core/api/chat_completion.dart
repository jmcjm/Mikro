import 'package:dio/dio.dart';

import '../models/provider_config.dart';
import 'api_errors.dart';

/// Single `/chat/completions` round trip shared by every LLM feature (title and tags, notes).
/// Returns the raw `choices[0].message.content`; parsing it is the caller's business.
Future<String> chatCompletion(
  Dio dio, {
  required ProviderConfig config,
  required String system,
  required String user,
  double temperature = 0,
}) async {
  try {
    final response = await dio.post<dynamic>(
      '${config.baseUrl}/chat/completions',
      data: {
        'model': config.tagModel,
        'temperature': temperature,
        'messages': [
          {'role': 'system', 'content': system},
          {'role': 'user', 'content': user},
        ],
      },
      options: Options(headers: {'Authorization': 'Bearer ${config.apiKey}'}),
    );
    // Type casting and descending the structure is done step by step explicitly. The chain
    // data?['choices']?[0]?['message']?['content'] produced raw runtime errors:
    // RangeError on empty choices list and _TypeError on any unexpected shape,
    // while the generic post<Map<String, dynamic>> turned non-map bodies into false network errors.
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw MikroApiException(ApiErrorKind.badFormat, 'response body is not an object');
    }
    final content = _extractContent(data);
    if (content is! String) {
      throw MikroApiException(ApiErrorKind.noContent, 'no message content in response');
    }
    return content;
  } on DioException catch (e) {
    throw mapDioError(e);
  }
}

/// Navigates `choices[0].message.content` without assuming anything about the response structure.
/// Returns null for any structure not conforming to the contract.
Object? _extractContent(Map<String, dynamic> data) {
  final choices = data['choices'];
  if (choices is! List || choices.isEmpty) return null;
  final choice = choices.first;
  if (choice is! Map) return null;
  final message = choice['message'];
  if (message is! Map) return null;
  return message['content'];
}
