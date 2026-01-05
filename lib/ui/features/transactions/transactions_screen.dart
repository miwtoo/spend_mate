import 'package:flutter/material.dart';
import 'package:spend_mate/data/repositories/ai_provider_config_repository.dart';
import 'package:spend_mate/data/repositories/firefly_config_repository.dart';
import 'package:spend_mate/ui/features/ai_chat/ai_chat_screen.dart';
import 'package:spend_mate/ui/features/auto_import/auto_import_screen.dart';

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({
    super.key,
    required this.configRepository,
    required this.fireflyConfigRepository,
  });

  final AiProviderConfigRepository configRepository;
  final FireflyConfigRepository fireflyConfigRepository;

  Future<void> _openAiChat(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AiChatScreen(
          configRepository: configRepository,
        ),
      ),
    );
  }

  Future<void> _openAutoImport(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AutoImportScreen(
          configRepository: configRepository,
          fireflyConfigRepository: fireflyConfigRepository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick actions',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _openAutoImport(context),
                      icon: const Icon(Icons.auto_awesome_motion_outlined),
                      label: const Text('Auto Import'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _openAiChat(context),
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('AI Chat'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'All transactions',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.receipt_long),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No transactions yet. New imports and AI chat entries will appear here once connected to Firefly III.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
