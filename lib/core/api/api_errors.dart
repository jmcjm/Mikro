import 'package:dio/dio.dart';

/// Kind of failure when communicating with a provider. Each value has a corresponding
/// message in ARB — that is why response shapes that break the contract have distinct kinds,
/// rather than a single bucket with an attached description: the description would be technical
/// English injected into the localized UI message.
///
/// Enum value names are stored in the `errorKind` column and form part of the database schema.
enum ApiErrorKind {
  network,
  auth,
  tooLarge,
  rateLimit,
  server,

  /// Unexpected HTTP status code. The only API error kind that interpolates [MikroApiException.message]
  /// into the message — because that detail is the status number itself.
  badResponse,

  /// Response body is not a JSON object.
  badFormat,

  /// Chat response without message content: missing `choices`, empty list, or invalid structure.
  noContent,

  /// Transcription response without `text` field.
  noTranscript,

  /// Model failed twice in a row to return a parsable tag list.
  badTags,
}

class MikroApiException implements Exception {
  MikroApiException(this.kind, this.message);

  final ApiErrorKind kind;

  /// Technical failure detail: HTTP code or a brief note describing how the response violated
  /// the contract. This is NOT user-facing text and deliberately does not go through l10n —
  /// the network layer has no access to BuildContext, and the message would otherwise be persisted
  /// in the database frozen in the locale active at write time. The user-facing string is assembled
  /// by UI solely from [kind] (see `recordingErrorText`).
  ///
  /// Interpolated into the localized string as `{detail}` only where the detail is a number:
  /// [ApiErrorKind.server] and [ApiErrorKind.badResponse]. For other kinds it remains in logs
  /// and the database.
  final String message;

  @override
  String toString() => 'MikroApiException($kind, $message)';
}

MikroApiException mapDioError(DioException e) {
  final code = e.response?.statusCode;
  if (code == 401 || code == 403) return MikroApiException(ApiErrorKind.auth, 'HTTP $code');
  if (code == 413) return MikroApiException(ApiErrorKind.tooLarge, 'HTTP 413');
  if (code == 429) return MikroApiException(ApiErrorKind.rateLimit, 'HTTP 429');
  if (code != null && code >= 500) return MikroApiException(ApiErrorKind.server, 'HTTP $code');
  // Status code only, without response body: field lands in database and UI, and error
  // responses can echo sensitive data sent in the request.
  if (code != null) return MikroApiException(ApiErrorKind.badResponse, 'HTTP $code');
  return MikroApiException(ApiErrorKind.network, e.message ?? 'network error');
}
