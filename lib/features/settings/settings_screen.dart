import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/provider_config.dart';
import '../../core/providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _baseUrl = TextEditingController();
  final _apiKey = TextEditingController();
  final _sttModel = TextEditingController();
  final _tagModel = TextEditingController();
  ProviderPreset _preset = ProviderPreset.groq;
  var _loaded = false;

  @override
  void initState() {
    super.initState();
    ref.read(settingsRepositoryProvider).load().then((config) {
      if (!mounted) return;
      if (config != null) {
        _baseUrl.text = config.baseUrl;
        _apiKey.text = config.apiKey;
        _sttModel.text = config.sttModel;
        _tagModel.text = config.tagModel;
        _preset = ProviderPreset.values.firstWhere(
          (p) => p.baseUrl == config.baseUrl,
          orElse: () => ProviderPreset.custom,
        );
      } else {
        _applyPreset(ProviderPreset.groq);
      }
      setState(() => _loaded = true);
    });
  }

  void _applyPreset(ProviderPreset preset) {
    _preset = preset;
    if (preset != ProviderPreset.custom) {
      _baseUrl.text = preset.baseUrl;
      _sttModel.text = preset.sttModel;
      _tagModel.text = preset.tagModel;
    }
    setState(() {});
  }

  Future<void> _save() async {
    await ref.read(settingsRepositoryProvider).save(ProviderConfig(
          baseUrl: _baseUrl.text.trim(),
          apiKey: _apiKey.text.trim(),
          sttModel: _sttModel.text.trim(),
          tagModel: _tagModel.text.trim(),
        ));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Ustawienia zapisane.')));
    }
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _apiKey.dispose();
    _sttModel.dispose();
    _tagModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    return Scaffold(
      appBar: AppBar(title: const Text('Ustawienia')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<ProviderPreset>(
            initialValue: _preset,
            decoration: const InputDecoration(labelText: 'Dostawca'),
            items: const [
              DropdownMenuItem(value: ProviderPreset.groq, child: Text('Groq')),
              DropdownMenuItem(value: ProviderPreset.openai, child: Text('OpenAI')),
              DropdownMenuItem(value: ProviderPreset.custom, child: Text('Własny endpoint')),
            ],
            onChanged: (p) => _applyPreset(p!),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _baseUrl,
            decoration: const InputDecoration(labelText: 'Base URL'),
            enabled: _preset == ProviderPreset.custom,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _apiKey,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Klucz API'),
          ),
          const SizedBox(height: 12),
          TextField(
              controller: _sttModel,
              decoration: const InputDecoration(labelText: 'Model transkrypcji')),
          const SizedBox(height: 12),
          TextField(
              controller: _tagModel,
              decoration: const InputDecoration(labelText: 'Model tagów')),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Zapisz')),
        ],
      ),
    );
  }
}
