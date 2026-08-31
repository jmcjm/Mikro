import 'package:flutter_test/flutter_test.dart';
import 'package:mikro/core/models/provider_config.dart';

void main() {
  test('groq preset has correct defaults', () {
    expect(ProviderPreset.groq.baseUrl, 'https://api.groq.com/openai/v1');
    expect(ProviderPreset.groq.sttModel, 'whisper-large-v3-turbo');
    expect(ProviderPreset.groq.tagModel, 'llama-3.1-8b-instant');
  });
  test('openai preset has correct defaults', () {
    expect(ProviderPreset.openai.baseUrl, 'https://api.openai.com/v1');
    expect(ProviderPreset.openai.sttModel, 'whisper-1');
    expect(ProviderPreset.openai.tagModel, 'gpt-4o-mini');
  });
  test('custom preset is empty', () {
    expect(ProviderPreset.custom.baseUrl, '');
  });
}
