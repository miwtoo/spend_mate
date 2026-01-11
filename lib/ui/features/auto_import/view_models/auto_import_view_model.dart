import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:spend_mate/data/repositories/ai_provider_config_repository.dart';
import 'package:spend_mate/data/repositories/auto_import_repository.dart';
import 'package:spend_mate/data/repositories/firefly_account_repository.dart';
import 'package:spend_mate/data/repositories/firefly_category_repository.dart';
import 'package:spend_mate/data/repositories/firefly_config_repository.dart';
import 'package:spend_mate/data/repositories/firefly_transaction_repository.dart';
import 'package:spend_mate/data/services/ai/receipt_ai_parser.dart';
import 'package:spend_mate/data/services/firefly/firefly_api_service.dart';
import 'package:spend_mate/domain/models/auto_import_draft.dart';
import 'package:spend_mate/domain/models/auto_import_state.dart';
import 'package:spend_mate/domain/models/firefly_account.dart';
import 'package:spend_mate/domain/models/firefly_category.dart';
import 'package:spend_mate/domain/models/firefly_transaction_summary.dart';
import 'package:spend_mate/domain/models/receipt_parse_result.dart';

class AutoImportViewModel extends ChangeNotifier {
  AutoImportViewModel({
    required AiProviderConfigRepository configRepository,
    required FireflyConfigRepository fireflyConfigRepository,
  })  : _configRepository = configRepository,
        _fireflyConfigRepository = fireflyConfigRepository;

  final AiProviderConfigRepository _configRepository;
  final FireflyConfigRepository _fireflyConfigRepository;

  AutoImportRepository? _repository;
  ReceiptAiParser? _parser;
  FireflyAccountRepository? _fireflyAccountRepository;
  FireflyCategoryRepository? _fireflyCategoryRepository;
  FireflyTransactionRepository? _fireflyRepository;
  FireflyApiService? _fireflyApiService;
  AutoImportState _state = AutoImportState.empty();
  Timer? _scanTimer;
  bool _isScanning = false;
  bool _isRetrying = false;
  String? _activeRetryId;
  List<String> _retryQueueIds = const [];
  int _retryRemaining = 0;
  String? _error;
  bool _isLoadingAssets = false;
  List<FireflyAccount> _assetAccounts = const [];
  bool _isLoadingMerchants = false;
  List<String> _merchantSuggestions = const [];
  bool _isLoadingCategories = false;
  List<FireflyCategory> _categories = const [];
  bool _disposed = false;

  // Batch save state
  bool _isSavingAll = false;
  String? _activeSaveId;
  List<String> _saveQueueIds = const [];
  int _saveRemaining = 0;

  static const Duration scanInterval = Duration(seconds: 30);
  static const Duration retryDelay = Duration(seconds: 2);
  static const Duration saveDelay = Duration(milliseconds: 500);
  static const int maxAttachmentBytes = 8 * 1024 * 1024;
  static const int maxProcessedFiles = 500;
  static const int maxFilesPerScan = 5;
  static const String _hashPrefix = 'md5:';

  bool get enabled => _state.enabled;
  List<String> get folderPaths => List.unmodifiable(_state.folderPaths);
  List<AutoImportDraft> get visibleDrafts => _state.drafts
      .where((draft) =>
          draft.status != AutoImportStatus.discarded &&
          draft.status != AutoImportStatus.confirmed)
      .toList(growable: false);

  List<AutoImportDraft> get discardedDrafts => _state.drafts
      .where((draft) => draft.status == AutoImportStatus.discarded)
      .toList(growable: false);
  DateTime? get lastScanAt => _state.lastScanAt;
  bool get isScanning => _isScanning;
  bool get isRetrying => _isRetrying;
  String? get activeRetryId => _activeRetryId;
  List<String> get retryQueueIds => List.unmodifiable(_retryQueueIds);
  int get retryRemaining => _retryRemaining;
  String? get error => _error;
  bool get isLoadingAssets => _isLoadingAssets;
  List<FireflyAccount> get assetAccounts => List.unmodifiable(_assetAccounts);
  bool get isLoadingMerchants => _isLoadingMerchants;
  List<String> get merchantSuggestions =>
      List.unmodifiable(_merchantSuggestions);
  bool get isLoadingCategories => _isLoadingCategories;
  List<String> get categorySuggestions => List.unmodifiable(
        _categories.map((category) => category.name),
      );

  // Batch save getters
  bool get isSavingAll => _isSavingAll;
  String? get activeSaveId => _activeSaveId;
  List<String> get saveQueueIds => List.unmodifiable(_saveQueueIds);
  int get saveRemaining => _saveRemaining;

