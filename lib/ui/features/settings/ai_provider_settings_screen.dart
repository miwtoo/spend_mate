import 'package:flutter/material.dart';
import 'package:spend_mate/config/ai_provider.dart';
import 'package:spend_mate/config/ai_provider_config.dart';
import 'package:spend_mate/data/repositories/ai_provider_config_repository.dart';

class AiProviderSettingsScreen extends StatefulWidget {
  const AiProviderSettingsScreen({
    super.key,
    required this.configRepository,
  });

  final AiProviderConfigRepository configRepository;

  @override
  State<AiProviderSettingsScreen> createState() =>
      _AiProviderSettingsScreenState();
}

class _AiProviderSettingsScreenState extends State<AiProviderSettingsScreen> {
  final _baseUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _modelController = TextEditingController();
  final _visionModelController = TextEditingController();
  AiProvider _provider = AiProvider.openAiCompatible;
  bool _obscureApiKey = true;
  bool _saving = false;
  late final Future<void> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = _load();
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    _visionModelController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final config = await widget.configRepository.load();
    _provider = config.provider;
    _baseUrlController.text = config.baseUrl;
    _apiKeyController.text = config.apiKey;
    _modelController.text = config.model;
    _visionModelController.text = config.visionModel;
  }

  AiProviderConfig _buildConfig() {
    return AiProviderConfig(
      provider: _provider,
      baseUrl: _baseUrlController.text.trim(),
      apiKey: _apiKeyController.text.trim(),
      model: _modelController.text.trim(),
      visionModel: _visionModelController.text.trim(),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.configRepository.save(_buildConfig());
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _applyProviderDefaults(AiProvider provider) {
    if (provider == AiProvider.gemini) {
      if (_baseUrlController.text.trim().isEmpty) {
        _baseUrlController.text = 'https://generativelanguage.googleapis.com';
      }
      if (_modelController.text.trim().isEmpty) {
        _modelController.text = 'gemini-1.5-flash';
      }
      if (_visionModelController.text.trim().isEmpty) {
        _visionModelController.text = 'gemini-1.5-flash';
      }
      return;
    }

    // OpenAI-compatible
    if (_baseUrlController.text.trim().isEmpty) {
      _baseUrlController.text = 'https://api.openai.com';
    }
    if (_modelController.text.trim().isEmpty) {
      _modelController.text = 'gpt-4o-mini';
    }
    if (_visionModelController.text.trim().isEmpty) {
      _visionModelController.text = 'gpt-4o-mini';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('AI Provider'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<AiProvider>(
                key: ValueKey(_provider),
                initialValue: _provider,
                decoration: const InputDecoration(
                  labelText: 'Provider',
                  border: OutlineInputBorder(),
                ),
                items: AiProvider.values
                    .map(
                      (p) => DropdownMenuItem(
                        value: p,
                        child: Text(p.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: _saving
                    ? null
                    : (p) {
                        if (p == null) return;
                        setState(() => _provider = p);
                        _applyProviderDefaults(p);
                      },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _baseUrlController,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Base URL',
                  hintText: 'e.g. https://api.openai.com',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _modelController,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Model',
                  hintText: 'e.g. gpt-4o-mini / llama3 / gemini-1.5-flash',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _visionModelController,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Vision model (for attachments)',
                  hintText: 'e.g. glm-4.6v / gpt-4o-mini / gemini-1.5-flash',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _apiKeyController,
                enabled: !_saving,
                obscureText: _obscureApiKey,
                decoration: InputDecoration(
                  labelText: 'API Key',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: _obscureApiKey ? 'Show' : 'Hide',
                    onPressed: _saving
                        ? null
                        : () => setState(() => _obscureApiKey = !_obscureApiKey),
                    icon: Icon(
                      _obscureApiKey ? Icons.visibility : Icons.visibility_off,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_saving ? 'Saving…' : 'Save'),
              ),
              const SizedBox(height: 8),
              Text(
                'Note: API keys are stored locally on-device (not encrypted).',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }
}

