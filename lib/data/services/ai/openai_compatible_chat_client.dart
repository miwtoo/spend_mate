import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:spend_mate/data/services/ai/ai_chat_client.dart';
import 'package:spend_mate/ui/features/ai_chat/models/chat_message.dart';

class OpenAiCompatibleChatClient implements AiChatClient {
  OpenAiCompatibleChatClient({
    required this.baseUrl,
    required this.apiKey,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final String apiKey;
  final http.Client _httpClient;

  @override
  Future<String> sendChat({
    required List<ChatMessage> messages,
    required String model,
  }) async {
    final endpoint = _resolveChatCompletionsEndpoint();

    final body = <String, dynamic>{
      'model': model,
      'messages': messages.map(_toOpenAiMessage).toList(growable: false),
    };

    final response = await _httpClient
        .post(
          endpoint,
          headers: {
            'content-type': 'application/json',
            if (apiKey.trim().isNotEmpty) 'authorization': 'Bearer $apiKey',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 45));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final Map<String, dynamic>? json = _tryDecodeJsonObject(response.body);
      final message = (json?['error'] is Map<String, dynamic>)
          ? (json?['error']['message']?.toString() ?? 'Unknown error')
          : _truncateBody(response.body);
      throw Exception(
        'AI provider HTTP ${response.statusCode} calling '
        '${endpoint.toString()}: $message',
      );
    }

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception(
        'Invalid JSON from AI provider (HTTP ${response.statusCode}) calling '
        '${endpoint.toString()}: ${_truncateBody(response.body)}',
      );
    }

    final choices = json['choices'];
    if (choices is! List || choices.isEmpty) {
      throw Exception('AI provider returned no choices.');
    }

    final first = choices.first;
    if (first is! Map<String, dynamic>) {
      throw Exception('AI provider returned invalid choices format.');
    }

    final messageObj = first['message'];
    if (messageObj is! Map<String, dynamic>) {
      throw Exception('AI provider returned invalid message format.');
    }

    final content = messageObj['content']?.toString();
    if (content == null || content.trim().isEmpty) {
      throw Exception('AI provider returned empty content.');
    }

    return content.trim();
  }

  Uri _resolveChatCompletionsEndpoint() {
    final base = Uri.parse(baseUrl.trim());

    // If the user provides a full endpoint URL, use it as-is.
    final normalizedPath = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    if (normalizedPath.endsWith('/chat/completions') ||
        normalizedPath.endsWith('/v1/chat/completions')) {
      return base;
    }

    // If the base URL ends with a version segment (e.g. /v1, /v4), append
    // chat/completions. This supports providers that host OpenAI-compatible APIs
    // under non-/v1 roots (e.g. Z.ai: /api/coding/paas/v4/chat/completions).
    final segments =
        base.pathSegments.where((s) => s.trim().isNotEmpty).toList();
    final last = segments.isEmpty ? '' : segments.last;
    final looksLikeVersion =
        RegExp(r'^v\d+$', caseSensitive: false).hasMatch(last);

    final relativePath = looksLikeVersion
        ? 'chat/completions'
        : 'v1/chat/completions';

    // Uri.resolve() treats a base path without a trailing slash as a "file" and
    // will replace the last segment. We want to append, so force a directory.
    final baseAsDirectory = base.replace(
      path: base.path.isEmpty
          ? '/'
          : (base.path.endsWith('/') ? base.path : '${base.path}/'),
    );
    return baseAsDirectory.resolve(relativePath);
  }

  Map<String, dynamic> _toOpenAiMessage(ChatMessage message) {
    return <String, dynamic>{
      'role': message.role.openAiRole,
      'content': message.text,
    };
  }

  Map<String, dynamic>? _tryDecodeJsonObject(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  String _truncateBody(String body, {int maxChars = 300}) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return '(empty response body)';
    if (trimmed.length <= maxChars) return trimmed;
    return '${trimmed.substring(0, maxChars)}…';
  }
}


