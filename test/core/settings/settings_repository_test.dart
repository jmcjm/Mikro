import 'package:flutter_test/flutter_test.dart';
import 'package:mikro/core/models/provider_config.dart';
import 'package:mikro/core/settings/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeKeyStore implements KeyStore {
  FakeKeyStore([Map<String, String>? initial]) : values = {...?initial};
  final Map<String, String> values;
  @override
  Future<String?> read(String name) async => values[name];
  @override
  Future<void> write(String name, String v) async => values[name] = v;
}

const _groq = 'https://api.groq.com/openai/v1';
const _openai = 'https://api.openai.com/v1';

Future<SettingsRepository> repo(Map<String, Object> prefs, [FakeKeyStore? keys]) async {
  SharedPreferences.setMockInitialValues(prefs);
  return SettingsRepository(await SharedPreferences.getInstance(), keys ?? FakeKeyStore());
}

void main() {
  test('load returns null for every task when nothing is stored', () async {
    final r = await repo({});
    for (final task in ApiTask.values) {
      expect(await r.load(task), isNull, reason: task.name);
    }
  });

  test('each task saves and loads its own address, key and model', () async {
    final keys = FakeKeyStore();
    final r = await repo({}, keys);
    await r.save(
      ApiTask.stt,
      const ServiceConfig(baseUrl: _groq, apiKey: 'gsk', model: 'whisper-large-v3-turbo'),
    );
    await r.save(
      ApiTask.tags,
      const ServiceConfig(baseUrl: _groq, apiKey: 'gsk', model: 'llama-3.1-8b-instant'),
    );
    await r.save(
      ApiTask.notes,
      const ServiceConfig(baseUrl: _openai, apiKey: 'sk', model: 'gpt-4o'),
    );

    final notes = await r.load(ApiTask.notes);
    expect(notes!.baseUrl, _openai);
    expect(notes.apiKey, 'sk');
    expect(notes.model, 'gpt-4o');
    expect((await r.load(ApiTask.stt))!.model, 'whisper-large-v3-turbo');
    expect((await r.load(ApiTask.tags))!.model, 'llama-3.1-8b-instant');
    expect(keys.values, {
      'api_key_stt': 'gsk',
      'api_key_tags': 'gsk',
      'api_key_notes': 'sk',
    }, reason: 'keys live in the key store, one per task, never in preferences');
  });

  test('GUARD: storage key names', () {
    // On-disk format: renaming any of these orphans users' settings.
    expect(SettingsRepository.baseUrlKey(ApiTask.stt), 'stt_base_url');
    expect(SettingsRepository.baseUrlKey(ApiTask.tags), 'tags_base_url');
    expect(SettingsRepository.baseUrlKey(ApiTask.notes), 'notes_base_url');
    expect(SettingsRepository.modelKey(ApiTask.stt), 'stt_model');
    expect(SettingsRepository.modelKey(ApiTask.tags), 'tag_model');
    expect(SettingsRepository.modelKey(ApiTask.notes), 'notes_model');
    expect(SettingsRepository.apiKeyName(ApiTask.stt), 'api_key_stt');
    expect(SettingsRepository.legacyBaseUrlKey, 'base_url');
    expect(SettingsRepository.legacyApiKeyName, 'api_key');
  });

  test('GUARD: pre-split settings keep working for all three tasks', () async {
    // Exactly what the single-provider version wrote.
    final r = await repo({
      'base_url': _groq,
      'stt_model': 'whisper-large-v3-turbo',
      'tag_model': 'llama-3.1-8b-instant',
    }, FakeKeyStore({'api_key': 'stary'}));

    final stt = await r.load(ApiTask.stt);
    expect(stt!.baseUrl, _groq);
    expect(stt.apiKey, 'stary');
    expect(stt.model, 'whisper-large-v3-turbo');
    expect((await r.load(ApiTask.tags))!.model, 'llama-3.1-8b-instant');
    final notes = await r.load(ApiTask.notes);
    expect(notes!.apiKey, 'stary');
    expect(
      notes.model,
      'llama-3.1-8b-instant',
      reason: 'notes used the tagging model before they had their own',
    );
  });

  test('per-task values win over legacy ones, including a deliberately empty key', () async {
    final r = await repo({
      'base_url': _groq,
      'notes_base_url': _openai,
      'notes_model': 'gpt-4o',
    }, FakeKeyStore({'api_key': 'stary', 'api_key_notes': 'sk'}));
    final notes = await r.load(ApiTask.notes);
    expect(notes!.baseUrl, _openai);
    expect(notes.apiKey, 'sk');

    final cleared = await repo({
      'stt_base_url': _openai,
    }, FakeKeyStore({'api_key': 'stary', 'api_key_stt': ''}));
    expect(
      await cleared.load(ApiTask.stt),
      isNull,
      reason: 'a saved empty key is a value, not a reason to fall back to the old one',
    );
  });

  test('empty key borrows the transcription key only for the same address', () async {
    final r = await repo({
      'stt_base_url': _groq,
      'tags_base_url': _groq,
      'notes_base_url': _openai,
    }, FakeKeyStore({'api_key_stt': 'gsk', 'api_key_tags': '', 'api_key_notes': ''}));
    expect((await r.load(ApiTask.tags))!.apiKey, 'gsk');
    expect(
      await r.load(ApiTask.notes),
      isNull,
      reason: 'a Groq key must never be sent to another provider',
    );
  });

  test('empty address means not configured', () async {
    final r = await repo({'stt_base_url': ''}, FakeKeyStore({'api_key_stt': 'k'}));
    expect(await r.load(ApiTask.stt), isNull);
  });

  test('raw returns incomplete settings for the settings screen', () async {
    final r = await repo({'tags_base_url': _groq, 'tag_model': 'm'});
    final raw = await r.raw(ApiTask.tags);
    expect(raw.baseUrl, _groq);
    expect(raw.apiKey, '');
    expect(raw.model, 'm');
  });
}
