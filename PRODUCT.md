# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

## Users

**Primary — individual donors.** Mobile-first Indonesians who care about marine conservation, want to support credible projects, and want to see where their money went. They browse on a phone, often while logged out, and expect transparency without friction.

**Secondary — conservation organizations.** NGOs and community groups that publish projects, submit evidence reports, and need a credible public profile. They are not the primary Release 1 design focus, but their content and verification signals must stay trustworthy.

## Product Purpose

BlueTrack is a marine-conservation donation platform whose core value is trust. It lets people discover conservation projects, donate, and trace how each donation is used; it gives organizations a structured way to publish evidence; and it makes grant selection public. Success means a donor can answer "where did my money go?" without asking anyone, and a project can prove its work with evidence rather than claims.

## Positioning

Most donation apps stop at a progress bar. BlueTrack connects three things in one mobile experience: project discovery, a traceable donation record (including a public e-receipt/trace view), and a grant process whose weighted criteria and weights are publicly disclosed and locked. The trust mechanism — evidence, trace, and transparent selection — is the product, not a marketing layer.

## Operating Context

- Flutter mobile app, Android primary, with a web target for demos.
- Indonesian-first UI with English support; all user-facing strings are localized.
- Release 1 uses mock data; there is no backend yet. Donations, OTP, reports, and grant data are simulated.
- Donors may browse Explore, project detail, organization profile, transparency, trace, Learn, and notifications without logging in. Login is requested only when a protected action needs it, then the user returns to the same page and step.
- Saved projects and reports must work offline; the shell shows an offline banner.
- Release 2 (corporate grants, grant hub, public voting, proposal detail) is out of scope until explicitly requested.

## Capabilities and Constraints

- Release 1 pages: App Shell, Onboarding, Auth, Explore, Project Detail, Organization Profile, Donation, Transparency, Trace/E-Receipt, My Impact, Submit Proposal, My Proposals, Notifications, Learn, Profile/Settings.
- Bottom navigation has exactly four tabs: Jelajahi, Aksi, Dampakku, Profil. The Hibah tab is Release 2 and must not appear.
- Fund A (program donations) goes 100% to projects; Fund B (operational donations/sponsors) covers platform costs. They must never be mixed. Fixed financial values live in one config file.
- Mock OTP is `123456`; maximum 3 attempts; 60-second resend countdown.
- Onboarding captures five interests (Sampah Laut, Terumbu Karang, Mangrove, Perikanan Berkelanjutan, Satwa Laut), requires at least one, and uses them to sort Explore.
- Grant selection uses weighted expert assessment with publicly disclosed and locked weights; public vote is only one component and is never paid or rewarded.
- Sponsors and vendors must not control content, project priorities, or conservation decisions.
- Failed selection is shown as "Belum lolos seleksi siklus ini"; the word "ditolak" never appears in user-facing UI.
- No backend, no real payment gateway, no real authentication; repository interfaces with mock implementations are the data boundary.
- Saved projects and reports must remain usable offline.

## Brand Commitments

- Name: BlueTrack.
- Material 3, ocean blue / teal / coral palette, Plus Jakarta Sans.
- 16dp base padding and 16dp card radius.
- Bilingual Indonesian + English; Indonesian is the default.
- Tone: trustworthy, clear, calm, evidence-led. Not alarmist, not salesy, not gamified.
- Never use "ditolak" for a failed grant selection.

## Evidence on Hand

- Mock JSON data in `assets/mock/`: projects, organizations, donations, donation trace, impact, notifications, reports, reviews, education, ocean facts, locations, filters.
- Report photos in `assets/mock/` and UI screenshots in `screenshoot/`.
- 38 Dart test files covering key flows.
- `docs/validasi/trevan.md`.
- Absent: real backend, real payment transactions, real user accounts, real testimonials, audited financial statements, real grant results. Future work must not fabricate these.

## Product Principles

1. **Trust is the interface.** Every screen should make the next fact verifiable, not just persuasive.
2. **Show the evidence, not the claim.** Prefer receipts, trace steps, report photos, and public criteria over badges or slogans.
3. **Donor agency, not guilt.** Let people choose, understand, and leave without pressure; ask for login only when necessary.
4. **Money is sacred and separate.** Fund A and Fund B never blur; every amount has a visible destination.
5. **Dignity in every outcome.** Failed selection is stated neutrally and respectfully; no public shaming.

## Accessibility & Inclusion

- Bilingual Indonesian/English with locale-aware numbers and dates.
- Mobile touch targets and text must remain usable on small Android screens; do not rely on color alone to convey status.
- Offline and low-connectivity use is a first-class case for saved projects and reports.
- No formal WCAG certification has been claimed; treat AA contrast and readable type as the working bar.
