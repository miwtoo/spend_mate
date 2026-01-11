import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spend_mate/config/firefly_config.dart';
import 'package:spend_mate/data/services/firefly/firefly_api_exception.dart';
import 'package:spend_mate/data/services/firefly/firefly_api_service.dart';
import 'package:spend_mate/domain/models/firefly_transaction_request.dart';

void main() {
  group('FireflyApiService.listTransactions', () {
    test('requests the transactions endpoint with date range params', () async {
      Uri? capturedUri;
      final client = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(
          '{"data": []}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final service = FireflyApiService(httpClient: client);
      const config = FireflyConfig(
        baseUrl: 'https://firefly.miwtoo.me',
        apiToken: 'token',
        expenseAccountName: '',
        revenueAccountName: '',
        transferDestinationAccountName: '',
        defaultCurrencyCode: '',
      );

      final start = DateTime(2024, 1, 1);
      final end = DateTime(2024, 1, 31);
      await service.listTransactions(config: config, start: start, end: end);

      expect(capturedUri, isNotNull);
      expect(capturedUri!.path, '/api/v1/transactions');
      expect(capturedUri!.queryParameters['start'], '2024-01-01');
      expect(capturedUri!.queryParameters['end'], '2024-01-31');
      expect(capturedUri!.queryParameters['page'], '1');
    });

    test('throws friendly error on 5xx HTML responses', () async {
      final client = MockClient((request) async {
        return http.Response(
          '<!doctype html><html>Cloudflare</html>',
          502,
          headers: {'content-type': 'text/html'},
        );
      });
      final service = FireflyApiService(httpClient: client);
      const config = FireflyConfig(
        baseUrl: 'https://firefly.miwtoo.me',
        apiToken: 'token',
        expenseAccountName: '',
        revenueAccountName: '',
        transferDestinationAccountName: '',
        defaultCurrencyCode: '',
      );

      await expectLater(
        service.listTransactions(
          config: config,
          start: DateTime(2024, 1, 1),
          end: DateTime(2024, 1, 2),
        ),
        throwsA(
          isA<FireflyApiException>()
              .having((e) => e.statusCode, 'statusCode', 502)
              .having(
                (e) => e.userMessage,
                'userMessage',
                contains('server is unreachable'),
              )
              .having(
                (e) => e.userMessage,
                'userMessage',
                contains('temporary issue'),
              )
              .having(
                (e) => e.userMessage,
                'userMessage',
                isNot(contains('<')),
              ),
        ),
      );
    });

    test('throws gateway error on 503 Service Unavailable', () async {
      final client = MockClient((request) async {
        return http.Response(
          'Service Unavailable',
          503,
          headers: {'content-type': 'text/plain'},
        );
      });
      final service = FireflyApiService(httpClient: client);
      const config = FireflyConfig(
        baseUrl: 'https://firefly.miwtoo.me',
        apiToken: 'token',
        expenseAccountName: '',
        revenueAccountName: '',
        transferDestinationAccountName: '',
        defaultCurrencyCode: '',
      );

      await expectLater(
        service.listTransactions(
          config: config,
          start: DateTime(2024, 1, 1),
          end: DateTime(2024, 1, 2),
        ),
        throwsA(
          isA<FireflyApiException>()
              .having((e) => e.statusCode, 'statusCode', 503)
              .having(
                (e) => e.userMessage,
                'userMessage',
                contains('temporarily unavailable'),
              )
              .having(
                (e) => e.userMessage,
                'userMessage',
                contains('try again in a moment'),
              ),
        ),
      );
    });

    test('throws gateway error on 504 Gateway Timeout', () async {
      final client = MockClient((request) async {
        return http.Response(
          'Gateway Timeout',
          504,
          headers: {'content-type': 'text/plain'},
        );
      });
      final service = FireflyApiService(httpClient: client);
      const config = FireflyConfig(
        baseUrl: 'https://firefly.miwtoo.me',
        apiToken: 'token',
        expenseAccountName: '',
        revenueAccountName: '',
        transferDestinationAccountName: '',
        defaultCurrencyCode: '',
      );

      await expectLater(
        service.listTransactions(
          config: config,
          start: DateTime(2024, 1, 1),
          end: DateTime(2024, 1, 2),
        ),
        throwsA(
          isA<FireflyApiException>()
              .having((e) => e.statusCode, 'statusCode', 504)
              .having(
                (e) => e.userMessage,
                'userMessage',
                contains('timed out'),
              )
              .having(
                (e) => e.userMessage,
                'userMessage',
                contains('try again'),
              ),
        ),
      );
    });

    test('throws unexpected response on non-JSON HTML body', () async {
      final client = MockClient((request) async {
        return http.Response(
          '<html><body>not json</body></html>',
          200,
          headers: {'content-type': 'text/html'},
        );
      });
      final service = FireflyApiService(httpClient: client);
      const config = FireflyConfig(
        baseUrl: 'https://firefly.miwtoo.me',
        apiToken: 'token',
        expenseAccountName: '',
        revenueAccountName: '',
        transferDestinationAccountName: '',
        defaultCurrencyCode: '',
      );

      await expectLater(
        service.listTransactions(
          config: config,
          start: DateTime(2024, 1, 1),
          end: DateTime(2024, 1, 2),
        ),
        throwsA(
          isA<FireflyApiException>().having(
            (e) => e.userMessage,
            'userMessage',
            contains('unexpected response'),
          ),
        ),
      );
    });

    test('throws malformed data on invalid JSON', () async {
      final client = MockClient((request) async {
        return http.Response(
          '{not-json',
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final service = FireflyApiService(httpClient: client);
      const config = FireflyConfig(
        baseUrl: 'https://firefly.miwtoo.me',
        apiToken: 'token',
        expenseAccountName: '',
        revenueAccountName: '',
        transferDestinationAccountName: '',
        defaultCurrencyCode: '',
      );

      await expectLater(
        service.listTransactions(
          config: config,
          start: DateTime(2024, 1, 1),
          end: DateTime(2024, 1, 2),
        ),
        throwsA(
          isA<FireflyApiException>().having(
            (e) => e.userMessage,
            'userMessage',
            contains('malformed data'),
          ),
        ),
      );
    });

    test('throws authentication error on 302 redirect', () async {
      final client = MockClient((request) async {
        return http.Response(
          '<!doctype html><html><body>Redirecting to login...</body></html>',
          302,
          headers: {
            'content-type': 'text/html',
            'location': '/login',
          },
        );
      });
      final service = FireflyApiService(httpClient: client);
      const config = FireflyConfig(
        baseUrl: 'https://firefly.miwtoo.me',
        apiToken: 'invalid-token',
        expenseAccountName: '',
        revenueAccountName: '',
        transferDestinationAccountName: '',
        defaultCurrencyCode: '',
      );

      await expectLater(
        service.listTransactions(
          config: config,
          start: DateTime(2024, 1, 1),
          end: DateTime(2024, 1, 2),
        ),
        throwsA(
          isA<FireflyApiException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having(
                (e) => e.userMessage,
                'userMessage',
                contains('Authentication failed'),
              )
              .having(
                (e) => e.userMessage,
                'userMessage',
                contains('API token'),
              ),
        ),
      );
    });

    test('throws authentication error on 301 redirect', () async {
      final client = MockClient((request) async {
        return http.Response(
          '',
          301,
          headers: {
            'location': 'https://firefly.miwtoo.me/login',
          },
        );
      });
      final service = FireflyApiService(httpClient: client);
      const config = FireflyConfig(
        baseUrl: 'https://firefly.miwtoo.me',
        apiToken: 'expired-token',
        expenseAccountName: '',
        revenueAccountName: '',
        transferDestinationAccountName: '',
        defaultCurrencyCode: '',
      );

      await expectLater(
        service.listTransactions(
          config: config,
          start: DateTime(2024, 1, 1),
          end: DateTime(2024, 1, 2),
        ),
        throwsA(
          isA<FireflyApiException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having(
                (e) => e.userMessage,
                'userMessage',
                contains('Authentication failed'),
              ),
        ),
      );
    });
  });

  group('FireflyApiService transaction mutations', () {
    test('createTransaction parses transaction ids', () async {
      final client = MockClient((request) async {
        return http.Response(
          '{"data": {"id": "1", "attributes": {"transactions": [{"transaction_journal_id": "99"}]}}}',
          201,
          headers: {'content-type': 'application/json'},
        );
      });
      final service = FireflyApiService(httpClient: client);
      const config = FireflyConfig(
        baseUrl: 'https://firefly.miwtoo.me',
        apiToken: 'token',
        expenseAccountName: '',
        revenueAccountName: '',
        transferDestinationAccountName: '',
        defaultCurrencyCode: '',
      );
      const request = FireflyTransactionRequest(
        transactions: [
          FireflyTransactionSplit(
            type: FireflyTransactionType.withdrawal,
            date: '2024-01-01 00:00:00',
            amount: '5.00',
            description: 'Test',
            sourceName: 'Checking',
            destinationName: 'Cafe',
          ),
        ],
      );

      final ids = await service.createTransaction(
        config: config,
        request: request,
      );

      expect(ids.transactionId, '1');
      expect(ids.transactionJournalId, '99');
    });

    test('updateTransaction parses fallback journal id from split', () async {
      final client = MockClient((request) async {
        return http.Response(
          '{"data": {"id": "2", "attributes": {"transactions": [{"id": "55"}]}}}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final service = FireflyApiService(httpClient: client);
      const config = FireflyConfig(
        baseUrl: 'https://firefly.miwtoo.me',
        apiToken: 'token',
        expenseAccountName: '',
        revenueAccountName: '',
        transferDestinationAccountName: '',
        defaultCurrencyCode: '',
      );
      const request = FireflyTransactionRequest(
        transactions: [
          FireflyTransactionSplit(
            type: FireflyTransactionType.deposit,
            date: '2024-01-01 00:00:00',
            amount: '25',
            description: 'Test',
            sourceName: 'Income',
            destinationName: 'Checking',
          ),
        ],
      );

      final ids = await service.updateTransaction(
        config: config,
        transactionId: '2',
        request: request,
      );

      expect(ids.transactionId, '2');
      expect(ids.transactionJournalId, '55');
    });
  });

  group('FireflyApiService reference data', () {
    test('listAssetAccounts parses and sorts accounts', () async {
      final client = MockClient((request) async {
        return http.Response(
          '{"data": [{"id": "2", "attributes": {"name": "Beta"}}, {"id": "1", "attributes": {"name": "Alpha"}}]}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final service = FireflyApiService(httpClient: client);
      const config = FireflyConfig(
        baseUrl: 'https://firefly.miwtoo.me',
        apiToken: 'token',
        expenseAccountName: '',
        revenueAccountName: '',
        transferDestinationAccountName: '',
        defaultCurrencyCode: '',
      );

      final accounts = await service.listAssetAccounts(config: config);

      expect(accounts.length, 2);
      expect(accounts.first.name, 'Alpha');
      expect(accounts.last.name, 'Beta');
    });

    test('listCategories parses category list', () async {
      final client = MockClient((request) async {
        return http.Response(
          '{"data": [{"id": "c1", "attributes": {"name": "Food"}}]}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final service = FireflyApiService(httpClient: client);
      const config = FireflyConfig(
        baseUrl: 'https://firefly.miwtoo.me',
        apiToken: 'token',
        expenseAccountName: '',
        revenueAccountName: '',
        transferDestinationAccountName: '',
        defaultCurrencyCode: '',
      );

      final categories = await service.listCategories(config: config);

      expect(categories.length, 1);
      expect(categories.first.name, 'Food');
    });
  });
}
