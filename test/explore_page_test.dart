import 'dart:io';

import 'package:blue_track/core/config/app_config.dart';
import 'package:blue_track/core/state/app_state.dart';
import 'package:blue_track/core/theme/app_colors.dart';
import 'package:blue_track/features/explore/domain/project.dart';
import 'package:blue_track/features/explore/presentation/explore_page.dart';
import 'package:blue_track/shared/widgets/empty_state.dart';
import 'package:blue_track/shared/widgets/error_state.dart';
import 'package:blue_track/shared/widgets/project_card.dart';
import 'package:blue_track/shared/widgets/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_harness.dart';

/// The loading skeleton animates forever, so `pumpAndSettle` would time out
/// instead of failing on an assertion. Pump a fixed number of frames instead.
Future<void> pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
}

Future<void> pumpExplore(
  WidgetTester tester, {
  required FakeProjectRepository projects,
  FakeFilterRepository? filters,
  bool phoneSurface = false,
  double textScale = 1,
}) async {
  // Full test width (800dp) on purpose: the category rail is a horizontal
  // ListView, so a phone-width surface would scroll "Tersimpan" out of view
  // and lazily dispose the other chips. These tests only assert state, not
  // card layout.
  if (phoneSurface) {
    // 390x844 at dpr 3 — card layout (and the horizontal rail) only
    // reproduces phone overflow on a phone-sized surface.
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(1170, 2532);
    addTearDown(tester.view.reset);
  }
  await tester.pumpWidget(
    wrapPage(
      _TextScale(
        scale: textScale,
        child: ExplorePage(
          projectRepository: projects,
          filterRepository: filters ?? FakeFilterRepository(),
        ),
      ),
    ),
  );
  await pumpFrames(tester);
}

/// Applies a text scale (an accessibility setting) to the whole page.
class _TextScale extends StatelessWidget {
  const _TextScale({required this.scale, required this.child});

  final double scale;
  final Widget child;

  @override
  Widget build(BuildContext context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child,
  );
}

/// More than two pages of 4, so paging is observable.
FakeProjectRepository manyProjects({int count = 9}) => FakeProjectRepository([
  for (var i = 1; i <= count; i++)
    buildProject(
      id: 'p${i.toString().padLeft(2, '0')}',
      title: 'Pemulihan Terumbu Karang Nomor $i',
    ),
]);

/// The project list itself — the category chip row is a horizontal ListView
/// too, so scope the finder to the refreshable list.
Finder projectList() => find.descendant(
  of: find.byType(RefreshIndicator),
  matching: find.byType(ListView),
);

/// Cards in the current page. A lazy ListView only mounts what is near the
/// viewport, so read the children the page handed to the list.
int cardCount(WidgetTester tester) {
  final delegate = tester.widget<ListView>(projectList()).childrenDelegate;
  return (delegate as SliverChildListDelegate).children
      .whereType<ProjectCard>()
      .length;
}

/// Scrolls down in small steps, like a finger, until the next page starts
/// loading (its placeholder appears). One huge drag overshoots the list's
/// estimated scroll extent and leaves the position in a ballistic correction,
/// which is not what a real gesture does.
Future<void> scrollToNextPage(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    if (find.byType(Skeleton).evaluate().isNotEmpty) return;
    await tester.drag(projectList(), const Offset(0, -220));
    await tester.pump();
  }
  fail('scrolling to the bottom never started loading the next page');
}

/// Let the pending page load (mock latency) finish.
Future<void> settlePageLoad(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

ScrollPosition listPosition(WidgetTester tester) => tester
    .state<ScrollableState>(
      find.descendant(of: projectList(), matching: find.byType(Scrollable)),
    )
    .position;

/// Back to the very top, ending without overscroll so this gesture does not
/// arm the refresh indicator itself.
Future<void> scrollToTop(WidgetTester tester) async {
  final position = listPosition(tester);
  final gesture = await tester.startGesture(tester.getCenter(projectList()));
  for (var i = 0; i < 40 && position.pixels > 0; i++) {
    // Never step past the top: an overscroll arms the refresh indicator.
    final step = position.pixels < 220 ? position.pixels : 220.0;
    await gesture.moveBy(Offset(0, step));
    await tester.pump();
  }
  await gesture.up();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// Pull to refresh from the top of the list.
///
/// The overscroll has to be dragged in steps with a pump in between: a single
/// big `drag` move never arms the RefreshIndicator. Fixed frames afterwards,
/// because the skeleton animates forever.
Future<void> pullToRefresh(WidgetTester tester) async {
  final gesture = await tester.startGesture(tester.getCenter(projectList()));
  for (final step in const [60.0, 120.0, 120.0, 120.0]) {
    await gesture.moveBy(Offset(0, step));
    await tester.pump();
  }
  await gesture.up();
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

ChoiceChip chipWithLabel(WidgetTester tester, String label) =>
    tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label));

Future<void> tapChip(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(ChoiceChip, label));
  await pumpFrames(tester);
}

