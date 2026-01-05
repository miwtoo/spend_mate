import 'package:shared_preferences/shared_preferences.dart';
import 'package:spend_mate/config/firefly_config.dart';

class FireflyConfigRepository {
  FireflyConfigRepository._(this._prefs);

  final SharedPreferences _prefs;

  static const _kBaseUrl = 'firefly_base_url';
  static const _kApiToken = 'firefly_api_token';
  static const _kExpenseAccount = 'firefly_expense_account';
  static const _kRevenueAccount = 'firefly_revenue_account';
  static const _kTransferDestinationAccount =
      'firefly_transfer_destination_account';
  static const _kDefaultCurrency = 'firefly_default_currency';

  static Future<FireflyConfigRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return FireflyConfigRepository._(prefs);
  }

  Future<FireflyConfig> load() async {
    final defaults = FireflyConfig.defaults();
    return FireflyConfig(
      baseUrl: _prefs.getString(_kBaseUrl) ?? defaults.baseUrl,
      apiToken: _prefs.getString(_kApiToken) ?? defaults.apiToken,
      expenseAccountName:
          _prefs.getString(_kExpenseAccount) ?? defaults.expenseAccountName,
      revenueAccountName:
          _prefs.getString(_kRevenueAccount) ?? defaults.revenueAccountName,
      transferDestinationAccountName:
          _prefs.getString(_kTransferDestinationAccount) ??
              defaults.transferDestinationAccountName,
      defaultCurrencyCode:
          _prefs.getString(_kDefaultCurrency) ?? defaults.defaultCurrencyCode,
    );
  }

  Future<void> save(FireflyConfig config) async {
    await _prefs.setString(_kBaseUrl, config.baseUrl);
    await _prefs.setString(_kApiToken, config.apiToken);
    await _prefs.setString(_kExpenseAccount, config.expenseAccountName);
    await _prefs.setString(_kRevenueAccount, config.revenueAccountName);
    await _prefs.setString(
      _kTransferDestinationAccount,
      config.transferDestinationAccountName,
    );
    await _prefs.setString(_kDefaultCurrency, config.defaultCurrencyCode);
  }
}
