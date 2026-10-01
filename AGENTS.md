# AGENTS.md — BlueTrack

Permanent project context for BlueTrack. Read this before any code change. The original Word spec and Excel logbook are not required to understand scope.

## 1. Identity

- BlueTrack — Flutter/Dart mobile app: marine conservation + transparent donation platform (university group project).
- Core value is TRUST: every donation traceable, every project evidenced, grant selection public.
- **Staged development, week by week. Never build the whole app at once.**
- Communicate in Indonesian unless asked otherwise; code identifiers stay in English.

## 2. Scope boundary (non-negotiable)

**The current user request defines the implementation boundary.** The full page inventory is a product map, not permission to implement everything.

| Request | Implement |
| --- | --- |
| "Buat minggu 01" | Only Week 01 tasks |
| "Buat minggu 02" / "03" | Only that week |
| "Buat minggu 01-03" / "Buat subproyek 01" | Only SP01 (Weeks 01–03), nothing beyond |
| "Lanjut minggu berikutnya" | Next unfinished week, determined from task tracker + repo state |
| "Lanjut subproyek berikutnya" | Next unfinished subproject, from task tracker |

- Subproject week ranges only (no task details exist in this context): SP02 = Weeks 4–5, SP03 = Weeks 6–8, UTS, SP04 = Weeks 9–11, SP05 = Weeks 12–13, SP06 = Weeks 14–16, UAS. **Never invent later subproject assignments — ask the user for the breakdown.**
- Do not auto-implement: all P00–P17, Release 2, a backend, a framework change, architecture rewrites, unrelated features, deleted working functionality.
- Do not invent grant tier limits, financial rules, or scoring values — the product owner decides. On ambiguity: preserve the documented requirement, add a TODO, explain what's missing, ask before assuming.
- Recommended dev order (shell+onboarding → explore/detail → donation → transparency/trace → login/impact → proposals → learn/profile → Release 2) does **not** override the weekly assignment.

## 3. Release gating

**Release 1 pages:** P00 App Shell, P01 Onboarding, P02 Auth, P03 Explore, P04 Project Detail, P05 Org Profile, P06 Donation, P07 Transparency, P08 Trace/E-Receipt, P09 My Impact, P11 Submit Proposal, P12 My Proposals, P13 Notifications, P16 Learn, P17 Profile/Settings.

**Release 2 — never build before explicitly requested:** P10 Corporate Grants, P14 Grant Hub, P15 Proposal Detail, public voting, finalists, selection statistics, expert review details, the Hibah bottom-nav tab.

**Explicitly excluded — never build, never replace with invented features:** intermediary org selection dashboard (separate web app, not here), volunteer training, volunteer certificates, forum, comments, volunteer badges.

Routes: P00 ShellRoute; `/onboarding`, `/auth`, `/explore` (`?view=map`), `/project/:id` (`?tab=reports`), `/org/:id`, `/donate/:projectId`, `/donate/status/:donationId`, `/donate/platform`, `/transparency`, `/transparency/trace/:donationId`, `/impact`, `/grants/corporate`, `/grants/apply`, `/grants/my-proposals` (+ `/:id`), `/grants` (+ `/:id`, `?tab=vote|finalists|stats`), `/proposal/:id` (`?tab=expert`), `/learn`, `/profile`, `/settings`.

## 4. Product invariants (easy to get wrong)

- **Fund A (program donations): 100% to projects. Fund B (operational donations/sponsors): platform costs. Never mix.** All fixed financial values live in one config file — never hardcoded in widgets.
- Transparency, donation trace (public part), and Learn need **no login**. Ask for login only when a protected action requires it, via prompt card/screen, then return the user to the original page **and step**.
- Never show "ditolak" in user-facing UI. Failed selection = "Belum lolos seleksi siklus ini".
- Grant selection: weighted expert assessment with publicly disclosed **and locked** weights; public vote is one component only; voting never paid or rewarded.
- Sponsors/vendors must not control content, project priorities, or conservation decisions.
- Bottom nav: exactly 4 tabs in Release 1 (Jelajahi, Transparansi, Dampakku, Profil); 5 with Hibah in Release 2 — controlled by **one release config flag**, not duplicated per widget. Tabs preserve scroll position and history (`StatefulShellRoute` or equivalent). Every non-primary page has a back button. P11/P12/P13/P16 reachable via Profile in Release 1; bell icons on Explore and My Impact open P13. My Impact shows a login prompt when logged out instead of blocking silently.
- Saved projects and reports must work offline; show an offline banner in the shell.
- Mock OTP is `123456`; max 3 attempts before resend; 60s countdown; token stored with `flutter_secure_storage`.
- Onboarding: 5 interests (Penyu, Karang, Mangrove, Mamalia laut, Lamun), at least one required ("Pilih minimal satu"), saved via `shared_preferences` (`onboarding_done = true`), used to sort Explore.
- P11 grant tiers come from `assets/mock/grant_tiers.json`.