/// Opens the real Hive box behind [SavedProjectsController] in a throwaway
/// directory, so every test starts from a known, empty saved-projects state.
Future<void> openSavedProjectsBox() async {
  _hiveDir = await Directory.systemTemp.createTemp('bluetrack_saved');
  Hive.init(_hiveDir.path);
  await Hive.openBox<dynamic>(AppConfig.savedProjectsBox);
  await SavedProjectsController.instance.load();
}

/// Writes the saved-projects state a test needs.
///
/// Hive touches real files, and the `testWidgets` body runs in a fake-async
/// zone where that I/O never completes — so this has to go through
/// [WidgetTester.runAsync].
Future<void> seedSavedProjects(WidgetTester tester, List<String> ids) async {
  await tester.runAsync(() async {
    final box = Hive.box<dynamic>(AppConfig.savedProjectsBox);
    await box.clear();
    await box.putAll({for (final id in ids) id: true});
    await SavedProjectsController.instance.load();
  });
}

/// The saved-projects toggle that sits next to the search field.
Finder savedFilterButton() => find.byKey(const ValueKey('explore.savedFilter'));

Future<void> tapSavedFilter(WidgetTester tester) async {
  expect(savedFilterButton(), findsOneWidget);
  await tester.tap(savedFilterButton());
  await pumpFrames(tester);
}

/// Two projects in different categories, so a category chip can separate them.
List<Project> twoCategories() => [
  buildProject(id: 'p01', title: 'Penyu Hijau', category: 'penyu'),
  buildProject(id: 'p02', title: 'Pemulihan Karang Razak', category: 'karang'),
];

/// Temp directory backing the Hive box opened in [openSavedProjectsBox].
late Directory _hiveDir;

