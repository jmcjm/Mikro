class ProviderConfig {
  const ProviderConfig({
    required this.baseUrl,
    required this.apiKey,
    required this.sttModel,
    required this.tagModel,
  });

  final String baseUrl;
  final String apiKey;
  final String sttModel;
  final String tagModel;
}

enum ProviderPreset {
  groq('https://api.groq.com/openai/v1', 'whisper-large-v3-turbo', 'llama-3.1-8b-instant'),
  openai('https://api.openai.com/v1', 'whisper-1', 'gpt-4o-mini'),
  custom('', '', '');

  const ProviderPreset(this.baseUrl, this.sttModel, this.tagModel);

  final String baseUrl;
  final String sttModel;
  final String tagModel;
}