## 5. Code conventions

- Feature-oriented structure under `lib/` (`app/`, `core/{config,constants,router,theme,localization,utils}`, `shared/widgets`, `features/<name>/{data,domain,presentation}`). This is guidance — **inspect the repo first and preserve the architecture that actually exists.**
- Reusable widgets live once in `shared/widgets` — never copied into feature folders.
- Every applicable screen handles: loading, empty, error, offline, login-required — via shared state widgets.
- No hardcoded user-facing strings: all UI text supports Indonesian + English; numbers/dates follow active locale.
- UI: Material 3, ocean blue/teal/coral, Plus Jakarta Sans, 16dp base padding, 16dp card radius.
- **Mock data only — no backend.** Data comes from repository interfaces with mock implementations (JSON under `assets/mock/`) so a real API can later replace mocks without UI rewrites. Never change framework or add a backend without permission.
- Dependencies allowed where appropriate: `go_router`/`StatefulShellRoute`, `shared_preferences`, `flutter_secure_storage`, `flutter_form_builder`, `Hive` (saved projects). No unnecessary dependencies.

## 6. Repository state (verified 2026-10-01)

- Bare Flutter starter: only `lib/main.dart` (Hello World `MaterialApp`). No `test/`, no `assets/`, no `lib/` structure yet, default README. Git remote: `MANUSIAdosa/bluetrackproject`.
- Flutter 3.47.5 stable / Dart 3.13.4 (matches `pubspec.yaml` `sdk: ^3.13.4`); `flutter_lints ^6.0.0`; `analysis_options.yaml` excludes `build/`, `android/`, `web/`.
- None of the spec'd packages are installed yet.
- **Gotcha:** adding `assets/mock/` requires declaring it under `flutter: assets:` in `pubspec.yaml` + `flutter pub get`, or asset loads fail.

## 7. Mandatory workflow per request

1. **Inspect repo** — current files, `pubspec.yaml`, architecture, routes, components. Do not assume it's empty or that a prior task was completed.
2. **Determine scope** — subproject, week(s), exact tasks, excluded tasks.
3. **Plan** concisely.
4. **Implement** only in scope: reuse existing components, no unrelated rewrites, no future features, no backend, no undocumented functionality.
5. **Verify** — run `flutter pub get` after dependency changes, then `flutter analyze`, `flutter test`. Report actual results honestly; never claim a command ran when it didn't.
6. **Report** — requested scope, tasks completed, files created/modified, verification results, known issues, remaining tasks, next unfinished week.

### Task statuses

`IDLE` · `IN PROGRESS` · `DONE` · `BLOCKED`. Code generated ≠ DONE; verify first. Never mark future tasks complete. If the Excel logbook isn't in the repo, report status in your response instead of pretending to update it.

## 8. Weekly assignments — Subproject 01 (deadline 2026-10-07)

Logbook lists all four groups as IDLE until repo inspection proves otherwise. Task groups are independent — do not implement another group's tasks.

**Week 01 — Foundation**
- G1 · P00/P01 (Trevan Edgard): Material 3 theme — colors (ocean blue, teal, coral), Plus Jakarta Sans, 16dp padding, 16dp card radius.
- G2 · P02 (Anthony Louis): login form layout — email field, phone +`62` prefix, Continue, Send Code, privacy policy text, continue-without-login link.
- G3 · P03 (Richie Hujaya): shared widgets — PrimaryButton, StepIndicator, VerifiedBadge, FilterChipRow, ProgressBar, Skeleton, EmptyState, ErrorState.
- G4 · P04/P05 (Vincent Oswaldo Tio): mock project + org data; P04 header (image gallery, dot indicator, category chip, title, org row, VerifiedBadge).

**Week 02 — Main components**
- G1 · P00: BottomNavigationBar 4 tabs (icons, labels, notification badge), App Shell, offline banner.
- G2 · P02: six OTP boxes, resend countdown, validation error, button loading state.
- G3 · P03: ProjectCard, ProgressRing, Explore app bar, search field, category FilterChipRow, list/map toggle, project list.
- G4 · P04: funding card (progress, raised, target), TabBar (Tentang/Anggaran/Laporan/Ulasan), About tab, sticky Donate button.

**Week 03 — Completion**
- G1 · P01: ocean fact slides (~55% illustration area), dot indicator, Skip, Next → Choose Interests, interest grid (5 interests), Start button.
- G2 · P02/P06: shared login prompt card; P06 StepIndicator, quick amount chips, custom amount field, one-time/monthly toggle, Continue.
- G3 · P03: horizontal "Untuk minatmu" section, Tersimpan chip, loading/empty/error states.
- G4 · P04/P05: P04 Budget tab table; P05 org header, numeric summary card, verification checklist, download audit, contact buttons.