void main() {
  setUp(() async {
    // No interest matches the fake projects, so the "Untuk minatmu" rail stays
    // out of the way and card counts are predictable.
    SharedPreferences.setMockInitialValues({
      AppConfig.interestsKey: ['mamalia_laut'],
    });
    await openSavedProjectsBox();
  });

  tearDown(() async {
    await Hive.close();
    if (_hiveDir.existsSync()) _hiveDir.deleteSync(recursive: true);
  });

  testWidgets('load failure shows ErrorState instead of endless skeletons', (
    tester,
  ) async {
    final projects = FakeProjectRepository([buildProject()])..shouldFail = true;
    await pumpExplore(tester, projects: projects);

    expect(find.byType(SkeletonCard), findsNothing);
    expect(find.byType(ErrorState), findsOneWidget);
  });

  testWidgets('"Coba lagi" reloads the list after a load failure', (
    tester,
  ) async {
    final projects = FakeProjectRepository([buildProject()])..shouldFail = true;
    await pumpExplore(tester, projects: projects);
    projects.shouldFail = false;

    await tester.tap(find.text('Coba lagi'));
    await pumpFrames(tester);

    expect(projects.callCount, 2);
    expect(find.byType(ErrorState), findsNothing);
    expect(find.byType(ProjectCard), findsAtLeastNWidgets(1));
  });

  testWidgets('a search with no hits offers "Atur ulang filter" which resets '
      'the query and the category', (tester) async {
    final projects = FakeProjectRepository([
      buildProject(),
      buildProject(
        id: 'p02',
        title: 'Pemulihan Karang Razak',
        category: 'karang',
      ),
    ]);
    await pumpExplore(tester, projects: projects);

    await tapChip(tester, 'Karang');
    await tester.enterText(find.byType(TextField), 'tidak-ada-hasil');
    await pumpFrames(tester);

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('Tidak ada proyek'), findsOneWidget);
    expect(find.text('Atur ulang filter'), findsOneWidget);

    await tester.tap(find.text('Atur ulang filter'));
    await pumpFrames(tester);

    expect(find.byType(ProjectCard), findsAtLeastNWidgets(1));
    expect(find.byType(EmptyState), findsNothing);
    final search = tester.widget<TextField>(find.byType(TextField));
    expect(search.controller?.text, isEmpty);
    expect(chipWithLabel(tester, 'Semua').selected, isTrue);
  });

  testWidgets('the list/map toggle lines up with the search field and the '
      'first category chip', (tester) async {
    await pumpExplore(
      tester,
      projects: FakeProjectRepository([buildProject()]),
    );

    final toggle = tester.getTopLeft(find.byType(SegmentedButton<bool>)).dx;
    final search = tester.getTopLeft(find.byType(TextField)).dx;
    final chip = tester.getTopLeft(find.byType(ChoiceChip).first).dx;

    expect(toggle, moreOrLessEquals(search));
    expect(toggle, moreOrLessEquals(chip));
    // Both of those sit on the base padding, so the toggle has to as well.
    expect(toggle, moreOrLessEquals(AppDimens.padding));
  });

  testWidgets('the category chips hold project categories only, never the '
      'saved collection', (tester) async {
    await pumpExplore(
      tester,
      projects: FakeProjectRepository([buildProject()]),
    );

    final labels = tester
        .widgetList<ChoiceChip>(find.byType(ChoiceChip))
        .map((chip) => (chip.label as Text).data)
        .toList();
    expect(labels, ['Semua', 'Penyu', 'Karang']);
  });

  testWidgets('the saved toggle invites saving a project from Project Detail '
      'when nothing is saved yet, and "Lihat semua proyek" leaves it', (
    tester,
  ) async {
    await pumpExplore(
      tester,
      projects: FakeProjectRepository([buildProject()]),
    );

    await tapSavedFilter(tester);

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.textContaining('Belum ada proyek tersimpan'), findsOneWidget);
    // The copy has to point at the place where saving actually happens.
    expect(find.textContaining('Detail Proyek'), findsOneWidget);
    expect(find.text('Coba lagi'), findsNothing);

    await tester.tap(find.text('Lihat semua proyek'));
    await pumpFrames(tester);

    expect(find.byType(EmptyState), findsNothing);
    expect(find.byType(ProjectCard), findsAtLeastNWidgets(1));
  });

  testWidgets('the saved toggle lists only saved projects and hides '
      '"Untuk minatmu"', (tester) async {
    SharedPreferences.setMockInitialValues({
      AppConfig.interestsKey: ['karang'],
    });
    await seedSavedProjects(tester, ['p02']);
    await pumpExplore(tester, projects: FakeProjectRepository(twoCategories()));

    // The rail is up before the toggle, so its absence afterwards is caused by
    // the saved filter and not by the interests being empty.
    expect(find.byKey(const ValueKey('explore.forYouRail')), findsOneWidget);

    await tapSavedFilter(tester);

    expect(find.byKey(const ValueKey('explore.forYouRail')), findsNothing);
    expect(cardCount(tester), 1);
    expect(
      find.widgetWithText(ProjectCard, 'Pemulihan Karang Razak'),
      findsOneWidget,
    );
  });

  testWidgets('a category chip narrows the saved projects', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await seedSavedProjects(tester, ['p01', 'p02']);
    await pumpExplore(tester, projects: FakeProjectRepository(twoCategories()));

    await tapSavedFilter(tester);
    expect(cardCount(tester), 2);

    await tapChip(tester, 'Karang');

    expect(cardCount(tester), 1);
    expect(
      find.widgetWithText(ProjectCard, 'Pemulihan Karang Razak'),
      findsOneWidget,
    );
  });

  testWidgets('the search narrows the saved projects', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await seedSavedProjects(tester, ['p01', 'p02']);
    await pumpExplore(tester, projects: FakeProjectRepository(twoCategories()));

    await tapSavedFilter(tester);

    await tester.enterText(find.byType(TextField), 'Penyu Hijau');
    await pumpFrames(tester);

    expect(cardCount(tester), 1);
    expect(find.widgetWithText(ProjectCard, 'Penyu Hijau'), findsOneWidget);
  });

  testWidgets('turning the saved toggle off goes back to the first page', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    // Every project is saved, so switching the toggle off only changes paging.
    await seedSavedProjects(tester, [
      for (var i = 1; i <= 9; i++) 'p${i.toString().padLeft(2, '0')}',
    ]);
    await pumpExplore(tester, projects: manyProjects());

    await tapSavedFilter(tester);
    await scrollToNextPage(tester);
    await settlePageLoad(tester);
    expect(cardCount(tester), 8);

    await tapSavedFilter(tester);

    expect(cardCount(tester), 4);
  });

  testWidgets('saved projects that match nothing offer "Atur ulang filter", '
      'which clears the saved toggle, the category and the query', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await seedSavedProjects(tester, ['p01']);
    await pumpExplore(tester, projects: FakeProjectRepository(twoCategories()));

    await tapSavedFilter(tester);
    await tapChip(tester, 'Karang');
    await tester.enterText(find.byType(TextField), 'Penyu');
    await pumpFrames(tester);

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('Atur ulang filter'), findsOneWidget);
    expect(find.text('Coba lagi'), findsNothing);

    await tester.tap(find.text('Atur ulang filter'));
    await pumpFrames(tester);

    expect(find.byType(EmptyState), findsNothing);
    // p02 was never saved, so it is in the list again only because the saved
    // toggle is off. Counted from the list's children: a second card sits
    // below the fold, so it is never mounted in this surface.
    expect(cardCount(tester), 2);
    expect(find.widgetWithText(ProjectCard, 'Penyu Hijau'), findsOneWidget);
    expect(chipWithLabel(tester, 'Semua').selected, isTrue);
    final search = tester.widget<TextField>(find.byType(TextField));
    expect(search.controller?.text, isEmpty);
  });

  testWidgets('the saved toggle keeps a 48dp touch target', (tester) async {
    await pumpExplore(
      tester,
      projects: FakeProjectRepository([buildProject()]),
    );

    final size = tester.getSize(savedFilterButton());
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('only the first page of projects is shown after loading', (
    tester,
  ) async {
    // No interests at all, so the "Untuk minatmu" rail adds nothing and the
    // card count is the list page.
    SharedPreferences.setMockInitialValues({});
    await pumpExplore(tester, projects: manyProjects());

    expect(cardCount(tester), 4);
  });

  testWidgets('scrolling near the bottom shows a small skeleton, then appends '
      'the next page', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpExplore(tester, projects: manyProjects());

    await scrollToNextPage(tester);
    expect(find.byType(Skeleton), findsOneWidget);

    await settlePageLoad(tester);
    expect(find.byType(Skeleton), findsNothing);
    expect(cardCount(tester), 8);
  });

  testWidgets('scrolling to the end reveals every project and leaves no '
      'skeleton behind', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpExplore(tester, projects: manyProjects());
    expect(cardCount(tester), 4);

    await scrollToNextPage(tester);
    await settlePageLoad(tester);
    expect(cardCount(tester), 8);

    await scrollToNextPage(tester);
    await settlePageLoad(tester);
    expect(cardCount(tester), 9);
    expect(find.byType(Skeleton), findsNothing);
  });

  testWidgets('pull to refresh goes back to the first page', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final projects = manyProjects();
    await pumpExplore(tester, projects: projects);
    await scrollToNextPage(tester);
    await settlePageLoad(tester);
    await scrollToTop(tester);

    await pullToRefresh(tester);

    expect(projects.callCount, 2);
    expect(cardCount(tester), 4);
  });

  testWidgets('changing the search and clearing it both go back to the first '
      'page', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpExplore(tester, projects: manyProjects());
    await scrollToNextPage(tester);
    await settlePageLoad(tester);
    expect(cardCount(tester), 8);

    // Every title contains "karang", so the query keeps all 9 matches.
    await tester.enterText(find.byType(TextField), 'karang');
    await pumpFrames(tester);
    expect(cardCount(tester), 4);

    await scrollToNextPage(tester);
    await settlePageLoad(tester);
    expect(cardCount(tester), 8);

    await tester.tap(find.byIcon(Icons.clear));
    await pumpFrames(tester);
    expect(cardCount(tester), 4);
  });

  testWidgets('changing the category chip goes back to the first page', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await pumpExplore(tester, projects: manyProjects());
    await scrollToNextPage(tester);
    await settlePageLoad(tester);
    expect(cardCount(tester), 8);

    await tapChip(tester, 'Penyu');

    // All 9 projects are "penyu", so the category keeps every match.
    expect(cardCount(tester), 4);
  });

  // The rail height must come from the cards, so both a default and a large
  // text scale have to fit. `flutter_test` already fails on a render overflow.
  for (final textScale in const [1.0, 1.3]) {
    testWidgets('the "Untuk minatmu" rail fits one-line and two-line titles at '
        'text scale $textScale', (tester) async {
      SharedPreferences.setMockInitialValues({
        AppConfig.interestsKey: ['penyu'],
      });
      final projects = FakeProjectRepository([
        buildProject(id: 'p01', title: 'Penyu Hijau'),
        buildProject(
          id: 'p02',
          title: 'Pemulihan Populasi Penyu Hijau dan Bertelur di Pantai Timur',
        ),
        buildProject(id: 'p03', title: 'Penyu Belimbing'),
        buildProject(id: 'p04', title: 'Monitoring Sarana Turtle Beach'),
      ]);
      await pumpExplore(
        tester,
        projects: projects,
        phoneSurface: true,
        textScale: textScale,
      );

      final rail = find.byKey(const ValueKey('explore.forYouRail'));
      expect(rail, findsOneWidget);

      final railCards = find.descendant(
        of: rail,
        matching: find.byType(ProjectCard),
      );
      expect(railCards, findsAtLeastNWidgets(2));
      var tallest = 0.0;
      for (var i = 0; i < railCards.evaluate().length; i++) {
        final height = tester.getSize(railCards.at(i)).height;
        if (height > tallest) tallest = height;
      }
      expect(tester.getSize(rail).height, greaterThanOrEqualTo(tallest));
    });
  }
}
