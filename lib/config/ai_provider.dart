enum AiProvider {
  openAiCompatible,
  gemini,
}

extension AiProviderX on AiProvider {
  String get label {
    return switch (this) {
      AiProvider.openAiCompatible => 'OpenAI-compatible',
      AiProvider.gemini => 'Google Gemini',
    };
  }

  static AiProvider fromStoredValue(String? value) {
    return switch (value) {
      'gemini' => AiProvider.gemini,
      _ => AiProvider.openAiCompatible,
    };
  }

  String get storedValue {
    return switch (this) {
      AiProvider.openAiCompatible => 'openai_compatible',
      AiProvider.gemini => 'gemini',
    };
  }
}


