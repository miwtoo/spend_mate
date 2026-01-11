import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spend_mate/config/firefly_config.dart';
import 'package:spend_mate/data/repositories/firefly_config_repository.dart';
import 'package:spend_mate/data/repositories/firefly_transaction_repository.dart';
import 'package:spend_mate/data/services/firefly/firefly_api_service.dart';
import 'package:spend_mate/domain/models/auto_import_draft.dart';
import 'package:spend_mate/domain/models/firefly_transaction_ids.dart';
import 'package:spend_mate/domain/models/firefly_transaction_request.dart';
import 'package:spend_mate/domain/models/firefly_transaction_summary.dart';
import 'package:spend_mate/domain/models/receipt_parse_result.dart';

class _StubFireflyApiService extends FireflyApiService {
  _StubFireflyApiService()
      : super(httpClient: MockClient((_) async => http.Response('{}', 200)));

  final List<List<FireflyTransactionSummary>> pages = [];
  int listCalls = 0;
  DateTime? firstStart;
  DateTime? firstEnd;
  final List<int> pagesCalled = [];

  int createCalls = 0;
  int updateCalls = 0;
  bool throwOnUpdate = false;
  FireflyTransactionRequest? lastRequest;
  String? lastUpdateId;

  @override
  Future<List<FireflyTransactionSummary>> listTransactions({
    required FireflyConfig config,
    required DateTime start,
    required DateTime end,
    int page = 1,
  }) async {
    listCalls++;
    firstStart ??= start;
    firstEnd ??= end;
    pagesCalled.add(page);
    if (pages.length >= listCalls) {
      return pages[listCalls - 1];
    }
    return const [];
  }

  @override
  Future<FireflyTransactionIds> createTransaction({
    required FireflyConfig config,
    required FireflyTransactionRequest request,
  }) async {
    createCalls++;
    lastRequest = request;
    return const FireflyTransactionIds(
      transactionId: 'tx-1',
      transactionJournalId: 'journal-1',
    );
  }

  @override
  Future<FireflyTransactionIds> updateTransaction({
    required FireflyConfig config,
    required String transactionId,
    required FireflyTransactionRequest request,
  }) async {
    updateCalls++;
    lastUpdateId = transactionId;
    lastRequest = request;
    if (throwOnUpdate) {
      throw Exception('HTTP 404');
    }
    return const FireflyTransactionIds(
      transactionId: 'tx-2',
      transactionJournalId: 'journal-2',
    );
  }
}

Future<FireflyConfigRepository> _buildConfigRepository({
  FireflyConfig? config,
}) async {
  SharedPreferences.setMockInitialValues({});
  final repository = await FireflyConfigRepository.create();
  await repository.save(
    config ??
        const FireflyConfig(
          baseUrl: 'https://firefly.test',
          apiToken: 'token',
          expenseAccountName: '',
          revenueAccountName: '',
          transferDestinationAccountName: '',
          defaultCurrencyCode: '',
        ),
  );
  return repository;
}

FireflyTransactionSummary _summary(String id, DateTime date) {
  return FireflyTransactionSummary(
    transactionId: id,
    transactionJournalId: 'journal-$id',
    description: 'Example',
    amount: 12.34,
    date: date,
    type: 'withdrawal',
    sourceName: 'Checking',
    destinationName: 'Coffee',
  );
}

