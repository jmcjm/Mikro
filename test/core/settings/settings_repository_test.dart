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
  test('load zwraca null gdy nic nie zapisano', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = SettingsRepository(await SharedPreferences.getInstance(), FakeKeyStore());
    expect(await repo.load(), isNull);
  });

  test('save/load robi rundtrip, klucz idzie do keystore', () async {
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

  test('load zwraca null gdy jest baseUrl ale brak klucza', () async {
    SharedPreferences.setMockInitialValues({'base_url': 'https://x', 'stt_model': 'a', 'tag_model': 'b'});
    final repo = SettingsRepository(await SharedPreferences.getInstance(), FakeKeyStore());
    expect(await repo.load(), isNull);
  });
}
