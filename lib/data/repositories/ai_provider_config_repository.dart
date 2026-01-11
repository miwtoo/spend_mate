import 'package:shared_preferences/shared_preferences.dart';
import 'package:spend_mate/config/ai_provider.dart';
import 'package:spend_mate/config/ai_provider_config.dart';

class AiProviderConfigRepository {
  AiProviderConfigRepository._(this._prefs);

  final SharedPreferences _prefs;

  static const _kProvider = 'ai_provider';
  static const _kBaseUrl = 'ai_base_url';
  static const _kApiKey = 'ai_api_key';
  static const _kModel = 'ai_model';
  static const _kVisionModel = 'ai_vision_model';

  static Future<AiProviderConfigRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return AiProviderConfigRepository._(prefs);
  }

  Future<AiProviderConfig> load() async {
    final providerStr = _prefs.getString(_kProvider);
    final provider = AiProviderX.fromStoredValue(providerStr);

    final defaults = AiProviderConfig.defaults();
    return AiProviderConfig(
      provider: provider,
      baseUrl: _prefs.getString(_kBaseUrl) ?? _defaultBaseUrlFor(provider),
      apiKey: _prefs.getString(_kApiKey) ?? defaults.apiKey,
      model: _prefs.getString(_kModel) ?? _defaultModelFor(provider),
      visionModel:
          _prefs.getString(_kVisionModel) ?? _defaultVisionModelFor(provider),
    );
  }

  Future<void> save(AiProviderConfig config) async {
    await _prefs.setString(_kProvider, config.provider.storedValue);
    await _prefs.setString(_kBaseUrl, config.baseUrl);
    await _prefs.setString(_kApiKey, config.apiKey);
    await _prefs.setString(_kModel, config.model);
    await _prefs.setString(_kVisionModel, config.visionModel);
  }

  String _defaultModelFor(AiProvider provider) {
    return switch (provider) {
      AiProvider.openAiCompatible => 'gpt-4o-mini',
      AiProvider.gemini => 'gemini-1.5-flash',
    };
  }

  String _defaultVisionModelFor(AiProvider provider) {
    return switch (provider) {
      AiProvider.openAiCompatible => 'gpt-4o-mini',
      AiProvider.gemini => 'gemini-1.5-flash',
    };
  }

  String _defaultBaseUrlFor(AiProvider provider) {
    return switch (provider) {
      AiProvider.openAiCompatible => 'https://api.openai.com',
      AiProvider.gemini => 'https://generativelanguage.googleapis.com',
    };
  }
}
