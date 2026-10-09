import 'dart:convert';
import 'dart:io';

import 'package:blue_track/core/localization/app_localizations.dart';
import 'package:blue_track/core/state/app_state.dart';
import 'package:blue_track/features/notification/data/notification_repository.dart';
import 'package:blue_track/features/notification/presentation/notifications_page.dart';
import 'package:blue_track/features/repositories.dart';
import 'package:blue_track/features/shell/app_shell.dart';
import 'package:blue_track/shared/widgets/notification_bell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/test_harness.dart';

/// In-memory [NotificationRepository] so badge behavior can be driven
/// deterministically without touching the mock asset.
class FakeNotificationRepository implements NotificationRepository {
  FakeNotificationRepository(this.count);

  int count;

  @override
  Future<int> getUnreadCount() async => count;
}

void main() {
  setUp(() async {
    await NotificationsController.instance.load(
      repository: FakeNotificationRepository(0),
    );
  });

  group('NotificationRepository', () {
    test('mock JSON exposes a non-negative unread count', () {
      final raw = File('assets/mock/notifications.json').readAsStringSync();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      expect(decoded['unreadCount'], isA<int>());
      expect(decoded['unreadCount'] as int, greaterThanOrEqualTo(0));
    });

    test('registry returns the mock implementation', () {
      expect(Repositories.notifications, isA<NotificationRepository>());
    });
  });

  group('NotificationsController', () {
    test('starts at zero so no badge shows before loading', () {
      expect(NotificationsController.instance.unreadCount, 0);
    });

    test('negative counts are clamped to zero', () async {
      await NotificationsController.instance.load(
        repository: FakeNotificationRepository(-3),
      );
      expect(NotificationsController.instance.unreadCount, 0);
    });
  });

  group('NotificationBell', () {
    testWidgets('shows no badge when the count is zero', (tester) async {
      await tester.pumpWidget(wrapPage(const NotificationBell()));
      await tester.pumpAndSettle();

      expect(find.byType(Badge), findsNothing);
      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
    });

    testWidgets('shows the count from the repository as a badge', (
      tester,
    ) async {
      await NotificationsController.instance.load(
        repository: FakeNotificationRepository(3),
      );
      await tester.pumpWidget(wrapPage(const NotificationBell()));
      await tester.pumpAndSettle();

      expect(find.byType(Badge), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('tooltip follows the active locale', (tester) async {
      await tester.pumpWidget(wrapPage(const NotificationBell()));
      await tester.pumpAndSettle();

      expect(
        find.byTooltip('Notifikasi'),
        findsOneWidget,
        reason: 'Indonesian is the default locale',
      );

      await tester.pumpWidget(
        wrapPage(const NotificationBell(), locale: const Locale('en')),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Notifications'), findsOneWidget);
    });
  });

  group('AppShell nav badge', () {
    // Built on a real StatefulShellRoute so the badge is exercised on the same
    // widget tree the app renders, not on a stand-in shell.
    GoRouter shellRouter() => GoRouter(
      initialLocation: '/impact',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              AppShell(shell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/explore', builder: (c, s) => const SizedBox()),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/impact', builder: (c, s) => const SizedBox()),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/profile', builder: (c, s) => const SizedBox()),
              ],
            ),
          ],
        ),
      ],
    );

    testWidgets('My Impact tab shows the same count as the bell', (
      tester,
    ) async {
      await NotificationsController.instance.load(
        repository: FakeNotificationRepository(2),
      );

      final router = shellRouter();
      addTearDown(router.dispose);
      await tester.pumpWidget(wrapRouter(router));
      await tester.pumpAndSettle();

      // One badge: the My Impact destination. The bell is not part of the
      // shell, so this count comes only from the nav destination.
      expect(find.byType(Badge), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('My Impact tab shows no badge when the count is zero', (
      tester,
    ) async {
      await NotificationsController.instance.load(
        repository: FakeNotificationRepository(0),
      );

      final router = shellRouter();
      addTearDown(router.dispose);
      await tester.pumpWidget(wrapRouter(router));
      await tester.pumpAndSettle();

      expect(find.byType(Badge), findsNothing);
    });

    test('only the My Impact tab opts into the badge', () {
      expect(ShellTabs.byLocation('/impact')?.showsUnreadBadge, isTrue);
      for (final tab in ShellTabs.active) {
        if (tab.location == '/impact') continue;
        expect(tab.showsUnreadBadge, isFalse, reason: tab.location);
      }
    });
  });

group('NotificationsPage', () {
    testWidgets('states what notifications are about, not just "coming soon"',
        (tester) async {
      await tester.pumpWidget(wrapPage(const NotificationsPage()));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
      expect(
        find.text('Kabar tentang donasimu akan muncul di sini.'),
        findsOneWidget,
      );
      // Kept as a secondary note, never as the only message.
      expect(
        find.text('Halaman ini akan tersedia pada subproyek berikutnya.'),
        findsOneWidget,
      );
    });

    testWidgets('has a back button when pushed on the root navigator',
        (tester) async {
      // Built through a router because the back button comes from AppBar's
      // `Navigator.canPop()`, which is false when the page is the root route —
      // exactly how `/notifications` is mounted in the app.
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(path: '/', builder: (context, state) => const SizedBox()),
          GoRoute(
            path: '/notifications',
            builder: (context, state) => const NotificationsPage(),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(wrapRouter(router));
      await tester.pumpAndSettle();

      router.push('/notifications');
      await tester.pumpAndSettle();

      expect(find.byType(BackButton), findsOneWidget);
    });

    testWidgets('copy follows the active locale', (tester) async {
      await tester.pumpWidget(
        wrapPage(const NotificationsPage(), locale: const Locale('en')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsOneWidget);
      expect(
        find.text('News about your donations will appear here.'),
        findsOneWidget,
      );
    });
  });

  test('unread count copy exists in every supported locale', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = AppLocalizations(locale);
      expect(l10n.text('notifications.donationNews'), isNotEmpty);
      expect(
        l10n.text('notifications.donationNews'),
        isNot('notifications.donationNews'),
      );
    }
  });
}