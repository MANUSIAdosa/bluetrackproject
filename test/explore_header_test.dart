import 'package:blue_track/features/explore/domain/explore_map_data.dart';
import 'package:blue_track/features/explore/presentation/widgets/explore_header.dart';
import 'package:blue_track/features/explore/presentation/widgets/filter_sheet.dart';
import 'package:blue_track/shared/widgets/notification_bell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_harness.dart';

void main() {
  group('ExploreHeader', () {
    testWidgets('carries the title, search, bell and filter', (tester) async {
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
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('explore.header')), findsOneWidget);
      expect(find.text('Jelajahi'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(NotificationBell), findsOneWidget);
      expect(find.byKey(const ValueKey('explore.filterButton')), findsOneWidget);
      // The view action belongs to the controls row below the header, not to
      // the title row where it competed with the notification bell.
      expect(find.byKey(const ValueKey('explore.view.map')), findsNothing);
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
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('explore.filterCount')), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });
  });

  group('ExploreScopeSwitch', () {
    testWidgets('offers the saved collection as a single toggle', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapPage(
          ExploreScopeSwitch(
            saved: false,
            savedCount: 3,
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('explore.scope.saved')), findsOneWidget);
      // The page is already Explore, so a second tab for it was redundant.
      expect(find.byKey(const ValueKey('explore.scope.explore')), findsNothing);
      expect(find.text('Tersimpan'), findsOneWidget);
      expect(find.text('Jelajahi'), findsNothing);
      // The saved count is information about the collection, not a filter.
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('pressing the saved toggle enters and leaves the saved scope', (
      tester,
    ) async {
      bool? picked;

      await tester.pumpWidget(
        wrapPage(
          ExploreScopeSwitch(
            saved: false,
            savedCount: 0,
            onChanged: (value) => picked = value,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('explore.scope.saved')));
      expect(picked, isTrue);

      // Same button, now active: pressing it again leaves the saved scope.
      picked = null;
      await tester.pumpWidget(
        wrapPage(
          ExploreScopeSwitch(
            saved: true,
            savedCount: 0,
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
          ExploreScopeSwitch(saved: false, savedCount: 0, onChanged: (_) {}),
        ),
      );
      await tester.pump();

      final size = tester.getSize(
        find.byKey(const ValueKey('explore.scope.saved')),
      );
      expect(size.height, greaterThanOrEqualTo(44));
    });
  });

  group('ExploreControlsBar', () {
    testWidgets('keeps the saved toggle and the view action on one tidy row', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapPage(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ExploreControlsBar(
              saved: false,
              savedCount: 2,
              onSavedChanged: (_) {},
              mapMode: false,
              onViewChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      final saved = find.byKey(const ValueKey('explore.scope.saved'));
      final view = find.byKey(const ValueKey('explore.view.map'));
      expect(saved, findsOneWidget);
      expect(view, findsOneWidget);

      final savedRect = tester.getRect(saved);
      final viewRect = tester.getRect(view);
      final screen = tester.getSize(find.byType(Scaffold));

      // Same row, same height: the two controls read as one family.
      expect(
        savedRect.center.dy,
        moreOrLessEquals(viewRect.center.dy, epsilon: 0.5),
      );
      expect(
        savedRect.height,
        moreOrLessEquals(viewRect.height, epsilon: 0.5),
      );
      // Saved on the left, view pinned to the right gutter.
      expect(savedRect.left, 16);
      expect(viewRect.left, greaterThan(savedRect.right));
      expect(
        viewRect.right,
        moreOrLessEquals(screen.width - 16, epsilon: 0.5),
      );
    });

    testWidgets('the view action names the destination and reports it', (
      tester,
    ) async {
      bool? picked;

      await tester.pumpWidget(
        wrapPage(
          ExploreControlsBar(
            saved: false,
            savedCount: 0,
            onSavedChanged: (_) {},
            mapMode: false,
            onViewChanged: (value) => picked = value,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Peta'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('explore.view.map')));
      expect(picked, isTrue);

      await tester.pumpWidget(
        wrapPage(
          ExploreControlsBar(
            saved: false,
            savedCount: 0,
            onSavedChanged: (_) {},
            mapMode: true,
            onViewChanged: (value) => picked = value,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Daftar'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('explore.view.list')));
      expect(picked, isFalse);
    });

    testWidgets('wires the saved toggle and the view action separately', (
      tester,
    ) async {
      bool? savedPicked;
      bool? viewPicked;

      await tester.pumpWidget(
        wrapPage(
          ExploreControlsBar(
            saved: false,
            savedCount: 1,
            onSavedChanged: (value) => savedPicked = value,
            mapMode: false,
            onViewChanged: (value) => viewPicked = value,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('explore.scope.saved')));
      expect(savedPicked, isTrue);
      expect(viewPicked, isNull);

      await tester.tap(find.byKey(const ValueKey('explore.view.map')));
      expect(viewPicked, isTrue);
    });

    testWidgets('does not overflow when the controls have to wrap', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        wrapPage(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: ExploreControlsBar(
              saved: false,
              savedCount: 2,
              onSavedChanged: (_) {},
              mapMode: false,
              onViewChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      final saved = find.byKey(const ValueKey('explore.scope.saved'));
      final view = find.byKey(const ValueKey('explore.view.map'));
      expect(saved, findsOneWidget);
      expect(view, findsOneWidget);
      // Graceful fallback: the view action moves below instead of clipping.
      expect(
        tester.getTopLeft(view).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(saved).dy),
      );
    });
  });

  group('CategorySelector', () {
    testWidgets('shows one icon option per project category', (tester) async {
      await tester.pumpWidget(
        wrapPage(
          CategorySelector(
            categoryIds: const ['semua', 'penyu', 'karang', 'mangrove'],
            selectedId: 'semua',
            onSelected: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Kategori'), findsOneWidget);
      expect(find.byKey(const ValueKey('explore.category.semua')), findsOneWidget);
      expect(find.byKey(const ValueKey('explore.category.penyu')), findsOneWidget);
      expect(find.byKey(const ValueKey('explore.category.karang')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('explore.category.mangrove')),
        findsOneWidget,
      );
      // The saved collection is a scope, never a category option.
      expect(
        find.byKey(const ValueKey('explore.category.tersimpan')),
        findsNothing,
      );
    });

    testWidgets('reports the selected category', (tester) async {
      String? picked;

      await tester.pumpWidget(
        wrapPage(
          CategorySelector(
            categoryIds: const ['semua', 'penyu', 'karang'],
            selectedId: 'semua',
            onSelected: (id) => picked = id,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('explore.category.karang')));
      expect(picked, 'karang');
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
      expect(find.text('Kategori: Penyu'), findsOneWidget);
      expect(find.text('Jarak: <250 km'), findsOneWidget);
      expect(find.text('Kondisi: Kritis'), findsOneWidget);
      expect(find.text('Hapus semua'), findsOneWidget);
    });

    testWidgets('removing one token keeps the other dimensions', (tester) async {
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
        find.byKey(const ValueKey('explore.activeFilter.category')),
      );

      expect(changed, isNotNull);
      expect(changed!.category, 'semua');
      expect(changed!.distance, DistanceBand.dekat);
      expect(changed!.condition, ProjectCondition.kritis);
    });

    testWidgets('"Hapus semua" clears every dimension', (tester) async {
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

      expect(changed, ExploreFilterSelection.none);
    });
  });

  group('ExploreResultsBar', () {
    testWidgets('states how many projects the filters leave', (tester) async {
      await tester.pumpWidget(
        wrapPage(const ExploreResultsBar(count: 4)),
      );
      await tester.pump();

      expect(find.text('Proyek · 4'), findsOneWidget);
      // The view mode lives in the header, so the results line stays slim.
      expect(find.byKey(const ValueKey('explore.view.list')), findsNothing);
      expect(find.byKey(const ValueKey('explore.view.map')), findsNothing);
    });
  });
}
