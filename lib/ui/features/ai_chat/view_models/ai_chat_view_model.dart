import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:spend_mate/config/ai_provider_config.dart';
import 'package:spend_mate/data/repositories/ai_provider_config_repository.dart';
import 'package:spend_mate/data/services/ai/ai_chat_client.dart';
import 'package:spend_mate/ui/features/ai_chat/models/chat_message.dart';

class AiChatViewModel extends ChangeNotifier {
  AiChatViewModel({
    required AiProviderConfigRepository configRepository,
    http.Client? httpClient,
  })  : _configRepository = configRepository,
        _httpClient = httpClient ?? http.Client();

  final AiProviderConfigRepository _configRepository;
  final http.Client _httpClient;

  AiProviderConfig? _config;
  final List<ChatMessage> _messages = [];
  bool _isSending = false;
  String? _error;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isSending => _isSending;
  String? get error => _error;

  Future<void> initialize() async {
    await reloadConfig();

    if (_messages.isEmpty) {
      _messages.add(
        ChatMessage(
          role: ChatRole.system,
          text:
              'You are Spend Mate, a helpful finance assistant. Keep answers short and actionable.',
        ),
      );
    }

    notifyListeners();
  }

  Future<void> reloadConfig() async {
    _config = await _configRepository.load();
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> sendUserMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    _error = null;
    _messages.add(ChatMessage(role: ChatRole.user, text: trimmed));
    _isSending = true;
    notifyListeners();

    try {
      final config = _config ?? await _configRepository.load();
      final validationError = config.validateForChat();
      if (validationError != null) {
        throw Exception(validationError);
      }

      final client = AiChatClientFactory.fromConfig(
        config: config,
        httpClient: _httpClient,
      );

      final reply = await client.sendChat(
        messages: _messages,
        model: config.model,
      );

      _messages.add(ChatMessage(role: ChatRole.assistant, text: reply));
    } catch (e) {
      _error = e.toString();
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _httpClient.close();
    super.dispose();
  }
}


