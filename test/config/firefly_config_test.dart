import 'package:flutter_test/flutter_test.dart';
import 'package:spend_mate/config/firefly_config.dart';

void main() {
  group('FireflyConfig', () {
    test('hasCredentials is true only when baseUrl and token are set', () {
      const empty = FireflyConfig(
        baseUrl: '',
        apiToken: '',
        expenseAccountName: '',
        revenueAccountName: '',
        transferDestinationAccountName: '',
        defaultCurrencyCode: '',
      );
      const missingToken = FireflyConfig(
        baseUrl: 'https://firefly.test',
        apiToken: '',
        expenseAccountName: '',
        revenueAccountName: '',
        transferDestinationAccountName: '',
        defaultCurrencyCode: '',
      );
      const full = FireflyConfig(
        baseUrl: 'https://firefly.test',
        apiToken: 'token',
        expenseAccountName: '',
        revenueAccountName: '',
        transferDestinationAccountName: '',
        defaultCurrencyCode: '',
      );

      expect(empty.hasCredentials, isFalse);
      expect(missingToken.hasCredentials, isFalse);
      expect(full.hasCredentials, isTrue);
      expect(full.isConfigured, isTrue);
    });

    test('copyWith updates provided fields', () {
      const config = FireflyConfig(
        baseUrl: 'https://firefly.test',
        apiToken: 'token',
        expenseAccountName: 'Expenses',
        revenueAccountName: 'Income',
        transferDestinationAccountName: 'Savings',
        defaultCurrencyCode: 'USD',
      );

      final updated = config.copyWith(
        apiToken: 'new-token',
        defaultCurrencyCode: 'EUR',
      );

      expect(updated.baseUrl, config.baseUrl);
      expect(updated.apiToken, 'new-token');
      expect(updated.defaultCurrencyCode, 'EUR');
    });

    test('defaults returns an unconfigured config', () {
      final defaults = FireflyConfig.defaults();

      expect(defaults.baseUrl, '');
      expect(defaults.apiToken, '');
      expect(defaults.isConfigured, isFalse);
    });
  });
}
