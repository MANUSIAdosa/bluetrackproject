import 'package:blue_track/core/router/routes.dart';
import 'package:blue_track/core/state/app_state.dart';
import 'package:blue_track/features/actions/data/action_registration_draft.dart';
import 'package:blue_track/features/actions/data/action_repository.dart';
import 'package:blue_track/features/actions/domain/action_item.dart';
import 'package:blue_track/features/actions/presentation/action_registration_page.dart';
import 'package:blue_track/shared/widgets/error_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/action_fixtures.dart';
import 'support/test_harness.dart';

const _ackKey = ValueKey('action.register.equipmentAck');
const _next1Key = ValueKey('action.register.next.1');
const _next2Key = ValueKey('action.register.next.2');
const _confirmKey = ValueKey('action.register.confirmButton');

void main() {
  setUp(() {
    // Registration requires a session; the logged-out test opts out.
    AuthController.instance.setSignedIn(true);
  });

  tearDown(() {
    AuthController.instance.setSignedIn(false);
  });

  testWidgets('step 1 lists the equipment and blocks until acknowledged', (
    tester,
  ) async {
    final item = buildAction(
      equipment: const ['Sarung tangan', 'Kantong sampah'],
    );
    await _pumpWizard(tester, item: item);

    expect(find.text('Perlengkapan'), findsWidgets);
    expect(find.text('Sarung tangan'), findsOneWidget);
    expect(find.text('Kantong sampah'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('action.equipment.list')),
      findsOneWidget,
    );

    FilledButton next() => tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(_next1Key),
        matching: find.byType(FilledButton),
      ),
    );

    expect(next().onPressed, isNull);
    expect(
      find.text('Centang pernyataan perlengkapan untuk melanjutkan.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(_ackKey));
    await tester.pumpAndSettle();

    expect(next().onPressed, isNotNull);
    await tester.tap(find.byKey(_next1Key));
    await tester.pumpAndSettle();

    // Step 2 is the participant step.
    expect(
      find.byKey(const ValueKey('action.register.step.participant.body')),
      findsOneWidget,
    );
  });

  testWidgets('actions without equipment can continue immediately', (
    tester,
  ) async {
    await _pumpWizard(tester, item: buildAction(equipment: const []));

    expect(
      find.byKey(const ValueKey('action.equipment.empty')),
      findsOneWidget,
    );
    expect(find.byKey(_ackKey), findsNothing);

    await tester.tap(find.byKey(_next1Key));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('action.register.step.participant.body')),
      findsOneWidget,
    );
  });

  testWidgets('review step shows the summary and change links', (tester) async {
    final item = buildAction();
    await _pumpWizard(tester, item: item);

    await _advanceToReview(tester);

    expect(find.text('Tinjau pendaftaran'), findsOneWidget);
    expect(find.text(item.title), findsWidgets);
    expect(find.text('Perlengkapan disanggupi'), findsOneWidget);
    expect(find.text('Ubah'), findsNWidgets(2));

    // "Ubah" on the equipment row goes back to step 1.
    await tester.tap(find.text('Ubah').first);
    await tester.pumpAndSettle();

    expect(find.byKey(_ackKey), findsOneWidget);
  });

  testWidgets('participant step and review show the signed-in name', (
    tester,
  ) async {
    final item = buildAction(
      equipment: const ['Sarung tangan', 'Kantong sampah'],
    );
    await _pumpWizard(tester, item: item);

    await _advanceToReview(tester, stopAtParticipant: true);

    // Same name source as My Impact; without a readable token the page falls
    // back to that page's generic greeting.
    expect(find.text('Nama'), findsOneWidget);
    expect(find.text('Sahabat Laut'), findsOneWidget);

    await tester.tap(find.byKey(_next2Key));
    await tester.pumpAndSettle();

    expect(find.text('Nama'), findsOneWidget);
    expect(find.text('Sahabat Laut'), findsOneWidget);
    // The review repeats what has to be brought.
    expect(find.text('Sarung tangan'), findsOneWidget);
    expect(find.text('Kantong sampah'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('action.equipment.list')),
      findsOneWidget,
    );
  });

  testWidgets('confirming stores the registration and shows the result step', (
    tester,
  ) async {
    final item = buildAction();
    final repository = FakeActionRepository([item]);
    final store = InMemoryActionParticipationStore();
    await _pumpWizard(
      tester,
      item: item,
      repository: repository,
      store: store,
    );

    await _advanceToReview(tester);
    await tester.tap(find.byKey(_confirmKey));
    await tester.pumpAndSettle();

    expect(repository.registerCalls, ['a01']);
    expect(store.isRegistered('a01'), isTrue);
    expect(find.text('Pendaftaran berhasil'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('action.register.successStatus')),
      findsOneWidget,
    );
    expect(find.text('Ke Aksi Saya'), findsOneWidget);
  });

  testWidgets('a failed write never reports success', (tester) async {
    final item = buildAction();
    final repository = FakeActionRepository([item])
      ..shouldFailRegistration = true;
    final store = InMemoryActionParticipationStore();
    await _pumpWizard(
      tester,
      item: item,
      repository: repository,
      store: store,
    );

    await _advanceToReview(tester);
    await tester.tap(find.byKey(_confirmKey));
    await tester.pumpAndSettle();

    expect(store.isRegistered('a01'), isFalse);
    expect(find.text('Pendaftaran berhasil'), findsNothing);
    expect(find.byKey(const ValueKey('action.register.failed')), findsOneWidget);
    expect(find.text('Pendaftaran gagal'), findsOneWidget);
  });

  testWidgets('a full quota at confirm time blocks the submission', (
    tester,
  ) async {
    final item = buildAction(quota: 40, registered: 28);
    final repository = FakeActionRepository([item]);
    final store = InMemoryActionParticipationStore();
    await _pumpWizard(
      tester,
      item: item,
      repository: repository,
      store: store,
    );

    await _advanceToReview(tester);

    // Someone else takes the last seats while the user is in the wizard.
    repository.items[0] = buildAction(quota: 40, registered: 40);    await tester.tap(find.byKey(_confirmKey));
    await tester.pumpAndSettle();

    expect(repository.registerCalls, isEmpty);
    expect(store.isRegistered('a01'), isFalse);
    expect(find.byKey(const ValueKey('action.register.blocked')), findsOneWidget);
    expect(find.text('Kuota sudah penuh'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('action.register.blockedBack')),
      findsOneWidget,
    );
  });

  testWidgets('a started activity is not offered for registration', (
    tester,
  ) async {
    final item = buildAction(
      startsAt: DateTime(2026, 11, 3, 8),
      endsAt: DateTime(2026, 11, 3, 12),
    );
    await _pumpWizard(tester, item: item);

    expect(
      find.byKey(const ValueKey('action.register.unavailable')),
      findsOneWidget,
    );
    expect(find.text('Pendaftaran ditutup'), findsOneWidget);
    expect(find.byKey(_ackKey), findsNothing);
  });

  testWidgets('a logged-out user is sent to login and returns to step 3', (
    tester,
  ) async {
    final item = buildAction();
    final repository = FakeActionRepository([item]);
    final store = InMemoryActionParticipationStore();
    final drafts = InMemoryActionRegistrationDraftStore();
    AuthController.instance.setSignedIn(false);

    await _pumpWizard(
      tester,
      item: item,
      repository: repository,
      store: store,
      draftStore: drafts,
    );

    await _advanceToReview(tester);
    await tester.tap(find.byKey(_confirmKey));
    await tester.pumpAndSettle();

    expect(
      find.text('LOGIN:${Routes.actionRegisterUrl('a01')}?resume=1'),
      findsOneWidget,
    );
    expect(repository.registerCalls, isEmpty);
    expect(drafts.load('a01')?.step, 3);
    expect(drafts.load('a01')?.equipmentAcked, isTrue);

    // Signing in returns to the wizard with the same step and answers.
    AuthController.instance.setSignedIn(true);
    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpWizard(
      tester,
      item: item,
      repository: repository,
      store: store,
      draftStore: drafts,
      resume: true,
    );

    expect(
      find.byKey(const ValueKey('action.register.step.review.body')),
      findsOneWidget,
    );
    expect(find.text('Perlengkapan disanggupi'), findsOneWidget);
  });

  testWidgets('an existing registration reopens on the result step', (
    tester,
  ) async {
    final item = buildAction();
    final store = InMemoryActionParticipationStore();
    await store.setRegistered('a01', true);

    await _pumpWizard(tester, item: item, store: store);

    expect(find.text('Pendaftaran berhasil'), findsOneWidget);
    expect(find.byKey(_ackKey), findsNothing);
  });

  testWidgets('shows the error state when the action cannot be loaded', (
    tester,
  ) async {
    await _pumpWizard(
      tester,
      item: buildAction(),
      repository: FlakyActionRepository([buildAction()]),
    );

    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.text('Pendaftaran tidak dapat dimuat.'), findsOneWidget);
  });

  testWidgets('fits a narrow phone with large text on every step', (
    tester,
  ) async {
    final item = buildAction(
      title: 'Restorasi Terumbu Karang dan Pembersihan Pantai Bersama Warga',
      locationName: 'Pulau Pramuka, Kepulauan Seribu, DKI Jakarta',
      equipment: const ['Sarung tangan', 'Kantong sampah', 'Sepatu bot'],
    );
    await _pumpWizard(
      tester,
      item: item,
      size: const Size(320, 700),
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);

    await _advanceToReview(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Tinjau pendaftaran'), findsOneWidget);
  });
}