  String? assetAccountForFolder(String folder) {
    final normalized = _normalizeFolderPath(folder);
    if (normalized.trim().isEmpty) return null;
    return _state.assetAccountByFolder[normalized];
  }

  Future<void> initialize() async {
    _repository = await AutoImportRepository.create();
    _parser = ReceiptAiParser(configRepository: _configRepository);
    _fireflyApiService = FireflyApiService();
    _fireflyAccountRepository = FireflyAccountRepository(
      configRepository: _fireflyConfigRepository,
      apiService: _fireflyApiService!,
    );
    _fireflyCategoryRepository = FireflyCategoryRepository(
      configRepository: _fireflyConfigRepository,
      apiService: _fireflyApiService!,
    );
    _fireflyRepository = FireflyTransactionRepository(
      configRepository: _fireflyConfigRepository,
      apiService: _fireflyApiService!,
    );
    _state = _normalizeState(await _repository!.load());
    unawaited(refreshAssetAccounts());
    unawaited(refreshMerchantSuggestions());
    unawaited(refreshCategories());

    if (_state.enabled) {
      _startTimer();
      unawaited(scanNow());
    }

    _notifySafely();
  }

  void clearError() {
    _error = null;
    _notifySafely();
  }

  void setError(String message) {
    _error = message;
    _notifySafely();
  }

  Future<void> addFolderPath(String? path) async {
    if (path == null || path.trim().isEmpty) return;
    final normalized = _normalizeFolderPath(path);
    if (_isContentUri(normalized)) {
      _error =
          'Selected folder uses a document URI that cannot be scanned yet. '
          'Choose a local folder on device storage.';
      _notifySafely();
      return;
    }

    final existing = _state.folderPaths.map(_normalizeFolderPath).toSet();
    if (existing.contains(normalized)) return;

    final updatedAssetMap = Map<String, String>.from(
      _state.assetAccountByFolder,
    );

    _state = _state.copyWith(
      folderPaths: [..._state.folderPaths, normalized],
      assetAccountByFolder: updatedAssetMap,
    );
    await _saveState();

    if (_state.enabled) {
      _startTimer();
      await scanNow();
    }

    _notifySafely();
  }

  Future<void> removeFolderPath(String folder) async {
    final normalized = _normalizeFolderPath(folder);
    final updatedFolders = _state.folderPaths
        .map(_normalizeFolderPath)
        .where((path) => path != normalized)
        .toList(growable: false);
    if (updatedFolders.length == _state.folderPaths.length) return;

    await _deleteImagesForFolder(normalized);

    final updatedAssetMap = Map<String, String>.from(
      _state.assetAccountByFolder,
    )..removeWhere(
        (key, _) => _normalizeFolderPath(key) == normalized,
      );

    var updatedEnabled = _state.enabled;
    if (updatedFolders.isEmpty && updatedEnabled) {
      updatedEnabled = false;
      _stopTimer();
    }

    _state = _state.copyWith(
      enabled: updatedEnabled,
      folderPaths: updatedFolders,
      assetAccountByFolder: updatedAssetMap,
    );
    await _saveState();
    _notifySafely();
  }

  Future<void> setEnabled(bool enabled) async {
    if (_state.enabled == enabled) return;
    if (enabled && _state.folderPaths.isEmpty) {
      _error = 'Select at least one folder before enabling auto import.';
      _notifySafely();
      return;
    }
    _state = _state.copyWith(enabled: enabled);
    await _saveState();

    if (enabled) {
      _startTimer();
      await scanNow();
    } else {
      _stopTimer();
    }

    _notifySafely();
  }

