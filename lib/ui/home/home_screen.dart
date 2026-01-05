import 'package:flutter/material.dart';
import 'package:spend_mate/data/repositories/ai_provider_config_repository.dart';
import 'package:spend_mate/data/repositories/firefly_config_repository.dart';
import 'package:spend_mate/ui/features/settings/settings_screen.dart';
import 'package:spend_mate/ui/features/transactions/transactions_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.configRepository,
    required this.fireflyConfigRepository,
  });

  final AiProviderConfigRepository configRepository;
  final FireflyConfigRepository fireflyConfigRepository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final title = _selectedIndex == 0 ? 'All Transactions' : 'Settings';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          TransactionsScreen(
            configRepository: widget.configRepository,
            fireflyConfigRepository: widget.fireflyConfigRepository,
          ),
          SettingsScreen(
            configRepository: widget.configRepository,
            fireflyConfigRepository: widget.fireflyConfigRepository,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (value) {
          setState(() => _selectedIndex = value);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.receipt_long),
            label: 'Transaction',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: 'Setting',
          ),
        ],
      ),
    );
  }
}
