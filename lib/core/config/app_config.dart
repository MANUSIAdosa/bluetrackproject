/// Central application configuration.
///
/// All fixed values live here — never hardcode them inside widgets.
abstract final class AppConfig {
  // --- Release gating -----------------------------------------------------
  /// Release 2 adds the Hibah tab (5 tabs total). Must stay false until the
  /// user explicitly requests Release 2 work.
  static const bool isRelease2 = false;

  // --- Preference / storage keys -----------------------------------------
  static const String onboardingDoneKey = 'onboarding_done';
  static const String interestsKey = 'selected_interests';
  static const String savedProjectsBox = 'saved_projects';

  // --- Onboarding ---------------------------------------------------------
  // TODO(P01-part-4): the five interest IDs are the revised set
  // (Sampah Laut, Terumbu Karang, Mangrove, Perikanan Berkelanjutan,
  // Satwa Laut). `assets/mock/projects.json` still trains the OLD categories,
  // so Explore's "Untuk minatmu" sorting only matches `mangrove` until the
  // mock data is revised in its own part.
  static const List<String> interestIds = [
    'sampah_laut',
    'terumbu_karang',
    'mangrove',
    'perikanan',
    'satwa_laut',
  ];

  // --- Auth (mock) --------------------------------------------------------
  static const String mockOtp = '123456';
  static const int otpMaxAttempts = 3;
  static const int otpResendSeconds = 60;

  // --- Notifications ------------------------------------------------------
  // The unread count lives in the mock NotificationRepository, not here.

  // --- Donation (mock) ----------------------------------------------------
  // Product-confirmed Periode 2 part-1 amounts. Names keep the existing
  // "donation" family so no UI file needs renaming; the rename to the revised
  // "dukungan" wording belongs to the part that revises the donate UI.
  /// Minimal amount for a donation, in rupiah (no decimals) — minimum dukungan.
  static const int minDonationAmount = 10000;

  static const List<int> donationPresets = [25000, 50000, 100000, 250000];

  // --- Mock pagination -----------------------------------------------------
  /// Items per page for mock pagination (there is no real backend paging).
  static const int mockPageSize = 10;

  // --- Report wizard ------------------------------------------------------
  /// Default map centre for Step 2 (Lokasi) before the user places a pin.
  ///
  /// Mirrors the first entry in `assets/mock/locations.json` (Pantai
  /// Sukamade). TODO(lapor): the product owner should choose a neutral
  /// starting point (for example Indonesia's centre or the user's region)
  /// instead of a project site.
  static const double reportDefaultLatitude = -8.5236;
  static const double reportDefaultLongitude = 114.6131;

  // --- Report submission (simulation) -------------------------------------
  /// Simulated "send to server" delay so the loading state is visible.
  ///
  /// TODO(lapor): remove once a real API client replaces the mock submission.
  static const Duration reportSubmitDelay = Duration(milliseconds: 900);

  /// Flip to true to force every submission to fail, so the error and
  /// "Coba lagi" states can be checked manually. Tests inject a failing
  /// [ReportSubmissionService] instead.
  ///
  /// TODO(lapor): remove together with [reportSubmitDelay].
  static const bool reportSubmitSimulateFailure = false;

  /// Reporter identity used by the simulated submission until the auth
  /// session exposes the signed-in user.
  ///
  /// TODO(lapor): read the user id and display name from the auth session.
  static const String reportCurrentUserId = 'u-me';
  static const String reportCurrentUserName = 'Pengguna BlueTrack';

  /// Location the simulated report is attached to.
  ///
  /// The wizard only collects coordinates; the real flow should either let the
  /// user pick a project or let the backend resolve the nearest location.
  ///
  /// TODO(lapor): replace with the resolved location id from the API.
  static const String reportSimulatedLocationId = 'p01';
}

/// Release-gate configuration for the bottom-nav tabs (P00).
///
/// [AppConfig.isRelease2] still gates the optional Release 2 tab overall; the
/// flags below control each core tab individually. The active list and its
/// length are always derived here — never copied elsewhere:
/// `features/shell/app_shell.dart` binds every enabled tab id to its shell UI.
///
/// TODO(P00-part-UI): until the router branches are also driven by these
/// flags, keep every flag `true` — flipping one would desync the nav bar from
/// the hardcoded [StatefulShellRoute] branches.
class TabConfig {
  const TabConfig({
    required this.id,
    required this.name,
    required this.enabled,
  });

  /// Stable identifier used by the shell to bind this entry to its UI.
  final String id;

  /// Canonical tab name (from the revised concept). The visible label still
  /// lives in localization and keeps `nav.*` keys.
  final String name;

  /// Release flag: `false` keeps the tab out of the bottom nav.
  final bool enabled;

  /// Ordered per the revised concept: Jelajahi → Aksi → Dampakku → Profil.
  static const List<TabConfig> all = [
    TabConfig(id: 'jelajahi', name: 'Jelajahi', enabled: true),
    TabConfig(id: 'aksi', name: 'Aksi', enabled: true),
    TabConfig(id: 'dampakku', name: 'Dampakku', enabled: true),
    TabConfig(id: 'profil', name: 'Profil', enabled: true),
  ];

  /// Active tabs in configuration order.
  static List<TabConfig> get active =>
      all.where((tab) => tab.enabled).toList(growable: false);

  /// Active tab count, always computed from [active].
  static int get count => active.length;
}
