import 'package:spend_mate/config/ai_provider.dart';
import 'package:spend_mate/config/ai_provider_config.dart';
import 'package:spend_mate/data/services/ai/gemini_chat_client.dart';
import 'package:spend_mate/data/services/ai/openai_compatible_chat_client.dart';
import 'package:spend_mate/ui/features/ai_chat/models/chat_message.dart';
import 'package:http/http.dart' as http;

abstract interface class AiChatClient {
  Future<String> sendChat({
    required List<ChatMessage> messages,
    required String model,
  });
}

class AiChatClientFactory {
  static AiChatClient fromConfig({
    required AiProviderConfig config,
    required http.Client httpClient,
  }) {
    return switch (config.provider) {
      AiProvider.openAiCompatible => OpenAiCompatibleChatClient(
          baseUrl: config.baseUrl,
          apiKey: config.apiKey,
          httpClient: httpClient,
        ),
      AiProvider.gemini => GeminiChatClient(
          baseUrl: config.baseUrl,
          apiKey: config.apiKey,
          httpClient: httpClient,
        ),
    };
  }
}
