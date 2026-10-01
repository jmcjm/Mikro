// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get navRecord => 'Grabar';

  @override
  String get navLibrary => 'Biblioteca';

  @override
  String get navSettings => 'Ajustes';

  @override
  String get navAppearance => 'Apariencia';

  @override
  String get recorderHistoryTooltip => 'Biblioteca';

  @override
  String get recorderSavedSnackbar => 'Grabación guardada — transcripción en curso.';

  @override
  String get recorderSavedAction => 'Ver';

  @override
  String get recorderStatusRecording => 'Grabando';

  @override
  String get recorderStatusReady => 'Listo para grabar';

  @override
  String get recorderErrorMicPermission => 'Sin permiso de micrófono.';

  @override
  String recorderErrorStartFailed(String detail) {
    return 'No se pudo iniciar la grabación: $detail';
  }

  @override
  String get libraryTitle => 'Biblioteca';

  @override
  String get librarySearchHint => 'Buscar en transcripciones y etiquetas';

  @override
  String get libraryFilterAll => 'Todas';

  @override
  String libraryDatabaseError(String detail) {
    return 'Error de base de datos: $detail';
  }

  @override
  String get libraryEmptyNoResults => 'No se encontró nada.';

  @override
  String get libraryEmptyNoRecordings => 'Sin grabaciones';

  @override
  String get libraryEmptyDescription => 'Toca el micrófono en la pantalla de grabación — tu primera nota aparecerá aquí, con etiquetas.';

  @override
  String get libraryRecordCta => 'Graba tu primera nota';

  @override
  String get libraryRetry => 'Reintentar';

  @override
  String get detailTitle => 'Grabación';

  @override
  String get detailBackTooltip => 'Atrás';

  @override
  String get detailShareTooltip => 'Compartir';

  @override
  String get detailCopyTooltip => 'Copiar transcripción';

  @override
  String get detailDeleteTooltip => 'Eliminar';

  @override
  String get detailDeleteTitle => '¿Eliminar esta grabación?';

  @override
  String get detailDeleteMessage => 'El archivo de audio y la transcripción se eliminan definitivamente.';

  @override
  String get detailCancel => 'Cancelar';

  @override
  String get detailDelete => 'Eliminar';

  @override
  String get detailDeleteError => 'No se pudo eliminar la grabación.';

  @override
  String get detailRecordingDeleted => 'Grabación eliminada.';

  @override
  String get detailCopiedTranscript => 'Transcripción copiada al portapapeles.';

  @override
  String get detailCopied => 'Copiado.';

  @override
  String get detailTranscriptLabel => 'TRANSCRIPCIÓN';

  @override
  String get detailAddTagChip => 'etiqueta';

  @override
  String get detailAddTagTitle => 'Añadir etiqueta';

  @override
  String get detailAddTagLabel => 'Nombre de la etiqueta';

  @override
  String get detailAddTagDuplicate => 'Esta etiqueta ya está asignada.';

  @override
  String get detailAddTagConfirm => 'Añadir';

  @override
  String get detailTagSaveError => 'No se pudo guardar el cambio de etiqueta.';

  @override
  String get detailRemoveTagTooltip => 'Quitar etiqueta';

  @override
  String get detailRetryProcessing => 'Reintentar procesamiento';

  @override
  String get detailShareTranscript => 'Transcripción';

  @override
  String get detailShareAudio => 'Archivo de audio';

  @override
  String get detailCopiedAudioPath => 'Ruta del archivo de audio copiada al portapapeles.';

  @override
  String get detailShareError => 'No se pudo compartir.';

  @override
  String get detailRegenerateTooltip => 'Regenerar';

  @override
  String get detailRegenerateTitle => '¿Regenerar?';

  @override
  String get detailRegenerateMessage => 'Se eliminarán la transcripción, el título y todas las etiquetas (también las manuales) y la grabación se procesará desde cero.';

  @override
  String get detailRegenerateConfirm => 'Regenerar';

  @override
  String get detailRegenerateBusy => 'Esta grabación se está procesando ahora mismo.';

  @override
  String get detailRegenerateError => 'No se pudo restablecer la grabación.';

  @override
  String get detailRewindTooltip => 'Retroceder 10 segundos';

  @override
  String get detailForwardTooltip => 'Avanzar 10 segundos';

  @override
  String get detailSpeedTooltip => 'Velocidad de reproducción';

  @override
  String detailSpeedLabel(String rate) {
    return '$rate×';
  }

  @override
  String get detailSeekLabel => 'Barra de reproducción';

  @override
  String get statusQueued => 'En cola…';

  @override
  String get statusTranscribing => 'Transcribiendo…';

  @override
  String get statusTagging => 'Etiquetando…';

  @override
  String get statusDone => 'Listo';

  @override
  String get statusError => 'Error';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsThemeSection => 'TEMA';

  @override
  String get settingsProviderCustom => 'Personalizado';

  @override
  String get settingsBaseUrl => 'URL base';

  @override
  String get settingsApiKey => 'Clave de API';

  @override
  String get settingsShowKey => 'Mostrar clave';

  @override
  String get settingsHideKey => 'Ocultar clave';

  @override
  String get settingsSave => 'Guardar';

  @override
  String get settingsSaved => 'Ajustes guardados.';

  @override
  String get settingsThemeLight => 'Claro';

  @override
  String get settingsThemeDark => 'Oscuro';

  @override
  String get settingsThemeSystem => 'Sistema';

  @override
  String get onboardingWelcomeHeadline => 'Habla.\nMikro lo escribe\ny lo etiqueta.';

  @override
  String get onboardingWelcomeBody => 'Las grabaciones se quedan en tu dispositivo; la transcripción y las etiquetas van al proveedor que elijas.';

  @override
  String get onboardingMicHeadline => 'Primero,\nel micrófono.';

  @override
  String get onboardingMicBody => 'El sistema pregunta una sola vez. Sin acceso, Mikro no grabará ni una palabra.';

  @override
  String get onboardingMicTitle => 'Acceso al micrófono';

  @override
  String get onboardingMicSubtitle => 'Necesario para grabar';

  @override
  String get onboardingMicGranted => 'Concedido';

  @override
  String get onboardingMicAllow => 'Permitir';

  @override
  String get onboardingMicRetry => 'Reintentar';

  @override
  String get onboardingMicDenied => 'Denegado. Activa el acceso en los ajustes del sistema.';

  @override
  String get onboardingProviderHeadline => 'La clave de API\npuede esperar\ntanto como quieras.';

  @override
  String get onboardingProviderBody => 'La transcripción y las etiquetas van a Groq u OpenAI. Grabar funciona sin clave.';

  @override
  String get onboardingProviderTitle => 'Clave de API';

  @override
  String get onboardingProviderSubtitle => 'Groq u OpenAI — puedes añadirla más tarde';

  @override
  String get onboardingNext => 'Siguiente';

  @override
  String get onboardingStart => 'Empezar';

  @override
  String get apiErrorNetwork => 'Sin conexión de red.';

  @override
  String get apiErrorAuth => 'Error de autorización — revisa la clave de API en Ajustes.';

  @override
  String get apiErrorTooLarge => 'La API rechazó el archivo — demasiado grande.';

  @override
  String get apiErrorRateLimit => 'Límite de solicitudes superado — inténtalo de nuevo en un momento.';

  @override
  String apiErrorServer(String detail) {
    return 'Error del servidor del proveedor ($detail).';
  }

  @override
  String apiErrorBadResponse(String detail) {
    return 'Respuesta inesperada del servidor ($detail).';
  }

  @override
  String get apiErrorBadFormat => 'Formato de respuesta de la API inesperado.';

  @override
  String get apiErrorNoContent => 'La respuesta de la API no incluía contenido del mensaje.';

  @override
  String get apiErrorNoTranscript => 'La respuesta de la API no tenía campo de texto.';

  @override
  String get apiErrorBadTags => 'El modelo no devolvió etiquetas utilizables.';

  @override
  String get pipelineErrorNoConfig => 'Sin configuración de API — rellena la dirección y la clave en la sección correspondiente de Ajustes (transcripción, etiquetas o notas).';

  @override
  String get pipelineErrorSizeLimit => 'La grabación es demasiado grande para el proveedor de transcripción seleccionado (OpenAI y Groq: 25 MB, Gemini: 14 MB). Elige otro proveedor, p. ej. ElevenLabs.';

  @override
  String pipelineErrorUnexpected(String detail) {
    return 'Error inesperado: $detail';
  }

  @override
  String get errorUnknown => 'Error desconocido';

  @override
  String get navNotes => 'Notas';

  @override
  String get notesTitle => 'Notas';

  @override
  String get notesSearchHint => 'Buscar notas';

  @override
  String get notesEmpty => 'Aún no hay notas. Abre una grabación y usa «Crear nota».';

  @override
  String get notesNoResults => 'Ninguna nota coincide con tu búsqueda.';

  @override
  String get noteUntitled => 'Nota sin título';

  @override
  String get noteTitleHint => 'Título';

  @override
  String get noteContentHint => 'Contenido de la nota (Markdown)';

  @override
  String get noteEditTooltip => 'Editar';

  @override
  String get notePreviewTooltip => 'Vista previa';

  @override
  String get noteShareTooltip => 'Compartir';

  @override
  String noteSourceLink(String title) {
    return 'Fuente: $title';
  }

  @override
  String get noteSourceDeleted => 'La grabación de origen fue eliminada';

  @override
  String get noteDeleteTitle => '¿Eliminar la nota?';

  @override
  String get noteDeleteMessage => 'La nota se eliminará definitivamente. La grabación y la transcripción se conservan.';

  @override
  String get noteRegenerateTooltip => 'Regenerar desde la transcripción';

  @override
  String get noteRegenerateTitle => '¿Regenerar la nota?';

  @override
  String get noteRegenerateMessage => 'El contenido y el título se sustituirán por una versión nueva generada a partir de la transcripción actual. Se perderán tus ediciones.';

  @override
  String get noteSaveError => 'No se pudo guardar la nota.';

  @override
  String get noteDeleted => 'Nota eliminada.';

  @override
  String get detailMakeNote => 'Crear nota';

  @override
  String get detailOpenNote => 'Abrir nota';

  @override
  String get detailNoteGenerating => 'Creando nota…';

  @override
  String get detailTranscriptHint => 'La transcripción está vacía';

  @override
  String get detailTranscriptSaveError => 'No se pudo guardar la transcripción.';

  @override
  String get settingsSttModelHelp => 'ElevenLabs, Gemini y gpt-4o-transcribe-diarize (OpenAI) reconocen a los hablantes. Whisper (Groq, OpenAI) no distingue entre hablantes.';

  @override
  String get settingsModel => 'Modelo';

  @override
  String get navQuickRecord => 'Iniciar grabación';

  @override
  String get navQuickRecordStop => 'Detener grabación';

  @override
  String get translateTooltip => 'Traducir';

  @override
  String get translatePickTitle => 'Traducir a';

  @override
  String get translationOriginal => 'Original';

  @override
  String get translationDeleteTooltip => 'Eliminar traducción';

  @override
  String tagColorTitle(String tag) {
    return 'Color de «$tag»';
  }

  @override
  String get tagColorDefault => 'Predeterminado';

  @override
  String get noteColorTitle => 'Color de la nota';

  @override
  String get noteColorTooltip => 'Color';

  @override
  String get settingsSampling => 'Controlar temperature y top_p';

  @override
  String get settingsSamplingHelp => 'No todos los modelos lo admiten. Los modelos de razonamiento (p. ej. OpenAI GPT-5) lo rechazan con HTTP 400 — déjalo desactivado con ellos.';

  @override
  String get settingsTemperature => 'Temperature';

  @override
  String get settingsApiKeyInheritHelp => 'Déjalo vacío para usar la clave de Transcripción cuando la dirección sea la misma.';

  @override
  String get settingsNoteStyleDetailed => 'Detallado';

  @override
  String get settingsNoteStyleDetailedHelp => 'Títulos, viñetas y negritas; conserva todos los datos relevantes, tareas como lista de comprobación.';

  @override
  String get settingsNoteStyleConcise => 'Conciso';

  @override
  String get settingsNoteStyleConciseHelp => 'Unas pocas viñetas con lo esencial y las tareas, si las hay — se lee en un minuto.';

  @override
  String get settingsNoteStyleMeeting => 'Acta de reunión';

  @override
  String get settingsNoteStyleMeetingHelp => 'Participantes, temas, decisiones, tareas (quién, qué, para cuándo) y preguntas abiertas.';

  @override
  String get settingsNoteStyleCasual => 'Informal';

  @override
  String get settingsNoteStyleCasualHelp => 'Relajado y amistoso, con algunos emojis bien colocados — sin abusar.';

  @override
  String get settingsNoteStyleCustom => 'Personalizado';

  @override
  String get settingsNoteStyleCustomLabel => 'Instrucciones para la IA';

  @override
  String get settingsNoteStyleCustomHint => 'p. ej. Escribe apuntes de estudio: definiciones, ejemplos y 3 preguntas de repaso al final.';

  @override
  String get settingsNoteStyleCustomHelp => 'La app impone el formato (Markdown, título, idioma de la transcripción) por sí misma — describe aquí solo el estilo y la estructura.';

  @override
  String get settingsServicesSection => 'SERVICIOS DE IA';

  @override
  String get settingsSttTitle => 'Transcripción';

  @override
  String get settingsTagsTitle => 'Títulos y etiquetas';

  @override
  String get settingsNotesTitle => 'Notas';

  @override
  String get settingsTranslateTitle => 'Traducción';

  @override
  String get settingsProviderSection => 'PROVEEDOR';

  @override
  String get settingsNoteStyleSection => 'ESTILO DE NOTA';

  @override
  String get settingsApiKeyInheritHint => 'De Transcripción';

  @override
  String get settingsAdvanced => 'Avanzado';

  @override
  String get settingsAdvancedSamplingSummary => 'URL base · temperature y top_p';

  @override
  String get settingsBaseUrlFromProvider => 'URL base · definida por el proveedor';

  @override
  String settingsAdvancedSamplingValues(String temperature, String topP) {
    return 'URL base · temperature $temperature, top_p $topP';
  }
