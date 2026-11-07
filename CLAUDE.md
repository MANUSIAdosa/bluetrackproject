# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project rules

`AGENTS.md` is the authoritative product, scope, and workflow spec: implement only the week/subproject explicitly requested, respect Release 1/2 gating, and follow the inspect → scope → plan → implement → verify → report cycle. Read it before changing code. This file only covers commands and architecture.

## Commands

```bash
flutter pub get                    # after any dependency or asset change
flutter analyze                    # must be clean
flutter test                       # full suite
flutter test test/donation_trace_page_test.dart
flutter test test/donation_trace_page_test.dart --plain-name "opens the project reports tab"
flutter test --update-goldens test/_p08_visual_check_test.dart
flutter run                        # targets currently configured: Android, web
flutter build apk
flutter build web
dart format lib test
```

Asset directories must be registered under `flutter: assets:` in `pubspec.yaml`; when adding a new directory, run `flutter pub get` afterwards or asset loads fail.

## Architecture

### Bootstrap

- `lib/main.dart` initializes Hive (box `saved_projects`), loads `SavedProjectsController`, reads the onboarding flag from `shared_preferences`, initializes `AuthController`, then runs `ProviderScope(child: BlueTrackApp(...))`.
- `lib/app/app.dart` builds `MaterialApp.router` with `buildAppTheme()`, `AppLocalizations`, and `createRouter(onboardingDone:)`.
- `lib/core/config/app_config.dart` is the single source for fixed values: Release 2 flag, storage keys, mock OTP rules, donation amounts/presets, mock page size, and `TabConfig` (bottom-nav tab list and count). Never duplicate these values inside widgets.

### Routing and navigation

- `lib/core/router/routes.dart` owns path constants, URL builders (`Routes.projectDetailUrl(id)`, `Routes.donationTraceUrl(id)`, …), and `allRoutes`. `Routes.isKnown()` validates notification targets against `allRoutes`, so register every new route there and navigate through the builders instead of hardcoding strings.
- `lib/core/router/app_router.dart` is the only router. Detail routes use `parentNavigatorKey: rootKey` so they push above the shell and show a back button. The four tabs live inside one `StatefulShellRoute.indexedStack`, preserving each tab's history and scroll position: `/explore`, `/actions`, `/impact`, `/profile`.
- The onboarding redirect is synchronous and reads `OnboardingController`, seeded by `createRouter(onboardingDone:)`; it never writes preferences itself.
- Page variants are driven by query parameters: `?tab=` (project detail tabs, grants), `?view=map`, `?redirect=`, etc.
- Code reality vs. `AGENTS.md`: the shell's second tab is **Aksi** (`/actions`), which replaced the former Transparansi tab. `transparency_page.dart` and the `/transparency` routes still exist in older docs but are not registered in the current router. Treat `AGENTS.md` as the product source and confirm with the product owner before rewiring navigation.

### State management (hybrid by design)

- Riverpod (`flutter_riverpod`) is used for P13 notifications only: `notificationRepositoryProvider`, `notificationListProvider` (an `AsyncNotifier` that re-reads the repository after every mutation), and `unreadCountProvider` (derived badge count). Any widget watching these must sit under a `ProviderScope`; tests override the repository provider with a fake.
- Everything else uses singleton `ChangeNotifier` controllers from `lib/core/state/app_state.dart` (`AuthController`, `OnboardingController`, `SavedProjectsController`, `OfflineController`) with `ListenableBuilder`/`AnimatedBuilder`. `OnboardingState` owns the `shared_preferences` writes.
- Persistence split: `shared_preferences` for onboarding flag/interests, `flutter_secure_storage` for the mock auth token, Hive box `saved_projects` for saved ids, and Hive box `saved_project_snapshots` (opened lazily by `SavedProjectStore`) for offline project payloads.

### Data layer

- Each feature has `data/` interfaces plus mock implementations that read `assets/mock/*.json` through `rootBundle`. UI depends on the interface so a real API can replace mocks without rewriting pages.
- `lib/features/repositories.dart` is the app-wide registry for projects, filters, organizations, and notifications. Other features use their own repositories directly (for example, `DonationTracePage` accepts an optional repository for tests).
- `DonationMemoryStore` bridges donations created at runtime by the P06 flow into P08, where they do not exist in the JSON assets.
- Widget tests must not rely on real asset IO inside fake-async frames; use the fakes in `test/support/test_harness.dart` or call a repository's `loadFromAsset()` from a plain unit test.

### Localization, theme, formatting

- `lib/core/localization/app_localizations.dart` is a custom map-based ID/EN implementation, not ARB/intl. Access strings with `context.tr('key', {'n': '2'})`; never hardcode user-facing text. Every new key must be added to both `id` and `en` maps — `test/localization_test.dart` enforces key parity, non-empty values, and matching `{placeholders}`.
- `lib/core/theme/app_colors.dart` defines `AppColors` and `AppDimens` (16dp padding, 16dp card radius). `app_theme.dart` builds the Material 3 theme (Plus Jakarta Sans, ocean/teal/coral, component themes).
- `Formatters` in `lib/core/utils/formatters.dart` formats currency, dates, numbers, and notification timestamps by active locale. Use it instead of formatting inline.

### UI composition

- Feature folders map to product areas: `explore` (P03), `project` (P04 detail/reports/reviews), `organization` (P05), `donation` (P06), `support` (P08 trace/E-Receipt), `notification` (P13), plus `onboarding`, `auth`, `impact`, `learn`, `profile`, `settings`, and the Aksi family (`actions`, `report`, `my_reports`, `my_actions`, `community_action`). `transparency` exists but is currently unrouted.
- `lib/shared/widgets/` holds reusable widgets used across features (`PrimaryButton`, `ProjectCard`, `ProgressRing`, `EmptyState`, `ErrorState`, `Skeleton`, `OfflineBanner`, `LoginPromptCard`, `DonationTimeline`, …). Reuse them; never copy a widget into a feature folder.
- Pages live under `lib/features/<feature>/presentation/`, with feature-only widgets in `presentation/widgets/`.
- Pages handle loading, empty, error, offline, and login-required states through the shared widgets.

### Testing

- `test/support/test_harness.dart` provides `wrapPage` (theme + localization + `ProviderScope` with a fake notification repository), `wrapRouter`, `phoneSized`, `buildProject`, and in-memory fake repositories. Prefer these over asset-backed mocks in widget tests.
- Widget tests assert rendered Indonesian/English copy and stable `ValueKey` names (for example `p08-view-reports`). Visual checks/goldens live beside the tests that produce them; regenerate intentionally after visual changes with `--update-goldens` and review the PNG.
- Tests that touch Hive must initialize it against a temp directory first (see `test/routes_test.dart`). The app shell cannot always `pumpAndSettle` because Explore contains non-settling animation; fixed `pump(Duration)` calls are used there.

## Token Efficiency Rules

- Prefer minimal context usage and concise responses.
- Do not use brainstorming for simple tasks.
- Do not create extensive planning documents for small changes.
- Avoid subagents unless explicitly necessary.
- Prefer sequential execution over parallel agents.
- Use existing dependencies and project architecture.
- Avoid unnecessary code refactoring.
- Run only relevant tests.
- Do not repeat file analysis unless necessary.
- Explain completed changes briefly.
- Prioritize correctness over unnecessary abstractions.
