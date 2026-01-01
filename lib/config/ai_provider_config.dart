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

  String? validateForChat() {
    if (baseUrl.trim().isEmpty) {
      return 'AI Base URL is required.';
    }

    final parsed = Uri.tryParse(baseUrl.trim());
    if (parsed == null || !parsed.hasScheme || parsed.host.trim().isEmpty) {
      return 'AI Base URL must be a valid URL (e.g. https://api.openai.com).';
    }
    if (parsed.scheme != 'http' && parsed.scheme != 'https') {
      return 'AI Base URL must start with http:// or https://.';
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
