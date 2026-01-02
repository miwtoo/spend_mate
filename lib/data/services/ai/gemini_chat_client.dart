import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:spend_mate/data/services/ai/ai_chat_client.dart';
import 'package:spend_mate/ui/features/ai_chat/models/chat_message.dart';

class GeminiChatClient implements AiChatClient {
  GeminiChatClient({
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
    final endpoint = _resolve('/v1beta/models/$model:generateContent')
        .replace(queryParameters: {
      'key': apiKey,
    });

    final body = <String, dynamic>{
      'contents': messages.map(_toGeminiContent).toList(growable: false),
    };

    late final http.Response response;
    try {
      response = await _httpClient
          .post(
            endpoint,
            headers: const {
              'content-type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 45));
    } on SocketException catch (e) {
      throw Exception(
        'Network error calling ${endpoint.toString()}: ${e.message}. '
        'Check your internet connection/DNS and verify the Base URL. '
        'On Android release builds, ensure android.permission.INTERNET is declared.',
      );
    } on http.ClientException catch (e) {
      throw Exception(
        'Network error calling ${endpoint.toString()}: ${e.message}. '
        'Check your internet connection/DNS and verify the Base URL.',
      );
    } on TimeoutException {
      throw Exception(
        'Request timed out calling ${endpoint.toString()}. '
        'Check your connection and try again.',
      );
    }

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Invalid JSON from Gemini (${response.statusCode}).');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = json['error'];
      final message = (error is Map<String, dynamic>)
          ? (error['message']?.toString() ?? 'Unknown error')
          : 'HTTP ${response.statusCode}';
      throw Exception('Gemini error: $message');
    }

    final candidates = json['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw Exception('Gemini returned no candidates.');
    }

    final first = candidates.first;
    if (first is! Map<String, dynamic>) {
      throw Exception('Gemini returned invalid candidates format.');
    }

    final content = first['content'];
    if (content is! Map<String, dynamic>) {
      throw Exception('Gemini returned invalid content format.');
    }

    final parts = content['parts'];
    if (parts is! List || parts.isEmpty) {
      throw Exception('Gemini returned empty parts.');
    }

    final texts = <String>[];
    for (final part in parts) {
      if (part is Map<String, dynamic> && part['text'] != null) {
        texts.add(part['text'].toString());
      }
    }

    final joined = texts.join('\n').trim();
    if (joined.isEmpty) {
      throw Exception('Gemini returned empty text.');
    }

    return joined;
  }

  Uri _resolve(String path) {
    final base = Uri.parse(baseUrl.trim());
    return base.resolve(path);
  }

  Map<String, dynamic> _toGeminiContent(ChatMessage message) {
    final parts = <Map<String, dynamic>>[];
    final text = message.text.trim();
    if (text.isNotEmpty) {
      parts.add({'text': text});
    }
    for (final attachment in message.attachments) {
      parts.add({
        'inline_data': {
          'mime_type': attachment.mimeType,
          'data': attachment.toBase64(),
        },
      });
    }

    if (parts.isEmpty) {
      parts.add({'text': ''});
    }

    return <String, dynamic>{
      'role': message.role.geminiRole,
      'parts': parts,
    };
  }
}
