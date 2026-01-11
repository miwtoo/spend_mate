import 'package:flutter/foundation.dart';
import 'package:spend_mate/data/repositories/firefly_config_repository.dart';
import 'package:spend_mate/data/repositories/firefly_transaction_repository.dart';
import 'package:spend_mate/data/services/firefly/firefly_api_exception.dart';
import 'package:spend_mate/domain/models/firefly_transaction_summary.dart';

class TransactionsViewModel extends ChangeNotifier {
  TransactionsViewModel({
    required FireflyConfigRepository configRepository,
    required FireflyTransactionRepository transactionRepository,
  }) : _transactionRepository = transactionRepository;

  final FireflyTransactionRepository _transactionRepository;

  bool _isLoading = false;
  List<FireflyTransactionSummary> _transactions = const [];
  String? _error;
  bool _disposed = false;

  bool get isLoading => _isLoading;
  List<FireflyTransactionSummary> get transactions =>
      List.unmodifiable(_transactions);
  String? get error => _error;

  Future<void> loadTransactions() async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      final fetched = await _transactionRepository.fetchAllTransactions();
      // Sort by date descending (newest first)
      fetched.sort((a, b) => b.date.compareTo(a.date));
      _transactions = fetched;
      _error = null;
    } catch (e) {
      final message = _friendlyErrorMessage(e);
      _error = 'Failed to load transactions. $message';
      _transactions = const [];
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<void> refresh() async {
    await loadTransactions();
  }

  void _notifySafely() {
    if (_disposed) return;
    notifyListeners();
  }

  String _friendlyErrorMessage(Object error) {
    if (error is FireflyApiException) {
      return error.userMessage;
    }
    return 'Please try again.';
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
