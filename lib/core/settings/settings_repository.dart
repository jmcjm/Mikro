import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/provider_config.dart';

/// Secret storage for API keys, one entry per name.
abstract class KeyStore {
  Future<String?> read(String name);
  Future<void> write(String name, String value);
}

class SecureKeyStore implements KeyStore {
  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String name) => _storage.read(key: name);

  @override
  Future<void> write(String name, String value) => _storage.write(key: name, value: value);
}

/// Per-task API settings.
///
/// Storage format. Until per-task settings existed there was one provider: `base_url` and the
/// `api_key` secret shared by everything, plus `stt_model` and `tag_model`. Those keys are
/// kept and still read:
/// - `stt_model` and `tag_model` simply stay the model keys of their tasks;
/// - every per-task address and key falls back to the shared `base_url` / `api_key` while the
///   task has none of its own (the key is ABSENT — an empty string written by a save counts
///   as a value), and the notes model falls back to `tag_model`, which notes used before.
/// So an existing installation keeps working with no migration step, and the first save
/// writes explicit per-task values.
class SettingsRepository {
  SettingsRepository(this._prefs, this._keyStore);

  final SharedPreferences _prefs;
  final KeyStore _keyStore;

  static const legacyBaseUrlKey = 'base_url';
  static const legacyApiKeyName = 'api_key';

  static String baseUrlKey(ApiTask task) => '${task.name}_base_url';

  static String modelKey(ApiTask task) => switch (task) {
    ApiTask.stt => 'stt_model',
    ApiTask.tags => 'tag_model',
    ApiTask.notes => 'notes_model',
  };

  static String apiKeyName(ApiTask task) => 'api_key_${task.name}';

  /// Settings as stored, including incomplete ones — this is what the settings screen edits.
  Future<ServiceConfig> raw(ApiTask task) async {
    final baseUrl = _prefs.getString(baseUrlKey(task)) ?? _prefs.getString(legacyBaseUrlKey) ?? '';
    final model =
        _prefs.getString(modelKey(task)) ??
        (task == ApiTask.notes ? _prefs.getString(modelKey(ApiTask.tags)) : null) ??
        '';
    final apiKey =
        await _keyStore.read(apiKeyName(task)) ?? await _keyStore.read(legacyApiKeyName) ?? '';
    return ServiceConfig(baseUrl: baseUrl, apiKey: apiKey, model: model);
  }

  /// Usable settings for [task], or `null` when address or key is missing.
  ///
  /// An empty key for titles/tags or notes borrows the transcription key, but ONLY when both
  /// point at the same address: the user then types a key once per provider, and a key is
  /// never sent to a server it was not issued for.
  Future<ServiceConfig?> load(ApiTask task) async {
    final config = await raw(task);
    if (config.baseUrl.isEmpty) return null;
    var apiKey = config.apiKey;
    if (apiKey.isEmpty && task != ApiTask.stt) {
      final stt = await raw(ApiTask.stt);
      if (stt.baseUrl == config.baseUrl) apiKey = stt.apiKey;
    }
    if (apiKey.isEmpty) return null;
    return ServiceConfig(baseUrl: config.baseUrl, apiKey: apiKey, model: config.model);
  }

  Future<void> save(ApiTask task, ServiceConfig config) async {
    await _prefs.setString(baseUrlKey(task), config.baseUrl);
    await _prefs.setString(modelKey(task), config.model);
    await _keyStore.write(apiKeyName(task), config.apiKey);
  }
}
