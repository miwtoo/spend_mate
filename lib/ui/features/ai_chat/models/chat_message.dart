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
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final ChatRole role;
  final String text;
  final DateTime createdAt;
}


