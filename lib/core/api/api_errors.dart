import 'package:dio/dio.dart';

enum ApiErrorKind { network, auth, tooLarge, rateLimit, server, badResponse }

class MikroApiException implements Exception {
  MikroApiException(this.kind, this.message);

  final ApiErrorKind kind;
  final String message;

  String get userMessage => switch (kind) {
        ApiErrorKind.network => 'Brak połączenia z siecią.',
        ApiErrorKind.auth => 'Błąd autoryzacji — sprawdź klucz API w Ustawieniach.',
        ApiErrorKind.tooLarge => 'Plik odrzucony przez API — za duży.',
        ApiErrorKind.rateLimit => 'Limit zapytań przekroczony — spróbuj za chwilę.',
        ApiErrorKind.server => 'Błąd serwera dostawcy ($message).',
        ApiErrorKind.badResponse => message,
      };

  @override
  String toString() => 'MikroApiException($kind, $message)';
}

MikroApiException mapDioError(DioException e) {
  final code = e.response?.statusCode;
  if (code == 401 || code == 403) return MikroApiException(ApiErrorKind.auth, 'HTTP $code');
  if (code == 413) return MikroApiException(ApiErrorKind.tooLarge, 'HTTP 413');
  if (code == 429) return MikroApiException(ApiErrorKind.rateLimit, 'HTTP 429');
  if (code != null && code >= 500) return MikroApiException(ApiErrorKind.server, 'HTTP $code');
  if (code != null) {
    return MikroApiException(
      ApiErrorKind.badResponse,
      'Nieoczekiwana odpowiedź serwera (HTTP $code).',
    );
  }
  return MikroApiException(ApiErrorKind.network, e.message ?? 'network error');
}