void main() {
  group('FireflyTransactionRepository', () {
    test('fetchAllTransactions paginates from 1970 through today', () async {
      final api = _StubFireflyApiService()
        ..pages.addAll([
          [_summary('1', DateTime(2024, 1, 1))],
          [_summary('2', DateTime(2024, 1, 2))],
          const [],
        ]);
      final configRepository = await _buildConfigRepository();
      final repository = FireflyTransactionRepository(
        configRepository: configRepository,
        apiService: api,
      );

      final results = await repository.fetchAllTransactions();

      expect(results.length, 2);
      expect(api.listCalls, 3);
      expect(api.pagesCalled, [1, 2, 3]);
      expect(api.firstStart?.year, 1970);
      expect(api.firstStart?.month, 1);
      expect(api.firstStart?.day, 1);
      expect(api.firstEnd, isNotNull);
    });

    test('createFromDraft maps expense drafts into withdrawals', () async {
      final api = _StubFireflyApiService();
      final configRepository = await _buildConfigRepository();
      final repository = FireflyTransactionRepository(
        configRepository: configRepository,
        apiService: api,
      );

      final draft = AutoImportDraft(
        id: 'draft-1',
        sourcePath: '/tmp/receipt.png',
        detectedAt: DateTime(2024, 2, 3, 4, 5, 6),
        status: AutoImportStatus.pending,
        merchant: 'Cafe',
        amount: 12.5,
        currency: 'usd',
        date: DateTime(2024, 2, 3, 4, 5, 6),
        note: 'Latte',
        categoryName: 'Food',
        type: ReceiptTransactionType.expense,
      );

      await repository.createFromDraft(
        draft,
        assetAccountOverride: 'Checking',
      );

      final request = api.lastRequest;
      expect(request, isNotNull);
      final split = request!.transactions.first;
      expect(split.type, FireflyTransactionType.withdrawal);
      expect(split.sourceName, 'Checking');
      expect(split.destinationName, 'Cafe');
      expect(split.amount, '12.5');
      expect(split.date, '2024-02-03 04:05:06');
      expect(split.description, 'Cafe');
      expect(split.notes, 'Latte');
      expect(split.currencyCode, 'USD');
      expect(split.categoryName, 'Food');
    });

    test('transfer drafts require a configured destination', () async {
      final api = _StubFireflyApiService();
      final configRepository = await _buildConfigRepository();
      final repository = FireflyTransactionRepository(
        configRepository: configRepository,
        apiService: api,
      );

      final draft = AutoImportDraft(
        id: 'draft-2',
        sourcePath: '/tmp/transfer.png',
        detectedAt: DateTime(2024, 3, 3),
        status: AutoImportStatus.pending,
        amount: 42,
        type: ReceiptTransactionType.transfer,
      );

      expect(
        () => repository.createFromDraft(
          draft,
          assetAccountOverride: 'Checking',
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('destination account'),
          ),
        ),
      );
    });

    test('updateFromDraft falls back to create on 404', () async {
      final api = _StubFireflyApiService()..throwOnUpdate = true;
      final configRepository = await _buildConfigRepository(
        config: const FireflyConfig(
          baseUrl: 'https://firefly.test',
          apiToken: 'token',
          expenseAccountName: 'Expenses',
          revenueAccountName: '',
          transferDestinationAccountName: '',
          defaultCurrencyCode: '',
        ),
      );
      final repository = FireflyTransactionRepository(
        configRepository: configRepository,
        apiService: api,
      );

      final draft = AutoImportDraft(
        id: 'draft-3',
        sourcePath: '/tmp/receipt.png',
        detectedAt: DateTime(2024, 2, 3),
        status: AutoImportStatus.pending,
        fireflyTransactionId: 'tx-123',
        amount: 20,
        type: ReceiptTransactionType.expense,
      );

      await repository.updateFromDraft(
        draft,
        assetAccountOverride: 'Checking',
      );

      expect(api.updateCalls, 1);
      expect(api.createCalls, 1);
      expect(api.lastUpdateId, 'tx-123');
    });

    test('updateFromDraft rejects missing transaction id', () async {
      final api = _StubFireflyApiService();
      final configRepository = await _buildConfigRepository();
      final repository = FireflyTransactionRepository(
        configRepository: configRepository,
        apiService: api,
      );
      final draft = AutoImportDraft(
        id: 'draft-4',
        sourcePath: '/tmp/receipt.png',
        detectedAt: DateTime(2024, 2, 3),
        status: AutoImportStatus.pending,
        amount: 20,
        type: ReceiptTransactionType.expense,
      );

      expect(
        () => repository.updateFromDraft(
          draft,
          assetAccountOverride: 'Checking',
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('transaction id is missing'),
          ),
        ),
      );
    });

    test('withdrawals require an asset account override', () async {
      final api = _StubFireflyApiService();
      final configRepository = await _buildConfigRepository();
      final repository = FireflyTransactionRepository(
        configRepository: configRepository,
        apiService: api,
      );
      final draft = AutoImportDraft(
        id: 'draft-5',
        sourcePath: '/tmp/receipt.png',
        detectedAt: DateTime(2024, 2, 3),
        status: AutoImportStatus.pending,
        amount: 20,
        type: ReceiptTransactionType.expense,
      );

      expect(
        () => repository.createFromDraft(draft),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Select an asset account'),
          ),
        ),
      );
    });
  });
}
