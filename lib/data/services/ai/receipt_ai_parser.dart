import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:spend_mate/data/repositories/ai_provider_config_repository.dart';
import 'package:spend_mate/data/services/ai/ai_chat_client.dart';
import 'package:spend_mate/domain/models/receipt_parse_result.dart';
import 'package:spend_mate/ui/features/ai_chat/models/chat_attachment.dart';
import 'package:spend_mate/ui/features/ai_chat/models/chat_message.dart';

class ReceiptAiParser {
  ReceiptAiParser({
    required AiProviderConfigRepository configRepository,
    http.Client? httpClient,
  })  : _configRepository = configRepository,
        _sharedClient = httpClient;

  final AiProviderConfigRepository _configRepository;
  final http.Client? _sharedClient;

  Future<ReceiptParseResult> parseReceipt({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  }) async {
    final httpClient = _sharedClient ?? http.Client();
    final config = await _configRepository.load();
    final validationError = config.validateForChat();
    if (validationError != null) {
      throw Exception(validationError);
    }

    final attachment = ChatAttachment(
      type: ChatAttachmentType.image,
      name: fileName,
      mimeType: mimeType ?? _guessMimeType(fileName),
      bytes: bytes,
    );

    final client = AiChatClientFactory.fromConfig(
      config: config,
      httpClient: httpClient,
    );

    final model = config.visionModel.trim().isNotEmpty
        ? config.visionModel
        : config.model;

    final messages = <ChatMessage>[
      ChatMessage(
        role: ChatRole.system,
        text: _systemPrompt,
      ),
      ChatMessage(
        role: ChatRole.user,
        text: _userPrompt,
        attachments: [attachment],
      ),
    ];

    try {
      final response = await client.sendChat(messages: messages, model: model);
      return ReceiptParseResult.fromAiResponse(response);
    } finally {
      if (_sharedClient == null) {
        httpClient.close();
      }
    }
  }

  void dispose() {
    _sharedClient?.close();
  }
}

const _systemPrompt =
    'You are a receipt and transaction parser. Return ONLY valid JSON. '
    'Do not include markdown or explanations.';

const _userPrompt =
    'Extract receipt fields as JSON with keys: '
    'amount (number), currency (3-letter code or symbol), '
    'date (YYYY-MM-DD), time (HH:mm or h:mm a, optional), '
    'date_time (ISO 8601 date-time, optional), '
    'merchant (string), note (string), type (expense|income|transfer|unknown), '
    'confidence (0-1). Use null when unknown.';

String _guessMimeType(String name) {
  final dotIndex = name.lastIndexOf('.');
  if (dotIndex == -1 || dotIndex == name.length - 1) {
    return 'application/octet-stream';
  }
  final ext = name.substring(dotIndex + 1).toLowerCase();
  return switch (ext) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    'heic' => 'image/heic',
    'heif' => 'image/heif',
    _ => 'application/octet-stream',
  };
}
