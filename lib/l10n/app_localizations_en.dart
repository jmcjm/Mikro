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
  String get detailShareTooltip => 'Share';

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
  String get detailShareTranscript => 'Transcript';

  @override
  String get detailShareAudio => 'Audio file';

  @override
  String get detailCopiedAudioPath =>
      'Audio file path copied to the clipboard.';

  @override
  String get detailShareError => 'Couldn\'t share.';

  @override
  String get detailRegenerateTooltip => 'Regenerate';

  @override
  String get detailRegenerateTitle => 'Regenerate?';

  @override
  String get detailRegenerateMessage =>
      'The transcript, title and all tags (manual ones too) will be removed and the recording processed from scratch.';

  @override
  String get detailRegenerateConfirm => 'Regenerate';

  @override
  String get detailRegenerateBusy =>
      'This recording is being processed right now.';

  @override
  String get detailRegenerateError => 'Couldn\'t reset the recording.';

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
      'No API configuration — fill in the address and key in the matching Settings section (transcription, tags or notes).';

  @override
  String get pipelineErrorSizeLimit =>
      'The recording is too large for the selected transcription provider (OpenAI and Groq: 25 MB, Gemini: 14 MB). Choose another provider, e.g. ElevenLabs.';

  @override
  String pipelineErrorUnexpected(String detail) {
    return 'Unexpected error: $detail';
  }

  @override
  String get errorUnknown => 'Unknown error';

  @override
  String get navNotes => 'Notes';

  @override
  String get notesTitle => 'Notes';

  @override
  String get notesSearchHint => 'Search notes';

  @override
  String get notesEmpty =>
      'No notes yet. Open a recording and use “Make a note”.';

  @override
  String get notesNoResults => 'No notes match your search.';

  @override
  String get noteUntitled => 'Untitled note';

  @override
  String get noteTitleHint => 'Title';

  @override
  String get noteContentHint => 'Note content (Markdown)';

  @override
  String get noteEditTooltip => 'Edit';

  @override
  String get notePreviewTooltip => 'Preview';

  @override
  String noteSourceLink(String title) {
    return 'Source: $title';
  }

  @override
  String get noteSourceDeleted => 'Source recording was deleted';

  @override
  String get noteDeleteTitle => 'Delete note?';

  @override
  String get noteDeleteMessage =>
      'The note will be permanently deleted. The recording and transcript stay.';

  @override
  String get noteRegenerateTooltip => 'Regenerate from transcript';

  @override
  String get noteRegenerateTitle => 'Regenerate the note?';

  @override
  String get noteRegenerateMessage =>
      'Content and title will be replaced with a new version from the current transcript. Your edits will be lost.';

  @override
  String get noteSaveError => 'Could not save the note.';

  @override
  String get noteDeleted => 'Note deleted.';

  @override
  String get detailMakeNote => 'Make a note';

  @override
  String get detailOpenNote => 'Open note';

  @override
  String get detailNoteGenerating => 'Creating note…';

  @override
  String get detailTranscriptHint => 'Transcript is empty';

  @override
  String get detailTranscriptSaveError => 'Could not save the transcript.';

  @override
  String get settingsSttModelHelp =>
      'Speakers are recognised by ElevenLabs, Gemini and gpt-4o-transcribe-diarize (OpenAI). Whisper (Groq, OpenAI) does not tell speakers apart.';

  @override
  String get settingsSttSection => 'TRANSCRIPTION';

  @override
  String get settingsTagsSection => 'TITLES & TAGS';

  @override
  String get settingsNotesSection => 'NOTES';

  @override
  String get settingsModel => 'Model';

  @override
  String get translateTooltip => 'Translate';

  @override
  String get translatePickTitle => 'Translate into';

  @override
  String get translationOriginal => 'Original';

  @override
  String get translationDeleteTooltip => 'Delete translation';

  @override
  String get settingsTranslateSection => 'TRANSLATION';

  @override
  String get settingsSampling => 'Control temperature and top_p';

  @override
  String get settingsSamplingHelp =>
      'Not every model supports this. Reasoning models (e.g. OpenAI GPT-5) reject it with HTTP 400 — leave it off for those.';

  @override
  String get settingsTemperature => 'Temperature';

  @override
  String get settingsApiKeyInheritHelp =>
      'Leave empty to use the Transcription key when the address is the same.';

  @override
  String get settingsNoteStyle => 'Note style';

  @override
  String get settingsNoteStyleDetailed => 'Detailed';

  @override
  String get settingsNoteStyleDetailedHelp =>
      'Headings, bullet points and bold; keeps every relevant fact, tasks as a checklist.';

  @override
  String get settingsNoteStyleConcise => 'Concise';

  @override
  String get settingsNoteStyleConciseHelp =>
      'A few bullet points with the essentials plus any tasks — readable in a minute.';

  @override
  String get settingsNoteStyleMeeting => 'Meeting minutes';

  @override
  String get settingsNoteStyleMeetingHelp =>
      'Participants, topics, decisions, action items (who, what, by when) and open questions.';

  @override
  String get settingsNoteStyleCasual => 'Casual';

  @override
  String get settingsNoteStyleCasualHelp =>
      'Relaxed and friendly, with a few well-placed emoji — not a wall of them.';

  @override
  String get settingsNoteStyleCustom => 'Custom';

  @override
  String get settingsNoteStyleCustomLabel => 'Instructions for the AI';

  @override
  String get settingsNoteStyleCustomHint =>
      'e.g. Write study notes: definitions, examples, and 3 review questions at the end.';

  @override
  String get settingsNoteStyleCustomHelp =>
      'The app enforces the format (Markdown, title, transcript language) itself — describe only style and structure here.';
}
