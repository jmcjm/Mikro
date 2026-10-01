// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get navRecord => 'Aufnehmen';

  @override
  String get navLibrary => 'Bibliothek';

  @override
  String get navSettings => 'Einstellungen';

  @override
  String get navAppearance => 'Darstellung';

  @override
  String get recorderHistoryTooltip => 'Bibliothek';

  @override
  String get recorderSavedSnackbar => 'Aufnahme gespeichert — Transkription läuft.';

  @override
  String get recorderSavedAction => 'Anzeigen';

  @override
  String get recorderStatusRecording => 'Aufnahme läuft';

  @override
  String get recorderStatusReady => 'Bereit zur Aufnahme';

  @override
  String get recorderErrorMicPermission => 'Keine Mikrofonberechtigung.';

  @override
  String recorderErrorStartFailed(String detail) {
    return 'Aufnahme konnte nicht gestartet werden: $detail';
  }

  @override
  String get libraryTitle => 'Bibliothek';

  @override
  String get librarySearchHint => 'Transkripte und Tags durchsuchen';

  @override
  String get libraryFilterAll => 'Alle';

  @override
  String libraryDatabaseError(String detail) {
    return 'Datenbankfehler: $detail';
  }

  @override
  String get libraryEmptyNoResults => 'Nichts gefunden.';

  @override
  String get libraryEmptyNoRecordings => 'Keine Aufnahmen';

  @override
  String get libraryEmptyDescription => 'Tippe auf dem Aufnahme-Bildschirm auf das Mikrofon — deine erste Notiz erscheint hier, mit Tags versehen.';

  @override
  String get libraryRecordCta => 'Erste Notiz aufnehmen';

  @override
  String get libraryRetry => 'Erneut versuchen';

  @override
  String get detailTitle => 'Aufnahme';

  @override
  String get detailBackTooltip => 'Zurück';

  @override
  String get detailShareTooltip => 'Teilen';

  @override
  String get detailCopyTooltip => 'Transkript kopieren';

  @override
  String get detailDeleteTooltip => 'Löschen';

  @override
  String get detailDeleteTitle => 'Diese Aufnahme löschen?';

  @override
  String get detailDeleteMessage => 'Die Audiodatei und das Transkript werden endgültig gelöscht.';

  @override
  String get detailCancel => 'Abbrechen';

  @override
  String get detailDelete => 'Löschen';

  @override
  String get detailDeleteError => 'Die Aufnahme konnte nicht gelöscht werden.';

  @override
  String get detailRecordingDeleted => 'Aufnahme gelöscht.';

  @override
  String get detailCopiedTranscript => 'Transkript in die Zwischenablage kopiert.';

  @override
  String get detailCopied => 'Kopiert.';

  @override
  String get detailTranscriptLabel => 'TRANSKRIPT';

  @override
  String get detailAddTagChip => 'Tag';

  @override
  String get detailAddTagTitle => 'Tag hinzufügen';

  @override
  String get detailAddTagLabel => 'Tag-Name';

  @override
  String get detailAddTagDuplicate => 'Dieser Tag ist bereits zugewiesen.';

  @override
  String get detailAddTagConfirm => 'Hinzufügen';

  @override
  String get detailTagSaveError => 'Die Tag-Änderung konnte nicht gespeichert werden.';

  @override
  String get detailRemoveTagTooltip => 'Tag entfernen';

  @override
  String get detailRetryProcessing => 'Verarbeitung wiederholen';

  @override
  String get detailShareTranscript => 'Transkript';

  @override
  String get detailShareAudio => 'Audiodatei';

  @override
  String get detailCopiedAudioPath => 'Pfad der Audiodatei in die Zwischenablage kopiert.';

  @override
  String get detailShareError => 'Teilen nicht möglich.';

  @override
  String get detailRegenerateTooltip => 'Neu erzeugen';

  @override
  String get detailRegenerateTitle => 'Neu erzeugen?';

  @override
  String get detailRegenerateMessage => 'Transkript, Titel und alle Tags (auch manuelle) werden entfernt und die Aufnahme wird von Grund auf neu verarbeitet.';

  @override
  String get detailRegenerateConfirm => 'Neu erzeugen';

  @override
  String get detailRegenerateBusy => 'Diese Aufnahme wird gerade verarbeitet.';

  @override
  String get detailRegenerateError => 'Die Aufnahme konnte nicht zurückgesetzt werden.';

  @override
  String get detailRewindTooltip => '10 Sekunden zurück';

  @override
  String get detailForwardTooltip => '10 Sekunden vor';

  @override
  String get detailSpeedTooltip => 'Wiedergabegeschwindigkeit';

  @override
  String detailSpeedLabel(String rate) {
    return '$rate×';
  }

  @override
  String get detailSeekLabel => 'Wiedergabeleiste';

  @override
  String get statusQueued => 'In der Warteschlange…';

  @override
  String get statusTranscribing => 'Transkribiere…';

  @override
  String get statusTagging => 'Vergebe Tags…';

  @override
  String get statusDone => 'Fertig';

  @override
  String get statusError => 'Fehler';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get settingsThemeSection => 'DESIGN';

  @override
  String get settingsProviderCustom => 'Benutzerdefiniert';

  @override
  String get settingsBaseUrl => 'Basis-URL';

  @override
  String get settingsApiKey => 'API-Schlüssel';

  @override
  String get settingsShowKey => 'Schlüssel anzeigen';

  @override
  String get settingsHideKey => 'Schlüssel verbergen';

  @override
  String get settingsSave => 'Speichern';

  @override
  String get settingsSaved => 'Einstellungen gespeichert.';

  @override
  String get settingsThemeLight => 'Hell';

  @override
  String get settingsThemeDark => 'Dunkel';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get onboardingWelcomeHeadline => 'Sprich.\nMikro schreibt mit\nund vergibt Tags.';

  @override
  String get onboardingWelcomeBody => 'Aufnahmen bleiben auf deinem Gerät, Transkription und Tags gehen an den Anbieter deiner Wahl.';

  @override
  String get onboardingMicHeadline => 'Erst das\nMikrofon.';

  @override
  String get onboardingMicBody => 'Das System fragt nur einmal. Ohne Zugriff nimmt Mikro kein Wort auf.';

  @override
  String get onboardingMicTitle => 'Mikrofonzugriff';

  @override
  String get onboardingMicSubtitle => 'Für Aufnahmen erforderlich';

  @override
  String get onboardingMicGranted => 'Erteilt';

  @override
  String get onboardingMicAllow => 'Erlauben';

  @override
  String get onboardingMicRetry => 'Erneut versuchen';

  @override
  String get onboardingMicDenied => 'Abgelehnt. Aktiviere den Zugriff in den Systemeinstellungen.';

  @override
  String get onboardingProviderHeadline => 'Der API-Schlüssel\nkann warten,\nso lange du willst.';

  @override
  String get onboardingProviderBody => 'Transkription und Tags gehen an Groq oder OpenAI. Die Aufnahme selbst funktioniert ohne Schlüssel.';

  @override
  String get onboardingProviderTitle => 'API-Schlüssel';

  @override
  String get onboardingProviderSubtitle => 'Groq oder OpenAI — kann später hinzugefügt werden';

  @override
  String get onboardingNext => 'Weiter';

  @override
  String get onboardingStart => 'Los geht\'s';

  @override
  String get apiErrorNetwork => 'Keine Netzwerkverbindung.';

  @override
  String get apiErrorAuth => 'Autorisierung fehlgeschlagen — prüfe den API-Schlüssel in den Einstellungen.';

  @override
  String get apiErrorTooLarge => 'Die API hat die Datei abgelehnt — zu groß.';

  @override
  String get apiErrorRateLimit => 'Anfragelimit überschritten — versuche es gleich noch einmal.';

  @override
  String apiErrorServer(String detail) {
    return 'Serverfehler beim Anbieter ($detail).';
  }

  @override
  String apiErrorBadResponse(String detail) {
    return 'Unerwartete Serverantwort ($detail).';
  }

  @override
  String get apiErrorBadFormat => 'Unerwartetes API-Antwortformat.';

  @override
  String get apiErrorNoContent => 'Die API-Antwort enthielt keinen Nachrichteninhalt.';

  @override
  String get apiErrorNoTranscript => 'Die API-Antwort enthielt kein Textfeld.';

  @override
  String get apiErrorBadTags => 'Das Modell hat keine brauchbaren Tags geliefert.';

  @override
  String get pipelineErrorNoConfig => 'Keine API-Konfiguration — trage Adresse und Schlüssel im passenden Abschnitt der Einstellungen ein (Transkription, Tags oder Notizen).';

  @override
  String get pipelineErrorSizeLimit => 'Die Aufnahme ist für den gewählten Transkriptionsanbieter zu groß (OpenAI und Groq: 25 MB, Gemini: 14 MB). Wähle einen anderen Anbieter, z. B. ElevenLabs.';

  @override
  String pipelineErrorUnexpected(String detail) {
    return 'Unerwarteter Fehler: $detail';
  }

  @override
  String get errorUnknown => 'Unbekannter Fehler';

  @override
  String get navNotes => 'Notizen';

  @override
  String get notesTitle => 'Notizen';

  @override
  String get notesSearchHint => 'Notizen durchsuchen';

  @override
  String get notesEmpty => 'Noch keine Notizen. Öffne eine Aufnahme und wähle „Notiz erstellen“.';

  @override
  String get notesNoResults => 'Keine Notizen entsprechen deiner Suche.';

  @override
  String get noteUntitled => 'Unbenannte Notiz';

  @override
  String get noteTitleHint => 'Titel';

  @override
  String get noteContentHint => 'Notizinhalt (Markdown)';

  @override
  String get noteEditTooltip => 'Bearbeiten';

  @override
  String get notePreviewTooltip => 'Vorschau';

  @override
  String get noteShareTooltip => 'Teilen';

  @override
  String noteSourceLink(String title) {
    return 'Quelle: $title';
  }

  @override
  String get noteSourceDeleted => 'Die Quellaufnahme wurde gelöscht';

  @override
  String get noteDeleteTitle => 'Notiz löschen?';

  @override
  String get noteDeleteMessage => 'Die Notiz wird endgültig gelöscht. Aufnahme und Transkript bleiben erhalten.';

  @override
  String get noteRegenerateTooltip => 'Aus Transkript neu erzeugen';

  @override
  String get noteRegenerateTitle => 'Notiz neu erzeugen?';

  @override
  String get noteRegenerateMessage => 'Inhalt und Titel werden durch eine neue Version aus dem aktuellen Transkript ersetzt. Deine Änderungen gehen verloren.';

  @override
  String get noteSaveError => 'Die Notiz konnte nicht gespeichert werden.';

  @override
  String get noteDeleted => 'Notiz gelöscht.';

  @override
  String get detailMakeNote => 'Notiz erstellen';

  @override
  String get detailOpenNote => 'Notiz öffnen';

  @override
  String get detailNoteGenerating => 'Notiz wird erstellt…';

  @override
  String get detailTranscriptHint => 'Das Transkript ist leer';

  @override
  String get detailTranscriptSaveError => 'Das Transkript konnte nicht gespeichert werden.';

  @override
  String get settingsSttModelHelp => 'Sprecher werden von ElevenLabs, Gemini und gpt-4o-transcribe-diarize (OpenAI) erkannt. Whisper (Groq, OpenAI) unterscheidet keine Sprecher.';

  @override
  String get settingsModel => 'Modell';

  @override
  String get navQuickRecord => 'Aufnahme starten';

  @override
  String get navQuickRecordStop => 'Aufnahme beenden';

  @override
  String get translateTooltip => 'Übersetzen';

  @override
  String get translatePickTitle => 'Übersetzen in';

  @override
  String get translationOriginal => 'Original';

  @override
  String get translationDeleteTooltip => 'Übersetzung löschen';

  @override
  String tagColorTitle(String tag) {
    return 'Farbe von „$tag“';
  }

  @override
  String get tagColorDefault => 'Standard';

  @override
  String get noteColorTitle => 'Notizfarbe';

  @override
  String get noteColorTooltip => 'Farbe';

  @override
  String get settingsSampling => 'Temperature und top_p steuern';

  @override
  String get settingsSamplingHelp => 'Nicht jedes Modell unterstützt das. Reasoning-Modelle (z. B. OpenAI GPT-5) lehnen es mit HTTP 400 ab — lass es dort ausgeschaltet.';

  @override
  String get settingsTemperature => 'Temperature';

  @override
  String get settingsApiKeyInheritHelp => 'Leer lassen, um den Transkriptions-Schlüssel zu verwenden, wenn die Adresse dieselbe ist.';

  @override
  String get settingsNoteStyleDetailed => 'Ausführlich';

  @override
  String get settingsNoteStyleDetailedHelp => 'Überschriften, Aufzählungen und Fettdruck; behält jeden relevanten Fakt, Aufgaben als Checkliste.';

  @override
  String get settingsNoteStyleConcise => 'Knapp';

  @override
  String get settingsNoteStyleConciseHelp => 'Ein paar Stichpunkte mit dem Wesentlichen und eventuellen Aufgaben — in einer Minute gelesen.';

  @override
  String get settingsNoteStyleMeeting => 'Besprechungsprotokoll';

  @override
  String get settingsNoteStyleMeetingHelp => 'Teilnehmer, Themen, Beschlüsse, Aufgaben (wer, was, bis wann) und offene Fragen.';

  @override
  String get settingsNoteStyleCasual => 'Locker';

  @override
  String get settingsNoteStyleCasualHelp => 'Entspannt und freundlich, mit ein paar gut platzierten Emojis — keine Wand davon.';

  @override
  String get settingsNoteStyleCustom => 'Benutzerdefiniert';

  @override
  String get settingsNoteStyleCustomLabel => 'Anweisungen für die KI';

  @override
  String get settingsNoteStyleCustomHint => 'z. B. Schreibe Lernnotizen: Definitionen, Beispiele und 3 Wiederholungsfragen am Ende.';

  @override
  String get settingsNoteStyleCustomHelp => 'Die App legt das Format (Markdown, Titel, Transkriptsprache) selbst fest — beschreibe hier nur Stil und Struktur.';

  @override
  String get settingsServicesSection => 'KI-DIENSTE';

  @override
  String get settingsSttTitle => 'Transkription';

  @override
  String get settingsTagsTitle => 'Titel und Tags';

  @override
  String get settingsNotesTitle => 'Notizen';

  @override
  String get settingsTranslateTitle => 'Übersetzung';

  @override
  String get settingsProviderSection => 'ANBIETER';

  @override
  String get settingsNoteStyleSection => 'NOTIZSTIL';

  @override
  String get settingsApiKeyInheritHint => 'Aus Transkription';

  @override
  String get settingsAdvanced => 'Erweitert';

  @override
  String get settingsAdvancedSamplingSummary => 'Basis-URL · Temperature und top_p';

  @override
  String get settingsBaseUrlFromProvider => 'Basis-URL · vom Anbieter vorgegeben';

  @override
  String settingsAdvancedSamplingValues(String temperature, String topP) {
    return 'Basis-URL · Temperature $temperature, top_p $topP';
  }
