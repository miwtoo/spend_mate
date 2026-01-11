import 'package:flutter_test/flutter_test.dart';
import 'package:spend_mate/config/ai_provider.dart';
import 'package:spend_mate/config/ai_provider_config.dart';

void main() {
  group('AiProvider', () {
    test('labels and stored values match provider', () {
      expect(AiProvider.openAiCompatible.label, 'OpenAI-compatible');
      expect(AiProvider.gemini.label, 'Google Gemini');
      expect(AiProvider.openAiCompatible.storedValue, 'openai_compatible');
      expect(AiProvider.gemini.storedValue, 'gemini');
      expect(AiProviderX.fromStoredValue('gemini'), AiProvider.gemini);
      expect(
          AiProviderX.fromStoredValue('unknown'), AiProvider.openAiCompatible);
    });
  });

  group('AiProviderConfig', () {
    test('defaults are valid for OpenAI-compatible config', () {
      final config = AiProviderConfig.defaults();
      expect(config.provider, AiProvider.openAiCompatible);
      expect(config.baseUrl, 'https://api.openai.com');
      expect(config.model, isNotEmpty);
    });

    test('validates baseUrl and credentials', () {
      const emptyBaseUrl = AiProviderConfig(
        provider: AiProvider.openAiCompatible,
        baseUrl: '',
        apiKey: '',
        model: '',
        visionModel: '',
      );
      expect(emptyBaseUrl.validateForChat(), 'AI Base URL is required.');

      const invalidBaseUrl = AiProviderConfig(
        provider: AiProvider.openAiCompatible,
        baseUrl: 'not-a-url',
        apiKey: 'key',
        model: 'model',
        visionModel: 'model',
      );
      expect(
        invalidBaseUrl.validateForChat(),
        contains('must be a valid URL'),
      );

      const invalidScheme = AiProviderConfig(
        provider: AiProvider.openAiCompatible,
        baseUrl: 'ftp://example.com',
        apiKey: 'key',
        model: 'model',
        visionModel: 'model',
      );
      expect(
        invalidScheme.validateForChat(),
        'AI Base URL must start with http:// or https://.',
      );

      const missingKey = AiProviderConfig(
        provider: AiProvider.openAiCompatible,
        baseUrl: 'https://example.com',
        apiKey: '',
        model: 'model',
        visionModel: 'model',
      );
      expect(
        missingKey.validateForChat(),
        'AI API key is required for OpenAI-compatible providers.',
      );

      const missingModel = AiProviderConfig(
        provider: AiProvider.openAiCompatible,
        baseUrl: 'https://example.com',
        apiKey: 'key',
        model: '',
        visionModel: 'model',
      );
      expect(missingModel.validateForChat(), 'Model is required.');

      const geminiMissingKey = AiProviderConfig(
        provider: AiProvider.gemini,
        baseUrl: 'https://example.com',
        apiKey: '',
        model: 'gemini-1.5-flash',
        visionModel: 'gemini-1.5-flash',
      );
      expect(geminiMissingKey.validateForChat(), 'Gemini API key is required.');

      const geminiMissingModel = AiProviderConfig(
        provider: AiProvider.gemini,
        baseUrl: 'https://example.com',
        apiKey: 'key',
        model: '',
        visionModel: '',
      );
      expect(
        geminiMissingModel.validateForChat(),
        contains('Gemini model is required'),
      );

      const valid = AiProviderConfig(
        provider: AiProvider.gemini,
        baseUrl: 'https://example.com',
        apiKey: 'key',
        model: 'gemini-1.5-flash',
        visionModel: 'gemini-1.5-flash',
      );
      expect(valid.validateForChat(), isNull);

      const openAiValid = AiProviderConfig(
        provider: AiProvider.openAiCompatible,
        baseUrl: 'https://example.com',
        apiKey: 'key',
        model: 'gpt-4o-mini',
        visionModel: 'gpt-4o-mini',
      );
      expect(openAiValid.validateForChat(), isNull);
    });

    test('copyWith overrides selected fields', () {
      const config = AiProviderConfig(
        provider: AiProvider.openAiCompatible,
        baseUrl: 'https://example.com',
        apiKey: 'key',
        model: 'model',
        visionModel: 'vision',
      );

      final updated = config.copyWith(
        baseUrl: 'https://api.example.com',
        model: 'new-model',
      );

      expect(updated.baseUrl, 'https://api.example.com');
      expect(updated.model, 'new-model');
      expect(updated.apiKey, 'key');
      expect(updated.provider, AiProvider.openAiCompatible);
    });
  });
}
