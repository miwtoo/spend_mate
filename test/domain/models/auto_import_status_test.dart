import 'package:flutter_test/flutter_test.dart';
import 'package:spend_mate/domain/models/auto_import_draft.dart';

void main() {
  group('AutoImportStatus', () {
    test('should include processing status for drafts being parsed by AI', () {
      // Verify all required statuses exist
      const statuses = AutoImportStatus.values;

      // Processing status for drafts being parsed by AI
      expect(statuses, contains(AutoImportStatus.processing));

      // Pending approval status for drafts waiting for user confirmation
      expect(statuses, contains(AutoImportStatus.pending));

      // Failed status for drafts that failed AI parsing
      expect(statuses, contains(AutoImportStatus.failed));

      // Confirmed status for drafts saved to Firefly (should be hidden in Auto Import)
      expect(statuses, contains(AutoImportStatus.confirmed));

      // Discarded status for drafts rejected by user
      expect(statuses, contains(AutoImportStatus.discarded));
    });

    test('should have 5 statuses total', () {
      expect(AutoImportStatus.values.length, 5);
    });
  });
}
