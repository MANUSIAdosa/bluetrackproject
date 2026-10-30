import 'package:blue_track/core/localization/app_localizations.dart';
import 'package:blue_track/core/theme/app_theme.dart';
import 'package:blue_track/features/explore/data/project_repository.dart';
import 'package:blue_track/features/explore/domain/project.dart';
import 'package:blue_track/features/notification/application/notification_providers.dart';
import 'package:blue_track/features/notification/data/notification_repository.dart';
import 'package:blue_track/features/notification/domain/app_notification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Test-only harness mirroring the app's theme + localization setup.
///
/// Defaults to Indonesian (the app's primary language) so text assertions are
/// deterministic; pass `locale` to check the English copy.
///
/// Every page is hosted inside a [ProviderScope] like the real app. The
/// P13 repository provider is overridden with [FakeNotificationRepository]
/// seeded from [fakeNotificationSeed], so no widget test touches the mock
/// asset (real asset IO from within a fake-async frame cannot be pumped
/// deterministically — see the P01 ocean-facts seam notes).
Widget wrapPage(Widget child, {Locale locale = const Locale('id')}) {
  return ProviderScope(
    overrides: [
      notificationRepositoryProvider
          .overrideWithValue(FakeNotificationRepository(fakeNotificationSeed)),
    ],
    child: _wrapPageBody(child, locale: locale),
  );
}

Widget _wrapPageBody(Widget child, {required Locale locale}) {
  return MaterialApp(
    theme: buildAppTheme(),
    locale: locale,
    debugShowCheckedModeBanner: false,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

/// Builds a [Project] with sensible defaults so tests only state what matters.
Project buildProject({
  String id = 'p01',
  String title = 'Peneluruhan Penyu di Pantai Sukamade',
  String category = 'penyu',
  String orgName = 'Lembaga Konservasi',
  bool orgVerified = true,
  String location = 'Pantai Sukamade, Aceh',
  int raisedAmount = 18750000,
  int targetAmount = 25000000,
}) {
  return Project(
    id: id,
    title: title,
    category: category,
    orgId: 'o01',
    orgName: orgName,
    orgVerified: orgVerified,
    location: location,
    latitude: -4.0,
    longitude: 105.0,
    raisedAmount: raisedAmount,
    targetAmount: targetAmount,
    description: 'Deskripsi proyek konservasi.',
    about: const ['Butuh dukungan'],
    budget: const [BudgetLine(item: 'Pemantauan', amount: 1000, percent: 100)],
    galleryColors: const ['#0EA5E9', '#14B8A6'],
  );
}

/// Constrains a widget to a phone-like column width so wide test surfaces
/// don't distort card layouts (a 16:9 gallery grows with the width).
Widget phoneSized(Widget child, {double width = 360}) => Align(
  alignment: Alignment.topLeft,
  child: SizedBox(width: width, child: child),
);

/// Same environment, but hosted by a real router so navigation can be asserted.
Widget wrapRouter(GoRouter router, {Locale locale = const Locale('id')}) {
  return ProviderScope(
    overrides: [
      notificationRepositoryProvider
          .overrideWithValue(FakeNotificationRepository(fakeNotificationSeed)),
    ],
    child: MaterialApp.router(
      theme: buildAppTheme(),
      locale: locale,
      debugShowCheckedModeBanner: false,
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

/// Seed consumed by [FakeNotificationRepository] inside the harness scopes.
/// Tests mutate it (usually in setUp) BEFORE pumping. Mutable test-only
/// state — reset in the tests that care.
List<AppNotification> fakeNotificationSeed = [];

/// In-memory [NotificationRepository]: same async surface as the mock, no
/// asset IO. Fundamentally stateful so mark/delete flows are testable.
class FakeNotificationRepository implements NotificationRepository {
  FakeNotificationRepository([List<AppNotification>? initial])
      : _items = List.of(initial ?? const []);

  final List<AppNotification> _items;

  /// When true every repository call throws instead of returning data.
  bool shouldFail = false;

  @override
  Future<List<AppNotification>> getAll() async {
    _failIfNeeded();
    return [..._items]..sort((a, b) => b.time.compareTo(a.time));
  }

  @override
  Future<void> markAsRead(String id) async {
    _failIfNeeded();
    _replace(_items.firstWhere((item) => item.id == id)._withRead(true));
  }

  @override
  Future<void> markAllAsRead() async {
    _failIfNeeded();
    for (var i = 0; i < _items.length; i++) {
      _items[i] = _items[i]._withRead(true);
    }
  }

  @override
  Future<void> delete(String id) async {
    _failIfNeeded();
    _items.removeWhere((item) => item.id == id);
  }

  @override
  Future<int> unreadCount() async {
    _failIfNeeded();
    return _items.where((item) => !item.read).length;
  }

  void _replace(AppNotification updated) {
    final index = _items.indexWhere((item) => item.id == updated.id);
    if (index != -1) _items[index] = updated;
  }

  void _failIfNeeded() {
    if (!shouldFail) return;
    throw Exception('notification repository failed');
  }
}

/// Test-local extension: both the file and this harness need a copy-variant
/// helper, so it lives on the type via a private name trick.
extension on AppNotification {
  AppNotification _withRead(bool read) => AppNotification(
        id: id,
        type: type,
        title: title,
        body: body,
        time: time,
        read: read,
        route: route,
      );
}

/// In-memory [ProjectRepository] so pages can be driven deterministically.
class FakeProjectRepository implements ProjectRepository {
  FakeProjectRepository(this.projects);

  List<Project> projects;

  /// When true the next calls throw instead of returning data.
  bool shouldFail = false;

  int callCount = 0;

  @override
  Future<List<Project>> getProjects({String? category}) async {
    callCount++;
    if (shouldFail) throw Exception('boom');
    if (category == null || category == 'semua') return List.of(projects);
    return projects.where((p) => p.category == category).toList();
  }

  @override
  Future<Project?> getProjectById(String id) async {
    for (final project in projects) {
      if (project.id == id) return project;
    }
    return null;
  }

  @override
  Future<List<Project>> getProjectsByOrgId(String orgId) async {
    return projects.where((p) => p.orgId == orgId).toList();
  }
}

/// In-memory [FilterRepository].
class FakeFilterRepository implements FilterRepository {
  FakeFilterRepository([this.categoryIds = const ['semua', 'penyu', 'karang']]);

  final List<String> categoryIds;

  @override
  Future<List<String>> getCategoryIds() async => categoryIds;
}
