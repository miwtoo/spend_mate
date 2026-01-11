import 'package:flutter_test/flutter_test.dart';
import 'package:spend_mate/domain/models/firefly_transaction_request.dart';

void main() {
  group('FireflyTransactionRequest', () {
    test('serializes with optional fields when present', () {
      const split = FireflyTransactionSplit(
        type: FireflyTransactionType.withdrawal,
        date: '2024-01-01 00:00:00',
        amount: '12.5',
        description: 'Coffee',
        sourceName: 'Checking',
        destinationName: 'Cafe',
        transactionJournalId: 'journal-1',
        currencyCode: 'USD',
        notes: 'Morning latte',
        categoryName: 'Food',
      );

      const request = FireflyTransactionRequest(
        transactions: [split],
        applyRules: false,
        fireWebhooks: false,
        errorIfDuplicateHash: true,
        groupTitle: 'Group',
      );

      final json = request.toJson();

      expect(json['apply_rules'], false);
      expect(json['fire_webhooks'], false);
      expect(json['error_if_duplicate_hash'], true);
      expect(json['group_title'], 'Group');
      final tx = (json['transactions'] as List).first as Map<String, dynamic>;
      expect(tx['transaction_journal_id'], 'journal-1');
      expect(tx['currency_code'], 'USD');
      expect(tx['notes'], 'Morning latte');
      expect(tx['category_name'], 'Food');
    });

    test('omits empty optional fields', () {
      const split = FireflyTransactionSplit(
        type: FireflyTransactionType.deposit,
        date: '2024-01-01 00:00:00',
        amount: '100',
        description: 'Paycheck',
        sourceName: 'Income',
        destinationName: 'Checking',
        transactionJournalId: '   ',
        currencyCode: '',
        notes: '',
        categoryName: ' ',
      );

      const request = FireflyTransactionRequest(
        transactions: [split],
        groupTitle: '  ',
      );

      final json = request.toJson();
      final tx = (json['transactions'] as List).first as Map<String, dynamic>;

      expect(json.containsKey('group_title'), isFalse);
      expect(tx.containsKey('transaction_journal_id'), isFalse);
      expect(tx.containsKey('currency_code'), isFalse);
      expect(tx.containsKey('notes'), isFalse);
      expect(tx.containsKey('category_name'), isFalse);
    });
  });
}