  Future<void> scanNow() async {
    if (_isScanning) return;
    if (_repository == null || _parser == null) return;
    final folderPaths = _state.folderPaths
        .map(_normalizeFolderPath)
        .where((path) => path.trim().isNotEmpty)
        .toList(growable: false);
    if (folderPaths.isEmpty) {
      _error = 'Select at least one folder before scanning.';
      _notifySafely();
      return;
    }

    if (!await _ensureMediaAccess()) {
      _notifySafely();
      return;
    }

    _isScanning = true;
    _notifySafely();

    try {
      final processed = List<String>.from(_state.processedFiles);
      final processedSet = processed.toSet();
      final newDrafts = <AutoImportDraft>[];
      final errors = <String>[];

      var processedCount = 0;

      Future<void> scanFolder(
        Directory folder, {
        required bool recursive,
        required void Function() onFileProcessed,
      }) async {
        await for (final entity in folder.list(
          followLinks: false,
          recursive: recursive,
        )) {
          if (processedCount >= maxFilesPerScan) break;
          if (entity is! File) continue;
          if (!_isImagePath(entity.path)) continue;

          final stat = await entity.stat();
          final legacyKey = _buildLegacyFileKey(entity.path, stat);
          if (processedSet.contains(legacyKey)) continue;

          final bytes = await entity.readAsBytes();
          final hash = _hashBytes(bytes);
          final hashKey = _buildHashKey(hash);
          if (processedSet.contains(hashKey)) continue;

          processedSet.add(hashKey);
          processed.add(hashKey);

          final draft = await _analyzeFile(
            entity,
            bytes: bytes,
            sourceHash: hash,
          );
          newDrafts.add(draft);
          processedCount += 1;
          onFileProcessed();
        }
      }

      for (final folderPath in folderPaths) {
        if (processedCount >= maxFilesPerScan) break;
        if (_isContentUri(folderPath)) {
          errors.add(
            'Folder uses a document URI and cannot be scanned yet: $folderPath',
          );
          continue;
        }

        final folder = Directory(folderPath);
        if (!await folder.exists()) {
          errors.add('Folder no longer exists: $folderPath');
          continue;
        }

        var folderProcessed = 0;
        await scanFolder(
          folder,
          recursive: false,
          onFileProcessed: () => folderProcessed += 1,
        );
        if (folderProcessed == 0) {
          await scanFolder(
            folder,
            recursive: true,
            onFileProcessed: () => folderProcessed += 1,
          );
        }
      }

      final trimmedProcessed = processed.length > maxProcessedFiles
          ? processed.sublist(processed.length - maxProcessedFiles)
          : processed;

      _state = _state.copyWith(
        drafts: [..._state.drafts, ...newDrafts],
        processedFiles: trimmedProcessed,
        lastScanAt: DateTime.now(),
      );
      await _saveState();
      if (errors.isNotEmpty) {
        _error = errors.first;
      }
    } catch (e) {
      _error = 'Scan failed: $e';
    } finally {
      _isScanning = false;
      _notifySafely();
    }
  }

  Future<void> confirmDraft(String id) async {
    final targetIndex = _state.drafts.indexWhere((draft) => draft.id == id);
    if (targetIndex == -1 || _fireflyRepository == null) return;
    final target = _state.drafts[targetIndex];
    final assetOverride =
        target.assetAccountName ?? _assetAccountForPath(target.sourcePath);

    try {
      final created = await _fireflyRepository!.createFromDraft(
        target,
        assetAccountOverride: assetOverride,
      );
      _state = _state.copyWith(
        drafts: _state.drafts
            .map((draft) => draft.id == id
                ? draft.copyWith(
                    status: AutoImportStatus.confirmed,
                    errorMessage: null,
                    fireflyTransactionId:
                        created.transactionId ?? draft.fireflyTransactionId,
                    fireflyTransactionJournalId: created.transactionJournalId ??
                        draft.fireflyTransactionJournalId,
                  )
                : draft)
            .toList(growable: false),
      );
      _error = null;
    } catch (e) {
      _state = _state.copyWith(
        drafts: _state.drafts
            .map((draft) => draft.id == id
                ? draft.copyWith(errorMessage: e.toString())
                : draft)
            .toList(growable: false),
      );
      _error = 'Confirm failed: $e';
    }

    await _saveState();
    _notifySafely();
  }

  Future<void> updateConfirmedDraft(String id) async {
    final targetIndex = _state.drafts.indexWhere((draft) => draft.id == id);
    if (targetIndex == -1 || _fireflyRepository == null) return;
    final target = _state.drafts[targetIndex];
    final assetOverride =
        target.assetAccountName ?? _assetAccountForPath(target.sourcePath);

    if (target.fireflyTransactionId?.trim().isEmpty ?? true) {
      _state = _state.copyWith(
        drafts: _state.drafts
            .map((draft) => draft.id == id
                ? draft.copyWith(
                    errorMessage:
                        'Missing Firefly transaction id. Re-submit the draft.',
                  )
                : draft)
            .toList(growable: false),
      );
      _error = 'Update failed: missing Firefly transaction id for this draft.';
      await _saveState();
      _notifySafely();
      return;
    }

    try {
      final updated = await _fireflyRepository!.updateFromDraft(
        target,
        assetAccountOverride: assetOverride,
      );
      _state = _state.copyWith(
        drafts: _state.drafts
            .map((draft) => draft.id == id
                ? draft.copyWith(
                    status: AutoImportStatus.confirmed,
                    errorMessage: null,
                    fireflyTransactionId:
                        updated.transactionId ?? draft.fireflyTransactionId,
                    fireflyTransactionJournalId: updated.transactionJournalId ??
                        draft.fireflyTransactionJournalId,
                  )
                : draft)
            .toList(growable: false),
      );
      _error = null;
    } catch (e) {
      _state = _state.copyWith(
        drafts: _state.drafts
            .map((draft) => draft.id == id
                ? draft.copyWith(errorMessage: e.toString())
                : draft)
            .toList(growable: false),
      );
      _error = 'Update failed: $e';
    }

    await _saveState();
    _notifySafely();
  }

