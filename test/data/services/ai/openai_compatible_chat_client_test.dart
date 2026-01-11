import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spend_mate/data/services/ai/openai_compatible_chat_client.dart';
import 'package:spend_mate/ui/features/ai_chat/models/chat_attachment.dart';
import 'package:spend_mate/ui/features/ai_chat/models/chat_message.dart';

void main() {
  test('calls OpenAI-compatible /v1/chat/completions and parses reply',
      () async {
    late http.Request captured;

    final mock = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {'content': 'Hello!'},
            }
          ]
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final client = OpenAiCompatibleChatClient(
      baseUrl: 'https://example.com/',
      apiKey: 'key123',
      httpClient: mock,
    );

    final reply = await client.sendChat(
      model: 'my-model',
      messages: [
        ChatMessage(role: ChatRole.user, text: 'Hi'),
      ],
    );

    expect(reply, 'Hello!');
    expect(captured.method, 'POST');
    expect(captured.url.toString(), 'https://example.com/v1/chat/completions');
    expect(captured.headers['authorization'], 'Bearer key123');

    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['model'], 'my-model');
    expect(body['messages'], isA<List>());
  });

  test('when baseUrl already ends with /v1, calls /v1/chat/completions',
      () async {
    late http.Request captured;

    final mock = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {'content': 'OK'},
            }
          ]
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final client = OpenAiCompatibleChatClient(
      baseUrl: 'https://example.com/api/v1',
      apiKey: 'key123',
      httpClient: mock,
    );

    final reply = await client.sendChat(
      model: 'my-model',
      messages: [
        ChatMessage(role: ChatRole.user, text: 'Hi'),
      ],
    );

    expect(reply, 'OK');
    expect(
        captured.url.toString(), 'https://example.com/api/v1/chat/completions');
  });

  test('supports Z.ai-style baseUrl ending with /v4 (appends chat/completions)',
      () async {
    late http.Request captured;

    final mock = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {'content': 'ZAI'},
            }
          ]
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final client = OpenAiCompatibleChatClient(
      baseUrl: 'https://api.z.ai/api/coding/paas/v4',
      apiKey: 'key123',
      httpClient: mock,
    );

    final reply = await client.sendChat(
      model: 'glm-4.7',
      messages: [
        ChatMessage(role: ChatRole.user, text: 'Hi'),
      ],
    );

    expect(reply, 'ZAI');
    expect(
      captured.url.toString(),
      'https://api.z.ai/api/coding/paas/v4/chat/completions',
    );
  });

  test('non-JSON error body surfaces helpful exception (includes URL + status)',
      () async {
    final mock = MockClient((request) async {
      return http.Response('<html>not found</html>', 404);
    });

    final client = OpenAiCompatibleChatClient(
      baseUrl: 'https://api.z.ai/api/coding/paas/v4',
      apiKey: 'key123',
      httpClient: mock,
    );

    await expectLater(
      () => client.sendChat(
        model: 'glm-4.7',
        messages: [
          ChatMessage(role: ChatRole.user, text: 'Hi'),
        ],
      ),
      throwsA(
        predicate(
          (e) =>
              e is Exception &&
              e.toString().contains('HTTP 404') &&
              e.toString().contains('api.z.ai') &&
              e.toString().contains('/chat/completions'),
        ),
      ),
    );
  });

  test('sends attachments as multipart content for OpenAI-compatible APIs',
      () async {
    late http.Request captured;

    final mock = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {'content': 'OK'},
            }
          ]
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final client = OpenAiCompatibleChatClient(
      baseUrl: 'https://example.com',
      apiKey: 'key123',
      httpClient: mock,
    );

    final reply = await client.sendChat(
      model: 'my-model',
      messages: [
        ChatMessage(
          role: ChatRole.user,
          text: 'Hello',
          attachments: [
            ChatAttachment(
              type: ChatAttachmentType.image,
              name: 'photo.png',
              mimeType: 'image/png',
              bytes: Uint8List.fromList([1, 2, 3]),
            ),
            ChatAttachment(
              type: ChatAttachmentType.file,
              name: 'doc.txt',
              mimeType: 'text/plain',
              bytes: Uint8List.fromList([4, 5]),
            ),
          ],
        ),
      ],
    );

    expect(reply, 'OK');
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    final messages = body['messages'] as List<dynamic>;
    final content = (messages.first as Map<String, dynamic>)['content'];
    expect(content, isA<List>());
    final parts = content as List<dynamic>;
    expect(parts.length, 3);
    expect(parts.first['type'], 'text');
    expect(parts[1]['type'], 'image_url');
    expect(parts[2]['type'], 'text');
    expect(parts[2]['text'], contains('Attached file: doc.txt'));
  });

  test('invalid JSON responses throw a helpful error', () async {
    final mock = MockClient((request) async {
      return http.Response('not-json', 200);
    });

    final client = OpenAiCompatibleChatClient(
      baseUrl: 'https://example.com',
      apiKey: 'key123',
      httpClient: mock,
    );

    await expectLater(
      () => client.sendChat(
        model: 'my-model',
        messages: [
          ChatMessage(role: ChatRole.user, text: 'Hi'),
        ],
      ),
      throwsA(
        predicate(
          (e) =>
              e is Exception &&
              e.toString().contains('Invalid JSON') &&
              e.toString().contains('example.com'),
        ),
      ),
    );
  });
}
