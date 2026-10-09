import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_page.dart';
import '../../features/donation/presentation/donate_amount_page.dart';
import '../../features/explore/presentation/explore_page.dart';
import '../../features/impact/presentation/impact_page.dart';
import '../../features/legal/presentation/legal_page.dart';
import '../../features/notification/presentation/notifications_page.dart';
import '../../features/onboarding/presentation/onboarding_page.dart';
import '../../features/organization/presentation/org_profile_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/project/presentation/project_detail_page.dart';
import '../../features/shell/app_shell.dart';
import '../../features/transparency/presentation/transparency_page.dart';

/// Centralized router.
///
/// - StatefulShellRoute keeps per-tab scroll position and navigation history.
/// - Detail routes (P04/P05/P06/P13) live at the spec paths and push above
///   the shell using the root navigator, so each page shows a back button.
/// - `?tab=` / `?redirect=` / `?view=` query parameters are read by pages.
GoRouter createRouter({required bool onboardingDone}) {
  final rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: onboardingDone ? '/explore' : '/onboarding',
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => LoginPage(
          redirect: state.uri.queryParameters['redirect'],
        ),
      ),
      GoRoute(
        path: '/notifications',
        parentNavigatorKey: rootKey,
        builder: (context, state) => const NotificationsPage(),
      ),
      GoRoute(
        path: '/legal/privacy',
        parentNavigatorKey: rootKey,
        builder: (context, state) =>
            const LegalPage(documentKey: 'privacy'),
      ),
      GoRoute(
        path: '/legal/terms',
        parentNavigatorKey: rootKey,
        builder: (context, state) =>
            const LegalPage(documentKey: 'terms'),
      ),
      GoRoute(
        path: '/project/:id',
        parentNavigatorKey: rootKey,
        builder: (context, state) => ProjectDetailPage(
          projectId: state.pathParameters['id'] ?? '',
          initialTab: state.uri.queryParameters['tab'],
        ),
      ),
      GoRoute(
        path: '/org/:id',
        parentNavigatorKey: rootKey,
        builder: (context, state) =>
            OrgProfilePage(orgId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: '/donate/:projectId',
        parentNavigatorKey: rootKey,
        builder: (context, state) => DonateAmountPage(
          projectId: state.pathParameters['projectId'] ?? '',
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(shell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/explore',
                builder: (context, state) => const ExplorePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/transparency',
                builder: (context, state) => const TransparencyPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/impact',
                builder: (context, state) => const ImpactPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
