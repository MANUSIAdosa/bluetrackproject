import 'package:blue_track/core/localization/app_localizations.dart';
import 'package:blue_track/core/theme/app_theme.dart';
import 'package:blue_track/features/explore/data/project_repository.dart';
import 'package:blue_track/features/explore/domain/project.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

/// Test-only harness mirroring the app's theme + localization setup.
///
/// Defaults to Indonesian (the app's primary language) so text assertions are
/// deterministic; pass `locale` to check the English copy.
Widget wrapPage(Widget child, {Locale locale = const Locale('id')}) {
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
    budget: const [
      BudgetLine(item: 'Pemantauan', amount: 1000, percent: 100),
    ],
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
  return MaterialApp.router(
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
}

/// In-memory [FilterRepository].
class FakeFilterRepository implements FilterRepository {
  FakeFilterRepository([this.categoryIds = const ['semua', 'penyu', 'karang']]);

  final List<String> categoryIds;

  @override
  Future<List<String>> getCategoryIds() async => categoryIds;
}