  Future<List<FireflyTransactionSummary>> findExistingTransactions(
    AutoImportDraft draft,
  ) async {
    if (_fireflyRepository == null) return const [];
    final base = draft.date ?? draft.detectedAt;
    final start = base.subtract(const Duration(days: 7));
    final end = base.add(const Duration(days: 7));

    final results = await _fireflyRepository!.listRecentTransactions(
      start: start,
      end: end,
    );

    return _rankTransactionMatches(draft, results);
  }

  Future<void> linkDraftToFireflyTransaction(
    String draftId,
    FireflyTransactionSummary summary,
  ) async {
    final targetIndex =
        _state.drafts.indexWhere((draft) => draft.id == draftId);
    if (targetIndex == -1) return;
    _state = _state.copyWith(
      drafts: _state.drafts
          .map(
            (draft) => draft.id == draftId
                ? draft.copyWith(
                    fireflyTransactionId: summary.transactionId,
                    fireflyTransactionJournalId: summary.transactionJournalId,
                  )
                : draft,
          )
          .toList(growable: false),
    );
    await _saveState();
    _notifySafely();
  }

  Future<void> updateDraft(AutoImportDraft draft) async {
    final targetIndex = _state.drafts.indexWhere((item) => item.id == draft.id);
    if (targetIndex == -1) return;
    _state = _state.copyWith(
      drafts: _state.drafts
          .map((item) => item.id == draft.id ? draft : item)
          .toList(growable: false),
    );
    _error = null;
    await _saveState();
    _notifySafely();
  }

  Future<void> discardDraft(String id) async {
    _state = _state.copyWith(
      drafts: _state.drafts
          .map((draft) => draft.id == id
              ? draft.copyWith(status: AutoImportStatus.discarded)
              : draft)
          .toList(growable: false),
    );
    await _saveState();
    _notifySafely();
  }

  Future<void> restoreDraft(String id) async {
    _state = _state.copyWith(
      drafts: _state.drafts
          .map((draft) => draft.id == id
              ? draft.copyWith(status: AutoImportStatus.pending)
              : draft)
          .toList(growable: false),
    );
    await _saveState();
    _notifySafely();
  }

  Future<void> restoreAllDiscardedDrafts() async {
    final discardedIds = _state.drafts
        .where((draft) => draft.status == AutoImportStatus.discarded)
        .map((draft) => draft.id)
        .toSet();
    if (discardedIds.isEmpty) return;

    _state = _state.copyWith(
      drafts: _state.drafts
          .map((draft) => discardedIds.contains(draft.id)
              ? draft.copyWith(status: AutoImportStatus.pending)
              : draft)
          .toList(growable: false),
    );
    await _saveState();
    _notifySafely();
  }

  Future<void> retryDraft(AutoImportDraft draft) async {
    if (_isRetrying) return;
    _isRetrying = true;
    _activeRetryId = draft.id;
    _retryQueueIds = [draft.id];
    _retryRemaining = 1;
    _notifySafely();

    await _retryDraftInternal(draft);

    _retryRemaining = 0;
    _activeRetryId = null;
    _retryQueueIds = const [];
    _isRetrying = false;
    _notifySafely();
  }

  Future<void> retryFailedDrafts() async {
    if (_isRetrying) return;
    final failedDrafts = _state.drafts
        .where((draft) => draft.status == AutoImportStatus.failed)
        .toList(growable: false);
    if (failedDrafts.isEmpty) return;

    _isRetrying = true;
    _activeRetryId = null;
    _retryRemaining = failedDrafts.length;
    _retryQueueIds = failedDrafts.map((draft) => draft.id).toList();
    _notifySafely();

    for (var index = 0; index < failedDrafts.length; index += 1) {
      if (_disposed) break;
      _activeRetryId = failedDrafts[index].id;
      _retryQueueIds =
          failedDrafts.sublist(index).map((draft) => draft.id).toList();
      _notifySafely();
      if (index > 0) {
        await Future.delayed(retryDelay);
      }
      await _retryDraftInternal(
        failedDrafts[index],
        reportMissingFile: false,
      );
      _retryRemaining = failedDrafts.length - index - 1;
      _notifySafely();
    }

    _isRetrying = false;
    _activeRetryId = null;
    _retryQueueIds = const [];
    _retryRemaining = 0;
    _notifySafely();
  }

