import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spend_mate/data/services/ai/gemini_chat_client.dart';
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
}


