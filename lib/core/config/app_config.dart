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
  /// TODO: wire to NotificationRepository once P13 is implemented; 0 hides the badge.
  static const int unreadNotifications = 0;

  // --- Donation (mock) ----------------------------------------------------
  // TODO(product owner): confirm the preset donation amounts below.
  static const List<int> donationPresets = [50000, 100000, 250000, 500000];
}
