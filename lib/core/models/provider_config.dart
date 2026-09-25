/// The three jobs the app sends to an API. Each has its own endpoint, key and model, so e.g.
/// transcription can run on Groq's Whisper while notes use a stronger model elsewhere.
enum ApiTask { stt, tags, notes }

/// Endpoint for one [ApiTask]: an OpenAI-compatible base URL, its API key and the model name.
class ServiceConfig {
  const ServiceConfig({required this.baseUrl, required this.apiKey, required this.model});

  final String baseUrl;
  final String apiKey;
  final String model;
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
  custom('', {});

  const ProviderPreset(this.baseUrl, this._models);

  final String baseUrl;
  final Map<ApiTask, String> _models;

  /// Default model of this preset for [task]; empty for [custom].
  String model(ApiTask task) => _models[task] ?? '';

  /// Preset whose address is [baseUrl], [custom] for anything else.
  static ProviderPreset of(String baseUrl) =>
      values.firstWhere((p) => p != custom && p.baseUrl == baseUrl, orElse: () => custom);
}
