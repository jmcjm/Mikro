// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get navRecord => 'Record';

  @override
  String get navLibrary => 'Library';

  @override
  String get navSettings => 'Settings';

  @override
  String get navAppearance => 'Appearance';

  @override
  String get recorderHistoryTooltip => 'Library';

  @override
  String get recorderSavedSnackbar =>
      'Recording saved — transcription running.';

  @override
  String get recorderSavedAction => 'Show';

  @override
  String get recorderStatusRecording => 'Recording';

  @override
  String get recorderStatusReady => 'Ready to record';

  @override
  String get recorderErrorMicPermission => 'No microphone permission.';

  @override
  String recorderErrorStartFailed(String detail) {
    return 'Couldn\'t start recording: $detail';
  }

  @override
  String get libraryTitle => 'Library';

  @override
  String get librarySearchHint => 'Search transcripts and tags';

  @override
  String get libraryFilterAll => 'All';

  @override
  String libraryDatabaseError(String detail) {
    return 'Database error: $detail';
  }

  @override
  String get libraryEmptyNoResults => 'Nothing found.';

  @override
  String get libraryEmptyNoRecordings => 'No recordings';

  @override
  String get libraryEmptyDescription =>
      'Tap the microphone on the Record screen — your first note shows up here, tagged.';

  @override
  String get libraryRecordCta => 'Record your first note';

  @override
  String get libraryRetry => 'Retry';

  @override
  String get detailTitle => 'Recording';

  @override
  String get detailBackTooltip => 'Back';

  @override
  String get detailShareTooltip => 'Share transcript';

  @override
  String get detailCopyTooltip => 'Copy transcript';

  @override
  String get detailDeleteTooltip => 'Delete';

  @override
  String get detailDeleteTitle => 'Delete this recording?';

  @override
  String get detailDeleteMessage =>
      'The audio file and the transcript go for good.';

  @override
  String get detailCancel => 'Cancel';

  @override
  String get detailDelete => 'Delete';

  @override
  String get detailDeleteError => 'Couldn\'t delete the recording.';

  @override
  String get detailRecordingDeleted => 'Recording deleted.';

  @override
  String get detailCopiedTranscript => 'Transcript copied to the clipboard.';

  @override
  String get detailCopied => 'Copied.';

  @override
  String get detailTranscriptLabel => 'TRANSCRIPT';

  @override
  String get detailAddTagChip => 'tag';

  @override
  String get detailAddTagTitle => 'Add tag';

  @override
  String get detailAddTagLabel => 'Tag name';

  @override
  String get detailAddTagDuplicate => 'This tag is already assigned.';

  @override
  String get detailAddTagConfirm => 'Add';

  @override
  String get detailTagSaveError => 'Couldn\'t save the tag change.';

  @override
  String get detailRemoveTagTooltip => 'Remove tag';

  @override
  String get detailRetryProcessing => 'Retry processing';

  @override
  String get detailRewindTooltip => 'Back 10 seconds';

  @override
  String get detailForwardTooltip => 'Forward 10 seconds';

  @override
  String get detailSpeedTooltip => 'Playback speed';

  @override
  String detailSpeedLabel(String rate) {
    return '$rate×';
  }

  @override
  String get detailSeekLabel => 'Playback bar';

  @override
  String get statusQueued => 'Queued…';

  @override
  String get statusTranscribing => 'Transcribing…';

  @override
  String get statusTagging => 'Tagging…';

  @override
  String get statusDone => 'Done';

  @override
  String get statusError => 'Error';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsProviderSection => 'PROVIDER';

  @override
  String get settingsThemeSection => 'THEME';

  @override
  String get settingsProviderCustom => 'Custom';

  @override
  String get settingsBaseUrl => 'Base URL';

  @override
  String get settingsApiKey => 'API key';

  @override
  String get settingsShowKey => 'Show key';

  @override
  String get settingsHideKey => 'Hide key';

  @override
  String get settingsKeyStorage =>
      'Kept in the system keystore, not in SharedPreferences';

  @override
  String get settingsSttModel => 'STT model';

  @override
  String get settingsTagModel => 'Tagging model';

  @override
  String get settingsSave => 'Save';

  @override
  String get settingsSaved => 'Settings saved.';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get onboardingWelcomeHeadline =>
      'Speak.\nMikro writes it down\nand tags it.';

  @override
  String get onboardingWelcomeBody =>
      'Recordings stay on your device, transcription and tags go to the provider you pick.';

  @override
  String get onboardingMicHeadline => 'Microphone\nfirst.';

  @override
  String get onboardingMicBody =>
      'The system asks once. Without it Mikro won\'t record a word.';

  @override
  String get onboardingMicTitle => 'Microphone access';

  @override
  String get onboardingMicSubtitle => 'Required for recording';

  @override
  String get onboardingMicGranted => 'Granted';

  @override
  String get onboardingMicAllow => 'Allow';

  @override
  String get onboardingMicRetry => 'Retry';

  @override
  String get onboardingMicDenied =>
      'Denied. Turn the access on in your system settings.';

  @override
  String get onboardingProviderHeadline =>
      'The API key\ncan wait\nas long as you like.';

  @override
  String get onboardingProviderBody =>
      'Transcription and tags go to Groq or OpenAI. Recording itself works without a key.';

  @override
  String get onboardingProviderTitle => 'API key';

  @override
  String get onboardingProviderSubtitle =>
      'Groq or OpenAI — you can add it later';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingStart => 'Let\'s go';

  @override
  String get apiErrorNetwork => 'No network connection.';

  @override
  String get apiErrorAuth =>
      'Authorization failed — check the API key in Settings.';

  @override
  String get apiErrorTooLarge => 'The API rejected the file — too large.';

  @override
  String get apiErrorRateLimit =>
      'Rate limit exceeded — try again in a moment.';

  @override
  String apiErrorServer(String detail) {
    return 'Provider server error ($detail).';
  }

  @override
  String apiErrorBadResponse(String detail) {
    return 'Unexpected server response ($detail).';
  }

  @override
  String get apiErrorBadFormat => 'Unexpected API response format.';

  @override
  String get apiErrorNoContent => 'API response carried no message content.';

  @override
  String get apiErrorNoTranscript => 'API response had no text field.';

  @override
  String get apiErrorBadTags => 'The model returned no usable tags.';

  @override
  String get pipelineErrorNoConfig =>
      'No API configuration — set the key in Settings.';

  @override
  String get pipelineErrorSizeLimit =>
      'The recording is over the 25 MB limit — too long to transcribe.';

  @override
  String pipelineErrorUnexpected(String detail) {
    return 'Unexpected error: $detail';
  }

  @override
  String get errorUnknown => 'Unknown error';
}
