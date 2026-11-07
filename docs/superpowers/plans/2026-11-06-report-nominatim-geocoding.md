# Nominatim Geocoding (Nama Area + Pencarian Alamat) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the reporter see a human-readable area name for the pin and search a location by address through public Nominatim, without weakening the pin/coordinate as the authoritative location.

**Architecture:** One `GeocodingService` interface with a Nominatim HTTP implementation behind it, consumed only by the report location step. The wizard injects the service for tests. Coordinates stay authoritative; resolved names only prefill the landmark field when the user has not typed one.

**Tech Stack:** Flutter/Dart, `http` 1.6.0 (already present transitively), `flutter_map`, existing localization and widget-test patterns.

**Spec:** `docs/superpowers/specs/2026-11-06-report-nominatim-geocoding-design.md`

## Global Constraints
- Public Nominatim: absolute maximum 1 request/second, app-identifying User-Agent (skipped on web because browsers forbid that header), attribution "Data © OpenStreetMap contributors", user-initiated requests only — no search-as-you-type.
- Minimum 1.1 s between requests; search buttons disabled while loading, offline, or when the query is empty.
- Max 5 forward results; reverse result cached per 4-decimal coordinate.
- 8 s timeout; 429 → rate-limited copy; empty results → guidance copy; every failure keeps the manual pin usable.
- Never overwrite landmark text the user already typed.
- No new backend, no report model change, four wizard steps unchanged, Indonesian + English copy for every new string.

## Design pass (frontend-design + 8 Golden Rules)
- Palette/type unchanged: ocean `#0284C7`, teal `#14B8A6`, coral `#FF6F61`, background `#F6F9FC`, Plus Jakarta Sans, 16 dp padding, 16 dp card radius.
- Layout: map stays the hero; below it one column, left aligned: area name row → address search → landmark field. `+--------------------------------------+ | [ map with pin ] | | Nama area [Cari nama area] | | Dekat Pantai Sukamade | | Data © OpenStreetMap | | Cari alamat [.......] [Cari] | | · result 1 | | · result 2 | | Patokan atau area sekitar (opsional)| +--------------------------------------+`
- Principles: no new card kit or decoration; results are a bordered panel at 12 dp; secondary 11–12 px attribution; sentence-case labels; one clear action per row.
- 8 Golden Rules mapping: consistency (existing field/button styles), universal usability (works for sea and land; address optional), informative feedback (loading, empty, error, rate-limit copy), closure (selected result visibly moves pin and names the area), error prevention (no autocomplete floods, buttons disabled when invalid), easy reversal (pin drag still works; text never overwritten), user control (explicit search buttons), reduce memory load (name + attribution shown next to coordinates).

## Review Focus
- Offline: both new actions disabled with explanation; pin still works.
- 429 and timeout: distinct copy, no crash, retry possible.
- Empty results: guidance, not a dead end.
- User-typed landmark is never overwritten by a resolved name.
- Selecting a result moves pin and coordinates to that place, and the draft persists them.
- Web: User-Agent header omitted instead of throwing.

---

### Task 1: Geocoding domain and Nominatim service

**Files:**
- Create: `lib/features/report_submit/domain/geocoding.dart`
- Create: `lib/features/report_submit/data/geocoding_service.dart`
- Modify: `pubspec.yaml` (add `http: ^1.6.0`)
- Test: `test/geocoding_service_test.dart`

**Interfaces:**
- `GeocodingPlace({required String displayName, required double latitude, required double longitude})`
- `enum GeocodingFailure { timeout, rateLimited, unavailable, empty }`
- `GeocodingSearchResult.success(List<GeocodingPlace>)` / `.failed(GeocodingFailure)` with `hasPlaces`
- `GeocodingPlaceResult.success(GeocodingPlace)` / `.failed(GeocodingFailure)` with `hasPlace`
- `abstract interface class GeocodingService { Future<GeocodingSearchResult> search(String query, {String languageCode}); Future<GeocodingPlaceResult> reverse({required double latitude, required double longitude, String languageCode}); }`
- `NominatimGeocodingService({http.Client? client, Uri? baseUri, Duration timeout = 8s, Duration minInterval = 1100ms, String userAgent, Future<void> Function(Duration)? wait, DateTime Function()? now})`

- [x] Write failing tests: search URL/params/User-Agent and parsing; reverse parsing; 429; empty; timeout; 1.1 s throttle.
- [x] Run `flutter test test/geocoding_service_test.dart`; expected failures are missing files/behavior.
- [x] Add `http` dependency, run `flutter pub get`, implement domain and service.
- [x] Run the same test file; expect PASS.

### Task 2: Location step UI

**Files:**
- Modify: `lib/features/report_submit/presentation/widgets/report_location_step.dart`
- Modify: `lib/core/localization/app_localizations.dart`
- Test: `test/report_location_step_test.dart`

**Interfaces:**
- `ReportLocationStep` gains `GeocodingService? geocodingService` (defaults to `NominatimGeocodingService()`).
- Uses `OnboardingState`-free local state; reads `OfflineController.instance`.

- [x] Write failing widget tests: reverse fills the area name and prefills an empty landmark; typed landmark is preserved; search shows results and selecting one moves the pin; offline disables both actions; failure copy renders.
- [x] Run `flutter test test/report_location_step_test.dart`; confirm RED for missing UI.
- [x] Implement the area row, address field + search button, results panel, attribution, loading/empty/error states, and both localized copy sets.
- [x] Run the test file; expect PASS.

### Task 3: Wizard wiring and persistence

**Files:**
- Modify: `lib/features/report_submit/presentation/pages/report_wizard_page.dart`
- Test: `test/report_wizard_page_test.dart`

**Interfaces:**
- `ReportWizardPage` gains `GeocodingService? geocodingService`, forwarded to `ReportLocationStep`.

- [x] Write failing test: selecting a search result moves the pin, prefills the landmark when empty, and the draft stores the coordinates and text after the debounce.
- [x] Run `flutter test test/report_wizard_page_test.dart`; confirm RED.
- [x] Wire the injected service through the wizard.
- [x] Run the test file; expect PASS.

### Final focused verification
- [x] `flutter test test/geocoding_service_test.dart test/report_location_step_test.dart test/report_wizard_page_test.dart test/localization_test.dart`
- [x] `flutter analyze`
