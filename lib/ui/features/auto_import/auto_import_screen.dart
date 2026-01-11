import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:spend_mate/data/repositories/ai_provider_config_repository.dart';
import 'package:spend_mate/data/repositories/firefly_config_repository.dart';
import 'package:spend_mate/domain/models/auto_import_draft.dart';
import 'package:spend_mate/domain/models/firefly_transaction_summary.dart';
import 'package:spend_mate/domain/models/receipt_parse_result.dart';
import 'package:spend_mate/ui/features/auto_import/view_models/auto_import_view_model.dart';
import 'package:spend_mate/ui/features/settings/ai_provider_settings_screen.dart';

class AutoImportScreen extends StatefulWidget {
  const AutoImportScreen({
    super.key,
    required this.configRepository,
    required this.fireflyConfigRepository,
  });

  final AiProviderConfigRepository configRepository;
  final FireflyConfigRepository fireflyConfigRepository;

  @override
  State<AutoImportScreen> createState() => _AutoImportScreenState();
}

class _AutoImportScreenState extends State<AutoImportScreen>
    with WidgetsBindingObserver {
  late final AutoImportViewModel _vm;
  late final Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _vm = AutoImportViewModel(
      configRepository: widget.configRepository,
      fireflyConfigRepository: widget.fireflyConfigRepository,
    );
    _initFuture = _vm.initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _vm.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _vm.scanNow();
    }
  }

  Future<void> _pickFolder() async {
    try {
      final path = await FilePicker.platform.getDirectoryPath();
      if (!mounted) return;
      if (path == null) return;
      await _vm.addFolderPath(path);
    } catch (e) {
      _vm.setError('Failed to select folder: $e');
    }
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AiProviderSettingsScreen(
          configRepository: widget.configRepository,
        ),
      ),
    );
  }

  Future<void> _openDiscardedDrafts() async {
    if (_vm.discardedDrafts.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No discarded transactions to restore.')),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _DiscardedDraftsSheet(
        drafts: _vm.discardedDrafts,
        onRestore: _vm.restoreDraft,
        onRestoreAll: _vm.restoreAllDiscardedDrafts,
      ),
    );
  }

  Future<void> _reviewDraft(AutoImportDraft draft) async {
    await _vm.refreshCategories();
    if (!mounted) return;
    final isConfirmed = draft.status == AutoImportStatus.confirmed;
    final result = await showModalBottomSheet<_DraftEditResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _DraftEditSheet(
        draft: draft,
        initialStatus: draft.status,
        merchantSuggestions: _vm.merchantSuggestions,
        isLoadingMerchants: _vm.isLoadingMerchants,
        categorySuggestions: _vm.categorySuggestions,
        isLoadingCategories: _vm.isLoadingCategories,
        onCreateCategory: _vm.createCategory,
      ),
    );
    if (result == null) return;
    await _vm.updateDraft(result.draft);
    if (result.confirm) {
      if (isConfirmed) {
        if (result.draft.fireflyTransactionId?.trim().isEmpty ?? true) {
          final linked = await _promptLinkTransaction(result.draft);
          if (linked == null) return;
          await _vm.updateDraft(linked);
        }
        await _vm.updateConfirmedDraft(result.draft.id);
      } else {
        await _vm.confirmDraft(result.draft.id);
      }
    }
  }

  Future<AutoImportDraft?> _promptLinkTransaction(
    AutoImportDraft draft,
  ) async {
    final selected = await showModalBottomSheet<FireflyTransactionSummary>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _FindExistingTransactionSheet(
        draft: draft,
        onSearch: _vm.findExistingTransactions,
      ),
    );
    if (selected == null) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Update canceled.')),
      );
      return null;
    }
    await _vm.linkDraftToFireflyTransaction(draft.id, selected);
    return draft.copyWith(
      fireflyTransactionId: selected.transactionId,
      fireflyTransactionJournalId: selected.transactionJournalId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return AnimatedBuilder(
          animation: _vm,
          builder: (context, _) {
            final drafts = _vm.visibleDrafts;
            final theme = Theme.of(context);
            final failedCount = drafts
                .where((draft) => draft.status == AutoImportStatus.failed)
                .length;
            final pendingCount = drafts
                .where((draft) => draft.status == AutoImportStatus.pending)
                .length;
            final queuedRetryIds = _vm.retryQueueIds.toSet();
            final folderPaths = _vm.folderPaths;
            final hasFolders = folderPaths.isNotEmpty;
            final assetAccounts = _vm.assetAccounts;
            final hasAssets = assetAccounts.isNotEmpty;
            final assetItems = assetAccounts
                .map(
                  (account) => DropdownMenuItem<String>(
                    value: account.name,
                    child: Text(account.name),
                  ),
                )
                .toList(growable: false);

            return Scaffold(
              appBar: AppBar(
                title: const Text('Auto Import'),
                actions: [
                  IconButton(
                    tooltip: 'AI settings',
                    onPressed: _openSettings,
                    icon: const Icon(Icons.settings),
                  ),
                ],
              ),
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_vm.error != null)
                    MaterialBanner(
                      content: Text(_vm.error!),
                      leading: const Icon(Icons.error_outline),
                      actions: [
                        TextButton(
                          onPressed: _vm.clearError,
                          child: const Text('Dismiss'),
                        ),
                      ],
                    ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Watch Folders',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          if (!hasFolders)
                            Text(
                              'No folders selected yet. Choose one or more folders to watch for new images.',
                              style: theme.textTheme.bodyMedium,
                            )
                          else
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (var index = 0;
                                    index < folderPaths.length;
                                    index += 1) ...[
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          folderPaths[index],
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Remove folder',
                                        onPressed: _vm.isScanning
                                            ? null
                                            : () => _vm.removeFolderPath(
                                                  folderPaths[index],
                                                ),
                                        icon: const Icon(Icons.close),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      minWidth: 200,
                                      maxWidth: 320,
                                    ),
                                    child: Builder(
                                      builder: (context) {
                                        final selectedAsset =
                                            _vm.assetAccountForFolder(
                                          folderPaths[index],
                                        );
                                        final resolvedSelectedAsset =
                                            assetItems.any((item) =>
                                                    item.value == selectedAsset)
                                                ? selectedAsset
                                                : null;
                                        return DropdownButtonFormField<String>(
                                          key: ValueKey(
                                            '${folderPaths[index]}-${resolvedSelectedAsset ?? ''}',
                                          ),
                                          initialValue: resolvedSelectedAsset,
                                          items: assetItems,
                                          onChanged:
                                              _vm.isLoadingAssets || !hasAssets
                                                  ? null
                                                  : (value) =>
                                                      _vm.setFolderAssetAccount(
                                                        folderPaths[index],
                                                        value,
                                                      ),
                                          decoration: InputDecoration(
                                            labelText: _vm.isLoadingAssets
                                                ? 'Loading assets...'
                                                : 'Asset account',
                                            border: const OutlineInputBorder(),
                                            helperText: !hasAssets &&
                                                    !_vm.isLoadingAssets
                                                ? 'Connect Firefly to load assets.'
                                                : null,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  if (index != folderPaths.length - 1)
                                    const SizedBox(height: 12),
                                ],
                              ],
                            ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.icon(
                                onPressed: _pickFolder,
                                icon: const Icon(Icons.folder_open),
                                label: const Text('Add Folder'),
                              ),
                              OutlinedButton.icon(
                                onPressed: _vm.isScanning || !hasFolders
                                    ? null
                                    : _vm.scanNow,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Scan now'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile.adaptive(
                            value: _vm.enabled,
                            onChanged: !hasFolders
                                ? null
                                : (value) {
                                    _vm.setEnabled(value);
                                  },
                            title: const Text('Auto import enabled'),
                            subtitle: Text(
                              _vm.enabled
                                  ? 'Scanning in the background (best-effort on iOS).'
                                  : 'Enable to monitor these folders for new images.',
                            ),
                          ),
                          if (_vm.lastScanAt != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Last scan: ${_formatDateTime(context, _vm.lastScanAt!)}',
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Pending review',
                        style: theme.textTheme.titleMedium,
                      ),
                      Row(
                        children: [
                          if (pendingCount > 0 || _vm.isSavingAll)
                            TextButton.icon(
                              onPressed: _vm.isSavingAll || _vm.isRetrying
                                  ? null
                                  : _vm.saveAllDrafts,
                              icon: const Icon(Icons.save),
                              label: Text(
                                _vm.isSavingAll
                                    ? 'Saving ${_vm.saveRemaining} left'
                                    : 'Save All ($pendingCount)',
                              ),
                            ),
                          if (_vm.discardedDrafts.isNotEmpty)
                            TextButton.icon(
                              onPressed: _openDiscardedDrafts,
                              icon:
                                  const Icon(Icons.restore_from_trash_outlined),
                              label: Text(
                                  'Restore (${_vm.discardedDrafts.length})'),
                            ),
                          if (failedCount > 0 || _vm.isRetrying)
                            TextButton.icon(
                              onPressed:
                                  _vm.isRetrying ? null : _vm.retryFailedDrafts,
                              icon: const Icon(Icons.refresh),
                              label: Text(
                                _vm.isRetrying
                                    ? 'Retrying ${_vm.retryRemaining} left'
                                    : 'Retry all failed',
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (drafts.isEmpty)
                    Text(
                      _vm.isScanning
                          ? 'Scanning for new receipts...'
                          : 'No drafts yet.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  if (drafts.isNotEmpty)
                    ..._buildDraftSections(
                      context,
                      drafts: drafts,
                      onReview: _reviewDraft,
                      onConfirm: _vm.confirmDraft,
                      onDiscard: _vm.discardDraft,
                      onRetry: _vm.retryDraft,
                      retryEnabled: !_vm.isRetrying && !_vm.isSavingAll,
                      activeRetryId: _vm.activeRetryId,
                      queuedRetryIds: queuedRetryIds,
                      isSavingAll: _vm.isSavingAll,
                      activeSaveId: _vm.activeSaveId,
                      queuedSaveIds: _vm.saveQueueIds.toSet(),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

List<Widget> _buildDraftSections(
  BuildContext context, {
  required List<AutoImportDraft> drafts,
  required void Function(AutoImportDraft draft) onReview,
  required void Function(String id) onConfirm,
  required void Function(String id) onDiscard,
  required void Function(AutoImportDraft draft) onRetry,
  required bool retryEnabled,
  required String? activeRetryId,
  required Set<String> queuedRetryIds,
  required bool isSavingAll,
  required String? activeSaveId,
  required Set<String> queuedSaveIds,
}) {
  final widgets = <Widget>[];
  final theme = Theme.of(context);
  final localizations = MaterialLocalizations.of(context);

  // Group drafts by status
  final processingDrafts = drafts
      .where((draft) => draft.status == AutoImportStatus.processing)
      .toList();
  final pendingDrafts = drafts
      .where((draft) => draft.status == AutoImportStatus.pending)
      .toList();
  final failedDrafts =
      drafts.where((draft) => draft.status == AutoImportStatus.failed).toList();

  // Sort each section by date/detectedAt (newest first)
  for (final sectionDrafts in [processingDrafts, pendingDrafts, failedDrafts]) {
    sectionDrafts.sort((a, b) {
      final dateA = a.date ?? a.detectedAt;
      final dateB = b.date ?? b.detectedAt;
      return dateB.compareTo(dateA);
    });
  }

  bool isFirstSection = true;

  // Helper to add a status section header
  void addStatusHeader(String title) {
    if (!isFirstSection) {
      widgets.add(const SizedBox(height: 16));
    }
    widgets.add(
      Text(
        title,
        style: theme.textTheme.titleMedium,
      ),
    );
    widgets.add(const SizedBox(height: 8));
    isFirstSection = false;
  }

  // Add Processing section
  if (processingDrafts.isNotEmpty) {
    addStatusHeader('Processing');
    widgets.addAll(_buildDraftCardsForSection(
      processingDrafts,
      theme: theme,
      localizations: localizations,
      onReview: onReview,
      onConfirm: onConfirm,
      onDiscard: onDiscard,
      onRetry: onRetry,
      retryEnabled: retryEnabled,
      activeRetryId: activeRetryId,
      queuedRetryIds: queuedRetryIds,
      isSavingAll: isSavingAll,
      activeSaveId: activeSaveId,
      queuedSaveIds: queuedSaveIds,
    ));
  }

  // Add Pending approval section
  if (pendingDrafts.isNotEmpty) {
    addStatusHeader('Pending approval');
    widgets.addAll(_buildDraftCardsForSection(
      pendingDrafts,
      theme: theme,
      localizations: localizations,
      onReview: onReview,
      onConfirm: onConfirm,
      onDiscard: onDiscard,
      onRetry: onRetry,
      retryEnabled: retryEnabled,
      activeRetryId: activeRetryId,
      queuedRetryIds: queuedRetryIds,
      isSavingAll: isSavingAll,
      activeSaveId: activeSaveId,
      queuedSaveIds: queuedSaveIds,
    ));
  }

  // Add Failed section
  if (failedDrafts.isNotEmpty) {
    addStatusHeader('Failed');
    widgets.addAll(_buildDraftCardsForSection(
      failedDrafts,
      theme: theme,
      localizations: localizations,
      onReview: onReview,
      onConfirm: onConfirm,
      onDiscard: onDiscard,
      onRetry: onRetry,
      retryEnabled: retryEnabled,
      activeRetryId: activeRetryId,
      queuedRetryIds: queuedRetryIds,
      isSavingAll: isSavingAll,
      activeSaveId: activeSaveId,
      queuedSaveIds: queuedSaveIds,
    ));
  }

  return widgets;
}

List<Widget> _buildDraftCardsForSection(
  List<AutoImportDraft> sectionDrafts, {
  required ThemeData theme,
  required MaterialLocalizations localizations,
  required void Function(AutoImportDraft draft) onReview,
  required void Function(String id) onConfirm,
  required void Function(String id) onDiscard,
  required void Function(AutoImportDraft draft) onRetry,
  required bool retryEnabled,
  required String? activeRetryId,
  required Set<String> queuedRetryIds,
  required bool isSavingAll,
  required String? activeSaveId,
  required Set<String> queuedSaveIds,
}) {
  final widgets = <Widget>[];
  final datedDrafts = sectionDrafts
      .where((draft) => draft.date != null)
      .toList(growable: false);
  final unknownDrafts = sectionDrafts
      .where((draft) => draft.date == null)
      .toList(growable: false);

  bool isFirstGroup = true;
  DateTime? currentMonth;
  DateTime? currentDay;

  void addMonthHeader(DateTime month) {
    if (!isFirstGroup) {
      widgets.add(const SizedBox(height: 12));
    }
    widgets.add(
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          localizations.formatMonthYear(month),
          style: theme.textTheme.titleSmall,
        ),
      ),
    );
    isFirstGroup = false;
    currentMonth = month;
  }

  void addDateHeader(DateTime day) {
    widgets.add(const SizedBox(height: 8));
    widgets.add(
      Text(
        localizations.formatShortDate(day),
        style: theme.textTheme.labelLarge,
      ),
    );
    widgets.add(const SizedBox(height: 8));
    currentDay = day;
  }

  for (final draft in datedDrafts) {
    final date = draft.date!;
    final monthKey = DateTime(date.year, date.month);
    final dayKey = DateTime(date.year, date.month, date.day);

    final monthChanged =
        currentMonth == null || !_sameMonth(currentMonth!, monthKey);
    final dayChanged = currentDay == null || !_sameDay(currentDay!, dayKey);

    if (monthChanged) {
      addMonthHeader(monthKey);
      currentDay = null;
    }
    if (dayChanged) {
      addDateHeader(dayKey);
    }

    widgets.add(
      _DraftCard(
        draft: draft,
        onReview: onReview,
        onConfirm: onConfirm,
        onDiscard: onDiscard,
        onRetry: onRetry,
        retryEnabled: retryEnabled,
        activeRetryId: activeRetryId,
        queuedRetryIds: queuedRetryIds,
        isSavingAll: isSavingAll,
        activeSaveId: activeSaveId,
        queuedSaveIds: queuedSaveIds,
      ),
    );
  }

  if (unknownDrafts.isNotEmpty) {
    if (!isFirstGroup) {
      widgets.add(const SizedBox(height: 12));
    }
    widgets.add(
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          'Unknown date',
          style: theme.textTheme.titleSmall,
        ),
      ),
    );
    widgets.add(const SizedBox(height: 8));
    for (final draft in unknownDrafts) {
      widgets.add(
        _DraftCard(
          draft: draft,
          onReview: onReview,
          onConfirm: onConfirm,
          onDiscard: onDiscard,
          onRetry: onRetry,
          retryEnabled: retryEnabled,
          activeRetryId: activeRetryId,
          queuedRetryIds: queuedRetryIds,
          isSavingAll: isSavingAll,
          activeSaveId: activeSaveId,
          queuedSaveIds: queuedSaveIds,
        ),
      );
    }
  }

  return widgets;
}

bool _sameMonth(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month;
}

bool _sameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DraftCard extends StatelessWidget {
  const _DraftCard({
    required this.draft,
    required this.onReview,
    required this.onConfirm,
    required this.onDiscard,
    required this.onRetry,
    required this.retryEnabled,
    required this.activeRetryId,
    required this.queuedRetryIds,
    required this.isSavingAll,
    required this.activeSaveId,
    required this.queuedSaveIds,
  });

  final AutoImportDraft draft;
  final void Function(AutoImportDraft draft) onReview;
  final void Function(String id) onConfirm;
  final void Function(String id) onDiscard;
  final void Function(AutoImportDraft draft) onRetry;
  final bool retryEnabled;
  final String? activeRetryId;
  final Set<String> queuedRetryIds;
  final bool isSavingAll;
  final String? activeSaveId;
  final Set<String> queuedSaveIds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detectedLabel = _formatDateTime(context, draft.detectedAt);
    final amountLabel = _formatAmount(draft.amount, draft.currency);
    final statusLabel = _statusLabel(draft.status);
    final isRetrying = draft.id == activeRetryId;
    final isQueued = !isRetrying && queuedRetryIds.contains(draft.id);
    final isSaving = draft.id == activeSaveId;
    final isSaveQueued = !isSaving && queuedSaveIds.contains(draft.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ReceiptPreview(path: draft.sourcePath),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        draft.merchant ?? 'Unknown merchant',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        amountLabel,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        draft.date != null
                            ? 'Date: ${_formatDateTime(context, draft.date!)}'
                            : 'Date: unknown',
                        style: theme.textTheme.bodySmall,
                      ),
                      Text(
                        'Detected: $detectedLabel',
                        style: theme.textTheme.bodySmall,
                      ),
                      Text(
                        'Status: $statusLabel',
                        style: theme.textTheme.bodySmall,
                      ),
                      if (draft.categoryName?.trim().isNotEmpty == true)
                        Text(
                          'Category: ${draft.categoryName!.trim()}',
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (draft.note != null && draft.note!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                draft.note!,
                style: theme.textTheme.bodyMedium,
              ),
            ],
            if (draft.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                draft.errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            if (isRetrying || isQueued) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (isRetrying)
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      Icons.schedule,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  const SizedBox(width: 6),
                  Text(
                    isRetrying ? 'Retrying now...' : 'Queued for retry',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
            if (isSaving || isSaveQueued) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (isSaving)
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      Icons.schedule,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  const SizedBox(width: 6),
                  Text(
                    isSaving ? 'Saving...' : 'Queued for saving',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (draft.status == AutoImportStatus.processing)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('AI parsing in progress...'),
                      ],
                    ),
                  ),
                if (draft.status == AutoImportStatus.pending)
                  FilledButton(
                    onPressed: isSavingAll ? null : () => onReview(draft),
                    child: const Text('Review & Confirm'),
                  ),
                if (draft.status == AutoImportStatus.confirmed)
                  OutlinedButton(
                    onPressed: isSavingAll ? null : () => onReview(draft),
                    child: const Text('Edit'),
                  ),
                if (draft.status == AutoImportStatus.pending ||
                    draft.status == AutoImportStatus.confirmed)
                  OutlinedButton.icon(
                    onPressed: (retryEnabled && !isSavingAll)
                        ? () => onRetry(draft)
                        : null,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Re-run OCR'),
                  ),
                if (draft.status == AutoImportStatus.pending)
                  OutlinedButton(
                    onPressed: isSavingAll ? null : () => onDiscard(draft.id),
                    child: const Text('Discard'),
                  ),
                if (draft.status == AutoImportStatus.failed)
                  FilledButton.icon(
                    onPressed: retryEnabled ? () => onRetry(draft) : null,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                if (draft.status == AutoImportStatus.failed)
                  OutlinedButton(
                    onPressed: () => onDiscard(draft.id),
                    child: const Text('Dismiss'),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              draft.sourcePath,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptPreview extends StatelessWidget {
  const _ReceiptPreview({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final file = File(path);
    final fileExists = file.existsSync();

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        child: InkWell(
          onTap: fileExists ? () => _showReceiptPreview(context, file) : null,
          child: SizedBox(
            width: 72,
            height: 72,
            child: fileExists
                ? Image.file(
                    file,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.receipt_long_outlined,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                : Icon(
                    Icons.receipt_long_outlined,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
          ),
        ),
      ),
    );
  }
}

Future<void> _showReceiptPreview(BuildContext context, File file) async {
  if (!file.existsSync()) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Receipt image is no longer available.')),
    );
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      return Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: theme.colorScheme.surface,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: Center(
                  child: Image.file(
                    file,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.receipt_long_outlined,
                      color: theme.colorScheme.onSurfaceVariant,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ),
      );
    },
  );
}

String _statusLabel(AutoImportStatus status) {
  return switch (status) {
    AutoImportStatus.processing => 'Processing',
    AutoImportStatus.pending => 'Pending approval',
    AutoImportStatus.confirmed => 'Confirmed',
    AutoImportStatus.discarded => 'Discarded',
    AutoImportStatus.failed => 'Failed',
  };
}

String _formatAmount(double? amount, String? currency) {
  if (amount == null) return 'Amount: unknown';
  final value = amount.toStringAsFixed(2);
  if (currency == null || currency.trim().isEmpty) {
    return 'Amount: $value';
  }
  return 'Amount: $value ${currency.trim()}';
}

String _formatDateTime(BuildContext context, DateTime dateTime) {
  final localizations = MaterialLocalizations.of(context);
  final date = localizations.formatShortDate(dateTime);
  final time = localizations.formatTimeOfDay(TimeOfDay.fromDateTime(dateTime));
  return '$date $time';
}

class _FindExistingTransactionSheet extends StatefulWidget {
  const _FindExistingTransactionSheet({
    required this.draft,
    required this.onSearch,
  });

  final AutoImportDraft draft;
  final Future<List<FireflyTransactionSummary>> Function(AutoImportDraft draft)
      onSearch;

  @override
  State<_FindExistingTransactionSheet> createState() =>
      _FindExistingTransactionSheetState();
}

class _FindExistingTransactionSheetState
    extends State<_FindExistingTransactionSheet> {
  bool _isLoading = true;
  String? _error;
  List<FireflyTransactionSummary> _candidates = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await widget.onSearch(widget.draft);
      setState(() {
        _candidates = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseDate = widget.draft.date ?? widget.draft.detectedAt;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Find existing transaction',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Searching Firefly III within ±7 days of ${_formatDateTime(context, baseDate)}.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null) ...[
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ),
            ] else if (_candidates.isEmpty) ...[
              Text(
                'No matching transactions found.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Search again'),
                ),
              ),
            ] else ...[
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.45,
                child: ListView.separated(
                  itemCount: _candidates.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final transaction = _candidates[index];
                    final amountLabel = _formatAmount(
                      transaction.amount,
                      transaction.currencyCode,
                    );
                    final dateLabel =
                        _formatDateTime(context, transaction.date);
                    final subtitle = [
                      amountLabel.replaceFirst('Amount: ', ''),
                      dateLabel,
                      if (transaction.sourceName.trim().isNotEmpty)
                        transaction.sourceName.trim(),
                      if (transaction.destinationName.trim().isNotEmpty)
                        transaction.destinationName.trim(),
                    ].where((value) => value.isNotEmpty).join(' • ');
                    return ListTile(
                      title: Text(transaction.description),
                      subtitle: Text(subtitle),
                      trailing: transaction.isSplit
                          ? const Text('Split')
                          : const Icon(Icons.chevron_right),
                      enabled: !transaction.isSplit,
                      onTap: transaction.isSplit
                          ? null
                          : () => Navigator.of(context).pop(transaction),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Split transactions are excluded to prevent data loss.',
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DraftEditResult {
  const _DraftEditResult({
    required this.draft,
    required this.confirm,
  });

  final AutoImportDraft draft;
  final bool confirm;
}

class _DraftEditSheet extends StatefulWidget {
  const _DraftEditSheet({
    required this.draft,
    required this.initialStatus,
    required this.merchantSuggestions,
    required this.isLoadingMerchants,
    required this.categorySuggestions,
    required this.isLoadingCategories,
    required this.onCreateCategory,
  });

  final AutoImportDraft draft;
  final AutoImportStatus initialStatus;
  final List<String> merchantSuggestions;
  final bool isLoadingMerchants;
  final List<String> categorySuggestions;
  final bool isLoadingCategories;
  final Future<String?> Function(String name) onCreateCategory;

  @override
  State<_DraftEditSheet> createState() => _DraftEditSheetState();
}

class _DraftEditSheetState extends State<_DraftEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _merchantController;
  late final FocusNode _merchantFocusNode;
  late final TextEditingController _categoryController;
  late final FocusNode _categoryFocusNode;
  late final TextEditingController _amountController;
  late final TextEditingController _currencyController;
  late final TextEditingController _dateController;
  late final TextEditingController _timeController;
  late final TextEditingController _noteController;
  late List<String> _categoryOptions;
  ReceiptTransactionType _type = ReceiptTransactionType.unknown;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isCreatingCategory = false;
  static const int _maxMerchantSuggestions = 12;
  static const int _maxCategorySuggestions = 12;

  @override
  void initState() {
    super.initState();
    _merchantController = TextEditingController(text: widget.draft.merchant);
    _merchantFocusNode = FocusNode();
    _categoryController =
        TextEditingController(text: widget.draft.categoryName);
    _categoryFocusNode = FocusNode();
    _amountController = TextEditingController(
      text: widget.draft.amount?.toStringAsFixed(2) ?? '',
    );
    _currencyController = TextEditingController(
      text: widget.draft.currency?.toUpperCase() ?? '',
    );
    _dateController = TextEditingController();
    _timeController = TextEditingController();
    _noteController = TextEditingController(text: widget.draft.note);
    _categoryOptions = _mergeCategoryOptions(widget.categorySuggestions);
    final draftDate = widget.draft.date;
    _selectedDate = draftDate == null
        ? null
        : DateTime(draftDate.year, draftDate.month, draftDate.day);
    _selectedTime =
        draftDate == null ? null : TimeOfDay.fromDateTime(draftDate);
    _type = widget.draft.type;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _dateController.text = _formatDateLabel(_selectedDate);
    _timeController.text = _formatTimeLabel(_selectedTime);
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _merchantFocusNode.dispose();
    _categoryController.dispose();
    _categoryFocusNode.dispose();
    _amountController.dispose();
    _currencyController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String _formatDateLabel(DateTime? date) {
    if (date == null) return '';
    final localizations = MaterialLocalizations.of(context);
    return localizations.formatShortDate(date);
  }

  String _formatTimeLabel(TimeOfDay? time) {
    if (time == null) return '';
    final localizations = MaterialLocalizations.of(context);
    return localizations.formatTimeOfDay(time);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _selectedDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1),
    );
    if (picked == null) return;
    setState(() {
      _selectedDate = picked;
      _dateController.text = _formatDateLabel(picked);
      _selectedTime ??= TimeOfDay.fromDateTime(widget.draft.detectedAt);
      _timeController.text = _formatTimeLabel(_selectedTime);
    });
  }

  Future<void> _pickTime() async {
    final initial =
        _selectedTime ?? TimeOfDay.fromDateTime(widget.draft.detectedAt);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked == null) return;
    setState(() {
      _selectedTime = picked;
      _timeController.text = _formatTimeLabel(picked);
    });
  }

  String? _validateAmount(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    final parsed = double.tryParse(trimmed);
    if (parsed == null) return 'Enter a valid amount.';
    if (parsed <= 0) return 'Amount must be greater than zero.';
    return null;
  }

  void _submit({required bool confirm}) {
    final form = _formKey.currentState;
    if (form == null) return;
    if (!form.validate()) return;

    final merchant = _textOrNull(_merchantController.text);
    final category = _textOrNull(_categoryController.text);
    final amount = _parseAmountOrNull(_amountController.text);
    final currency = _textOrNull(_currencyController.text)?.toUpperCase();
    final note = _textOrNull(_noteController.text);
    final resolvedDate = _resolveDateTime();

    if (confirm && (amount == null || amount <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a valid amount before confirming.')),
      );
      return;
    }

    final nextStatus = widget.initialStatus == AutoImportStatus.confirmed
        ? AutoImportStatus.confirmed
        : AutoImportStatus.pending;
    final updated = widget.draft.copyWith(
      merchant: merchant,
      amount: amount,
      currency: currency,
      date: resolvedDate,
      note: note,
      categoryName: category,
      type: _type,
      status: nextStatus,
      errorMessage: null,
    );

    Navigator.of(context).pop(
      _DraftEditResult(draft: updated, confirm: confirm),
    );
  }

  String? _textOrNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  double? _parseAmountOrNull(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return double.tryParse(trimmed);
  }

  DateTime? _resolveDateTime() {
    final date = _selectedDate;
    if (date == null) return null;
    final time =
        _selectedTime ?? TimeOfDay.fromDateTime(widget.draft.detectedAt);
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  Iterable<String> _merchantOptions(TextEditingValue value) {
    final options = widget.merchantSuggestions;
    if (options.isEmpty) return const Iterable<String>.empty();
    final query = value.text.trim().toLowerCase();
    if (query.isEmpty) {
      return options.take(_maxMerchantSuggestions);
    }
    return options
        .where((option) => option.toLowerCase().contains(query))
        .take(_maxMerchantSuggestions);
  }

  Iterable<String> _categoryOptionsBuilder(TextEditingValue value) {
    if (_categoryOptions.isEmpty) {
      return const Iterable<String>.empty();
    }
    final query = value.text.trim().toLowerCase();
    if (query.isEmpty) {
      return _categoryOptions.take(_maxCategorySuggestions);
    }
    return _categoryOptions
        .where((option) => option.toLowerCase().contains(query))
        .take(_maxCategorySuggestions);
  }

  bool _categoryExists(String value) {
    final query = value.trim().toLowerCase();
    if (query.isEmpty) return false;
    return _categoryOptions.any(
      (option) => option.toLowerCase() == query,
    );
  }

  List<String> _mergeCategoryOptions(Iterable<String> options) {
    final seen = <String>{};
    final result = <String>[];
    for (final option in options) {
      final trimmed = option.trim();
      if (trimmed.isEmpty) continue;
      final key = trimmed.toLowerCase();
      if (seen.add(key)) {
        result.add(trimmed);
      }
    }
    result.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return result;
  }

  Future<void> _createCategory() async {
    if (_isCreatingCategory) return;
    final name = _categoryController.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _isCreatingCategory = true;
    });
    final created = await widget.onCreateCategory(name);
    if (!mounted) return;
    setState(() {
      _isCreatingCategory = false;
    });
    if (created == null || created.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create category.')),
      );
      return;
    }
    final updated = _mergeCategoryOptions(
      [..._categoryOptions, created.trim()],
    );
    setState(() {
      _categoryOptions = updated;
      _categoryController.text = created.trim();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Category created: ${created.trim()}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isConfirmed = widget.initialStatus == AutoImportStatus.confirmed;
    final title =
        isConfirmed ? 'Edit submitted transaction' : 'Review receipt draft';
    final confirmLabel = isConfirmed ? 'Save & Update' : 'Save & Confirm';

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                RawAutocomplete<String>(
                  textEditingController: _merchantController,
                  focusNode: _merchantFocusNode,
                  optionsBuilder: _merchantOptions,
                  onSelected: (value) => _merchantController.text = value,
                  optionsViewBuilder: (context, onSelected, options) {
                    if (options.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(8),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 240),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: options.length,
                            itemBuilder: (context, index) {
                              final option = options.elementAt(index);
                              return ListTile(
                                title: Text(option),
                                onTap: () => onSelected(option),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                  fieldViewBuilder: (
                    context,
                    textEditingController,
                    focusNode,
                    onFieldSubmitted,
                  ) {
                    final helperText = widget.isLoadingMerchants
                        ? 'Loading merchants...'
                        : widget.merchantSuggestions.isEmpty
                            ? 'Type a new merchant or keep it blank.'
                            : 'Pick a merchant or type a new one.';
                    return TextFormField(
                      controller: textEditingController,
                      focusNode: focusNode,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Merchant',
                        border: const OutlineInputBorder(),
                        helperText: helperText,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                RawAutocomplete<String>(
                  textEditingController: _categoryController,
                  focusNode: _categoryFocusNode,
                  optionsBuilder: _categoryOptionsBuilder,
                  onSelected: (value) => _categoryController.text = value,
                  optionsViewBuilder: (context, onSelected, options) {
                    if (options.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(8),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 240),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: options.length,
                            itemBuilder: (context, index) {
                              final option = options.elementAt(index);
                              return ListTile(
                                title: Text(option),
                                onTap: () => onSelected(option),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                  fieldViewBuilder: (
                    context,
                    textEditingController,
                    focusNode,
                    onFieldSubmitted,
                  ) {
                    final helperText = widget.isLoadingCategories
                        ? 'Loading categories...'
                        : _categoryOptions.isEmpty
                            ? 'Type a category or create a new one.'
                            : 'Pick a category or type a new one.';
                    return TextFormField(
                      controller: textEditingController,
                      focusNode: focusNode,
                      onChanged: (_) => setState(() {}),
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        border: const OutlineInputBorder(),
                        helperText: helperText,
                      ),
                    );
                  },
                ),
                if (_categoryController.text.trim().isNotEmpty &&
                    !_categoryExists(_categoryController.text) &&
                    !widget.isLoadingCategories) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _isCreatingCategory ? null : _createCategory,
                      icon: _isCreatingCategory
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add),
                      label: Text(
                        _isCreatingCategory
                            ? 'Creating...'
                            : 'Create "${_categoryController.text.trim()}"',
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    border: OutlineInputBorder(),
                  ),
                  validator: _validateAmount,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _currencyController,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 3,
                  decoration: const InputDecoration(
                    labelText: 'Currency',
                    counterText: '',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _dateController,
                  readOnly: true,
                  onTap: _pickDate,
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _timeController,
                  readOnly: true,
                  onTap: _pickTime,
                  decoration: const InputDecoration(
                    labelText: 'Time',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.access_time),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ReceiptTransactionType>(
                  initialValue: _type,
                  items: ReceiptTransactionType.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(_typeLabel(value)),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _type = value;
                    });
                  },
                  decoration: const InputDecoration(
                    labelText: 'Transaction type',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _noteController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Note',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _submit(confirm: false),
                        child: const Text('Save'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => _submit(confirm: true),
                        child: Text(confirmLabel),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _typeLabel(ReceiptTransactionType type) {
  return switch (type) {
    ReceiptTransactionType.expense => 'Expense',
    ReceiptTransactionType.income => 'Income',
    ReceiptTransactionType.transfer => 'Transfer',
    ReceiptTransactionType.unknown => 'Unknown',
  };
}

class _DiscardedDraftsSheet extends StatelessWidget {
  const _DiscardedDraftsSheet({
    required this.drafts,
    required this.onRestore,
    required this.onRestoreAll,
  });

  final List<AutoImportDraft> drafts;
  final Future<void> Function(String id) onRestore;
  final Future<void> Function() onRestoreAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Discarded Transactions',
                  style: theme.textTheme.titleLarge,
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${drafts.length} discarded transaction${drafts.length == 1 ? '' : 's'}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: onRestoreAll,
              icon: const Icon(Icons.restore),
              label: const Text('Restore All'),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: ListView.separated(
                itemCount: drafts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final draft = drafts[index];
                  return _DiscardedDraftCard(
                    draft: draft,
                    onRestore: onRestore,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscardedDraftCard extends StatelessWidget {
  const _DiscardedDraftCard({
    required this.draft,
    required this.onRestore,
  });

  final AutoImportDraft draft;
  final Future<void> Function(String id) onRestore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amountLabel = _formatAmount(draft.amount, draft.currency);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ReceiptPreview(path: draft.sourcePath),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        draft.merchant ?? 'Unknown merchant',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        amountLabel,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        draft.date != null
                            ? 'Date: ${_formatDateTime(context, draft.date!)}'
                            : 'Date: unknown',
                        style: theme.textTheme.bodySmall,
                      ),
                      Text(
                        'Detected: ${_formatDateTime(context, draft.detectedAt)}',
                        style: theme.textTheme.bodySmall,
                      ),
                      if (draft.categoryName?.trim().isNotEmpty == true)
                        Text(
                          'Category: ${draft.categoryName!.trim()}',
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => onRestore(draft.id),
                  icon: const Icon(Icons.restore),
                  label: const Text('Restore'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
