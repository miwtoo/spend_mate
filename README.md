# spend_mate

A Flutter application for managing expenses with Firefly III integration and AI-powered receipt scanning.

## Features

### Auto-Import with Discarded Transaction Recovery

The auto-import feature scans folders for receipt images, uses AI to extract transaction details, and creates transactions in Firefly III.

**Key features:**
- AI-powered receipt parsing using OpenAI-compatible or Gemini APIs
- Automatic folder scanning (background on Android, best-effort on iOS)
- Draft review and confirmation before creating transactions
- **Discarded transaction recovery** - restore previously discarded drafts back to the review queue

**Transaction Lifecycle:**
1. **Processing** - AI is analyzing the receipt image
2. **Pending approval** - AI parsing completed, awaiting user review
3. **Confirmed** - Transaction created in Firefly III
4. **Discarded** - User discarded the draft (can be restored)
5. **Failed** - AI parsing failed or other error

**Restoring Discarded Transactions:**
- Click "Restore (N)" button on the auto-import screen to view discarded drafts
- Use "Restore All" to restore all discarded transactions at once
- Or restore individual drafts by clicking "Restore" on each card
- Discarded drafts persist across app restarts (SQLite storage)

### AI Chat

Chat interface for expense tracking and financial queries.

### Settings

Configure AI providers (OpenAI-compatible, Gemini) and Firefly III connection settings.

## Development

### Running Tests

```bash
flutter test
```

### Test Coverage

```bash
flutter test --coverage
lcov --summary coverage/lcov.info
```

Current coverage: **79.4%** (794 of 1000 lines)

### Code Quality

```bash
flutter analyze
```

## Architecture

- **MVVM Pattern** - ViewModels manage state and business logic
- **Repository Pattern** - Data layer abstraction for local storage and APIs
- **SQLite Storage** - Persistent local database for auto-import state
- **Firefly III Integration** - REST API integration for transaction management
