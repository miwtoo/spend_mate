import 'package:flutter/material.dart';
import 'package:spend_mate/data/repositories/ai_provider_config_repository.dart';
import 'package:spend_mate/data/repositories/firefly_config_repository.dart';
import 'package:spend_mate/ui/features/auto_import/auto_import_screen.dart';
import 'package:spend_mate/ui/features/settings/ai_provider_settings_screen.dart';
import 'package:spend_mate/ui/features/settings/firefly_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.configRepository,
    required this.fireflyConfigRepository,
  });

  final AiProviderConfigRepository configRepository;
  final FireflyConfigRepository fireflyConfigRepository;

  Future<void> _openAiProviderSettings(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AiProviderSettingsScreen(
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

  Future<void> _openFireflySettings(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FireflySettingsScreen(
          configRepository: fireflyConfigRepository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.auto_awesome_motion_outlined),
            title: const Text('Auto Import'),
            subtitle: const Text('Configure folder watch and drafts queue'),
            onTap: () => _openAutoImport(context),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: ListTile(
            leading: const Icon(Icons.cloud_outlined),
            title: const Text('Firefly III'),
            subtitle: const Text('Base URL, access token, default accounts'),
            onTap: () => _openFireflySettings(context),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('AI Provider'),
            subtitle: const Text('Base URL, API key, model'),
            onTap: () => _openAiProviderSettings(context),
          ),
        ),
      ],
    );
  }
}
