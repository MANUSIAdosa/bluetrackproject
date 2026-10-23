/// Centralized route paths and URL builders.
///
/// The router registers the constants below and every push uses the URL
/// helpers, so no navigation code hardcodes a path string. Dynamic-path
/// constants keep their `:param` patterns; the `...Url` helpers turn an id
/// into the actual URL — parameter order can never get swapped.
abstract final class Routes {
  // --- Static paths -------------------------------------------------------
  static const onboarding = '/onboarding';
  static const auth = '/auth';
  static const explore = '/explore';
  static const impact = '/impact';
  static const notifications = '/notifications';
  static const learn = '/learn';
  static const profile = '/profile';
  static const settings = '/settings';

  // --- Dynamic path patterns (register these) -----------------------------
  static const projectDetail = '/project/:id';
  static const orgDetail = '/org/:id';
  static const donation = '/donate/:projectId';
  static const donationStatus = '/donate/status/:donationId';

  // --- Tab Aksi & its sub-routes (provisional names) ----------------------
  // TODO(P00-part-3): provisional paths still to be agreed with the team; do
  // not remove the routes themselves.
  static const actionAgenda = '/actions';
  static const actionDetail = '/actions/:id';
  static const report = '/report';
  static const myReports = '/my-reports';
  static const myActions = '/my-actions';
  static const communityActionApply = '/community-action/apply';
  static const donationTrace = '/support/trace/:donationId';

  // --- Existing app paths outside the Part 3 table ------------------------
  static const legalPrivacy = '/legal/privacy';
  static const legalTerms = '/legal/terms';
  static const donatePlatform = '/donate/platform';

  // --- URL helpers for the dynamic routes --------------------------------
  static String projectDetailUrl(String id) => '/project/$id';

  static String orgDetailUrl(String orgId) => '/org/$orgId';

  static String donationUrl(String projectId) => '/donate/$projectId';

  static String donationStatusUrl(String donationId) =>
      '/donate/status/$donationId';

  static String donationTraceUrl(String donationId) =>
      '/support/trace/$donationId';

  static String actionDetailUrl(String actionId) => '/actions/$actionId';
}