  Future<void> _retryDraftInternal(
    AutoImportDraft draft, {
    bool reportMissingFile = true,
  }) async {
    final file = File(draft.sourcePath);
    if (!await file.exists()) {
      if (reportMissingFile) {
        _error = 'Receipt file no longer exists.';
      }
      _state = _state.copyWith(
        drafts: _state.drafts
            .map(
              (item) => item.id == draft.id
                  ? item.copyWith(
                      status: AutoImportStatus.failed,
                      errorMessage: 'Receipt file no longer exists.',
                    )
                  : item,
            )
            .toList(growable: false),
      );
      await _saveState();
      return;
    }

    final analyzedDraft = await _analyzeFile(file);
    final refreshedDraft = _mergeDraftWithAnalysis(
      draft,
      analyzedDraft,
    );
    _state = _state.copyWith(
      drafts: _state.drafts
          .map(
            (item) => item.id == draft.id ? refreshedDraft : item,
          )
          .toList(growable: false),
    );
    await _saveState();
  }

  /// Saves all pending drafts to Firefly III in a batch operation.
  /// Follows the same pattern as retryFailedDrafts for consistency.
  Future<void> saveAllDrafts() async {
    if (_isSavingAll || _isRetrying) return;
    final pendingDrafts = _state.drafts
        .where((draft) => draft.status == AutoImportStatus.pending)
        .toList(growable: false);
    if (pendingDrafts.isEmpty) {
      _error = 'No pending drafts to save.';
      _notifySafely();
      return;
    }

    _isSavingAll = true;
    _activeSaveId = null;
    _saveRemaining = pendingDrafts.length;
    _saveQueueIds = pendingDrafts.map((draft) => draft.id).toList();
    _notifySafely();

    var successCount = 0;
    var failureCount = 0;

    for (var index = 0; index < pendingDrafts.length; index += 1) {
      if (_disposed) break;
      _activeSaveId = pendingDrafts[index].id;
      _saveQueueIds =
          pendingDrafts.sublist(index).map((draft) => draft.id).toList();
      _notifySafely();
      if (index > 0) {
        await Future.delayed(saveDelay);
      }

      try {
        await confirmDraft(pendingDrafts[index].id);
        // Check if the draft was successfully confirmed
        final updatedDraft = _state.drafts
            .where((draft) => draft.id == pendingDrafts[index].id)
            .firstOrNull;
        if (updatedDraft?.status == AutoImportStatus.confirmed) {
          successCount++;
        } else {
          failureCount++;
        }
      } catch (_) {
        failureCount++;
      }
      _saveRemaining = pendingDrafts.length - index - 1;
      _notifySafely();
    }

    _isSavingAll = false;
    _activeSaveId = null;
    _saveQueueIds = const [];
    _saveRemaining = 0;

    if (failureCount > 0) {
      _error = 'Saved $successCount draft${successCount == 1 ? '' : 's'}, '
          '$failureCount failed.';
    } else {
      _error = null;
    }
    _notifySafely();
  }

  Future<AutoImportDraft> _analyzeFile(
    File file, {
    Uint8List? bytes,
    String? sourceHash,
  }) async {
    final now = DateTime.now();
    final fileName = _fileName(file.path);
    final assetAccountName = _assetAccountForPath(file.path);
    Uint8List? fileBytes;
    String? hash;

    try {
      fileBytes = bytes ?? await file.readAsBytes();
      hash = sourceHash ?? _hashBytes(fileBytes);
      if (fileBytes.length > maxAttachmentBytes) {
        return _failedDraft(
          file.path,
          now,
          'Image is too large to parse. Max is 8 MB.',
          assetAccountName: assetAccountName,
          sourceHash: hash,
        );
      }

      final result = await _parser!.parseReceipt(
        bytes: fileBytes,
        fileName: fileName,
      );

      return AutoImportDraft(
        id: _newId(),
        sourcePath: file.path,
        sourceHash: hash,
        detectedAt: now,
        status: AutoImportStatus.pending,
        merchant: result.merchant,
        amount: result.amount,
        currency: result.currency,
        date: result.date,
        note: result.note,
        type: result.type,
        confidence: result.confidence,
        assetAccountName: assetAccountName,
      );
    } catch (e) {
      return _failedDraft(
        file.path,
        now,
        e.toString(),
        assetAccountName: assetAccountName,
        sourceHash: hash ?? sourceHash,
      );
    }
  }

