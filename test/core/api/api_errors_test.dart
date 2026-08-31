import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikro/core/api/api_errors.dart';

DioException _withStatus(int code) => DioException(
      requestOptions: RequestOptions(path: '/x'),
      response: Response(requestOptions: RequestOptions(path: '/x'), statusCode: code),
    );

void main() {
  test('401 -> auth', () => expect(mapDioError(_withStatus(401)).kind, ApiErrorKind.auth));
  test('403 -> auth', () => expect(mapDioError(_withStatus(403)).kind, ApiErrorKind.auth));
  test('413 -> tooLarge', () => expect(mapDioError(_withStatus(413)).kind, ApiErrorKind.tooLarge));
  test('429 -> rateLimit', () => expect(mapDioError(_withStatus(429)).kind, ApiErrorKind.rateLimit));
  test('500 -> server', () => expect(mapDioError(_withStatus(500)).kind, ApiErrorKind.server));
  test('no response -> network', () {
    final e = DioException(requestOptions: RequestOptions(path: '/x'), type: DioExceptionType.connectionError);
    expect(mapDioError(e).kind, ApiErrorKind.network);
  });
  test('auth carries only the code, not a sentence for the user', () {
    // The UI constructs the sentence from kind via l10n; the network layer returns only technical details.
    expect(mapDioError(_withStatus(401)).message, 'HTTP 401');
  });
  test('404 -> badResponse without trace of raw body', () {
    final e = DioException(
      requestOptions: RequestOptions(path: '/x'),
      response: Response(
        requestOptions: RequestOptions(path: '/x'),
        statusCode: 404,
        data: {'error': 'model not found', 'echo': 'sekret uzytkownika'},
      ),
    );
    final mapped = mapDioError(e);
    expect(mapped.kind, ApiErrorKind.badResponse);
    expect(mapped.message, 'HTTP 404');
    expect(mapped.message, isNot(contains('sekret')));
  });
}
