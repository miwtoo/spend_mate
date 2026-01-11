import 'package:spend_mate/config/firefly_config.dart';
import 'package:spend_mate/data/repositories/firefly_config_repository.dart';
import 'package:spend_mate/data/services/firefly/firefly_api_service.dart';
import 'package:spend_mate/domain/models/auto_import_draft.dart';
import 'package:spend_mate/domain/models/firefly_transaction_ids.dart';
import 'package:spend_mate/domain/models/firefly_transaction_request.dart';
import 'package:spend_mate/domain/models/firefly_transaction_summary.dart';
import 'package:spend_mate/domain/models/receipt_parse_result.dart';

class FireflyTransactionRepository {
  FireflyTransactionRepository({
    required FireflyConfigRepository configRepository,
    required FireflyApiService apiService,
  })  : _configRepository = configRepository,
        _apiService = apiService;

  final FireflyConfigRepository _configRepository;
  final FireflyApiService _apiService;

  Future<FireflyTransactionIds> createFromDraft(
    AutoImportDraft draft, {
    String? assetAccountOverride,
  }) async {
    final config = await _configRepository.load();
    _validateConfig(config);

    final request = _buildRequest(
      draft,
      config,
      assetAccountOverride,
    );
    return _apiService.createTransaction(config: config, request: request);
  }

  Future<FireflyTransactionIds> updateFromDraft(
    AutoImportDraft draft, {
    String? assetAccountOverride,
  }) async {
    final config = await _configRepository.load();
    _validateConfig(config);

    final transactionId = draft.fireflyTransactionId?.trim() ?? '';
    if (transactionId.isEmpty) {
      throw Exception('Firefly transaction id is missing.');
    }

    final request = _buildRequest(
      draft,
      config,
      assetAccountOverride,
      transactionJournalId: draft.fireflyTransactionJournalId,
    );
    try {
      return await _apiService.updateTransaction(
        config: config,
        transactionId: transactionId,
        request: request,
      );
    } catch (error) {
      if (_isNotFoundError(error)) {
        final createRequest = _buildRequest(
          draft,
          config,
          assetAccountOverride,
        );
        return _apiService.createTransaction(
          config: config,
          request: createRequest,
        );
      }
      rethrow;
    }
  }

  Future<List<FireflyTransactionSummary>> listRecentTransactions({
    required DateTime start,
    required DateTime end,
  }) async {
    final config = await _configRepository.load();
    _validateConfig(config);

    return _apiService.listTransactions(
      config: config,
      start: start,
      end: end,
      page: 1,
    );
  }

  Future<List<FireflyTransactionSummary>> fetchAllTransactions() async {
    final config = await _configRepository.load();
    _validateConfig(config);

    final startDate = DateTime(1970, 1, 1);
    final endDate = DateTime.now();

    final allTransactions = <FireflyTransactionSummary>[];
    var page = 1;

    while (true) {
      final transactions = await _apiService.listTransactions(
        config: config,
        start: startDate,
        end: endDate,
        page: page,
      );

      if (transactions.isEmpty) {
        break;
      }

      allTransactions.addAll(transactions);
      page++;
    }

    return allTransactions;
  }

  FireflyTransactionRequest _buildRequest(
    AutoImportDraft draft,
    FireflyConfig config,
    String? assetAccountOverride, {
    String? transactionJournalId,
  }) {
    final amount = draft.amount;
    if (amount == null || amount <= 0) {
      throw Exception('Draft amount is missing.');
    }

    final date = draft.date ?? draft.detectedAt;
    final description = _descriptionFor(draft);
    final currency = _currencyFor(draft, config);
    final type = _mapType(draft.type);
    final categoryName = _categoryFor(draft);

    late final String sourceName;
    late final String destinationName;
    if (type == FireflyTransactionType.transfer) {
      final accounts = _resolveTransferAccounts(
        config,
        assetAccountOverride,
      );
      sourceName = accounts.source;
      destinationName = accounts.destination;
    } else {
      sourceName = _sourceAccountFor(
        type,
        config,
        assetAccountOverride,
      );
      destinationName = _destinationAccountFor(
        type,
        draft,
        config,
        assetAccountOverride,
      );
    }

    return FireflyTransactionRequest(
      transactions: [
        FireflyTransactionSplit(
          type: type,
          date: _formatDate(date),
          amount: _formatAmount(amount),
          description: description,
          sourceName: sourceName,
          destinationName: destinationName,
          transactionJournalId: transactionJournalId,
          currencyCode: currency,
          notes: _notesFor(draft, description),
          categoryName: categoryName,
        ),
      ],
    );
  }

