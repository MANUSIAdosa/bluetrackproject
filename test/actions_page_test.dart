import 'package:blue_track/features/actions/data/action_repository.dart';
import 'package:blue_track/features/actions/domain/action_item.dart';
import 'package:blue_track/features/actions/presentation/actions_page.dart';
import 'package:blue_track/features/actions/presentation/widgets/action_card.dart';
import 'package:blue_track/features/actions/presentation/widgets/action_card_skeleton.dart';
import 'package:blue_track/shared/widgets/empty_state.dart';
import 'package:blue_track/shared/widgets/error_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/action_fixtures.dart';
import 'support/test_harness.dart';

void main() {
  test('mock repository loads every action sorted by start time', () async {
    final actions = await const MockActionRepository(
      delay: Duration.zero,
    ).getActions();

    expect(actions, hasLength(6));
    expect(actions.first.id, 'a01');
    for (var i = 1; i < actions.length; i++) {
      expect(
        actions[i].startsAt.isBefore(actions[i - 1].startsAt),
        isFalse,
        reason: 'actions must arrive sorted by start time',
      );
    }
  });

  testWidgets('shows skeleton cards while loading', (tester) async {
    final repository = ControlledActionRepository();

    await tester.pumpWidget(wrapPage(ActionsPage(repository: repository)));
    await tester.pump();

    expect(find.byKey(const ValueKey('actions.loading')), findsOneWidget);
    expect(find.byType(ActionCardSkeleton), findsAtLeastNWidgets(1));
    expect(find.byType(ActionCard), findsNothing);

    repository.completer.complete([buildAction()]);
    await tester.pumpAndSettle();

    expect(find.byType(ActionCard), findsOneWidget);
  });

  testWidgets('shows the empty state when there are no actions', (tester) async {
    await tester.pumpWidget(
      wrapPage(ActionsPage(repository: FakeActionRepository(const []))),
    );
    await tester.pumpAndSettle();

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('Belum ada aksi yang tersedia saat ini.'), findsOneWidget);
  });

  testWidgets('shows the error state and retries', (tester) async {
    final repository = FlakyActionRepository([buildAction()]);

    await tester.pumpWidget(wrapPage(ActionsPage(repository: repository)));
    await tester.pumpAndSettle();

    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.text('Aksi tidak dapat dimuat.'), findsOneWidget);

    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();

    expect(find.byType(ErrorState), findsNothing);
    expect(find.byType(ActionCard), findsOneWidget);
  });

  testWidgets('opens the existing action detail route from a card', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/actions',
      routes: [
        GoRoute(
          path: '/actions',
          builder: (context, state) =>
              ActionsPage(repository: FakeActionRepository([buildAction()])),
        ),
        GoRoute(
          path: '/actions/:id',
          builder: (context, state) => Scaffold(
            body: Text('Detail ${state.pathParameters['id']}'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(wrapRouter(router));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('actionCard.a01')));
    await tester.pumpAndSettle();

    expect(find.text('Detail a01'), findsOneWidget);
  });

  testWidgets('renders English copy from the active locale', (tester) async {
    await tester.pumpWidget(
      wrapPage(
        ActionsPage(repository: FakeActionRepository([buildAction()])),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Action'), findsOneWidget);
    expect(find.text('Beach Cleanup'), findsOneWidget);
    expect(find.textContaining('7:00'), findsOneWidget);
    expect(find.text('28/40 participants'), findsOneWidget);
  });

  testWidgets('lays out two equal columns without overflow at 320dp', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final items = [
      buildAction(
        id: 'a01',
        title: 'Restorasi Terumbu Karang di Kepulauan Seribu',
        type: ActionType.coralRestoration,
        locationName: 'Pulau Pramuka, Kepulauan Seribu',
        organizerName: 'Yayasan Konservasi Laut Nusantara',
        quota: 20,
        registered: 20,
      ),
      buildAction(
        id: 'a02',
        title: 'Pemantauan Penyu di Pantai Sukamade',
        type: ActionType.wildlifeMonitoring,
        locationName: 'Pantai Sukamade, Banyuwangi',
        organizerName: 'Komunitas Laut Bersih',
        quota: 15,
        registered: 9,
      ),
      buildAction(
        id: 'a03',
        title: 'Sekolah Laut untuk Anak Pesisir',
        type: ActionType.education,
        locationName: 'Pulau Tidung, Kepulauan Seribu',
        organizerName: 'Pendidikan Bahari Nusantara',
      ),
    ];

    await tester.pumpWidget(
      wrapPage(ActionsPage(repository: FakeActionRepository(items))),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GridView), findsOneWidget);

    final first = find.byKey(const ValueKey('actionCard.a01'));
    final second = find.byKey(const ValueKey('actionCard.a02'));
    final third = find.byKey(const ValueKey('actionCard.a03'));

    expect(tester.getTopLeft(first).dy, tester.getTopLeft(second).dy);
    expect(
      tester.getTopLeft(second).dx,
      greaterThan(tester.getTopLeft(first).dx),
    );
    expect(
      tester.getTopLeft(third).dy,
      greaterThan(tester.getTopLeft(first).dy),
    );
    expect(
      tester.getSize(first).width,
      closeTo(tester.getSize(second).width, 0.1),
    );
    expect(tester.takeException(), isNull);
  });
}
