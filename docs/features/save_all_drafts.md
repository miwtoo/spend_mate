# Save All Drafts Feature

## Overview

The Save All Drafts feature allows users to save all pending transaction drafts to Firefly III in a single batch operation. This improves efficiency when processing multiple receipts at once.

## Location

- **UI**: `lib/ui/features/auto_import/auto_import_screen.dart`
- **ViewModel**: `lib/ui/features/auto_import/view_models/auto_import_view_model.dart`
- **Tests**: `test/ui/features/auto_import/save_all_drafts_test.dart`

## Features

### 1. Save All Button

A "Save All" button appears in the "Pending review" section header when there are pending drafts. The button shows:
- **Normal state**: "Save All (N)" where N is the count of pending drafts
- **Saving state**: "Saving N left" with a progress count

### 2. Batch Save Operation

The `saveAllDrafts()` method in `AutoImportViewModel`:

1. **Filters pending drafts**: Only drafts with `AutoImportStatus.pending` are included
2. **Sequential processing**: Drafts are saved one at a time with a 500ms delay between each
3. **Progress tracking**: Shows remaining count and active draft ID
4. **Per-item status**: Each draft card shows "Saving..." or "Queued for saving" status

### 3. Partial Failure Handling

- Individual draft failures don't stop the batch operation
- Success/failure counts are tracked
- Error message format: "Saved X draft(s), Y failed."
- Failed drafts remain in pending/failed state for retry

### 4. Duplicate Prevention

- Only pending drafts are saved (confirmed/discarded are excluded)
- Button is disabled during save operations
- Button is disabled during retry operations
- `_isSavingAll` flag prevents concurrent batch saves

### 5. UI Feedback

- **Progress indicator**: Circular spinner on active draft card
- **Queued status**: Clock icon for drafts waiting to save
- **Button state**: Disabled during operation
- **Card buttons**: All action buttons disabled during save
- **Error banner**: Shows summary after completion

## Implementation Details

### State Management

```dart
// Batch save state
bool _isSavingAll = false;
String? _activeSaveId;
List<String> _saveQueueIds = const [];
int _saveRemaining = 0;
```

### Public Getters

```dart
bool get isSavingAll => _isSavingAll;
String? get activeSaveId => _activeSaveId;
List<String> get saveQueueIds => List.unmodifiable(_saveQueueIds);
int get saveRemaining => _saveRemaining;
```

### Key Method

```dart
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
  // ... batch save logic
}
```

### Save Delay

A 500ms delay between saves prevents overwhelming the API:

```dart
static const Duration saveDelay = Duration(milliseconds: 500);
```

### Auth and Payload Handling

The feature delegates to the existing `confirmDraft()` method for each draft, ensuring:
- Proper Firefly III authentication headers
- Correct transaction request payload formatting
- Asset account override handling
- Error handling and status updates

## UI Components

### Header Button

```dart
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
```

### Draft Card Status

```dart
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
```

## Error Handling

### No Pending Drafts

```dart
_error = 'No pending drafts to save.';
```

### Partial Failures

```dart
_error = 'Saved $successCount draft${successCount == 1 ? '' : 's'}, '
    '$failureCount failed.';
```

### Success

```dart
_error = null; // Clear any previous errors
```

## Testing

The feature includes comprehensive test coverage in `save_all_drafts_test.dart`:

- State management tests
- Business logic tests
- Progress tracking tests
- Partial failure handling tests
- Duplicate prevention tests
- UI integration tests
- Sequential processing tests
- State cleanup tests
- Auth and payload handling tests
- Edge case tests

**Total: 44 tests**

## Related Features

- **Retry All Failed**: Similar batch operation pattern for retrying failed drafts
- **Restore All**: Similar batch operation pattern for restoring discarded drafts
- **Confirm Draft**: Individual draft save method used by Save All

## Future Enhancements

Potential improvements:

1. **Parallel processing**: Save multiple drafts concurrently (with rate limiting)
2. **Batch API endpoint**: Use Firefly III batch transaction creation if available
3. **Undo functionality**: Option to revert a batch save operation
4. **Save selection**: Allow users to select specific drafts to save
5. **Retry failed in batch**: Option to retry only failed drafts from a batch
