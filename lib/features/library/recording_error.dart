import '../../core/api/api_errors.dart';
import '../../core/pipeline/processing_pipeline.dart';
import '../../l10n/app_localizations.dart';

/// Assembles a localized error description from persisted database fields: error kind and technical detail.
/// The database deliberately does not store pre-formatted strings — a recording might fail under
/// one locale and be viewed under another, so localized text is generated dynamically during rendering.
///
/// [kind] corresponds to `Recordings.errorKind`, i.e. a name from [ApiErrorKind] or a pipeline
/// `errorKind*` constant. [detail] is `Recordings.errorMessage`: HTTP code or exception message.
String recordingErrorText(AppLocalizations l10n, {String? kind, String? detail}) {
  final apiKind = ApiErrorKind.values.asNameMap()[kind];
  if (apiKind != null) {
    return switch (apiKind) {
      ApiErrorKind.network => l10n.apiErrorNetwork,
      ApiErrorKind.auth => l10n.apiErrorAuth,
      ApiErrorKind.tooLarge => l10n.apiErrorTooLarge,
      ApiErrorKind.rateLimit => l10n.apiErrorRateLimit,
      ApiErrorKind.server => l10n.apiErrorServer(detail ?? ''),
      ApiErrorKind.badResponse => l10n.apiErrorBadResponse(detail ?? ''),
      ApiErrorKind.badFormat => l10n.apiErrorBadFormat,
      ApiErrorKind.noContent => l10n.apiErrorNoContent,
      ApiErrorKind.noTranscript => l10n.apiErrorNoTranscript,
      ApiErrorKind.badTags => l10n.apiErrorBadTags,
    };
  }
  if (kind == errorKindNoConfig) return l10n.pipelineErrorNoConfig;
  if (kind == errorKindSizeLimit) return l10n.pipelineErrorSizeLimit;
  if (kind == errorKindUnknown && detail != null) return l10n.pipelineErrorUnexpected(detail);
  // Rows created prior to this schema have NULL errorKind and the full sentence in errorMessage.
  // We display it as-is: a frozen language message is preferable to losing the error cause entirely.
  return detail ?? l10n.errorUnknown;
}
