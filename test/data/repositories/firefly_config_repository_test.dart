import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spend_mate/config/firefly_config.dart';
import 'package:spend_mate/data/repositories/firefly_config_repository.dart';

void main() {
  group('FireflyConfigRepository', () {
    test('loads defaults when no values are stored', () async {
      SharedPreferences.setMockInitialValues({});
      final repository = await FireflyConfigRepository.create();

      final config = await repository.load();

      expect(config.baseUrl, '');
      expect(config.apiToken, '');
      expect(config.expenseAccountName, '');
      expect(config.revenueAccountName, '');
      expect(config.transferDestinationAccountName, '');
      expect(config.defaultCurrencyCode, '');
    });

    test('persists and reloads Firefly config', () async {
      SharedPreferences.setMockInitialValues({});
      final repository = await FireflyConfigRepository.create();

      const saved = FireflyConfig(
        baseUrl: 'https://firefly.test',
        apiToken: 'token-123',
        expenseAccountName: 'Expenses',
        revenueAccountName: 'Income',
        transferDestinationAccountName: 'Savings',
        defaultCurrencyCode: 'USD',
      );

      await repository.save(saved);
      final loaded = await repository.load();

      expect(loaded.baseUrl, saved.baseUrl);
      expect(loaded.apiToken, saved.apiToken);
      expect(loaded.expenseAccountName, saved.expenseAccountName);
      expect(loaded.revenueAccountName, saved.revenueAccountName);
      expect(
        loaded.transferDestinationAccountName,
        saved.transferDestinationAccountName,
      );
      expect(loaded.defaultCurrencyCode, saved.defaultCurrencyCode);
    });
  });
}
