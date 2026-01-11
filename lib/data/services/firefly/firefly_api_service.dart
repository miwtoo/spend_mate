import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart' show Client;
import 'package:spend_mate/config/firefly_config.dart';
import 'package:spend_mate/data/services/firefly/firefly_api_exception.dart';
import 'package:spend_mate/domain/models/firefly_account.dart';
import 'package:spend_mate/domain/models/firefly_category.dart';
import 'package:spend_mate/domain/models/firefly_transaction_ids.dart';
import 'package:spend_mate/domain/models/firefly_transaction_request.dart';
import 'package:spend_mate/domain/models/firefly_transaction_summary.dart';

class _NoRedirectClient extends http.BaseClient {
  _NoRedirectClient(this._inner);

  final Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // Disable automatic redirects
    final streamedResponse = await _inner.send(request);
    final response = http.StreamedResponse(
      streamedResponse.stream,
      streamedResponse.statusCode,
      contentLength: streamedResponse.contentLength,
      request: streamedResponse.request,
      headers: streamedResponse.headers,
      isRedirect: false,
      persistentConnection: streamedResponse.persistentConnection,
      reasonPhrase: streamedResponse.reasonPhrase,
    );
    return response;
  }

  @override
  void close() => _inner.close();
}

class FireflyApiService {
  FireflyApiService({http.Client? httpClient})
      : _httpClient = httpClient ?? _NoRedirectClient(http.Client()),
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

    _ensureSuccessResponse(
      method: 'POST',
      uri: url,
      response: response,
    );

    _ensureJsonResponse(
      method: 'POST',
      uri: url,
      response: response,
    );

    return _parseTransactionIds(
      response.body,
      method: 'POST',
      uri: url,
      statusCode: response.statusCode,
      contentType: _contentType(response),
    );
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

    _ensureSuccessResponse(
      method: 'PUT',
      uri: url,
      response: response,
    );

    _ensureJsonResponse(
      method: 'PUT',
      uri: url,
      response: response,
    );

    return _parseTransactionIds(
      response.body,
      method: 'PUT',
      uri: url,
      statusCode: response.statusCode,
      contentType: _contentType(response),
    );
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

    _ensureSuccessResponse(
      method: 'GET',
      uri: url,
      response: response,
    );

    _ensureJsonResponse(
      method: 'GET',
      uri: url,
      response: response,
    );

    final decoded = _decodeJsonMap(
      method: 'GET',
      uri: url,
      response: response,
    );
    final data = decoded['data'];
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

    _ensureSuccessResponse(
      method: 'GET',
      uri: url,
      response: response,
    );

    _ensureJsonResponse(
      method: 'GET',
      uri: url,
      response: response,
    );

    final decoded = _decodeJsonMap(
      method: 'GET',
      uri: url,
      response: response,
    );
    final data = decoded['data'];
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

    _ensureSuccessResponse(
      method: 'GET',
      uri: url,
      response: response,
    );

    _ensureJsonResponse(
      method: 'GET',
      uri: url,
      response: response,
    );

    final decoded = _decodeJsonMap(
      method: 'GET',
      uri: url,
      response: response,
    );
    final data = decoded['data'];
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

    _ensureSuccessResponse(
      method: 'POST',
      uri: url,
      response: response,
    );

    _ensureJsonResponse(
      method: 'POST',
      uri: url,
      response: response,
    );

    final decoded = _decodeJsonMap(
      method: 'POST',
      uri: url,
      response: response,
    );
    final data = decoded['data'];
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

    _ensureSuccessResponse(
      method: 'GET',
      uri: url,
      response: response,
    );

    _ensureJsonResponse(
      method: 'GET',
      uri: url,
      response: response,
    );

