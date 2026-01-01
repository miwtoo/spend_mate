import 'package:flutter/material.dart';
import 'package:spend_mate/data/repositories/ai_provider_config_repository.dart';
import 'package:spend_mate/ui/features/ai_chat/ai_chat_screen.dart';
import 'package:spend_mate/ui/features/settings/ai_provider_settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.configRepository,
  });

  final AiProviderConfigRepository configRepository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Spend Mate')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('AI Chat'),
              subtitle: const Text('Talk to your finance concierge'),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AiChatScreen(
                      configRepository: configRepository,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('AI Provider'),
              subtitle: const Text('Base URL, API key, model'),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AiProviderSettingsScreen(
                      configRepository: configRepository,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}