/// Walks steps 1 → 2 → 3 of the wizard.
Future<void> _advanceToReview(WidgetTester tester, {bool stopAtParticipant = false}) async {
  final ack = find.byKey(_ackKey);
  await _tryReveal(tester, ack);
  if (ack.evaluate().isNotEmpty) {
    await tester.ensureVisible(ack);
    await tester.pumpAndSettle();
    await tester.tap(ack);
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byKey(_next1Key));
  await tester.pumpAndSettle();
  if (stopAtParticipant) return;
  await tester.tap(find.byKey(_next2Key));
  await tester.pumpAndSettle();
}

/// Scrolls a lazily built list item into view. Missing items (for example an
/// action without equipment) simply leave the view where it is.
Future<void> _tryReveal(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isNotEmpty) return;
  try {
    await tester.scrollUntilVisible(finder, 200, maxScrolls: 20);
    await tester.pumpAndSettle();
  } catch (_) {
    // Nothing to reveal.
  }
}

Future<void> _pumpWizard(
  WidgetTester tester, {
  required ActionItem item,
  ActionRepository? repository,
  InMemoryActionParticipationStore? store,
  InMemoryActionRegistrationDraftStore? draftStore,
  bool resume = false,
  Size size = const Size(390, 844),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  final router = GoRouter(
    initialLocation: Routes.actionRegisterUrl(item.id),
    routes: [
      GoRoute(
        path: Routes.actionRegister,
        builder: (context, state) => ActionRegistrationPage(
          actionId: state.pathParameters['id'] ?? '',
          repository: repository ?? FakeActionRepository([item]),
          participationStore: store ?? InMemoryActionParticipationStore(),
          draftStore: draftStore ?? InMemoryActionRegistrationDraftStore(),
          resume: resume || state.uri.queryParameters['resume'] == '1',
          now: () => DateTime(2026, 11, 3, 9),
        ),
      ),
      GoRoute(
        path: Routes.auth,
        builder: (context, state) => Scaffold(
          appBar: AppBar(),
          body: Text('LOGIN:${state.uri.queryParameters['redirect'] ?? ''}'),
        ),
      ),
      GoRoute(
        path: Routes.myActions,
        builder: (context, state) => const Scaffold(
          body: Text('MY_ACTIONS'),
        ),
      ),
    ],
  );

  await tester.pumpWidget(wrapRouter(router));
  await tester.pumpAndSettle();
}
