import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:blue_track/core/localization/app_localizations.dart';
import 'package:blue_track/core/router/routes.dart';
import 'package:blue_track/core/state/app_state.dart';
import 'package:blue_track/core/theme/app_colors.dart';
import 'package:blue_track/core/theme/app_theme.dart';
import 'package:blue_track/core/utils/formatters.dart';
import 'package:blue_track/features/notification/application/notification_providers.dart';
import 'package:blue_track/features/notification/data/notification_repository.dart';
import 'package:blue_track/features/notification/domain/app_notification.dart';
import 'package:blue_track/features/notification/presentation/notifications_page.dart';
import 'package:blue_track/features/repositories.dart';
import 'package:blue_track/features/shell/app_shell.dart';
import 'package:blue_track/shared/widgets/login_prompt_card.dart';
import 'package:blue_track/shared/widgets/notification_bell.dart';
import 'package:blue_track/shared/widgets/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/test_harness.dart';

const assetPath = 'assets/mock/notifications.json';

/// Builds a notification with sensible defaults so tests only state what
/// matters. Tiers are always relative to the real current time (matching how
/// the page groups), so the assertions never age out.
AppNotification buildNotification({
  String id = 'n1',
  NotificationType type = NotificationType.reportStatus,
  bool read = false,
  NotificationTimeTier tier = NotificationTimeTier.today,
  String route = Routes.myReports,
}) {
  final now = DateTime.now();
  final minutes = switch (tier) {
    // Same instant: always the same calendar day.
    NotificationTimeTier.today => 0,
    NotificationTimeTier.thisWeek => 2 * 24 * 60,
    NotificationTimeTier.older => 30 * 24 * 60,
  };
  return AppNotification(
    id: id,
    type: type,
    title: 'Judul $id',
    body: 'Isi singkat $id.',
    time: now.subtract(Duration(minutes: minutes)),
    read: read,
    route: route,
  );
}

/// Router hosting `/notifications` as the root, optionally with target routes
/// the mock data navigates to.
GoRouter pageRouter({List<GoRoute> extra = const []}) => GoRouter(
      initialLocation: '/start',
      routes: [
        GoRoute(
          path: '/start',
          builder: (context, state) => const NotificationsPage(),
        ),
        ...extra,
      ],
    );

