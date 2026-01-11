import 'package:flutter_test/flutter_test.dart';
import 'package:spend_mate/domain/models/auto_import_draft.dart';
import 'package:spend_mate/domain/models/auto_import_state.dart';

void main() {
  group('AutoImportState', () {
    test('creates empty state', () {
      final state = AutoImportState.empty();

      expect(state.enabled, false);
      expect(state.folderPaths, isEmpty);
      expect(state.assetAccountByFolder, isEmpty);
      expect(state.drafts, isEmpty);
      expect(state.processedFiles, isEmpty);
      expect(state.lastScanAt, null);
    });

    test('copyWith updates fields while preserving others', () {
      final now = DateTime(2024, 1, 1, 12, 0);
      final state = AutoImportState(
        enabled: true,
        folderPaths: const ['/path/to/folder'],
        assetAccountByFolder: const {'/path/to/folder': 'Cash'},
        drafts: [
          AutoImportDraft(
            id: 'draft-1',
            sourcePath: '/tmp/receipt.png',
            detectedAt: now,
            status: AutoImportStatus.pending,
          ),
        ],
        processedFiles: const ['file1'],
        lastScanAt: null,
      );

      final updated = state.copyWith(
        enabled: false,
        drafts: [
          AutoImportDraft(
            id: 'draft-1',
            sourcePath: '/tmp/receipt.png',
            detectedAt: now,
            status: AutoImportStatus.discarded,
          ),
        ],
      );

      expect(updated.enabled, false);
      expect(updated.folderPaths, state.folderPaths);
      expect(updated.assetAccountByFolder, state.assetAccountByFolder);
      expect(updated.drafts.first.status, AutoImportStatus.discarded);
      expect(updated.processedFiles, state.processedFiles);
      expect(updated.lastScanAt, state.lastScanAt);
    });

    test('serializes and parses JSON with discarded drafts', () {
      final now = DateTime(2024, 1, 1, 12, 0);
      final state = AutoImportState(
        enabled: true,
        folderPaths: const ['/path/to/folder'],
        assetAccountByFolder: const {'/path/to/folder': 'Cash'},
        drafts: [
          AutoImportDraft(
            id: 'draft-1',
            sourcePath: '/tmp/receipt1.png',
            detectedAt: now,
            status: AutoImportStatus.pending,
          ),
          AutoImportDraft(
            id: 'draft-2',
            sourcePath: '/tmp/receipt2.png',
            detectedAt: now.add(const Duration(days: 1)),
            status: AutoImportStatus.discarded,
          ),
        ],
        processedFiles: const ['file1'],
        lastScanAt: DateTime(2024, 1, 1, 12, 0),
      );

      final json = state.toJson();
      final parsed = AutoImportState.fromJson(json);

      expect(parsed.enabled, state.enabled);
      expect(parsed.folderPaths, state.folderPaths);
      expect(parsed.assetAccountByFolder, state.assetAccountByFolder);
      expect(parsed.drafts.length, 2);
      expect(parsed.drafts[0].status, AutoImportStatus.pending);
      expect(parsed.drafts[1].status, AutoImportStatus.discarded);
      expect(parsed.processedFiles, state.processedFiles);
      expect(parsed.lastScanAt, state.lastScanAt);
    });

    test('handles discarded drafts when filtering visible drafts', () {
      final now = DateTime(2024, 1, 1, 12, 0);
      final state = AutoImportState(
        enabled: true,
        folderPaths: const ['/path'],
        assetAccountByFolder: const {},
        drafts: [
          AutoImportDraft(
            id: 'draft-1',
            sourcePath: '/tmp/receipt1.png',
            detectedAt: now,
            status: AutoImportStatus.pending,
          ),
          AutoImportDraft(
            id: 'draft-2',
            sourcePath: '/tmp/receipt2.png',
            detectedAt: now.add(const Duration(days: 1)),
            status: AutoImportStatus.discarded,
          ),
          AutoImportDraft(
            id: 'draft-3',
            sourcePath: '/tmp/receipt3.png',
            detectedAt: now.add(const Duration(days: 2)),
            status: AutoImportStatus.confirmed,
          ),
          AutoImportDraft(
            id: 'draft-4',
            sourcePath: '/tmp/receipt4.png',
            detectedAt: now.add(const Duration(days: 3)),
            status: AutoImportStatus.failed,
          ),
        ],
        processedFiles: const [],
        lastScanAt: null,
      );

      // Filter out discarded and confirmed drafts (what visibleDrafts does)
      final visibleDrafts = state.drafts
          .where((draft) =>
              draft.status != AutoImportStatus.discarded &&
              draft.status != AutoImportStatus.confirmed)
          .toList();

      expect(visibleDrafts.length, 2);
      expect(visibleDrafts[0].id, 'draft-1');
      expect(visibleDrafts[1].id, 'draft-4');
    });

    test('filters only discarded drafts', () {
      final now = DateTime(2024, 1, 1, 12, 0);
      final state = AutoImportState(
        enabled: true,
        folderPaths: const ['/path'],
        assetAccountByFolder: const {},
        drafts: [
          AutoImportDraft(
            id: 'draft-1',
            sourcePath: '/tmp/receipt1.png',
            detectedAt: now,
            status: AutoImportStatus.pending,
          ),
          AutoImportDraft(
            id: 'draft-2',
            sourcePath: '/tmp/receipt2.png',
            detectedAt: now.add(const Duration(days: 1)),
            status: AutoImportStatus.discarded,
          ),
          AutoImportDraft(
            id: 'draft-3',
            sourcePath: '/tmp/receipt3.png',
            detectedAt: now.add(const Duration(days: 2)),
            status: AutoImportStatus.confirmed,
          ),
        ],
        processedFiles: const [],
        lastScanAt: null,
      );

      // Filter only discarded drafts (what discardedDrafts getter does)
      final discardedDrafts = state.drafts
          .where((draft) => draft.status == AutoImportStatus.discarded)
          .toList();

      expect(discardedDrafts.length, 1);
      expect(discardedDrafts[0].id, 'draft-2');
      expect(discardedDrafts[0].status, AutoImportStatus.discarded);
    });
  });

  group('AutoImportDraft restore functionality', () {
    test('copyWith can change status from discarded to pending', () {
      final now = DateTime(2024, 1, 1, 12, 0);
      final discarded = AutoImportDraft(
        id: 'draft-1',
        sourcePath: '/tmp/receipt.png',
        detectedAt: now,
        status: AutoImportStatus.discarded,
        merchant: 'Cafe',
        amount: 10.0,
      );

      final restored = discarded.copyWith(status: AutoImportStatus.pending);

      expect(restored.id, discarded.id);
      expect(restored.sourcePath, discarded.sourcePath);
      expect(restored.detectedAt, discarded.detectedAt);
      expect(restored.merchant, discarded.merchant);
      expect(restored.amount, discarded.amount);
      expect(restored.status, AutoImportStatus.pending);
    });

    test('serializes and parses discarded status', () {
      final now = DateTime(2024, 1, 1, 12, 0);
      final draft = AutoImportDraft(
        id: 'draft-1',
        sourcePath: '/tmp/receipt.png',
        detectedAt: now,
        status: AutoImportStatus.discarded,
        merchant: 'Cafe',
        amount: 10.0,
      );

      final json = draft.toJson();
      final parsed = AutoImportDraft.fromJson(json);

      expect(parsed.id, draft.id);
      expect(parsed.status, AutoImportStatus.discarded);
      expect(parsed.merchant, draft.merchant);
      expect(parsed.amount, draft.amount);
      expect(parsed.detectedAt, draft.detectedAt);
    });
  });
}
