import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spend_mate/data/services/ai/gemini_chat_client.dart';
import 'package:spend_mate/ui/features/ai_chat/models/chat_attachment.dart';
import 'package:spend_mate/ui/features/ai_chat/models/chat_message.dart';

void main() {
  test('calls Gemini generateContent and parses reply', () async {
    late http.Request captured;

    final mock = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': 'Gemini says hi'},
                ]
              }
            }
          ]
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final client = GeminiChatClient(
      baseUrl: 'https://generativelanguage.googleapis.com',
      apiKey: 'abc',
      httpClient: mock,
    );

    final reply = await client.sendChat(
      model: 'gemini-1.5-flash',
      messages: [
        ChatMessage(role: ChatRole.user, text: 'Hi'),
      ],
    );

    expect(reply, 'Gemini says hi');
    expect(captured.url.toString(), contains('key=abc'));

    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['contents'], isA<List>());
  });

  test('serializes attachments into Gemini inline_data parts', () async {
    late http.Request captured;
    final mock = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': 'ok'},
                ]
              }
            }
          ]
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final client = GeminiChatClient(
      baseUrl: 'https://generativelanguage.googleapis.com',
      apiKey: 'abc',
      httpClient: mock,
    );

    await client.sendChat(
      model: 'gemini-1.5-flash',
      messages: [
        ChatMessage(
          role: ChatRole.user,
          text: '',
          attachments: [
            ChatAttachment(
              type: ChatAttachmentType.image,
              name: 'photo.png',
              mimeType: 'image/png',
              bytes: Uint8List.fromList([1, 2, 3]),
            ),
          ],
        ),
      ],
    );

    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    final contents = body['contents'] as List<dynamic>;
    final parts =
        (contents.first as Map<String, dynamic>)['parts'] as List<dynamic>;
    expect(parts.first['inline_data']['mime_type'], 'image/png');
  });

  test('surfaces Gemini error payloads', () async {
    final mock = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'error': {'message': 'bad request'}
        }),
        400,
        headers: {'content-type': 'application/json'},
      );
    });

    final client = GeminiChatClient(
      baseUrl: 'https://generativelanguage.googleapis.com',
      apiKey: 'abc',
      httpClient: mock,
    );

    await expectLater(
      () => client.sendChat(
        model: 'gemini-1.5-flash',
        messages: [
          ChatMessage(role: ChatRole.user, text: 'Hi'),
        ],
      ),
      throwsA(
        predicate(
          (e) =>
              e is Exception &&
              e.toString().contains('Gemini error') &&
              e.toString().contains('bad request'),
        ),
      ),
    );
  });
}
