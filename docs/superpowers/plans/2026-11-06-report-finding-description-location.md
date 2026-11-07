# Report Finding Description and Location Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Collect a required finding description, preserve exact coordinates plus an optional location landmark, and make a newly submitted report visible through the existing My Reports route.

**Architecture:** Extend the existing wizard draft and Report model with backward-compatible text fields. Keep the four-step wizard, place description with photos, keep coordinates/pin authoritative, and merge the session submission store into the already-registered My Reports page. No geocoder or new dependency.

**Tech Stack:** Flutter/Dart, GoRouter, Hive draft store, existing mock report stores, Flutter widget tests.

**Spec:** `docs/superpowers/specs/2026-11-06-report-finding-description-location-design.md`

## Global Constraints
- Keep the existing four wizard steps and existing repository architecture.
- UI copy must support Indonesian and English.
- No backend, geocoding provider, address autocomplete, or dependency changes.
- Keep latitude/longitude as the precise report location; the optional landmark is supplementary.
- Do not invent a description character limit or new report measurements.
- Per user request, run focused report tests and `flutter analyze`; do not rerun the full suite.

## Review Focus
- Old Hive drafts without new fields restore with empty defaults and remain readable.
- Whitespace-only descriptions do not allow step 1 to continue or a draft to submit.
- Optional empty location detail does not block submission; non-empty detail survives a resume.
- Reports from the session store and repository are merged without duplicate IDs.
- `AppConfig.reportCurrentUserId` and the My Reports default owner ID share one source, so actual mock submissions pass the owner filter.
- Session reports remain visible while repository data is loading or errors; loading/error feedback and retry do not hide them.
- The success CTA navigates to the registered `/my-reports` route and the new report is visible there.
- Submission state is shown as submitted, not verified.

---

### Task 1: Persist and submit report text fields

**Files:**
- Modify: `lib/features/report_submit/domain/report_draft.dart`
- Modify: `lib/features/project/domain/report.dart`
- Modify: `lib/features/report_submit/data/report_submission_service.dart`
- Test: `test/report_draft_store_test.dart`
- Create: `test/report_submission_service_test.dart`

**Interfaces:**
- Draft fields: `description` defaults to empty; `locationDetail` defaults to empty/optional. Older JSON missing either key remains readable.
- `Report.locationDetail` is optional and older report JSON remains readable.
- Mock submission copies `description` and trimmed non-empty `locationDetail` from the wizard draft.

- [x] Write failing tests for JSON round-trip, legacy draft defaults, and submission pass-through.
- [x] Run `flutter test test/report_draft_store_test.dart test/report_submission_service_test.dart`; confirm failures are for missing fields/behavior.
- [x] Implement the compatible draft/model/service fields.
- [x] Run the same targeted tests and confirm they pass.

### Task 2: Add required description to step 1

**Files:**
- Modify: `lib/features/report_submit/presentation/pages/report_wizard_page.dart`
- Modify: `lib/core/localization/app_localizations.dart`
- Test: `test/report_wizard_page_test.dart`

**Interfaces:**
- Step 1 combines photo evidence and a required multiline description.
- Description is valid iff `description.trim().isNotEmpty`.
- Review edits of the description return to step 1.

- [x] Write failing widget tests for description presence, whitespace validation, entering the description, and keeping it in the draft.
- [x] Run `flutter test test/report_wizard_page_test.dart`; confirm failures correspond to the missing behavior.
- [x] Implement the field, validation/feedback, and Indonesian/English strings without a new character limit.
- [x] Run `flutter test test/report_wizard_page_test.dart` and confirm it passes.

### Task 3: Add optional location landmark

**Files:**
- Modify: `lib/features/report_submit/presentation/pages/report_wizard_page.dart`
- Modify: `lib/features/report_submit/presentation/widgets/report_location_step.dart`
- Modify: `lib/core/localization/app_localizations.dart`
- Test: `test/report_location_step_test.dart`
- Test: `test/report_wizard_page_test.dart`

**Interfaces:**
- Step 2 adds optional `locationDetail` text; the map pin and latitude/longitude remain unchanged and authoritative.
- No address lookup or coordinate-copy action is added to the submission flow.

- [x] Write failing tests for entering/restoring location detail and for empty detail not blocking location completion.
- [x] Run `flutter test test/report_location_step_test.dart test/report_wizard_page_test.dart`; confirm failures correspond to missing behavior.
- [x] Implement optional text input, draft updates, and localized labels/help text.
- [x] Run the same targeted tests and confirm they pass.

### Task 4: Review, success, and My Reports integration

**Files:**
- Modify: `lib/features/report_submit/presentation/widgets/report_review_step.dart`
- Modify: `lib/features/report_submit/presentation/pages/report_success_page.dart`
- Modify: `lib/features/my_reports/presentation/my_reports_page.dart`
- Modify: `lib/core/localization/app_localizations.dart`
- Test: `test/report_review_submit_test.dart`
- Test: `test/my_reports_page_test.dart`

**Interfaces:**
- Review displays description, optional location detail, and coordinates; edit actions return to their owning steps.
- Success CTA navigates to `Routes.myReports` and remains enabled.
- The registered My Reports page combines repository reports and session-store reports by unique ID, with the newest report visible; session reports remain visible while repository data loads or errors.
- The default submitter and list owner use the same mock ID (`u01`) via `AppConfig.reportCurrentUserId`.
- The success summary displays the report ID and submitted status without implying verification.

- [x] Write failing widget tests for review/success details, enabled navigation, and visibility of a newly submitted session report without duplicates.
- [x] Run `flutter test test/report_review_submit_test.dart test/my_reports_page_test.dart`; confirm failures correspond to missing behavior.
- [x] Implement the summary, active route CTA, and session/repository merge with localized copy.
- [x] Run the same targeted tests and confirm they pass.

### Final focused verification

- [x] Run `flutter test test/report_draft_store_test.dart test/report_submission_service_test.dart test/report_location_step_test.dart test/report_wizard_page_test.dart test/report_review_submit_test.dart test/my_reports_page_test.dart test/localization_test.dart`.
- [x] Run `flutter analyze`.
- [x] Report the pre-existing full-suite baseline failures separately; do not rerun the full suite per the user's instruction.
