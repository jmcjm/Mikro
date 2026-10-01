// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get navRecord => 'Enregistrer';

  @override
  String get navLibrary => 'Bibliothèque';

  @override
  String get navSettings => 'Réglages';

  @override
  String get navAppearance => 'Apparence';

  @override
  String get recorderHistoryTooltip => 'Bibliothèque';

  @override
  String get recorderSavedSnackbar =>
      'Enregistrement sauvegardé — transcription en cours.';

  @override
  String get recorderSavedAction => 'Afficher';

  @override
  String get recorderStatusRecording => 'Enregistrement';

  @override
  String get recorderStatusReady => 'Prêt à enregistrer';

  @override
  String get recorderErrorMicPermission =>
      'Pas d\'autorisation pour le microphone.';

  @override
  String recorderErrorStartFailed(String detail) {
    return 'Impossible de démarrer l\'enregistrement : $detail';
  }

  @override
  String get libraryTitle => 'Bibliothèque';

  @override
  String get librarySearchHint =>
      'Rechercher dans les transcriptions et les tags';

  @override
  String get libraryFilterAll => 'Tous';

  @override
  String libraryDatabaseError(String detail) {
    return 'Erreur de base de données : $detail';
  }

  @override
  String get libraryEmptyNoResults => 'Aucun résultat.';

  @override
  String get libraryEmptyNoRecordings => 'Aucun enregistrement';

  @override
  String get libraryEmptyDescription =>
      'Touchez le microphone sur l\'écran d\'enregistrement — votre première note apparaîtra ici, avec ses tags.';

  @override
  String get libraryRecordCta => 'Enregistrer votre première note';

  @override
  String get libraryRetry => 'Réessayer';

  @override
  String get detailTitle => 'Enregistrement';

  @override
  String get detailBackTooltip => 'Retour';

  @override
  String get detailShareTooltip => 'Partager';

  @override
  String get detailCopyTooltip => 'Copier la transcription';

  @override
  String get detailDeleteTooltip => 'Supprimer';

  @override
  String get detailDeleteTitle => 'Supprimer cet enregistrement ?';

  @override
  String get detailDeleteMessage =>
      'Le fichier audio et la transcription sont supprimés définitivement.';

  @override
  String get detailCancel => 'Annuler';

  @override
  String get detailDelete => 'Supprimer';

  @override
  String get detailDeleteError => 'Impossible de supprimer l\'enregistrement.';

  @override
  String get detailRecordingDeleted => 'Enregistrement supprimé.';

  @override
  String get detailCopiedTranscript =>
      'Transcription copiée dans le presse-papiers.';

  @override
  String get detailCopied => 'Copié.';

  @override
  String get detailTranscriptLabel => 'TRANSCRIPTION';

  @override
  String get detailAddTagChip => 'tag';

  @override
  String get detailAddTagTitle => 'Ajouter un tag';

  @override
  String get detailAddTagLabel => 'Nom du tag';

  @override
  String get detailAddTagDuplicate => 'Ce tag est déjà attribué.';

  @override
  String get detailAddTagConfirm => 'Ajouter';

  @override
  String get detailTagSaveError =>
      'Impossible d\'enregistrer la modification du tag.';

  @override
  String get detailRemoveTagTooltip => 'Retirer le tag';

  @override
  String get detailRetryProcessing => 'Relancer le traitement';

  @override
  String get detailShareTranscript => 'Transcription';

  @override
  String get detailShareAudio => 'Fichier audio';

  @override
  String get detailCopiedAudioPath =>
      'Chemin du fichier audio copié dans le presse-papiers.';

  @override
  String get detailShareError => 'Impossible de partager.';

  @override
  String get detailRegenerateTooltip => 'Régénérer';

  @override
  String get detailRegenerateTitle => 'Régénérer ?';

  @override
  String get detailRegenerateMessage =>
      'La transcription, le titre et tous les tags (y compris manuels) seront supprimés et l\'enregistrement sera retraité depuis le début.';

  @override
  String get detailRegenerateConfirm => 'Régénérer';

  @override
  String get detailRegenerateBusy =>
      'Cet enregistrement est en cours de traitement.';

  @override
  String get detailRegenerateError =>
      'Impossible de réinitialiser l\'enregistrement.';

  @override
  String get detailRewindTooltip => 'Reculer de 10 secondes';

  @override
  String get detailForwardTooltip => 'Avancer de 10 secondes';

  @override
  String get detailSpeedTooltip => 'Vitesse de lecture';

  @override
  String detailSpeedLabel(String rate) {
    return '$rate×';
  }

  @override
  String get detailSeekLabel => 'Barre de lecture';

  @override
  String get statusQueued => 'En attente…';

  @override
  String get statusTranscribing => 'Transcription…';

  @override
  String get statusTagging => 'Ajout des tags…';

  @override
  String get statusDone => 'Terminé';

  @override
  String get statusError => 'Erreur';

  @override
  String get settingsTitle => 'Réglages';

  @override
  String get settingsThemeSection => 'THÈME';

  @override
  String get settingsProviderCustom => 'Personnalisé';

  @override
  String get settingsBaseUrl => 'URL de base';

  @override
  String get settingsApiKey => 'Clé API';

  @override
  String get settingsShowKey => 'Afficher la clé';

  @override
  String get settingsHideKey => 'Masquer la clé';

  @override
  String get settingsSave => 'Enregistrer';

  @override
  String get settingsSaved => 'Réglages enregistrés.';

  @override
  String get settingsThemeLight => 'Clair';

  @override
  String get settingsThemeDark => 'Sombre';

  @override
  String get settingsThemeSystem => 'Système';

  @override
  String get onboardingWelcomeHeadline =>
      'Parlez.\nMikro l\'écrit\net l\'étiquette.';

  @override
  String get onboardingWelcomeBody =>
      'Les enregistrements restent sur votre appareil ; la transcription et les tags partent chez le fournisseur de votre choix.';

  @override
  String get onboardingMicHeadline => 'Le microphone\nd\'abord.';

  @override
  String get onboardingMicBody =>
      'Le système ne demande qu\'une fois. Sans accès, Mikro n\'enregistrera pas un mot.';

  @override
  String get onboardingMicTitle => 'Accès au microphone';

  @override
  String get onboardingMicSubtitle => 'Nécessaire pour enregistrer';

  @override
  String get onboardingMicGranted => 'Accordé';

  @override
  String get onboardingMicAllow => 'Autoriser';

  @override
  String get onboardingMicRetry => 'Réessayer';

  @override
  String get onboardingMicDenied =>
      'Refusé. Activez l\'accès dans les réglages du système.';

  @override
  String get onboardingProviderHeadline =>
      'La clé API\npeut attendre\naussi longtemps que vous voulez.';

  @override
  String get onboardingProviderBody =>
      'La transcription et les tags vont chez Groq ou OpenAI. L\'enregistrement fonctionne sans clé.';

  @override
  String get onboardingProviderTitle => 'Clé API';

  @override
  String get onboardingProviderSubtitle =>
      'Groq ou OpenAI — vous pouvez l\'ajouter plus tard';

  @override
  String get onboardingNext => 'Suivant';

  @override
  String get onboardingStart => 'C\'est parti';

  @override
  String get apiErrorNetwork => 'Pas de connexion réseau.';

  @override
  String get apiErrorAuth =>
      'Échec de l\'autorisation — vérifiez la clé API dans les Réglages.';

  @override
  String get apiErrorTooLarge =>
      'L\'API a refusé le fichier — trop volumineux.';

  @override
  String get apiErrorRateLimit =>
      'Limite de requêtes dépassée — réessayez dans un instant.';

  @override
  String apiErrorServer(String detail) {
    return 'Erreur du serveur du fournisseur ($detail).';
  }

  @override
  String apiErrorBadResponse(String detail) {
    return 'Réponse inattendue du serveur ($detail).';
  }

  @override
  String get apiErrorBadFormat => 'Format de réponse de l\'API inattendu.';

  @override
  String get apiErrorNoContent =>
      'La réponse de l\'API ne contenait aucun contenu de message.';

  @override
  String get apiErrorNoTranscript =>
      'La réponse de l\'API ne contenait pas de champ texte.';

  @override
  String get apiErrorBadTags => 'Le modèle n\'a renvoyé aucun tag exploitable.';

  @override
  String get pipelineErrorNoConfig =>
      'Aucune configuration d\'API — renseignez l\'adresse et la clé dans la section correspondante des Réglages (transcription, tags ou notes).';

  @override
  String get pipelineErrorSizeLimit =>
      'L\'enregistrement est trop volumineux pour le fournisseur de transcription choisi (OpenAI et Groq : 25 Mo, Gemini : 14 Mo). Choisissez un autre fournisseur, par ex. ElevenLabs.';

  @override
  String pipelineErrorUnexpected(String detail) {
    return 'Erreur inattendue : $detail';
  }

  @override
  String get errorUnknown => 'Erreur inconnue';

  @override
  String get navNotes => 'Notes';

  @override
  String get notesTitle => 'Notes';

  @override
  String get notesSearchHint => 'Rechercher dans les notes';

  @override
  String get notesEmpty =>
      'Pas encore de notes. Ouvrez un enregistrement et utilisez « Créer une note ».';

  @override
  String get notesNoResults => 'Aucune note ne correspond à votre recherche.';

  @override
  String get noteUntitled => 'Note sans titre';

  @override
  String get noteTitleHint => 'Titre';

  @override
  String get noteContentHint => 'Contenu de la note (Markdown)';

  @override
  String get noteEditTooltip => 'Modifier';

  @override
  String get notePreviewTooltip => 'Aperçu';

  @override
  String get noteShareTooltip => 'Partager';

  @override
  String noteSourceLink(String title) {
    return 'Source : $title';
  }

  @override
  String get noteSourceDeleted => 'L\'enregistrement source a été supprimé';

  @override
  String get noteDeleteTitle => 'Supprimer la note ?';

  @override
  String get noteDeleteMessage =>
      'La note sera supprimée définitivement. L\'enregistrement et la transcription sont conservés.';

  @override
  String get noteRegenerateTooltip => 'Régénérer à partir de la transcription';

  @override
  String get noteRegenerateTitle => 'Régénérer la note ?';

  @override
  String get noteRegenerateMessage =>
      'Le contenu et le titre seront remplacés par une nouvelle version issue de la transcription actuelle. Vos modifications seront perdues.';

  @override
  String get noteSaveError => 'Impossible d\'enregistrer la note.';

  @override
  String get noteDeleted => 'Note supprimée.';

  @override
  String get detailMakeNote => 'Créer une note';

  @override
  String get detailOpenNote => 'Ouvrir la note';

  @override
  String get detailNoteGenerating => 'Création de la note…';

  @override
  String get detailTranscriptHint => 'La transcription est vide';

  @override
  String get detailTranscriptSaveError =>
      'Impossible d\'enregistrer la transcription.';

  @override
  String get settingsSttModelHelp =>
      'Les locuteurs sont reconnus par ElevenLabs, Gemini et gpt-4o-transcribe-diarize (OpenAI). Whisper (Groq, OpenAI) ne distingue pas les locuteurs.';

  @override
  String get settingsModel => 'Modèle';

  @override
  String get navQuickRecord => 'Démarrer l\'enregistrement';

  @override
  String get navQuickRecordStop => 'Arrêter l\'enregistrement';

  @override
  String get translateTooltip => 'Traduire';

  @override
  String get translatePickTitle => 'Traduire en';

  @override
  String get translationOriginal => 'Original';

  @override
  String get translationDeleteTooltip => 'Supprimer la traduction';

  @override
  String tagColorTitle(String tag) {
    return 'Couleur de « $tag »';
  }

  @override
  String get tagColorDefault => 'Par défaut';

  @override
  String get noteColorTitle => 'Couleur de la note';

  @override
  String get noteColorTooltip => 'Couleur';

  @override
  String get settingsSampling => 'Contrôler temperature et top_p';

  @override
  String get settingsSamplingHelp =>
      'Tous les modèles ne le gèrent pas. Les modèles de raisonnement (par ex. OpenAI GPT-5) le rejettent avec une erreur HTTP 400 — laissez-le désactivé pour eux.';

  @override
  String get settingsTemperature => 'Temperature';

  @override
  String get settingsApiKeyInheritHelp =>
      'Laissez vide pour utiliser la clé de Transcription lorsque l\'adresse est la même.';

  @override
  String get settingsNoteStyleDetailed => 'Détaillé';

  @override
  String get settingsNoteStyleDetailedHelp =>
      'Titres, puces et gras ; conserve chaque fait pertinent, tâches sous forme de liste à cocher.';

  @override
  String get settingsNoteStyleConcise => 'Concis';

  @override
  String get settingsNoteStyleConciseHelp =>
      'Quelques puces avec l\'essentiel et les éventuelles tâches — lisible en une minute.';

  @override
  String get settingsNoteStyleMeeting => 'Compte rendu de réunion';

  @override
  String get settingsNoteStyleMeetingHelp =>
      'Participants, sujets, décisions, actions (qui, quoi, pour quand) et questions ouvertes.';

  @override
  String get settingsNoteStyleCasual => 'Décontracté';

  @override
  String get settingsNoteStyleCasualHelp =>
      'Détendu et amical, avec quelques emojis bien placés — pas une avalanche.';

  @override
  String get settingsNoteStyleCustom => 'Personnalisé';

  @override
  String get settingsNoteStyleCustomLabel => 'Instructions pour l\'IA';

  @override
  String get settingsNoteStyleCustomHint =>
      'par ex. Rédige des notes de cours : définitions, exemples et 3 questions de révision à la fin.';

  @override
  String get settingsNoteStyleCustomHelp =>
      'L\'application impose elle-même le format (Markdown, titre, langue de la transcription) — décrivez ici uniquement le style et la structure.';

  @override
  String get settingsServicesSection => 'SERVICES D\'IA';

  @override
  String get settingsSttTitle => 'Transcription';

  @override
  String get settingsTagsTitle => 'Titres et tags';

  @override
  String get settingsNotesTitle => 'Notes';

  @override
  String get settingsTranslateTitle => 'Traduction';

  @override
  String get settingsProviderSection => 'FOURNISSEUR';

  @override
  String get settingsNoteStyleSection => 'STYLE DE NOTE';

  @override
  String get settingsApiKeyInheritHint => 'Depuis Transcription';

  @override
  String get settingsAdvanced => 'Avancé';

  @override
  String get settingsAdvancedSamplingSummary =>
      'URL de base · temperature et top_p';

  @override
  String get settingsBaseUrlFromProvider =>
      'URL de base · définie par le fournisseur';

  @override
  String settingsAdvancedSamplingValues(String temperature, String topP) {
    return 'URL de base · temperature $temperature, top_p $topP';
  }
}
