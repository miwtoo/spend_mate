import 'package:flutter_test/flutter_test.dart';
import 'package:spend_mate/domain/models/firefly_transaction_ids.dart';

void main() {
  group('FireflyTransactionIds', () {
    test('hasAny reflects presence of ids', () {
      const empty = FireflyTransactionIds();
      const withTransaction = FireflyTransactionIds(transactionId: 'tx');
      const withJournal =
          FireflyTransactionIds(transactionJournalId: 'journal');

      expect(empty.hasAny, isFalse);
      expect(withTransaction.hasAny, isTrue);
      expect(withJournal.hasAny, isTrue);
    });

    test('copyWith keeps existing ids', () {
      const ids = FireflyTransactionIds(
        transactionId: 'tx',
        transactionJournalId: 'journal',
      );

      final updated = ids.copyWith(transactionId: 'tx2');

      expect(updated.transactionId, 'tx2');
      expect(updated.transactionJournalId, 'journal');
    });

    test('copyWith can update journal id', () {
      const ids = FireflyTransactionIds(
        transactionId: 'tx',
        transactionJournalId: 'journal',
      );

      final updated = ids.copyWith(transactionJournalId: 'journal-2');

      expect(updated.transactionJournalId, 'journal-2');
      expect(updated.transactionId, 'tx');
    });
  });
}