  AutoImportDraft _failedDraft(
    String path,
    DateTime now,
    String message, {
    String? assetAccountName,
    String? sourceHash,
  }) {
    return AutoImportDraft(
      id: _newId(),
      sourcePath: path,
      detectedAt: now,
      status: AutoImportStatus.failed,
      errorMessage: message,
      type: ReceiptTransactionType.unknown,
      assetAccountName: assetAccountName,
      sourceHash: sourceHash,
    );
  }

  AutoImportDraft _mergeDraftWithAnalysis(
    AutoImportDraft original,
    AutoImportDraft analyzed,
  ) {
    final analysisFailed = analyzed.status == AutoImportStatus.failed;
    final keepConfirmed = original.status == AutoImportStatus.confirmed;
    final nextStatus = analysisFailed
        ? (keepConfirmed ? AutoImportStatus.confirmed : AutoImportStatus.failed)
        : (keepConfirmed
            ? AutoImportStatus.confirmed
            : AutoImportStatus.pending);
    final shouldReplace = !analysisFailed;

    return AutoImportDraft(
      id: original.id,
      sourcePath: original.sourcePath,
      detectedAt: original.detectedAt,
      status: nextStatus,
      sourceHash: analyzed.sourceHash ?? original.sourceHash,
      fireflyTransactionId: original.fireflyTransactionId,
      fireflyTransactionJournalId: original.fireflyTransactionJournalId,
      merchant: shouldReplace ? analyzed.merchant : original.merchant,
      amount: shouldReplace ? analyzed.amount : original.amount,
      currency: shouldReplace ? analyzed.currency : original.currency,
      date: shouldReplace ? analyzed.date : original.date,
      note: shouldReplace ? analyzed.note : original.note,
      categoryName: original.categoryName,
      type: shouldReplace ? analyzed.type : original.type,
      confidence: shouldReplace ? analyzed.confidence : original.confidence,
      assetAccountName: analyzed.assetAccountName ?? original.assetAccountName,
      errorMessage: analysisFailed ? analyzed.errorMessage : null,
    );
  }

  void _startTimer() {
    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(scanInterval, (_) {
      scanNow();
    });
  }

  void _stopTimer() {
    _scanTimer?.cancel();
    _scanTimer = null;
  }

  Future<void> _saveState() async {
    if (_repository == null) return;
    await _repository!.save(_state);
  }

  void _notifySafely() {
    if (_disposed) return;
    notifyListeners();
  }

  AutoImportState _normalizeState(AutoImportState state) {
    final normalizedFolders = <String>[];
    final seen = <String>{};
    for (final folder in state.folderPaths) {
      final normalized = _normalizeFolderPath(folder);
      if (normalized.trim().isEmpty) continue;
      if (seen.add(normalized)) {
        normalizedFolders.add(normalized);
      }
    }

    final normalizedAssets = <String, String>{};
    state.assetAccountByFolder.forEach((folder, account) {
      final normalizedFolder = _normalizeFolderPath(folder);
      if (normalizedFolder.trim().isEmpty) return;
      if (!seen.contains(normalizedFolder)) return;
      final value = account.trim();
      if (value.isEmpty) return;
      normalizedAssets[normalizedFolder] = value;
    });

    return state.copyWith(
      folderPaths: normalizedFolders,
      assetAccountByFolder: normalizedAssets,
    );
  }

  bool _isImagePath(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.heic') ||
        lower.endsWith('.heif');
  }

  String _buildLegacyFileKey(String path, FileStat stat) {
    return '$path|${stat.size}|${stat.modified.millisecondsSinceEpoch}';
  }

  String _hashBytes(List<int> bytes) {
    return md5.convert(bytes).toString();
  }

  String _buildHashKey(String hash) => '$_hashPrefix$hash';

