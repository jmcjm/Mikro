/// The three jobs the app sends to an API. Each has its own endpoint, key and model, so e.g.
/// transcription can run on ElevenLabs while notes use a stronger model elsewhere.
enum ApiTask { stt, tags, notes }

/// Endpoint for one [ApiTask]: base URL, its API key and the model name.
class ServiceConfig {
  const ServiceConfig({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    this.sampling,
  });

  final String baseUrl;
  final String apiKey;
  final String model;

  /// Sampling parameters sent with chat requests, or `null` to send none and leave the
  /// model's defaults. Opt-in because not every model accepts them: OpenAI's reasoning
  /// models answer HTTP 400 to any temperature other than the default.
  final SamplingParams? sampling;
}

class SamplingParams {
  const SamplingParams({required this.temperature, required this.topP});

  /// Defaults offered when the user turns sampling control on for [task]: deterministic
  /// titles and tags, a little room for phrasing in notes.
  factory SamplingParams.defaultFor(ApiTask task) =>
      SamplingParams(temperature: task == ApiTask.notes ? 0.2 : 0, topP: 1);

  final double temperature;
  final double topP;
}

/// Wire format of a transcription request. Titles, tags and notes always go through
/// OpenAI-compatible `/chat/completions` (Gemini included); speech-to-text is where providers
/// genuinely differ.
enum SttProtocol {
  /// `POST /audio/transcriptions`, multipart, Bearer key — OpenAI, Groq, most self-hosted servers.
  openai,

  /// `POST /speech-to-text`, multipart, `xi-api-key` header, per-word speaker ids.
  elevenlabs,

  /// `models/{model}:generateContent` with the audio inline and a transcription prompt.
  gemini,
}

enum ProviderPreset {
  groq('https://api.groq.com/openai/v1', {
    ApiTask.stt: 'whisper-large-v3-turbo',
    ApiTask.tags: 'llama-3.1-8b-instant',
    // A title and five tags are fine on 8B; a structured summary of a whole recording is not.
    ApiTask.notes: 'llama-3.3-70b-versatile',
  }),
  openai('https://api.openai.com/v1', {
    ApiTask.stt: 'whisper-1',
    ApiTask.tags: 'gpt-4o-mini',
    ApiTask.notes: 'gpt-4o-mini',
  }),
  // Speech-to-text only: ElevenLabs has no chat completion API.
  elevenlabs('https://api.elevenlabs.io/v1', {ApiTask.stt: 'scribe_v2'}, SttProtocol.elevenlabs),
  // One address for every task — the OpenAI-compatible one — so the "empty key borrows the
  // transcription key for the same address" rule works for Gemini too. The transcription
  // client derives the native endpoint from it (see TranscriptionApi).
  gemini('https://generativelanguage.googleapis.com/v1beta/openai', {
    ApiTask.stt: 'gemini-3.8-flash',
    ApiTask.tags: 'gemini-3.5-flash-lite',
    ApiTask.notes: 'gemini-3.8-flash',
  }, SttProtocol.gemini),
  custom('', {ApiTask.stt: '', ApiTask.tags: '', ApiTask.notes: ''});

  const ProviderPreset(this.baseUrl, this._models, [this.sttProtocol = SttProtocol.openai]);

  final String baseUrl;
  final Map<ApiTask, String> _models;
  final SttProtocol sttProtocol;

  /// Default model of this preset for [task]; empty for [custom].
  String model(ApiTask task) => _models[task] ?? '';

  /// Whether the provider offers [task] at all.
  bool supports(ApiTask task) => _models.containsKey(task);

  /// Presets offered in the settings section of [task], in display order.
  static List<ProviderPreset> forTask(ApiTask task) =>
      values.where((p) => p.supports(task)).toList();

  /// Preset whose address is [baseUrl] (trailing slash ignored), [custom] for anything else.
  static ProviderPreset of(String baseUrl) {
    final normalized = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return values.firstWhere((p) => p != custom && p.baseUrl == normalized, orElse: () => custom);
  }
}

/// How notes are written. Sent to the model as style instructions on top of the fixed format
/// rules (Markdown, title heading, language of the transcript, no invented facts).
enum NoteStyle { detailed, concise, meeting, casual, custom }
