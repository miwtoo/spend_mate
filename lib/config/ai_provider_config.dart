import 'package:spend_mate/config/ai_provider.dart';

class AiProviderConfig {
  const AiProviderConfig({
    required this.provider,
    required this.baseUrl,
    required this.apiKey,
    required this.model,
  });

  final AiProvider provider;
  final String baseUrl;
  final String apiKey;
  final String model;

  factory AiProviderConfig.defaults() {
    return const AiProviderConfig(
      provider: AiProvider.openAiCompatible,
      baseUrl: 'https://api.openai.com',
      apiKey: '',
      model: 'gpt-4o-mini',
    );
  }

  AiProviderConfig copyWith({
    AiProvider? provider,
    String? baseUrl,
    String? apiKey,
    String? model,
  }) {
    return AiProviderConfig(
      provider: provider ?? this.provider,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
    );
  }

  /// Returns a user-friendly error string if configuration is incomplete.
  String? validateForChat() {
    if (baseUrl.trim().isEmpty) {
      return 'AI Base URL is required.';
    }

    if (provider == AiProvider.openAiCompatible) {
      if (apiKey.trim().isEmpty) {
        return 'AI API key is required for OpenAI-compatible providers.';
      }
      if (model.trim().isEmpty) {
        return 'Model is required.';
      }
    }

    if (provider == AiProvider.gemini) {
      if (apiKey.trim().isEmpty) {
        return 'Gemini API key is required.';
      }
      if (model.trim().isEmpty) {
        return 'Gemini model is required (e.g. gemini-1.5-flash).';
      }
    }

    return null;
  }
}