  String _descriptionFor(AutoImportDraft draft) {
    return draft.merchant?.trim().isNotEmpty == true
        ? draft.merchant!.trim()
        : (draft.note?.trim().isNotEmpty == true
            ? draft.note!.trim()
            : 'Auto import');
  }

  String? _notesFor(AutoImportDraft draft, String description) {
    final note = draft.note?.trim();
    if (note == null || note.isEmpty) return null;
    if (note == description) return null;
    return note;
  }

  String? _categoryFor(AutoImportDraft draft) {
    final category = draft.categoryName?.trim();
    if (category == null || category.isEmpty) return null;
    return category;
  }

  String? _currencyFor(AutoImportDraft draft, FireflyConfig config) {
    if (draft.currency != null && draft.currency!.trim().isNotEmpty) {
      return draft.currency!.trim().toUpperCase();
    }
    if (config.defaultCurrencyCode.trim().isNotEmpty) {
      return config.defaultCurrencyCode.trim().toUpperCase();
    }
    return null;
  }

  FireflyTransactionType _mapType(ReceiptTransactionType type) {
    return switch (type) {
      ReceiptTransactionType.income => FireflyTransactionType.deposit,
      ReceiptTransactionType.transfer => FireflyTransactionType.transfer,
      ReceiptTransactionType.expense || ReceiptTransactionType.unknown =>
        FireflyTransactionType.withdrawal,
    };
  }

  String _sourceAccountFor(
    FireflyTransactionType type,
    FireflyConfig config,
    String? assetAccountOverride,
  ) {
    switch (type) {
      case FireflyTransactionType.withdrawal:
      case FireflyTransactionType.transfer:
        return _requireAssetAccount(assetAccountOverride);
      case FireflyTransactionType.deposit:
        if (config.revenueAccountName.trim().isNotEmpty) {
          return config.revenueAccountName.trim();
        }
        return 'Income';
    }
  }

  String _destinationAccountFor(
    FireflyTransactionType type,
    AutoImportDraft draft,
    FireflyConfig config,
    String? assetAccountOverride,
  ) {
    switch (type) {
      case FireflyTransactionType.withdrawal:
        if (config.expenseAccountName.trim().isNotEmpty) {
          return config.expenseAccountName.trim();
        }
        if (draft.merchant?.trim().isNotEmpty == true) {
          return draft.merchant!.trim();
        }
        return 'Expenses';
      case FireflyTransactionType.deposit:
        return _requireAssetAccount(assetAccountOverride);
      case FireflyTransactionType.transfer:
        if (config.transferDestinationAccountName.trim().isNotEmpty) {
          return config.transferDestinationAccountName.trim();
        }
        throw Exception(
          'Transfer drafts need a destination account. Configure it in Settings.',
        );
    }
  }

  ({String source, String destination}) _resolveTransferAccounts(
    FireflyConfig config,
    String? assetAccountOverride,
  ) {
    final configuredDestination =
        config.transferDestinationAccountName.trim();
    if (configuredDestination.isNotEmpty) {
      return (
        source: _requireAssetAccount(assetAccountOverride),
        destination: configuredDestination,
      );
    }

    throw Exception(
      'Transfer drafts need a destination account. Configure it in Settings.',
    );
  }

  String _requireAssetAccount(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      throw Exception(
        'Select an asset account for this folder before confirming.',
      );
    }
    return trimmed;
  }

  String _formatAmount(double value) {
    final normalized = value.abs();
    final fixed = normalized.toStringAsFixed(2);
    return _trimTrailingZeros(fixed);
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final second = local.second.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute:$second';
  }

  String _trimTrailingZeros(String value) {
    final trimmed = value.replaceFirst(RegExp(r'\.0+$'), '');
    if (!trimmed.contains('.')) {
      return trimmed;
    }
    return trimmed
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  void _validateConfig(FireflyConfig config) {
    if (!config.hasCredentials) {
      throw Exception('Firefly connection is not configured.');
    }
  }

  bool _isNotFoundError(Object error) {
    final message = error.toString();
    return message.contains('HTTP 404') ||
        message.contains('NotFoundHttpException') ||
        message.contains('Resource not found');
  }
}
