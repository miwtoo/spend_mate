import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:spend_mate/config/ai_provider.dart';
import 'package:spend_mate/config/ai_provider_config.dart';
import 'package:spend_mate/data/repositories/ai_provider_config_repository.dart';
import 'package:spend_mate/data/services/ai/ai_chat_client.dart';
import 'package:spend_mate/ui/features/ai_chat/models/chat_attachment.dart';
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
  final List<ChatAttachment> _pendingAttachments = [];
  bool _isSending = false;
  String? _error;

  static const int maxAttachmentBytes = 8 * 1024 * 1024;
  static const int maxTotalAttachmentBytes = 20 * 1024 * 1024;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  List<ChatAttachment> get pendingAttachments =>
      List.unmodifiable(_pendingAttachments);
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

  void setError(String message) {
    _error = message;
    notifyListeners();
  }

  void addPendingAttachment(ChatAttachment attachment) {
    _error = null;
    final size = attachment.sizeBytes;
    if (size > maxAttachmentBytes) {
      _error =
          'Attachment "${attachment.name}" is too large (${attachment.sizeLabel}). '
          'Max per file is ${(maxAttachmentBytes / (1024 * 1024)).toStringAsFixed(0)} MB.';
      notifyListeners();
      return;
    }

    final total = _pendingAttachments.fold<int>(
          0,
          (sum, item) => sum + item.sizeBytes,
        ) +
        size;
    if (total > maxTotalAttachmentBytes) {
      _error =
          'Total attachments exceed ${(maxTotalAttachmentBytes / (1024 * 1024)).toStringAsFixed(0)} MB.';
      notifyListeners();
      return;
    }

    _pendingAttachments.add(attachment);
    notifyListeners();
  }

  void removePendingAttachment(String id) {
    _pendingAttachments.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  void clearPendingAttachments() {
    _pendingAttachments.clear();
    notifyListeners();
  }

  Future<void> sendUserMessage({required String text}) async {
    final trimmed = text.trim();
    final attachments = List<ChatAttachment>.from(_pendingAttachments);
    if (trimmed.isEmpty && attachments.isEmpty) return;

    _error = null;
    _pendingAttachments.clear();
    _messages.add(
      ChatMessage(
        role: ChatRole.user,
        text: trimmed,
        attachments: attachments,
      ),
    );
    _isSending = true;
    notifyListeners();

    try {
      final config = _config ?? await _configRepository.load();
      final validationError = config.validateForChat();
      if (validationError != null) {
        throw Exception(validationError);
      }
      if (config.provider != AiProvider.gemini &&
          attachments.any((attachment) => !attachment.isImage)) {
        throw Exception(
          'File attachments are only supported with Gemini right now. '
          'Remove files or switch to Gemini in Settings.',
        );
      }

      final client = AiChatClientFactory.fromConfig(
        config: config,
        httpClient: _httpClient,
      );
      final model = attachments.isNotEmpty &&
              config.visionModel.trim().isNotEmpty
          ? config.visionModel
          : config.model;

      final reply = await client.sendChat(
        messages: _messages,
        model: model,
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
