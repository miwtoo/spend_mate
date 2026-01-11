import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:spend_mate/config/ai_provider.dart';
import 'package:spend_mate/config/ai_provider_config.dart';
import 'package:spend_mate/data/services/ai/ai_chat_client.dart';
import 'package:spend_mate/data/services/ai/gemini_chat_client.dart';
import 'package:spend_mate/data/services/ai/openai_compatible_chat_client.dart';

void main() {
  test('AiChatClientFactory returns provider-specific clients', () {
    const openAiConfig = AiProviderConfig(
      provider: AiProvider.openAiCompatible,
      baseUrl: 'https://example.com',
      apiKey: 'key',
      model: 'model',
      visionModel: 'model',
    );
    const geminiConfig = AiProviderConfig(
      provider: AiProvider.gemini,
      baseUrl: 'https://example.com',
      apiKey: 'key',
      model: 'model',
      visionModel: 'model',
    );
    final httpClient =
        MockClient((request) async => throw StateError('unused'));

    final openAi = AiChatClientFactory.fromConfig(
      config: openAiConfig,
      httpClient: httpClient,
    );
    final gemini = AiChatClientFactory.fromConfig(
      config: geminiConfig,
      httpClient: httpClient,
    );

    expect(openAi, isA<OpenAiCompatibleChatClient>());
    expect(gemini, isA<GeminiChatClient>());
  });
}
