import 'package:flutter_test/flutter_test.dart';
import 'package:mikro/core/models/provider_config.dart';
import 'package:mikro/core/settings/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeKeyStore implements KeyStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String v) async => value = v;
}

void main() {
  test('load returns null when nothing is stored', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = SettingsRepository(await SharedPreferences.getInstance(), FakeKeyStore());
    expect(await repo.load(), isNull);
  });

  test('save/load round-trips, key goes to keystore', () async {
    SharedPreferences.setMockInitialValues({});
    final keyStore = FakeKeyStore();
    final repo = SettingsRepository(await SharedPreferences.getInstance(), keyStore);
    const config = ProviderConfig(
      baseUrl: 'https://api.groq.com/openai/v1',
      apiKey: 'sekret',
      sttModel: 'whisper-large-v3-turbo',
      tagModel: 'llama-3.1-8b-instant',
    );
    await repo.save(config);
    expect(keyStore.value, 'sekret');
    final loaded = await repo.load();
    expect(loaded!.baseUrl, config.baseUrl);
    expect(loaded.apiKey, 'sekret');
    expect(loaded.sttModel, config.sttModel);
    expect(loaded.tagModel, config.tagModel);
  });

  test('load returns null when baseUrl exists but key is missing', () async {
    SharedPreferences.setMockInitialValues({'base_url': 'https://x', 'stt_model': 'a', 'tag_model': 'b'});
    final repo = SettingsRepository(await SharedPreferences.getInstance(), FakeKeyStore());
    expect(await repo.load(), isNull);
  });

  // --- Regression guards (Task 4, follow-up) ---
  // Tests in the plan do not pin preference key names or empty value
  // handling: roundtrip save/load uses the same constants, and the only test accessing
  // raw keys performs a NEGATIVE assertion (load == null), which passes even
  // when the key name is completely different.

  test('GUARD: load reads exact keys base_url, stt_model, and tag_model', () async {
    // These three literals are the on-disk data format — they survive app updates.
    // Changing them would orphan the settings of every existing user.
    SharedPreferences.setMockInitialValues({
      'base_url': 'https://api.groq.com/openai/v1',
      'stt_model': 'whisper-large-v3-turbo',
      'tag_model': 'llama-3.1-8b-instant',
    });
    final repo = SettingsRepository(
      await SharedPreferences.getInstance(),
      FakeKeyStore()..value = 'sekret',
    );

    final loaded = await repo.load();
    expect(loaded, isNotNull, reason: 'complete raw keys must yield configuration');
    expect(loaded!.baseUrl, 'https://api.groq.com/openai/v1', reason: 'base_url key');
    expect(loaded.sttModel, 'whisper-large-v3-turbo', reason: 'stt_model key');
    expect(loaded.tagModel, 'llama-3.1-8b-instant', reason: 'tag_model key');
    expect(loaded.apiKey, 'sekret', reason: 'API key comes from KeyStore, not preferences');
  });

  test('GUARD: empty value counts as absent — for both baseUrl and key', () async {
    // Covers BOTH isEmpty guards. An empty base_url alone would leave half of apiKey.isEmpty
    // without a guard.
    SharedPreferences.setMockInitialValues({'base_url': '', 'stt_model': 'a', 'tag_model': 'b'});
    final emptyUrlRepo = SettingsRepository(
      await SharedPreferences.getInstance(),
      FakeKeyStore()..value = 'sekret',
    );
    expect(await emptyUrlRepo.load(), isNull,
        reason: 'empty baseUrl means missing configuration, not configuration with empty URL');

    SharedPreferences.setMockInitialValues(
        {'base_url': 'https://x', 'stt_model': 'a', 'tag_model': 'b'});
    final emptyKeyRepo = SettingsRepository(
      await SharedPreferences.getInstance(),
      FakeKeyStore()..value = '',
    );
    expect(await emptyKeyRepo.load(), isNull,
        reason: 'empty API key means missing key, not zero-length key');
  });
}
