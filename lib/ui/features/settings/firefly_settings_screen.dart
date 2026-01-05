import 'package:flutter/material.dart';
import 'package:spend_mate/config/firefly_config.dart';
import 'package:spend_mate/data/repositories/firefly_config_repository.dart';

class FireflySettingsScreen extends StatefulWidget {
  const FireflySettingsScreen({
    super.key,
    required this.configRepository,
  });

  final FireflyConfigRepository configRepository;

  @override
  State<FireflySettingsScreen> createState() => _FireflySettingsScreenState();
}

class _FireflySettingsScreenState extends State<FireflySettingsScreen> {
  final _baseUrlController = TextEditingController();
  final _tokenController = TextEditingController();
  final _expenseAccountController = TextEditingController();
  final _revenueAccountController = TextEditingController();
  final _transferAccountController = TextEditingController();
  final _currencyController = TextEditingController();

  bool _obscureToken = true;
  bool _saving = false;
  late final Future<void> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = _load();
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _tokenController.dispose();
    _expenseAccountController.dispose();
    _revenueAccountController.dispose();
    _transferAccountController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final config = await widget.configRepository.load();
    _baseUrlController.text = config.baseUrl;
    _tokenController.text = config.apiToken;
    _expenseAccountController.text = config.expenseAccountName;
    _revenueAccountController.text = config.revenueAccountName;
    _transferAccountController.text = config.transferDestinationAccountName;
    _currencyController.text = config.defaultCurrencyCode;
  }

  FireflyConfig _buildConfig() {
    return FireflyConfig(
      baseUrl: _baseUrlController.text.trim(),
      apiToken: _tokenController.text.trim(),
      expenseAccountName: _expenseAccountController.text.trim(),
      revenueAccountName: _revenueAccountController.text.trim(),
      transferDestinationAccountName: _transferAccountController.text.trim(),
      defaultCurrencyCode: _currencyController.text.trim(),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.configRepository.save(_buildConfig());
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Firefly III'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _baseUrlController,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Base URL',
                  hintText: 'e.g. https://firefly.example.com',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _tokenController,
                enabled: !_saving,
                obscureText: _obscureToken,
                decoration: InputDecoration(
                  labelText: 'Personal Access Token',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: _obscureToken ? 'Show' : 'Hide',
                    onPressed: _saving
                        ? null
                        : () => setState(() => _obscureToken = !_obscureToken),
                    icon: Icon(
                      _obscureToken ? Icons.visibility : Icons.visibility_off,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Default accounts for auto-import',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _expenseAccountController,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Expense account (optional)',
                  hintText: 'e.g. Expenses',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _revenueAccountController,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Revenue account (optional)',
                  hintText: 'e.g. Salary',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _transferAccountController,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Transfer destination (optional)',
                  hintText: 'e.g. Savings',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _currencyController,
                enabled: !_saving,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Default currency code (optional)',
                  hintText: 'e.g. USD',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_saving ? 'Saving...' : 'Save'),
              ),
              const SizedBox(height: 8),
              Text(
                'Token is stored locally on-device (not encrypted).',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }
}
