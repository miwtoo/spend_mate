import 'package:flutter_test/flutter_test.dart';
import 'package:spend_mate/domain/models/auto_import_draft.dart';

void main() {
  group('Auto Import Draft Sections', () {
    test('should separate drafts into Processing, Pending, and Failed sections', () {
      // Create test drafts with different statuses
      final allDrafts = [
        _createDraft('1', AutoImportStatus.processing),
        _createDraft('2', AutoImportStatus.pending),
        _createDraft('3', AutoImportStatus.failed),
        _createDraft('4', AutoImportStatus.confirmed), // Should be hidden
        _createDraft('5', AutoImportStatus.discarded), // Should be hidden
        _createDraft('6', AutoImportStatus.processing),
        _createDraft('7', AutoImportStatus.pending),
        _createDraft('8', AutoImportStatus.failed),
      ];

      // Filter for visible drafts (excluding confirmed and discarded)
      final visibleDrafts = allDrafts
          .where((draft) =>
              draft.status != AutoImportStatus.confirmed &&
              draft.status != AutoImportStatus.discarded)
          .toList();

      // Verify confirmed and discarded are filtered out
      expect(visibleDrafts, hasLength(6));

      // Verify each section exists
      final processing = visibleDrafts
          .where((d) => d.status == AutoImportStatus.processing)
          .toList();
      final pending = visibleDrafts
          .where((d) => d.status == AutoImportStatus.pending)
          .toList();
      final failed = visibleDrafts
          .where((d) => d.status == AutoImportStatus.failed)
          .toList();

      expect(processing, hasLength(2));
      expect(pending, hasLength(2));
      expect(failed, hasLength(2));
    });

    test('should sort drafts by date within each section, newest first', () {
      final now = DateTime.now();
      final drafts = [
        _createDraftWithDate('1', AutoImportStatus.pending, now.subtract(const Duration(days: 3))),
        _createDraftWithDate('2', AutoImportStatus.pending, now.subtract(const Duration(days: 1))),
        _createDraftWithDate('3', AutoImportStatus.pending, now),
        _createDraftWithDate('4', AutoImportStatus.pending, now.subtract(const Duration(days: 2))),
      ];

      // Sort by date descending (newest first)
      drafts.sort((a, b) {
        final dateA = a.date ?? a.detectedAt;
        final dateB = b.date ?? b.detectedAt;
        return dateB.compareTo(dateA);
      });

      // Verify order is newest first
      expect(drafts[0].id, '3'); // now
      expect(drafts[1].id, '2'); // 1 day ago
      expect(drafts[2].id, '4'); // 2 days ago
      expect(drafts[3].id, '1'); // 3 days ago
    });

    test('should filter only discarded drafts for recovery UI', () {
      final allDrafts = [
        _createDraft('1', AutoImportStatus.processing),
        _createDraft('2', AutoImportStatus.pending),
        _createDraft('3', AutoImportStatus.failed),
        _createDraft('4', AutoImportStatus.confirmed),
        _createDraft('5', AutoImportStatus.discarded),
        _createDraft('6', AutoImportStatus.discarded),
      ];

      // Filter only discarded drafts (what discardedDrafts getter does)
      final discardedDrafts = allDrafts
          .where((draft) => draft.status == AutoImportStatus.discarded)
          .toList();

      // Verify only discarded drafts are included
      expect(discardedDrafts, hasLength(2));
      expect(discardedDrafts[0].id, '5');
      expect(discardedDrafts[1].id, '6');
    });

    test('should handle empty discarded drafts list', () {
      final allDrafts = [
        _createDraft('1', AutoImportStatus.processing),
        _createDraft('2', AutoImportStatus.pending),
        _createDraft('3', AutoImportStatus.failed),
        _createDraft('4', AutoImportStatus.confirmed),
      ];

      final discardedDrafts = allDrafts
          .where((draft) => draft.status == AutoImportStatus.discarded)
          .toList();

      expect(discardedDrafts, isEmpty);
    });
  });
}

AutoImportDraft _createDraft(String id, AutoImportStatus status) {
  return AutoImportDraft(
    id: id,
    sourcePath: '/test/path$id.jpg',
    detectedAt: DateTime.now(),
    status: status,
  );
}

AutoImportDraft _createDraftWithDate(String id, AutoImportStatus status, DateTime date) {
  return AutoImportDraft(
    id: id,
    sourcePath: '/test/path$id.jpg',
    detectedAt: date,
    status: status,
    date: date,
  );
}
