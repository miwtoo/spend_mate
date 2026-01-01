# AGENTS.md

## Project Context
`spend_mate` is an AI-Powered Mobile Client for **Firefly III**. 
It acts as a "Smart Remote" for personal finance, shifting from manual data entry to **Intent-Based Tracking** using OCR and Natural Language Chat.

## Architectural Strategy
The app functions as a middleman between the user and a Firefly III instance, following the official [Flutter App Architecture Guide](https://docs.flutter.dev/app-architecture/guide).

### High-Level Flow
- **Frontend**: Flutter (Mobile: Android/iOS).
- **AI Layer**: Google Gemini API. Parsers unstructured inputs (images, voice) into structured JSON.
- **Backend**: Self-hosted Firefly III instance (REST API).

### Layered Architecture (MVVM Style)
1.  **UI Layer**
    *   **Views**: Flutter Widgets (Stateless/Stateful). Passive rendering, no business logic.
    *   **ViewModels**: State Management (Bloc/Riverpod). Handles state, user input, and transforms data for the View.
2.  **Domain Layer (Optional)**
    *   **Use Cases**: Encapsulate complex business logic involving multiple repositories. Use only when logic is too complex for ViewModels.
3.  **Data Layer**
    *   **Repositories**: Single source of truth. Orchestrates data fetching, caching, and error handling. Returns Domain Models.
    *   **Services**: Low-level wrappers for APIs (e.g., `FireflyApiService`, `GeminiAiService`) or local storage.

## Key Features to Implement
1. **"Snap & Forget" (Vision OCR)**:
   - User takes a photo of a receipt.
   - AI extracts: Total, Date, Store Name, Currency.
   - App pre-fills transaction form.
   - **Libs**: `camera`, `image_picker`.

2. **Natural Language Chat ("Financial Concierge")**:
   - Conversational interface for adding transactions ("Sold bike for $200").
   - AI interprets: Transaction Type, Amount, Source/Dest Accounts.
   - Multi-currency support (e.g., "Paid 5000 Yen for Ramen").

3. **Debt & Loan Intelligence**:
   - Visual Debt Dashboard.
   - AI projections for payoff dates based on extra payments.

## Tech Stack & Conventions
- **Framework**: Flutter (Dart).
- **State Management**: [Pending Decision: Bloc or Riverpod].
- **AI Provider**: Google Gemini (primary target).
- **API Interaction**: REST calls to Firefly III instance.

## Dev Environment Tips
- Run `flutter pub get` immediately after pulling changes or adding dependencies.
- Use `flutter devices` to check connected devices/simulators.
- If using code generation (e.g., Freezed/JSON Serializable), run `dart run build_runner build --delete-conflicting-outputs`.
- Use `flutter pub add <package>` to add dependencies safely; check `pubspec.yaml` versions.
- **Assets**: If adding images/icons, register them in `pubspec.yaml` under `flutter: assets:`.

## Testing Instructions
- **Run all tests**: `flutter test`
- **Run specific file**: `flutter test test/features/ocr/ocr_test.dart`
- **Focus on a test**: Use `flutter test --plain-name "test description"` to run a specific test case.
- **AI Logic**: Always write unit tests for the AI parser logic (e.g., "Given this raw string, it returns this JSON") to avoid regression.
- **Mocking**: Use `mockito` or `mocktail` for Firefly API and Gemini API calls during testing.
- **Reference**: See [Compass App Tests](https://github.com/flutter/samples/tree/main/compass_app/test) for best practices.

## Code Quality & PR Instructions
- **Formatting**: Run `dart format .` to ensure standard Dart formatting.
- **Linting**: Run `flutter analyze` and fix any warnings before finishing a task.
- **Quick Fixes**: Use `dart fix --apply` to resolve simple lint errors automatically.
- **File Structure**:
  Based on the [Compass App Case Study](https://docs.flutter.dev/app-architecture/case-study):
  - `lib/`
    - `ui/`: Feature-based grouping (e.g., `features/ocr/`).
      - `core/`: Shared widgets and themes.
      - `<feature_name>/`
        - `view_models/`: State management logic.
        - `widgets/`: Feature-specific UI.
    - `domain/`: Business logic and models.
      - `models/`: Data types used across layers.
      - `use_cases/`: (Optional) Complex interactions.
    - `data/`: Data retrieval and storage.
      - `repositories/`: Coordinators of data sources.
      - `services/`: API clients and local storage wrappers.
    - `config/`: App configuration (routes, constants).
    - `main.dart`: Entry point.
  - `test/`: Matches `lib/` structure.
- **Commits**: Use conventional commits (e.g., `feat: add camera permission`, `fix: parsing logic`).
