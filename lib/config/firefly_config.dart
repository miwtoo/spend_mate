class FireflyConfig {
  const FireflyConfig({
    required this.baseUrl,
    required this.apiToken,
    required this.expenseAccountName,
    required this.revenueAccountName,
    required this.transferDestinationAccountName,
    required this.defaultCurrencyCode,
  });

  final String baseUrl;
  final String apiToken;
  final String expenseAccountName;
  final String revenueAccountName;
  final String transferDestinationAccountName;
  final String defaultCurrencyCode;

  bool get hasCredentials =>
      baseUrl.trim().isNotEmpty && apiToken.trim().isNotEmpty;

  bool get isConfigured => hasCredentials;

  FireflyConfig copyWith({
    String? baseUrl,
    String? apiToken,
    String? expenseAccountName,
    String? revenueAccountName,
    String? transferDestinationAccountName,
    String? defaultCurrencyCode,
  }) {
    return FireflyConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      apiToken: apiToken ?? this.apiToken,
      expenseAccountName: expenseAccountName ?? this.expenseAccountName,
      revenueAccountName: revenueAccountName ?? this.revenueAccountName,
      transferDestinationAccountName:
          transferDestinationAccountName ?? this.transferDestinationAccountName,
      defaultCurrencyCode: defaultCurrencyCode ?? this.defaultCurrencyCode,
    );
  }

  factory FireflyConfig.defaults() {
    return const FireflyConfig(
      baseUrl: '',
      apiToken: '',
      expenseAccountName: '',
      revenueAccountName: '',
      transferDestinationAccountName: '',
      defaultCurrencyCode: '',
    );
  }
}
