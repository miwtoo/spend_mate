import 'package:flutter_test/flutter_test.dart';
import 'package:spend_mate/domain/models/auto_import_draft.dart';
import 'package:spend_mate/domain/models/receipt_parse_result.dart';

void main() {
  group('AutoImportDraft', () {
    test('copyWith updates fields while preserving others', () {
      final draft = AutoImportDraft(
        id: 'draft-1',
        sourcePath: '/tmp/receipt.png',
        detectedAt: DateTime(2024, 1, 1),
        status: AutoImportStatus.pending,
        amount: 10,
      );

      final updated = draft.copyWith(
        status: AutoImportStatus.confirmed,
        amount: 12.5,
        merchant: 'Cafe',
      );

      expect(updated.id, draft.id);
      expect(updated.sourcePath, draft.sourcePath);
      expect(updated.detectedAt, draft.detectedAt);
      expect(updated.status, AutoImportStatus.confirmed);
      expect(updated.amount, 12.5);
      expect(updated.merchant, 'Cafe');
    });

    test('serializes and parses JSON fields', () {
      final draft = AutoImportDraft(
        id: 'draft-2',
        sourcePath: '/tmp/receipt.png',
        detectedAt: DateTime(2024, 2, 2, 3, 4, 5),
        status: AutoImportStatus.failed,
        sourceHash: 'hash',
        fireflyTransactionId: 'tx',
        fireflyTransactionJournalId: 'journal',
        merchant: 'Cafe',
        amount: 9.99,
        currency: 'usd',
        date: DateTime(2024, 2, 1),
        note: 'Note',
        categoryName: 'Food',
        type: ReceiptTransactionType.expense,
        confidence: 0.9,
        assetAccountName: 'Checking',
        errorMessage: 'Error',
      );

      final json = draft.toJson();
      final parsed = AutoImportDraft.fromJson(json);

      expect(parsed.id, draft.id);
      expect(parsed.sourcePath, draft.sourcePath);
      expect(parsed.detectedAt, draft.detectedAt);
      expect(parsed.status, AutoImportStatus.failed);
      expect(parsed.sourceHash, 'hash');
      expect(parsed.fireflyTransactionId, 'tx');
      expect(parsed.fireflyTransactionJournalId, 'journal');
      expect(parsed.merchant, 'Cafe');
      expect(parsed.amount, 9.99);
      expect(parsed.currency, 'usd');
      expect(parsed.date, draft.date);
      expect(parsed.note, 'Note');
      expect(parsed.categoryName, 'Food');
      expect(parsed.type, ReceiptTransactionType.expense);
      expect(parsed.confidence, 0.9);
      expect(parsed.assetAccountName, 'Checking');
      expect(parsed.errorMessage, 'Error');
    });

    test('parses fallback status/type values', () {
      final draft = AutoImportDraft.fromJson({
        'id': 'draft-3',
        'sourcePath': '/tmp/receipt.png',
        'detectedAt': DateTime(2024, 3, 3).toIso8601String(),
        'status': 'processing',
        'type': 'income',
        'amount': '15.50',
      });

      expect(draft.status, AutoImportStatus.processing);
      expect(draft.type, ReceiptTransactionType.income);
      expect(draft.amount, 15.5);
    });
  });
}
