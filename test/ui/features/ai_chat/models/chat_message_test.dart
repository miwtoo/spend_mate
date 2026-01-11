import 'package:flutter_test/flutter_test.dart';
import 'package:spend_mate/ui/features/ai_chat/models/chat_message.dart';

void main() {
  test('ChatRole maps to OpenAI and Gemini roles', () {
    expect(ChatRole.system.openAiRole, 'system');
    expect(ChatRole.user.openAiRole, 'user');
    expect(ChatRole.assistant.openAiRole, 'assistant');

    expect(ChatRole.system.geminiRole, 'user');
    expect(ChatRole.user.geminiRole, 'user');
    expect(ChatRole.assistant.geminiRole, 'model');
  });
}