/// Host identical to the app's root environment: ProviderScope (P13 repo
/// overridden with the harness fake seeded from [seed]) + MaterialApp.router.
Widget notifyHost({
  required GoRouter router,
  List<AppNotification>? seed,
  Locale locale = const Locale('id'),
}) {
  if (seed != null) fakeNotificationSeed = seed;
  return ProviderScope(
    overrides: [
      notificationRepositoryProvider
          .overrideWithValue(FakeNotificationRepository(fakeNotificationSeed)),
    ],
    child: MaterialApp.router(
      theme: buildAppTheme(),
      locale: locale,
      routerConfig: router,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

/// Pumps `/notifications` and settles. Returns nothing — resolve the
/// container via `ProviderScope.containerOf` when state is asserted.
Future<void> pumpNotifications(
  WidgetTester tester, {
  List<GoRoute> extra = const [],
  List<AppNotification>? seed,
  Locale locale = const Locale('id'),
  GoRouter? router,
}) async {
  final actualRouter = router ?? pageRouter(extra: extra);
  addTearDown(actualRouter.dispose);
  // The list view only builds visible children; a tall surface keeps all
  // seeded tiles in the viewport so finder assertions stay simple.
  await tallSurface(tester);
  await tester.pumpWidget(notifyHost(
    router: actualRouter,
    seed: seed,
    locale: locale,
  ));
  await tester.pumpAndSettle();
}

/// Enlarges the test surface for one test, restored automatically.
Future<void> tallSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(600, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

/// Slow/failing repository for loading and error state tests.
class GatedRepository implements NotificationRepository {
  GatedRepository([List<AppNotification>? items])
      : items = List.of(items ?? [buildNotification(id: 'only')]);

  List<AppNotification> items;

  /// Callers release the pending [getAll]; until then the load stays in
  /// flight (slow network stand-in).
  final Completer<void> gate = Completer<void>();

  bool shouldFail = false;

  @override
  Future<List<AppNotification>> getAll() async {
    if (shouldFail) throw Exception('repo failed');
    await gate.future;
    return [...items]..sort((a, b) => b.time.compareTo(a.time));
  }

  @override
  Future<void> markAsRead(String id) => () async {
        _replaceRead(id, true);
      }();

  @override
  Future<void> markAllAsRead() async {
    for (var i = 0; i < items.length; i++) {
      items[i] = _read(items[i], true);
    }
  }

  @override
  Future<void> delete(String id) async {
    items.removeWhere((item) => item.id == id);
  }

  @override
  Future<int> unreadCount() async =>
      items.where((item) => !item.read).length;

  void _replaceRead(String id, bool read) {
    final index = items.indexWhere((item) => item.id == id);
    if (index != -1) items[index] = _read(items[index], read);
  }

  AppNotification _read(AppNotification item, bool read) =>
      AppNotification(
        id: item.id,
        type: item.type,
        title: item.title,
        body: item.body,
        time: item.time,
        read: read,
        route: item.route,
      );
}

void main() {
  group('model', () {
    test('parses minutesAgo relative to the given now', () {
      final now = DateTime(2026, 10, 24, 10);
      final notification = AppNotification.fromJson(
        {
          'id': 'n9',
          'type': 'action_reminder',
          'title': 'T',
          'body': 'B',
          'minutesAgo': 90,
          'read': false,
          'route': '/my-actions',
        },
        now,
      );

      expect(notification.id, 'n9');
      expect(notification.type, NotificationType.actionReminder);
      expect(notification.time, now.subtract(const Duration(minutes: 90)));
      expect(notification.read, isFalse);
      expect(notification.route, '/my-actions');
    });

    test('accepts ISO time entries and serializes them back', () {
      final notification = AppNotification.fromJson(
        {
          'id': 'n8',
          'type': 'reportStatus',
          'title': 'T',
          'body': 'B',
          'time': '2026-10-01T08:00:00.000',
          'read': true,
          'route': '/report',
        },
        DateTime.now(),
      );

      final json = notification.toJson();
      expect(
        AppNotification.fromJson(json, DateTime.now()),
        notification,
      );
      expect(json['type'], 'reportStatus');
      expect(notification.read, isTrue);
    });

    test('unknown types fall back instead of crashing', () {
      final notification = AppNotification.fromJson(
        {
          'id': 'n7',
          'type': 'totally_new_kind',
          'title': 'T',
          'body': 'B',
          'minutesAgo': 1,
          'read': false,
          'route': '/report',
        },
        DateTime.now(),
      );
      expect(notification.type, NotificationType.reportStatus);
    });
  });

  group('mock asset contract', () {
    List<Map<String, dynamic>> rows() =>
        ((jsonDecode(File(assetPath).readAsStringSync())
                    as Map<String, dynamic>)['notifications']!
                as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .toList();

    test('has at least 8 notifications with unique ids', () {
      final data = rows();
      expect(data.length, greaterThanOrEqualTo(8));
      expect(data.map((r) => r['id']).toSet().length, data.length);
    });

    test('all three notification types are represented', () {
      final types = rows().map((r) => r['type']).toSet();
      expect(
        types,
        containsAll(['report_status', 'action_reminder', 'location_update']),
      );
    });

    test('read and unread are both represented', () {
      final reads = rows().map((r) => r['read']).toSet();
      expect(reads, containsAll([true, false]));
    });

    test('every row parses and has a registered route', () async {
      final items = await MockNotificationRepository.loadFromAsset();

      expect(items.length, greaterThanOrEqualTo(8));
      for (final item in items) {
        expect(item.title, isNotEmpty);
        expect(item.body, isNotEmpty);
        expect(
          Routes.isKnown(item.route),
          isTrue,
          reason: '${item.route} is not registered (${item.id})',
        );
      }
    });
  });

  group('repository contract', () {
    test('registry still binds the mock implementation', () {
      expect(Repositories.notifications, isA<MockNotificationRepository>());
    });

    test('getAll returns newest first; unreadCount matches data', () async {
      final repo = MockNotificationRepository.initial([
        buildNotification(id: 'old', tier: NotificationTimeTier.older),
        buildNotification(id: 'new', tier: NotificationTimeTier.today),
      ]);

      final items = await repo.getAll();
      expect(items.map((i) => i.id).toList(), ['new', 'old']);
      expect(await repo.unreadCount(), 2);
    });

    test('markAsRead clears exactly one notification', () async {
      final repo = MockNotificationRepository.initial([
        buildNotification(id: 'a'),
        buildNotification(id: 'b'),
      ]);

      await repo.markAsRead('a');
      final items = await repo.getAll();
      expect(items.firstWhere((i) => i.id == 'a').read, isTrue);
      expect(items.firstWhere((i) => i.id == 'b').read, isFalse);
      expect(await repo.unreadCount(), 1);
    });

    test('markAsRead twice keeps count stable at zero', () async {
      final repo = MockNotificationRepository.initial([
        buildNotification(id: 'a'),
      ]);
      await repo.markAsRead('a');
      await repo.markAsRead('a');
      expect(await repo.unreadCount(), 0);
    });

    test('markAllAsRead clears everything', () async {
      final repo = MockNotificationRepository.initial([
        buildNotification(id: 'a', read: true),
        buildNotification(id: 'b'),
        buildNotification(id: 'c'),
      ]);

      await repo.markAllAsRead();
      expect(await repo.unreadCount(), 0);
    });

    test('delete removes only the targeted item', () async {
      final repo = MockNotificationRepository.initial([
        buildNotification(id: 'a'),
        buildNotification(id: 'b'),
      ]);

      await repo.delete('a');
      final items = await repo.getAll();
      expect(items.map((i) => i.id), ['b']);
      expect(await repo.unreadCount(), 1);
    });
  });

  group('providers', () {
    final seed = [
      buildNotification(id: 'a', tier: NotificationTimeTier.today),
      buildNotification(
        id: 'b',
        type: NotificationType.actionReminder,
        read: true,
      ),
      buildNotification(id: 'c', type: NotificationType.locationUpdate),
    ];

    Future<ProviderContainer> container([NotificationRepository? repo]) async {
      final c = ProviderContainer(
        overrides: [
          notificationRepositoryProvider
              .overrideWithValue(repo ?? FakeNotificationRepository(seed)),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('list loads newest first; count derives from it', () async {
      final c = await container();
      final list = await c.read(notificationListProvider.future);
      expect(list.map((i) => i.id).toSet(), {'a', 'b', 'c'});
      expect(c.read(unreadCountProvider), 2);
    });

    test('markAsRead updates list AND count through one state', () async {
      final c = await container();
      await c.read(notificationListProvider.notifier).markAsRead('a');

      final list = await c.read(notificationListProvider.future);
      expect(list.firstWhere((i) => i.id == 'a').read, isTrue);
      expect(c.read(unreadCountProvider), 1);
    });

    test('markAllAsRead zeroes the badge count', () async {
      final c = await container();
      await c.read(notificationListProvider.notifier).markAllAsRead();
      expect(c.read(unreadCountProvider), 0);
    });

    test('delete removes the item and re-derives the count', () async {
      final c = await container();
      await c.read(notificationListProvider.notifier).delete('c');

      final list = await c.read(notificationListProvider.future);
      expect(list.map((i) => i.id), isNot(contains('c')));
      expect(c.read(unreadCountProvider), 1);
    });

    test('count stays 0 while the list has not settled', () async {
      final gated = GatedRepository();
      final c = await container(gated);

      final snapshot = c.read(notificationListProvider);
      expect(snapshot.isLoading, isTrue);
      expect(c.read(unreadCountProvider), 0);

      gated.gate.complete();
      await c.read(notificationListProvider.future);
      expect(c.read(unreadCountProvider), 1);
    });

    test('repository failure surfaces as error, not a crash', () async {
      final c = await container(GatedRepository()..shouldFail = true);
      // Reading once starts the build (loading); flushing the microtasks lets
      // the rejected future settle into the error state.
      c.read(notificationListProvider);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(c.read(notificationListProvider).hasError, isTrue);
      expect(c.read(unreadCountProvider), 0);
    });
  });

  group('NotificationsPage', () {
    List<AppNotification> pageSeed() => [
          buildNotification(id: 'n101', tier: NotificationTimeTier.today),
          buildNotification(
            id: 'n102',
            type: NotificationType.locationUpdate,
          ),
          buildNotification(
            id: 'n103',
            type: NotificationType.actionReminder,
            tier: NotificationTimeTier.thisWeek,
            read: true,
          ),
          buildNotification(
            id: 'n104',
            tier: NotificationTimeTier.thisWeek,
            read: true,
          ),
          buildNotification(
            id: 'n108',
            tier: NotificationTimeTier.older,
            read: true,
          ),
        ];

    int unreadDotCount(WidgetTester tester) => tester
        .widgetList<Container>(find.byType(Container))
        .where((container) {
          final decoration = container.decoration;
          return decoration is BoxDecoration &&
              decoration.shape == BoxShape.circle &&
              decoration.color == AppColors.ocean;
        })
        .length;

    testWidgets('groups show all three recency headers', (tester) async {
      await pumpNotifications(tester, seed: pageSeed());

      expect(find.text('Hari ini'), findsOneWidget);
      expect(find.text('Minggu ini'), findsOneWidget);
      expect(find.text('Lebih lama'), findsOneWidget);
    });

    testWidgets('items show title, body, time and blue dots for unread', (
      tester,
    ) async {
      await pumpNotifications(tester, seed: pageSeed());

      expect(find.text('Judul n101'), findsOneWidget);
      expect(find.text('Isi singkat n101.'), findsOneWidget);
      // Unread count: n101, n102 → three blue dots (n108 was seeded read).
      expect(unreadDotCount(tester), 2);
      // The time label renders inside the tile (locale-styled; just presence).
      expect(find.byType(Text), findsWidgets);
      final timeTexts = find.textContaining(RegExp(r'\d{1,2}'));
      expect(timeTexts, findsWidgets);
    });

    testWidgets('tap marks read first, then navigates to the target', (
      tester,
    ) async {
      await pumpNotifications(
        tester,
        seed: pageSeed(),
        extra: [
          GoRoute(
            path: Routes.myReports,
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('Laporanku'))),
          ),
        ],
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(NotificationsPage)),
      );
      await tester.tap(find.byType(ListTile).first);
      await tester.pumpAndSettle();

      // n101 sits first in the list and points at the registered
      // /my-reports route — the target page is on screen.
      expect(find.text('Laporanku'), findsOneWidget);
      final list = await container.read(notificationListProvider.future);
      expect(list.firstWhere((i) => i.id == 'n101').read, isTrue);
    });

    testWidgets('unregistered target falls back to a safe message', (
      tester,
    ) async {
      fakeNotificationSeed = [
        buildNotification(
          id: 'bad',
          route: '/this-route/is-not-registered',
        ),
      ];
      await pumpNotifications(tester, seed: fakeNotificationSeed);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(NotificationsPage)),
      );
      await tester.tap(find.byType(ListTile).first);
      await tester.pumpAndSettle();

      // Fallback message instead of the router's raw error screen.
      expect(
        find.text('Halaman tujuan notifikasi ini belum tersedia.'),
        findsOneWidget,
      );
      expect(find.byType(NotificationsPage), findsOneWidget);
      final list = await container.read(notificationListProvider.future);
      expect(list.firstWhere((i) => i.id == 'bad').read, isTrue);

      // Let the snackbar's dismissal timer fire so no timer leaks at the end
      // of the test.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('swipe deletes the item and updates the page', (
      tester,
    ) async {
      await pumpNotifications(tester, seed: pageSeed());
      final container = ProviderScope.containerOf(
        tester.element(find.byType(NotificationsPage)),
      );
      expect(find.byType(Dismissible), findsNWidgets(5));

      await tester.drag(find.byType(Dismissible).first, const Offset(-450, 0));
      await tester.pumpAndSettle();

      expect(find.byType(Dismissible), findsNWidgets(4));
      final list = await container.read(notificationListProvider.future);
      expect(list.map((i) => i.id), isNot(contains('n101')));
    });

    testWidgets('Tandai semua dibaca clears dots and disables itself', (
      tester,
    ) async {
      await pumpNotifications(tester, seed: pageSeed());
      final container = ProviderScope.containerOf(
        tester.element(find.byType(NotificationsPage)),
      );
      expect(container.read(unreadCountProvider), 2);
      expect(unreadDotCount(tester), 2);

      await tester.tap(find.text('Tandai semua dibaca'));
      await tester.pumpAndSettle();

      expect(container.read(unreadCountProvider), 0);
      expect(unreadDotCount(tester), 0);
      final button = tester.widget<TextButton>(
        find.ancestor(
          of: find.text('Tandai semua dibaca'),
          matching: find.byType(TextButton),
        ),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('loading state renders skeletons', (tester) async {
      await tallSurface(tester);
      final gated = GatedRepository(pageSeed());
      final router = pageRouter();
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationRepositoryProvider.overrideWithValue(gated),
          ],
          child: MaterialApp.router(
            theme: buildAppTheme(),
            locale: const Locale('id'),
            routerConfig: router,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      // One raw pump — no settle: the load is intentionally still in flight.
      await tester.pump();

      expect(find.byType(Skeleton), findsWidgets);

      gated.gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(Skeleton), findsNothing);
      expect(find.text('Hari ini'), findsOneWidget);
    });

    testWidgets('error state offers Coba lagi that retries the real load', (
      tester,
    ) async {
      await tallSurface(tester);
      final failing = GatedRepository(pageSeed())..shouldFail = true;
      final router = pageRouter();
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationRepositoryProvider.overrideWithValue(failing),
          ],
          child: MaterialApp.router(
            theme: buildAppTheme(),
            locale: const Locale('id'),
            routerConfig: router,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Notifikasi gagal dimuat.'), findsOneWidget);
      expect(find.text('Coba lagi'), findsOneWidget);

      // Source recovers, then the retry must actually re-read it.
      failing.shouldFail = false;
      failing.gate.complete();
      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();

      expect(find.text('Notifikasi gagal dimuat.'), findsNothing);
      expect(find.text('Hari ini'), findsOneWidget);
    });

    testWidgets('empty state after deleting everything', (tester) async {
      await pumpNotifications(tester, seed: pageSeed());

      for (var i = 0; i < 5; i++) {
        await tester.drag(find.byType(Dismissible).first, const Offset(-450, 0));
        await tester.pumpAndSettle();
      }

      expect(find.text('Belum ada notifikasi.'), findsOneWidget);
    });

    testWidgets('signed-out users see the prompt card but the list too', (
      tester,
    ) async {
      await pumpNotifications(tester, seed: pageSeed());

      expect(find.byType(LoginPromptCard), findsOneWidget);
      // Login never blocks the mock notifications (P13 requirement).
      expect(find.text('Judul n101'), findsOneWidget);
      expect(find.byType(ListTile), findsNWidgets(5));
    });

    testWidgets('signed-in users skip the prompt card', (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      await AuthController.instance.signIn('tester@example.com');
      addTearDown(AuthController.instance.signOut);

      await pumpNotifications(tester, seed: pageSeed());

      expect(find.byType(LoginPromptCard), findsNothing);
      expect(find.text('Judul n101'), findsOneWidget);
    });

    testWidgets('copy follows the active locale (en)', (tester) async {
      await pumpNotifications(
        tester,
        seed: const [],
        locale: const Locale('en'),
      );

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Mark all as read'), findsOneWidget);
      expect(find.text('No notifications yet.'), findsOneWidget);
    });
  });

  group('shell badge integration', () {
    GoRouter shellRouter() => GoRouter(
          initialLocation: '/explore',
          routes: [
            StatefulShellRoute.indexedStack(
              builder: (context, state, navigationShell) =>
                  AppShell(shell: navigationShell),
              branches: [
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: '/explore',
                      builder: (c, s) => const SizedBox(),
                    ),
                  ],
                ),
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: '/actions',
                      builder: (c, s) => const SizedBox(),
                    ),
                  ],
                ),
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: '/impact',
                      builder: (c, s) => const SizedBox(),
                    ),
                  ],
                ),
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: '/profile',
                      builder: (c, s) => const SizedBox(),
                    ),
                  ],
                ),
              ],
            ),
          ],
        );

    testWidgets('tab badge shows the live unread count', (tester) async {
      final router = shellRouter();
      addTearDown(router.dispose);
      await tester.pumpWidget(
        notifyHost(router: router, seed: [
          buildNotification(id: 'a'),
          buildNotification(id: 'b'),
          buildNotification(id: 'c', read: true),
        ]),
      );
      await tester.pumpAndSettle();

      final navBadge = find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byType(Badge),
      );
      expect(navBadge, findsOneWidget);
      expect(find.descendant(of: navBadge, matching: find.text('2')),
          findsOneWidget);
    });

    testWidgets('marking all read hides the badge without reloading', (
      tester,
    ) async {
      final router = shellRouter();
      addTearDown(router.dispose);
      await tester.pumpWidget(
        notifyHost(router: router, seed: [
          buildNotification(id: 'a'),
          buildNotification(id: 'b'),
        ]),
      );
      await tester.pumpAndSettle();

      // The page posts the same mutation through the same provider — the
      // badge must react without any manual reload.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AppShell)),
      );
      await container.read(notificationListProvider.notifier).markAllAsRead();
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.byType(Badge),
        ),
        findsNothing,
      );
    });

    testWidgets('no badge when the list is empty', (tester) async {
      final router = shellRouter();
      addTearDown(router.dispose);
      await tester.pumpWidget(
        notifyHost(router: router, seed: const []),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.byType(Badge),
        ),
        findsNothing,
      );
    });

    testWidgets('NotificationBell shows the same count as the shell', (
      tester,
    ) async {
      fakeNotificationSeed = [
        buildNotification(id: 'a'),
        buildNotification(id: 'b'),
      ];
      await tester.pumpWidget(wrapPage(const NotificationBell()));
      await tester.pumpAndSettle();

      expect(find.text('2'), findsOneWidget);
    });
  });
}
