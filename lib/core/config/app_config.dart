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
  static const List<String> interestIds = [
    'penyu',
    'karang',
    'mangrove',
    'mamalia_laut',
    'lamun',
  ];

  // --- Auth (mock) --------------------------------------------------------
  static const String mockOtp = '123456';
  static const int otpMaxAttempts = 3;
  static const int otpResendSeconds = 60;

  // --- Notifications ------------------------------------------------------
  // The unread count lives in the mock NotificationRepository, not here.

  // --- Donation (mock) ----------------------------------------------------
  // TODO(product owner): confirm the preset donation amounts below.
  static const List<int> donationPresets = [50000, 100000, 250000, 500000];

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
