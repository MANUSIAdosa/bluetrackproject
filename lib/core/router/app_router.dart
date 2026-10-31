import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/state/app_state.dart';
import '../../features/actions/presentation/action_detail_page.dart';
import '../../features/actions/presentation/actions_page.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/community_action/presentation/community_action_apply_page.dart';
import '../../features/donation/presentation/donate_amount_page.dart';
import '../../features/donation/presentation/donate_status_page.dart';
import '../../features/explore/presentation/explore_page.dart';
import '../../features/impact/presentation/impact_page.dart';
import '../../features/learn/presentation/learn_page.dart';
import '../../features/legal/presentation/legal_page.dart';
import '../../features/my_actions/presentation/my_actions_page.dart';
import '../../features/my_reports/presentation/my_reports_page.dart';
import '../../features/notification/presentation/notifications_page.dart';
import '../../features/onboarding/presentation/onboarding_page.dart';
import '../../features/organization/presentation/org_profile_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/project/presentation/project_detail_page.dart';
import '../../features/report_submit/presentation/pages/report_success_page.dart';
import '../../features/report_submit/presentation/pages/report_wizard_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/shell/app_shell.dart';
import '../../features/support/presentation/donation_trace_page.dart';

/// Centralized router.
///
/// - StatefulShellRoute keeps per-tab scroll position and navigation history.
/// - Detail routes (P04/P05/P06/P07/P08/P10/P11/P12/P13/P15/P16/P17) live at
///   the spec paths and push above the shell using the root navigator, so each
///   page shows a back button.
/// - `?tab=` / `?redirect=` / `?view=` query parameters are read by pages.
/// - The onboarding redirect uses the controller seeded below: it is
///   synchronous (preferences are async), never sets the flag itself, and
///   cannot loop (either branch points at the other page, once).
GoRouter createRouter({required bool onboardingDone}) {
  final rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

  // Seed the sync flag the redirect reads from the value main()/tests read
  // from shared_preferences. Rerun on every router rebuild (pumpWidget in
  // tests) so the value always matches the widget under test.
  OnboardingController.instance.init(onboardingDone);

  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: onboardingDone ? Routes.explore : Routes.onboarding,
    redirect: (context, state) {
      final done = OnboardingController.instance.done;
      final location = state.matchedLocation;
      if (!done && location != Routes.onboarding) {
        return Routes.onboarding;
      }
      if (done && location == Routes.onboarding) {
        return Routes.explore;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.onboarding,
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(
        path: Routes.interests,
        parentNavigatorKey: rootKey,
        builder: (context, state) => const OnboardingPage(editInterests: true),
      ),
      GoRoute(
        path: Routes.auth,
        builder: (context, state) =>
            LoginPage(redirect: state.uri.queryParameters['redirect']),
      ),
      GoRoute(
        path: Routes.notifications,
        parentNavigatorKey: rootKey,
        builder: (context, state) => const NotificationsPage(),
      ),
      GoRoute(
        path: Routes.learn,
        parentNavigatorKey: rootKey,
        builder: (context, state) => const LearnPage(),
      ),
      GoRoute(
        path: Routes.settings,
        parentNavigatorKey: rootKey,
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: Routes.legalPrivacy,
        parentNavigatorKey: rootKey,
        builder: (context, state) => const LegalPage(documentKey: 'privacy'),
      ),
      GoRoute(
        path: Routes.legalTerms,
        parentNavigatorKey: rootKey,
        builder: (context, state) => const LegalPage(documentKey: 'terms'),
      ),
      GoRoute(
        path: Routes.projectDetail,
        parentNavigatorKey: rootKey,
        builder: (context, state) => ProjectDetailPage(
          projectId: state.pathParameters['id'] ?? '',
          initialTab: state.uri.queryParameters['tab'],
        ),
      ),
      GoRoute(
        path: Routes.orgDetail,
        parentNavigatorKey: rootKey,
        builder: (context, state) =>
            OrgProfilePage(orgId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: Routes.donationStatus,
        parentNavigatorKey: rootKey,
        builder: (context, state) => DonateStatusPage(
          donationId: state.pathParameters['donationId'] ?? '',
        ),
      ),
      GoRoute(
        path: Routes.donation,
        parentNavigatorKey: rootKey,
        builder: (context, state) => DonateAmountPage(
          projectId: state.pathParameters['projectId'] ?? '',
        ),
      ),
      // --- Part 3 detail placeholders (previously unrouted) ------------------
      // TODO(P00-part-3): Aksi-family paths are proposals still to be agreed
      // with the team; do not remove the routes.
      GoRoute(
        path: Routes.donationTrace,
        parentNavigatorKey: rootKey,
        builder: (context, state) => DonationTracePage(
          donationId: state.pathParameters['donationId'] ?? '',
        ),
      ),
      // /actions/:id must reach ActionDetailPage, never the /actions tab
      // branch below, so it lives at the root navigator as its own route.
      GoRoute(
        path: Routes.actionDetail,
        parentNavigatorKey: rootKey,
        builder: (context, state) =>
            ActionDetailPage(actionId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: Routes.report,
        parentNavigatorKey: rootKey,
        builder: (context, state) => ReportWizardPage(
          // Set by the login round trip so the draft reopens on step 4.
          autoResume: state.uri.queryParameters['resume'] == '1',
        ),
      ),
      GoRoute(
        path: Routes.reportSuccess,
        parentNavigatorKey: rootKey,
        builder: (context, state) =>
            ReportSuccessPage(reportId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: Routes.myReports,
        parentNavigatorKey: rootKey,
        builder: (context, state) => const MyReportsPage(),
      ),
      GoRoute(
        path: Routes.myActions,
        parentNavigatorKey: rootKey,
        builder: (context, state) => const MyActionsPage(),
      ),
      GoRoute(
        path: Routes.communityActionApply,
        parentNavigatorKey: rootKey,
        builder: (context, state) => const CommunityActionApplyPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(shell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.explore,
                builder: (context, state) => const ExplorePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                // TODO(P00-part-2): provisional route name for the Aksi tab
                // (revised concept: Lapor → Pantau → Aksi → Dukung). The old
                // Transparansi tab is replaced; transparency_page.dart stays
                // in the repo but is no longer routed.
                path: Routes.actionAgenda,
                builder: (context, state) => const ActionsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.impact,
                builder: (context, state) => const ImpactPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.profile,
                builder: (context, state) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