    return _parseTransactionSummaries(
      response.body,
      method: 'GET',
      uri: url,
      statusCode: response.statusCode,
      contentType: _contentType(response),
    );
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
    return FireflyCategory(
        id: id.isEmpty ? name.trim() : id, name: name.trim());
  }

  FireflyTransactionIds _parseTransactionIds(
    String responseBody, {
    required String method,
    required Uri uri,
    required int statusCode,
    required String? contentType,
  }) {
    final trimmed = responseBody.trim();
    if (trimmed.isEmpty) return const FireflyTransactionIds();

    dynamic decoded;
    try {
      decoded = jsonDecode(trimmed);
    } catch (_) {
      final exception = FireflyApiException.invalidJson(
        method: method,
        uri: uri,
        statusCode: statusCode,
        responseSnippet: _snippetFor(responseBody),
        contentType: contentType,
      );
      _logApiError(exception);
      throw exception;
    }

    final data = _firstData(decoded);
    String? transactionId;
    String? journalId;
    if (data is Map) {
      transactionId = data['id']?.toString();
      final attributes = data['attributes'];
      final transactions =
          attributes is Map ? attributes['transactions'] : null;
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
    String responseBody, {
    required String method,
    required Uri uri,
    required int statusCode,
    required String? contentType,
  }) {
    final trimmed = responseBody.trim();
    if (trimmed.isEmpty) return const [];

    dynamic decoded;
    try {
      decoded = jsonDecode(trimmed);
    } catch (_) {
      final exception = FireflyApiException.invalidJson(
        method: method,
        uri: uri,
        statusCode: statusCode,
        responseSnippet: _snippetFor(responseBody),
        contentType: contentType,
      );
      _logApiError(exception);
      throw exception;
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
        final destinationName = split['destination_name']?.toString() ?? '';
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

  void _ensureSuccessResponse({
    required String method,
    required Uri uri,
    required http.Response response,
  }) {
    // Detect 302 redirects - typically indicates authentication failure
    // Firefly III redirects to login page when unauthenticated
    if (response.statusCode == 302 || response.statusCode == 301) {
      final location = response.headers['location'];
      final exception = FireflyApiException.authenticationRequired(
        method: method,
        uri: uri,
        responseSnippet: 'Redirect to: ${location ?? "unknown"}',
        contentType: _contentType(response),
      );
      _logApiError(exception);
      throw exception;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    // Handle gateway errors (502, 503, 504) with specific messages
    if (response.statusCode >= 502 && response.statusCode <= 504) {
      final exception = FireflyApiException.gatewayError(
        method: method,
        uri: uri,
        statusCode: response.statusCode,
        responseSnippet: _snippetFor(response.body),
        contentType: _contentType(response),
      );
      _logApiError(exception);
      throw exception;
    }

    final exception = FireflyApiException.httpError(
      method: method,
      uri: uri,
      statusCode: response.statusCode,
      responseSnippet: _snippetFor(response.body),
      contentType: _contentType(response),
      isJson: _isJsonResponse(response),
    );
    _logApiError(exception);
    throw exception;
  }

  void _ensureJsonResponse({
    required String method,
    required Uri uri,
    required http.Response response,
  }) {
    final trimmed = response.body.trim();
    if (trimmed.isEmpty) return;

    final contentType = _contentType(response);
    final isJson = _isJsonResponse(response);
    if (isJson) return;
    if (_looksLikeHtml(trimmed)) {
      final exception = FireflyApiException.unexpectedResponse(
        method: method,
        uri: uri,
        statusCode: response.statusCode,
        responseSnippet: _snippetFor(trimmed),
        contentType: contentType,
        isJson: false,
      );
      _logApiError(exception);
      throw exception;
    }
  }

  Map<String, dynamic> _decodeJsonMap({
    required String method,
    required Uri uri,
    required http.Response response,
  }) {
    final trimmed = response.body.trim();
    if (trimmed.isEmpty) return const {};

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return <String, dynamic>{'data': decoded};
    } catch (_) {
      final exception = FireflyApiException.invalidJson(
        method: method,
        uri: uri,
        statusCode: response.statusCode,
        responseSnippet: _snippetFor(response.body),
        contentType: _contentType(response),
      );
      _logApiError(exception);
      throw exception;
    }
  }

  String? _contentType(http.Response response) {
    return response.headers['content-type'];
  }

  bool _isJsonResponse(http.Response response) {
    final contentType = _contentType(response);
    return contentType != null && contentType.toLowerCase().contains('json');
  }

  bool _looksLikeHtml(String value) {
    final lowered = value.trimLeft().toLowerCase();
    return lowered.startsWith('<!doctype') ||
        lowered.startsWith('<html') ||
        lowered.startsWith('<head') ||
        lowered.startsWith('<body');
  }

  String _snippetFor(String value) {
    var snippet = value.trim();
    if (snippet.isEmpty) return '';
    snippet = snippet.replaceAll(RegExp(r'\\s+'), ' ');
    const limit = 200;
    if (snippet.length > limit) {
      snippet = snippet.substring(0, limit);
    }
    return snippet;
  }

  void _logApiError(FireflyApiException exception) {
    debugPrint(
      'Firefly API error ${exception.method} ${exception.uri} '
      'status=${exception.statusCode} '
      'content-type=${exception.contentType ?? 'unknown'} '
      'snippet="${exception.responseSnippet}"',
    );
  }
}
