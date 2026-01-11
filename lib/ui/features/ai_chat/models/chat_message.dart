import 'package:spend_mate/ui/features/ai_chat/models/chat_attachment.dart';

enum ChatRole {
  system,
  user,
  assistant,
}

extension ChatRoleX on ChatRole {
  String get openAiRole {
    return switch (this) {
      ChatRole.system => 'system',
      ChatRole.user => 'user',
      ChatRole.assistant => 'assistant',
    };
  }

  /// Gemini uses "user" and "model". We'll map assistant -> model.
  String get geminiRole {
    return switch (this) {
      ChatRole.system => 'user',
      ChatRole.user => 'user',
      ChatRole.assistant => 'model',
    };
  }
}

class ChatMessage {
  ChatMessage({
    required this.role,
    required this.text,
    List<ChatAttachment>? attachments,
    DateTime? createdAt,
  })  : attachments = List.unmodifiable(attachments ?? const []),
        createdAt = createdAt ?? DateTime.now();

  final ChatRole role;
  final String text;
  final List<ChatAttachment> attachments;
  final DateTime createdAt;
}