  Future<void> _deleteImagesForFolder(String folder) async {
    final pathsToDelete = _state.drafts
        .where((draft) => _pathMatchesFolder(draft.sourcePath, folder))
        .map((draft) => draft.sourcePath.trim())
        .where((path) => path.isNotEmpty)
        .toSet();

    for (final path in pathsToDelete) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }
  }

  String _normalizeFolderPath(String path) {
    final trimmed = path.trim();
    if (trimmed.startsWith('file://')) {
      return Uri.parse(trimmed).toFilePath();
    }
    return trimmed;
  }

  bool _isContentUri(String path) {
    return path.startsWith('content://');
  }

  String _fileName(String path) {
    final parts = path.split(Platform.pathSeparator);
    return parts.isEmpty ? path : parts.last;
  }

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

  String? _assetAccountForPath(String path) {
    if (_state.assetAccountByFolder.isEmpty) return null;
    String? match;
    var longest = 0;
    _state.assetAccountByFolder.forEach((folder, account) {
      final normalizedFolder = _normalizeFolderPath(folder);
      if (_pathMatchesFolder(path, normalizedFolder) &&
          normalizedFolder.length > longest) {
        match = account;
        longest = normalizedFolder.length;
      }
    });
    return match;
  }

  bool _pathMatchesFolder(String path, String folder) {
    final normalized = _normalizeFolderPath(path);
    final normalizedFolder = _normalizeFolderPath(folder);
    final folderWithSeparator = normalizedFolder.endsWith(
      Platform.pathSeparator,
    )
        ? normalizedFolder
        : '$normalizedFolder${Platform.pathSeparator}';
    return normalized == normalizedFolder ||
        normalized.startsWith(folderWithSeparator);
  }

  List<FireflyTransactionSummary> _rankTransactionMatches(
    AutoImportDraft draft,
    List<FireflyTransactionSummary> transactions,
  ) {
    if (transactions.isEmpty) return const [];
    final merchantQuery = draft.merchant?.trim().toLowerCase();
    final currencyQuery = draft.currency?.trim().toUpperCase();
    final amountQuery = draft.amount;
    final baseDate = (draft.date ?? draft.detectedAt).toLocal();

    final scored = transactions
        .map(
          (transaction) => (
            transaction,
            _scoreTransaction(
              transaction,
              amountQuery: amountQuery,
              merchantQuery: merchantQuery,
              currencyQuery: currencyQuery,
              baseDate: baseDate,
            ),
          ),
        )
        .toList();

    scored.sort((a, b) {
      final scoreCompare = b.$2.compareTo(a.$2);
      if (scoreCompare != 0) return scoreCompare;
      final dateDeltaA = (a.$1.date.toLocal().difference(baseDate)).abs();
      final dateDeltaB = (b.$1.date.toLocal().difference(baseDate)).abs();
      return dateDeltaA.compareTo(dateDeltaB);
    });

    return scored.map((entry) => entry.$1).toList(growable: false);
  }

  double _scoreTransaction(
    FireflyTransactionSummary transaction, {
    required double? amountQuery,
    required String? merchantQuery,
    required String? currencyQuery,
    required DateTime baseDate,
  }) {
    var score = 0.0;
    if (amountQuery != null) {
      final delta = (transaction.amount.abs() - amountQuery).abs();
      if (delta <= 0.01) {
        score += 4;
      } else if (delta <= 1) {
        score += 2;
      }
    }

    if (merchantQuery != null && merchantQuery.isNotEmpty) {
      final description = transaction.description.toLowerCase();
      if (description.contains(merchantQuery)) {
        score += 3;
      }
    }

    if (currencyQuery != null && currencyQuery.isNotEmpty) {
      if ((transaction.currencyCode ?? '').toUpperCase() == currencyQuery) {
        score += 1;
      }
    }

    final dateDelta =
        transaction.date.toLocal().difference(baseDate).inDays.abs();
    score += (7 - dateDelta).clamp(0, 7).toDouble() * 0.1;

    return score;
  }

  List<FireflyCategory> _mergeCategories(
    Iterable<FireflyCategory> categories,
  ) {
    final byName = <String, FireflyCategory>{};
    for (final category in categories) {
      final name = category.name.trim();
      if (name.isEmpty) continue;
      byName.putIfAbsent(name.toLowerCase(), () {
        final id = category.id.trim();
        return FireflyCategory(id: id.isEmpty ? name : id, name: name);
      });
    }
    final result = byName.values.toList(growable: false)
      ..sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    return result;
  }

  Future<void> refreshAssetAccounts() async {
    if (_fireflyAccountRepository == null) return;
    if (_isLoadingAssets) return;
    _isLoadingAssets = true;
    _notifySafely();

    try {
      final accounts = await _fireflyAccountRepository!.listAssetAccounts();
      _assetAccounts = accounts;
      final selectedAssets = _state.assetAccountByFolder.values
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toSet();
      for (final selected in selectedAssets) {
        if (!_assetAccounts.any(
          (account) => account.name.toLowerCase() == selected.toLowerCase(),
        )) {
          _assetAccounts = [
            ..._assetAccounts,
            FireflyAccount(id: selected, name: selected),
          ];
        }
      }
    } catch (e) {
      final message = e.toString();
      if (!message.toLowerCase().contains('not configured')) {
        _error = 'Failed to load Firefly asset accounts: $e';
      }
    } finally {
      _isLoadingAssets = false;
      _notifySafely();
    }
  }

  Future<void> refreshMerchantSuggestions() async {
    if (_fireflyAccountRepository == null) return;
    if (_isLoadingMerchants) return;
    _isLoadingMerchants = true;
    _notifySafely();

    try {
      final accounts = await _fireflyAccountRepository!.listExpenseAccounts();
      final names = <String>{};
      for (final account in accounts) {
        final name = account.name.trim();
        if (name.isNotEmpty) {
          names.add(name);
        }
      }
      final sorted = names.toList(growable: false)
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      _merchantSuggestions = sorted;
    } catch (e) {
      final message = e.toString();
      if (!message.toLowerCase().contains('not configured')) {
        _error = 'Failed to load Firefly merchants: $e';
      }
    } finally {
      _isLoadingMerchants = false;
      _notifySafely();
    }
  }

  Future<void> refreshCategories() async {
    if (_fireflyCategoryRepository == null) return;
    if (_isLoadingCategories) return;
    _isLoadingCategories = true;
    _notifySafely();

    try {
      final categories = await _fireflyCategoryRepository!.listCategories();
      _categories = _mergeCategories(categories);

      final selectedCategories = _state.drafts
          .map((draft) => draft.categoryName?.trim())
          .where((value) => value != null && value.isNotEmpty)
          .cast<String>()
          .toSet();
      if (selectedCategories.isNotEmpty) {
        final extras = selectedCategories
            .where(
              (name) => !_categories.any(
                (category) => category.name.toLowerCase() == name.toLowerCase(),
              ),
            )
            .map(
              (name) => FireflyCategory(id: name, name: name),
            );
        _categories = _mergeCategories([..._categories, ...extras]);
      }
    } catch (e) {
      final message = e.toString();
      if (!message.toLowerCase().contains('not configured')) {
        _error = 'Failed to load Firefly categories: $e';
      }
    } finally {
      _isLoadingCategories = false;
      _notifySafely();
    }
  }

  Future<String?> createCategory(String name) async {
    if (_fireflyCategoryRepository == null) return null;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    final existing = _categories.firstWhere(
      (category) => category.name.toLowerCase() == trimmed.toLowerCase(),
      orElse: () => const FireflyCategory(id: '', name: ''),
    );
    if (existing.name.isNotEmpty) {
      return existing.name;
    }
    try {
      final created = await _fireflyCategoryRepository!.createCategory(trimmed);
      _categories = _mergeCategories([..._categories, created]);
      _notifySafely();
      return created.name;
    } catch (e) {
      _error = 'Failed to create category: $e';
      _notifySafely();
      return null;
    }
  }

  Future<void> setFolderAssetAccount(
    String folder,
    String? accountName,
  ) async {
    final normalizedFolder = _normalizeFolderPath(folder);
    if (normalizedFolder.trim().isEmpty) return;
    if (!_state.folderPaths
        .map(_normalizeFolderPath)
        .contains(normalizedFolder)) {
      return;
    }
    final value = accountName?.trim() ?? '';
    final updated = Map<String, String>.from(_state.assetAccountByFolder);
    if (value.isEmpty) {
      updated.remove(normalizedFolder);
    } else {
      updated[normalizedFolder] = value;
    }
    final updatedDrafts = _state.drafts
        .map(
          (draft) => _pathMatchesFolder(
            draft.sourcePath,
            normalizedFolder,
          )
              ? draft.copyWith(
                  assetAccountName: value.isEmpty ? null : value,
                )
              : draft,
        )
        .toList(growable: false);
    _state = _state.copyWith(
      assetAccountByFolder: updated,
      drafts: updatedDrafts,
    );
    await _saveState();
    _notifySafely();
  }

  Future<bool> _ensureMediaAccess() async {
    if (kIsWeb) {
      _error = 'Auto import is not supported on web yet.';
      return false;
    }

    if (Platform.isIOS) {
      final status = await Permission.photos.request();
      if (status.isGranted || status.isLimited) return true;
      _error = 'Photos permission is required to scan this folder.';
      return false;
    }

    if (Platform.isAndroid) {
      final photosStatus = await Permission.photos.request();
      if (photosStatus.isGranted) return true;

      final storageStatus = await Permission.storage.request();
      if (storageStatus.isGranted) return true;

      _error = 'Storage permission is required to scan this folder.';
      return false;
    }

    return true;
  }

  @override
  void dispose() {
    _stopTimer();
    _parser?.dispose();
    _fireflyApiService?.dispose();
    _disposed = true;
    super.dispose();
  }
}
