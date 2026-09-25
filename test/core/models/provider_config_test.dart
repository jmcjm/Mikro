import 'package:flutter_test/flutter_test.dart';
import 'package:mikro/core/models/provider_config.dart';

void main() {
  test('groq preset has correct defaults', () {
    expect(ProviderPreset.groq.baseUrl, 'https://api.groq.com/openai/v1');
    expect(ProviderPreset.groq.model(ApiTask.stt), 'whisper-large-v3-turbo');
    expect(ProviderPreset.groq.model(ApiTask.tags), 'llama-3.1-8b-instant');
    expect(ProviderPreset.groq.model(ApiTask.notes), 'llama-3.3-70b-versatile');
  });
  test('openai preset has correct defaults', () {
    expect(ProviderPreset.openai.baseUrl, 'https://api.openai.com/v1');
    expect(ProviderPreset.openai.model(ApiTask.stt), 'whisper-1');
    expect(ProviderPreset.openai.model(ApiTask.tags), 'gpt-4o-mini');
    expect(ProviderPreset.openai.model(ApiTask.notes), 'gpt-4o-mini');
  });
  test('custom preset is empty', () {
    expect(ProviderPreset.custom.baseUrl, '');
    for (final task in ApiTask.values) {
      expect(ProviderPreset.custom.model(task), '');
    }
  });
  test('preset is recognised by address, anything else is custom', () {
    expect(ProviderPreset.of('https://api.openai.com/v1'), ProviderPreset.openai);
    expect(ProviderPreset.of('http://localhost:8000/v1'), ProviderPreset.custom);
    expect(ProviderPreset.of(''), ProviderPreset.custom);
  });
}
