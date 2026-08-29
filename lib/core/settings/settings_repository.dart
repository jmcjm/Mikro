import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/provider_config.dart';

abstract class KeyStore {
  Future<String?> read();
  Future<void> write(String value);
}

class SecureKeyStore implements KeyStore {
  static const _storage = FlutterSecureStorage();
  static const _key = 'api_key';

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String value) => _storage.write(key: _key, value: value);
}

class SettingsRepository {
  SettingsRepository(this._prefs, this._keyStore);

  final SharedPreferences _prefs;
  final KeyStore _keyStore;

  static const _baseUrlKey = 'base_url';
  static const _sttModelKey = 'stt_model';
  static const _tagModelKey = 'tag_model';

  Future<ProviderConfig?> load() async {
    final baseUrl = _prefs.getString(_baseUrlKey);
    final apiKey = await _keyStore.read();
    if (baseUrl == null || baseUrl.isEmpty || apiKey == null || apiKey.isEmpty) return null;
    return ProviderConfig(
      baseUrl: baseUrl,
      apiKey: apiKey,
      sttModel: _prefs.getString(_sttModelKey) ?? '',
      tagModel: _prefs.getString(_tagModelKey) ?? '',
    );
  }

  Future<void> save(ProviderConfig config) async {
    await _prefs.setString(_baseUrlKey, config.baseUrl);
    await _prefs.setString(_sttModelKey, config.sttModel);
    await _prefs.setString(_tagModelKey, config.tagModel);
    await _keyStore.write(config.apiKey);
  }
}
