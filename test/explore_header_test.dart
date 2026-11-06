import 'package:blue_track/core/theme/app_colors.dart';
import 'package:blue_track/features/explore/domain/explore_map_data.dart';
import 'package:blue_track/features/explore/presentation/widgets/explore_header.dart';
import 'package:blue_track/features/explore/presentation/widgets/filter_sheet.dart';
import 'package:blue_track/shared/widgets/notification_bell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_harness.dart';

void main() {
  group('ExploreHeader', () {
    testWidgets('carries the title, search, bell, filter and saved action', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        wrapPage(
          ExploreHeader(
            searchController: controller,
            query: '',
            onQueryChanged: (_) {},
            onClearQuery: () {},
            filterActiveCount: 0,
            onFilterPressed: () {},
            saved: false,
            savedCount: 2,
            onSavedChanged: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('explore.header')), findsOneWidget);
      expect(find.text('Jelajahi'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(NotificationBell), findsOneWidget);
      expect(find.byKey(const ValueKey('explore.filterButton')), findsOneWidget);
      expect(find.byKey(const ValueKey('explore.scope.saved')), findsOneWidget);
      // The view switch belongs to the results line, not the title row.
      expect(find.byKey(const ValueKey('explore.view.map')), findsNothing);
    });

    testWidgets('wires the saved action in the title row', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      bool? picked;

      await tester.pumpWidget(
        wrapPage(
          ExploreHeader(
            searchController: controller,
            query: '',
            onQueryChanged: (_) {},
            onClearQuery: () {},
            filterActiveCount: 0,
            onFilterPressed: () {},
            saved: false,
            savedCount: 2,
            onSavedChanged: (value) => picked = value,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('explore.scope.saved')));
      expect(picked, isTrue);
    });

    testWidgets('reports search changes and clears the query', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      var changed = '';
      var cleared = 0;

      await tester.pumpWidget(
        wrapPage(
          ExploreHeader(
            searchController: controller,
            query: '',
            onQueryChanged: (value) => changed = value,
            onClearQuery: () => cleared++,
            filterActiveCount: 0,
            onFilterPressed: () {},
            saved: false,
            savedCount: 0,
            onSavedChanged: (_) {},
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'penyu');
      expect(changed, 'penyu');

      // The clear action only exists once there is a query.
      expect(find.byIcon(Icons.clear), findsNothing);
      await tester.pumpWidget(
        wrapPage(
          ExploreHeader(
            searchController: controller,
            query: 'penyu',
            onQueryChanged: (_) {},
            onClearQuery: () => cleared++,
            filterActiveCount: 0,
            onFilterPressed: () {},
            saved: false,
            savedCount: 0,
            onSavedChanged: (_) {},
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byIcon(Icons.clear));
      expect(cleared, 1);
    });

    testWidgets('badges the filter button with the active group count', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        wrapPage(
          ExploreHeader(
            searchController: controller,
            query: '',
            onQueryChanged: (_) {},
            onClearQuery: () {},
            filterActiveCount: 2,
            onFilterPressed: () {},
            saved: false,
            savedCount: 0,
            onSavedChanged: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('explore.filterCount')), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });
  });

  group('SavedScopeButton', () {
    testWidgets('shows the saved count and toggles the scope', (tester) async {
      bool? picked;

      await tester.pumpWidget(
        wrapPage(
          SavedScopeButton(
            saved: false,
            savedCount: 3,
            onChanged: (value) => picked = value,
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('explore.scope.saved')), findsOneWidget);
      // The page is already Explore, so a second tab for it was redundant.
      expect(find.byKey(const ValueKey('explore.scope.explore')), findsNothing);
      // The saved count is information about the collection, not a filter.
      expect(find.text('3'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('explore.scope.saved')));
      expect(picked, isTrue);

      // Same button, now active: pressing it again leaves the saved scope.
      picked = null;
      await tester.pumpWidget(
        wrapPage(
          SavedScopeButton(
            saved: true,
            savedCount: 3,
            onChanged: (value) => picked = value,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('explore.scope.saved')));
      expect(picked, isFalse);
    });

    testWidgets('keeps a comfortable touch target', (tester) async {
      await tester.pumpWidget(
        wrapPage(
          SavedScopeButton(saved: false, savedCount: 0, onChanged: (_) {}),
        ),
      );
      await tester.pump();

      final size = tester.getSize(
        find.byKey(const ValueKey('explore.scope.saved')),
      );
      expect(size.height, greaterThanOrEqualTo(44));
      expect(size.width, greaterThanOrEqualTo(44));
    });

    testWidgets('rests on the gradient and fills only when active', (
      tester,
    ) async {
      Future<Color?> backgroundOf(bool saved) async {
        await tester.pumpWidget(
          wrapPage(
            SavedScopeButton(
              saved: saved,
              savedCount: 2,
              onChanged: (_) {},
            ),
          ),
        );
        await tester.pump();

        return tester
            .widget<Material>(
              find
                  .descendant(
                    of: find.byType(SavedScopeButton),
                    matching: find.byType(Material),
                  )
                  .first,
            )
            .color;
      }

      // At rest there is no surface of its own, so the header gradient shows
      // through without a lighter square around the bookmark.
      expect(await backgroundOf(false), Colors.transparent);
      expect(await backgroundOf(true), AppColors.surface);
    });
  });

  group('ExploreViewSwitch', () {
    testWidgets('shows both views with the current one selected', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapPage(ExploreViewSwitch(mapMode: false, onChanged: (_) {})),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('explore.view.list')), findsOneWidget);
      expect(find.byKey(const ValueKey('explore.view.map')), findsOneWidget);
      expect(
        tester
            .widget<ExploreViewSwitch>(find.byType(ExploreViewSwitch))
            .mapMode,
        isFalse,
      );

      await tester.pumpWidget(
        wrapPage(ExploreViewSwitch(mapMode: true, onChanged: (_) {})),
      );
      await tester.pump();

      expect(
        tester
            .widget<ExploreViewSwitch>(find.byType(ExploreViewSwitch))
            .mapMode,
        isTrue,
      );
    });

    testWidgets('reports the view the user picked', (tester) async {
      bool? picked;

      await tester.pumpWidget(
        wrapPage(
          ExploreViewSwitch(mapMode: false, onChanged: (value) => picked = value),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('explore.view.map')));
      expect(picked, isTrue);

      picked = null;
      await tester.pumpWidget(
        wrapPage(
          ExploreViewSwitch(mapMode: true, onChanged: (value) => picked = value),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('explore.view.list')));
      expect(picked, isFalse);
    });

    testWidgets('keeps the segmented control at a comfortable touch target', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapPage(ExploreViewSwitch(mapMode: false, onChanged: (_) {})),
      );
      await tester.pump();

      expect(
        tester.getSize(find.byType(SegmentedButton<bool>)).height,
        greaterThanOrEqualTo(48),
      );
      expect(find.byKey(const ValueKey('explore.view.list')), findsOneWidget);
      expect(find.byKey(const ValueKey('explore.view.map')), findsOneWidget);
    });
  });

  group('ActiveFilterBar', () {
    testWidgets('stays out of the way when no filter is active', (tester) async {
      await tester.pumpWidget(
        wrapPage(
          ActiveFilterBar(
            selection: ExploreFilterSelection.none,
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('explore.activeFilters')), findsNothing);
    });

    testWidgets('labels every active token with its filter dimension', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapPage(
          ActiveFilterBar(
            selection: const ExploreFilterSelection(
              category: 'penyu',
              distance: DistanceBand.dekat,
              condition: ProjectCondition.kritis,
            ),
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('explore.activeFilters')), findsOneWidget);
      // The category is visible as the selected rail chip, so the bar never
      // repeats it as a token.
      expect(
        find.byKey(const ValueKey('explore.activeFilter.category')),
        findsNothing,
      );
      expect(find.text('Jarak: <250 km'), findsOneWidget);
      expect(find.text('Kondisi: Kritis'), findsOneWidget);
      expect(find.text('Hapus semua'), findsOneWidget);
    });

    testWidgets('removing one token keeps the category and the other filter', (
      tester,
    ) async {
      ExploreFilterSelection? changed;

      await tester.pumpWidget(
        wrapPage(
          ActiveFilterBar(
            selection: const ExploreFilterSelection(
              category: 'penyu',
              distance: DistanceBand.dekat,
              condition: ProjectCondition.kritis,
            ),
            onChanged: (value) => changed = value,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const ValueKey('explore.activeFilter.distance')),
      );

      expect(changed, isNotNull);
      expect(changed!.category, 'penyu');
      expect(changed!.distance, DistanceBand.semua);
      expect(changed!.condition, ProjectCondition.kritis);
    });

    testWidgets('"Hapus semua" clears the sheet filters but keeps the rail '
        'category', (tester) async {
      ExploreFilterSelection? changed;

      await tester.pumpWidget(
        wrapPage(
          ActiveFilterBar(
            selection: const ExploreFilterSelection(
              category: 'penyu',
              distance: DistanceBand.jauh,
              condition: ProjectCondition.baik,
            ),
            onChanged: (value) => changed = value,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('explore.clearFilters')));

      expect(changed!.category, 'penyu');
      expect(changed!.distance, DistanceBand.semua);
      expect(changed!.condition, isNull);
    });
  });

  group('ExploreResultsBar', () {
    testWidgets('states the count and offers both views on one line', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapPage(
          ExploreResultsBar(
            count: 4,
            mapMode: false,
            onViewChanged: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('4 proyek'), findsOneWidget);
      expect(find.byKey(const ValueKey('explore.view.list')), findsOneWidget);
      expect(find.byKey(const ValueKey('explore.view.map')), findsOneWidget);

      final count = tester.getRect(
        find.byKey(const ValueKey('explore.resultsCount')),
      );
      final view = tester.getRect(find.byType(ExploreViewSwitch));
      final screen = tester.getSize(find.byType(Scaffold));

      expect(count.left, 16);
      expect(view.right, moreOrLessEquals(screen.width - 16, epsilon: 0.5));
      expect(count.center.dy, moreOrLessEquals(view.center.dy, epsilon: 0.5));
    });

    testWidgets('shows the category chip only in map mode', (tester) async {
      await tester.pumpWidget(
        wrapPage(
          ExploreResultsBar(
            count: 4,
            mapMode: false,
            onViewChanged: (_) {},
            categoryId: 'penyu',
            onCategoryPressed: () {},
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('explore.mapCategoryChip')),
        findsNothing,
      );

      await tester.pumpWidget(
        wrapPage(
          ExploreResultsBar(
            count: 4,
            mapMode: true,
            onViewChanged: (_) {},
            categoryId: 'penyu',
            onCategoryPressed: () {},
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('explore.mapCategoryChip')),
        findsOneWidget,
      );
    });

    testWidgets('keeps the map category readable on a phone', (tester) async {
      // A large phone width still leaves the chip and the view switch sharing
      // one line. The test font is wider than Plus Jakarta Sans, so this is a
      // stricter surface than the real 390dp device.
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(430, 932);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        wrapPage(
          ExploreResultsBar(
            count: 3,
            mapMode: true,
            onViewChanged: (_) {},
            categoryId: 'penyu',
            onCategoryPressed: () {},
          ),
        ),
      );
      await tester.pump();

      // The chip used to split the free space with the spacer, which cut the
      // label down to "Kateg…" at phone width.
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.text('Penyu')).width,
        greaterThanOrEqualTo(55),
      );
      final chip = tester.getRect(
        find.byKey(const ValueKey('explore.mapCategoryChip')),
      );
      final view = tester.getRect(find.byType(ExploreViewSwitch));
      expect(chip.right, lessThanOrEqualTo(view.left));
    });
  });
}
