import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:spend_mate/config/firefly_config.dart';
import 'package:spend_mate/domain/models/firefly_account.dart';
import 'package:spend_mate/domain/models/firefly_category.dart';
import 'package:spend_mate/domain/models/firefly_transaction_ids.dart';
import 'package:spend_mate/domain/models/firefly_transaction_request.dart';
import 'package:spend_mate/domain/models/firefly_transaction_summary.dart';

class FireflyApiService {
  FireflyApiService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client(),
        _ownsClient = httpClient == null;

  final http.Client _httpClient;
  final bool _ownsClient;

  Future<FireflyTransactionIds> createTransaction({
    required FireflyConfig config,
    required FireflyTransactionRequest request,
  }) async {
    final baseUrl = _normalizeBaseUrl(config.baseUrl);
    if (baseUrl.isEmpty) {
      throw Exception('Firefly base URL is empty.');
    }

    final url = Uri.parse('$baseUrl/api/v1/transactions');
    final response = await _httpClient.post(
      url,
      headers: {
        'accept': 'application/vnd.api+json',
        'content-type': 'application/json',
        'authorization': 'Bearer ${config.apiToken.trim()}',
      },
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = response.body.trim().isEmpty
          ? 'HTTP ${response.statusCode}'
          : 'HTTP ${response.statusCode}: ${response.body}';
      throw Exception('Firefly create transaction failed: $message');
    }

    return _parseTransactionIds(response.body);
  }

  Future<FireflyTransactionIds> updateTransaction({
    required FireflyConfig config,
    required String transactionId,
    required FireflyTransactionRequest request,
  }) async {
    final baseUrl = _normalizeBaseUrl(config.baseUrl);
    if (baseUrl.isEmpty) {
      throw Exception('Firefly base URL is empty.');
    }
    final trimmedId = transactionId.trim();
    if (trimmedId.isEmpty) {
      throw Exception('Firefly transaction id is empty.');
    }

    final url = Uri.parse('$baseUrl/api/v1/transactions/$trimmedId');
    final response = await _httpClient.put(
      url,
      headers: {
        'accept': 'application/vnd.api+json',
        'content-type': 'application/json',
        'authorization': 'Bearer ${config.apiToken.trim()}',
      },
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = response.body.trim().isEmpty
          ? 'HTTP ${response.statusCode}'
          : 'HTTP ${response.statusCode}: ${response.body}';
      throw Exception('Firefly update transaction failed: $message');
    }

    return _parseTransactionIds(response.body);
  }

