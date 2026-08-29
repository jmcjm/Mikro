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

  // --- Straznicy regresji (Task 4, uzupelnienie) ---
  // Testy z planu nie przypinaja ani nazw kluczy w preferencjach, ani obslugi pustych
  // wartosci: roundtrip save/load chodzi przez te same stale, a jedyny test siegajacy po
  // surowe klucze robi asercje NEGATYWNA (load == null), ktora przechodzi rowniez wtedy,
  // gdy nazwa klucza jest zupelnie inna.

  test('STRAZNIK: load czyta dokladnie klucze base_url, stt_model i tag_model', () async {
    // Te trzy literaly to format danych na dysku — przezywaja aktualizacje aplikacji.
    // Ich zmiana osierociłaby ustawienia kazdego istniejacego uzytkownika.
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
    expect(loaded, isNotNull, reason: 'komplet surowych kluczy musi dac konfiguracje');
    expect(loaded!.baseUrl, 'https://api.groq.com/openai/v1', reason: 'klucz base_url');
    expect(loaded.sttModel, 'whisper-large-v3-turbo', reason: 'klucz stt_model');
    expect(loaded.tagModel, 'llama-3.1-8b-instant', reason: 'klucz tag_model');
    expect(loaded.apiKey, 'sekret', reason: 'klucz API pochodzi z KeyStore, nie z preferencji');
  });

  test('STRAZNIK: pusta wartosc liczy sie jak brak — i dla baseUrl, i dla klucza', () async {
    // Pokrywa OBA guardy isEmpty. Sam pusty base_url zostawilby polowe apiKey.isEmpty
    // bez straznika.
    SharedPreferences.setMockInitialValues({'base_url': '', 'stt_model': 'a', 'tag_model': 'b'});
    final bezUrl = SettingsRepository(
      await SharedPreferences.getInstance(),
      FakeKeyStore()..value = 'sekret',
    );
    expect(await bezUrl.load(), isNull,
        reason: 'pusty baseUrl to brak konfiguracji, nie konfiguracja z pustym URL');

    SharedPreferences.setMockInitialValues(
        {'base_url': 'https://x', 'stt_model': 'a', 'tag_model': 'b'});
    final bezKlucza = SettingsRepository(
      await SharedPreferences.getInstance(),
      FakeKeyStore()..value = '',
    );
    expect(await bezKlucza.load(), isNull,
        reason: 'pusty klucz API to brak klucza, nie klucz o zerowej dlugosci');
  });
}