  Future<List<FireflyAccount>> listAssetAccounts({
    required FireflyConfig config,
  }) async {
    final baseUrl = _normalizeBaseUrl(config.baseUrl);
    if (baseUrl.isEmpty) {
      throw Exception('Firefly base URL is empty.');
    }

    final url = Uri.parse('$baseUrl/api/v1/accounts?type=asset');
    final response = await _httpClient.get(
      url,
      headers: {
        'accept': 'application/vnd.api+json',
        'authorization': 'Bearer ${config.apiToken.trim()}',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = response.body.trim().isEmpty
          ? 'HTTP ${response.statusCode}'
          : 'HTTP ${response.statusCode}: ${response.body}';
      throw Exception('Firefly list accounts failed: $message');
    }

    final decoded = jsonDecode(response.body);
    final data = decoded is Map<String, dynamic> ? decoded['data'] : null;
    if (data is! List) return const [];

    final accounts = <FireflyAccount>[];
    for (final item in data) {
      if (item is! Map<String, dynamic>) continue;
      final id = item['id']?.toString() ?? '';
      final attributes = item['attributes'];
      final name = attributes is Map<String, dynamic>
          ? attributes['name']?.toString() ?? ''
          : '';
      if (id.isEmpty || name.trim().isEmpty) continue;
      accounts.add(FireflyAccount(id: id, name: name.trim()));
    }

    accounts.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return accounts;
  }

  Future<List<FireflyAccount>> listExpenseAccounts({
    required FireflyConfig config,
  }) async {
    final baseUrl = _normalizeBaseUrl(config.baseUrl);
    if (baseUrl.isEmpty) {
      throw Exception('Firefly base URL is empty.');
    }

    final url = Uri.parse('$baseUrl/api/v1/accounts?type=expense');
    final response = await _httpClient.get(
      url,
      headers: {
        'accept': 'application/vnd.api+json',
        'authorization': 'Bearer ${config.apiToken.trim()}',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = response.body.trim().isEmpty
          ? 'HTTP ${response.statusCode}'
          : 'HTTP ${response.statusCode}: ${response.body}';
      throw Exception('Firefly list accounts failed: $message');
    }

    final decoded = jsonDecode(response.body);
    final data = decoded is Map<String, dynamic> ? decoded['data'] : null;
    if (data is! List) return const [];

    final accounts = <FireflyAccount>[];
    for (final item in data) {
      if (item is! Map<String, dynamic>) continue;
      final id = item['id']?.toString() ?? '';
      final attributes = item['attributes'];
      final name = attributes is Map<String, dynamic>
          ? attributes['name']?.toString() ?? ''
          : '';
      if (id.isEmpty || name.trim().isEmpty) continue;
      accounts.add(FireflyAccount(id: id, name: name.trim()));
    }

    accounts.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return accounts;
  }

  Future<List<FireflyCategory>> listCategories({
    required FireflyConfig config,
  }) async {
    final baseUrl = _normalizeBaseUrl(config.baseUrl);
    if (baseUrl.isEmpty) {
      throw Exception('Firefly base URL is empty.');
    }

    final url = Uri.parse('$baseUrl/api/v1/categories');
    final response = await _httpClient.get(
      url,
      headers: {
        'accept': 'application/vnd.api+json',
        'authorization': 'Bearer ${config.apiToken.trim()}',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = response.body.trim().isEmpty
          ? 'HTTP ${response.statusCode}'
          : 'HTTP ${response.statusCode}: ${response.body}';
      throw Exception('Firefly list categories failed: $message');
    }

    final decoded = jsonDecode(response.body);
    final data = decoded is Map<String, dynamic> ? decoded['data'] : null;
    if (data is! List) return const [];

    final categories = <FireflyCategory>[];
    for (final item in data) {
      final category = _parseCategory(item);
      if (category != null) {
        categories.add(category);
      }
    }

    categories.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return categories;
  }

  Future<FireflyCategory> createCategory({
    required FireflyConfig config,
    required String name,
  }) async {
    final baseUrl = _normalizeBaseUrl(config.baseUrl);
    if (baseUrl.isEmpty) {
      throw Exception('Firefly base URL is empty.');
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw Exception('Category name is empty.');
    }

    final url = Uri.parse('$baseUrl/api/v1/categories');
    final response = await _httpClient.post(
      url,
      headers: {
        'accept': 'application/vnd.api+json',
        'content-type': 'application/json',
        'authorization': 'Bearer ${config.apiToken.trim()}',
      },
      body: jsonEncode({'name': trimmed}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = response.body.trim().isEmpty
          ? 'HTTP ${response.statusCode}'
          : 'HTTP ${response.statusCode}: ${response.body}';
      throw Exception('Firefly create category failed: $message');
    }

    final decoded = jsonDecode(response.body);
    final data = decoded is Map<String, dynamic> ? decoded['data'] : null;
    final parsed = _parseCategory(data);
    return parsed ?? FireflyCategory(id: trimmed, name: trimmed);
  }

  Future<List<FireflyTransactionSummary>> listTransactions({
    required FireflyConfig config,
    required DateTime start,
    required DateTime end,
    int page = 1,
  }) async {
    final baseUrl = _normalizeBaseUrl(config.baseUrl);
    if (baseUrl.isEmpty) {
      throw Exception('Firefly base URL is empty.');
    }

    final query = <String, String>{
      'start': _formatDate(start),
      'end': _formatDate(end),
      'page': page.toString(),
    };
    final url = Uri.parse('$baseUrl/api/v1/transactions')
        .replace(queryParameters: query);
    final response = await _httpClient.get(
      url,
      headers: {
        'accept': 'application/vnd.api+json',
        'authorization': 'Bearer ${config.apiToken.trim()}',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = response.body.trim().isEmpty
          ? 'HTTP ${response.statusCode}'
          : 'HTTP ${response.statusCode}: ${response.body}';
      throw Exception('Firefly list transactions failed: $message');
    }

    return _parseTransactionSummaries(response.body);
  }

  void dispose() {
    if (_ownsClient) {
      _httpClient.close();
    }
  }

  FireflyCategory? _parseCategory(dynamic value) {
    if (value is! Map<String, dynamic>) return null;
    final id = value['id']?.toString() ?? '';
    final attributes = value['attributes'];
    final name = attributes is Map<String, dynamic>
        ? attributes['name']?.toString() ?? ''
        : '';
    if (name.trim().isEmpty) return null;
    return FireflyCategory(id: id.isEmpty ? name.trim() : id, name: name.trim());
  }

  FireflyTransactionIds _parseTransactionIds(String responseBody) {
    final trimmed = responseBody.trim();
    if (trimmed.isEmpty) return const FireflyTransactionIds();

    dynamic decoded;
    try {
      decoded = jsonDecode(trimmed);
    } catch (_) {
      return const FireflyTransactionIds();
    }

    final data = _firstData(decoded);
    String? transactionId;
    String? journalId;
    if (data is Map) {
      transactionId = data['id']?.toString();
      final attributes = data['attributes'];
      final transactions = attributes is Map ? attributes['transactions'] : null;
      final firstSplit = _firstListEntry(transactions);
      if (firstSplit is Map) {
        journalId = firstSplit['transaction_journal_id']?.toString() ??
            firstSplit['id']?.toString();
      }
    }

    return FireflyTransactionIds(
      transactionId: _trimToNull(transactionId),
      transactionJournalId: _trimToNull(journalId),
    );
  }

  List<FireflyTransactionSummary> _parseTransactionSummaries(
    String responseBody,
  ) {
    final trimmed = responseBody.trim();
    if (trimmed.isEmpty) return const [];

    dynamic decoded;
    try {
      decoded = jsonDecode(trimmed);
    } catch (_) {
      return const [];
    }

    if (decoded is! Map) return const [];
    final data = decoded['data'];
    if (data is! List) return const [];

    final summaries = <FireflyTransactionSummary>[];
    for (final entry in data) {
      if (entry is! Map) continue;
      final groupId = entry['id']?.toString() ?? '';
      if (groupId.trim().isEmpty) continue;
      final attributes = entry['attributes'];
      if (attributes is! Map) continue;
      final transactions = attributes['transactions'];
      if (transactions is! List || transactions.isEmpty) continue;
      final isSplit = transactions.length > 1;
      for (final split in transactions) {
        if (split is! Map) continue;
        final journalId = split['transaction_journal_id']?.toString() ??
            split['id']?.toString() ??
            '';
        if (journalId.trim().isEmpty) continue;
        final description = split['description']?.toString() ?? 'Transaction';
        final amountRaw = split['amount']?.toString() ?? '';
        final amount = double.tryParse(amountRaw) ?? 0;
        final dateText = split['date']?.toString();
        final date = DateTime.tryParse(dateText ?? '');
        if (date == null) continue;
        final type = split['type']?.toString() ?? '';
        final sourceName = split['source_name']?.toString() ?? '';
        final destinationName =
            split['destination_name']?.toString() ?? '';
        final currencyCode = split['currency_code']?.toString();

        summaries.add(
          FireflyTransactionSummary(
            transactionId: groupId,
            transactionJournalId: journalId,
            description: description,
            amount: amount,
            date: date,
            type: type,
            sourceName: sourceName,
            destinationName: destinationName,
            currencyCode: _trimToNull(currencyCode),
            isSplit: isSplit,
          ),
        );
      }
    }

    return summaries;
  }

  dynamic _firstData(dynamic decoded) {
    if (decoded is! Map) return null;
    final data = decoded['data'];
    if (data is List && data.isNotEmpty) {
      return data.first;
    }
    return data;
  }

  dynamic _firstListEntry(dynamic value) {
    if (value is List && value.isNotEmpty) {
      return value.first;
    }
    return null;
  }

  String? _trimToNull(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  String _normalizeBaseUrl(String value) {
    var trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    if (!trimmed.contains('://')) {
      trimmed = 'http://$trimmed';
    }
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
