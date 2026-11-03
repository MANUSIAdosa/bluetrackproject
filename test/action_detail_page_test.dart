import 'package:blue_track/core/localization/app_localizations.dart';
import 'package:blue_track/core/router/routes.dart';
import 'package:blue_track/core/state/app_state.dart';
import 'package:blue_track/core/utils/formatters.dart';
import 'package:blue_track/features/actions/data/action_participation_store.dart';
import 'package:blue_track/features/actions/data/action_repository.dart';
import 'package:blue_track/features/actions/domain/action_item.dart';
import 'package:blue_track/features/actions/presentation/action_detail_page.dart';
import 'package:blue_track/shared/widgets/offline_banner.dart';
import 'package:blue_track/shared/widgets/verified_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/action_fixtures.dart';
import 'support/fake_tile_provider.dart';
import 'support/test_harness.dart';

const _registerButtonKey = ValueKey('action.detail.registerButton');
const _reminderSwitchKey = ValueKey('action.detail.reminderSwitch');
const _statusKey = ValueKey('action.detail.status');
const _mapKey = ValueKey('action.detail.map');
const _organizerKey = ValueKey('action.detail.organizer');

void main() {
  tearDown(() {
    AuthController.instance.setSignedIn(false);
    OfflineController.instance.setOffline(false);
  });

  testWidgets('shows complete activity information', (tester) async {
    final item = buildAction(
      description: 'Deskripsi lengkap kegiatan konservasi.',
      meetingPoint: 'Pos Pantai Kuta',
      equipment: const ['Sarung tangan', 'Kantong sampah'],
    );

    await _pumpDetail(tester, item: item);

    expect(find.text(item.title), findsOneWidget);
    expect(find.text('Bersih Pantai'), findsOneWidget);
    expect(find.text('Terbuka'), findsOneWidget);
    expect(find.text('28/40 peserta'), findsOneWidget);
    expect(find.text(item.description), findsOneWidget);
    expect(find.text(Formatters.date(item.startsAt, 'id')), findsOneWidget);
    expect(
      find.text(
        '${Formatters.time(item.startsAt, 'id')} – '
        '${Formatters.time(item.endsAt, 'id')}',
      ),
      findsOneWidget,
    );
    expect(find.text(item.locationName), findsOneWidget);
    expect(find.text(item.meetingPoint), findsOneWidget);
    expect(find.text('Sarung tangan'), findsOneWidget);
    expect(find.text('Kantong sampah'), findsOneWidget);
    expect(find.text(item.organizerName), findsOneWidget);
    expect(find.byType(VerifiedBadge), findsWidgets);
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byKey(const ValueKey('action.detail.marker')), findsOneWidget);
  });

  testWidgets('shows Penuh and disables registration when quota is full', (
    tester,
  ) async {
    final item = buildAction(quota: 40, registered: 40);

    await _pumpDetail(tester, item: item);

    expect(_statusText('Penuh'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(_registerButtonKey),
        matching: find.text('Penuh'),
      ),
      findsOneWidget,
    );
    expect(_registerButton(tester).onPressed, isNull);
  });

  testWidgets('shows Selesai and disables registration after the action ended', (
    tester,
  ) async {
    final item = buildAction(
      startsAt: DateTime(2026, 11, 1, 7),
      endsAt: DateTime(2026, 11, 1, 10),
    );

    await _pumpDetail(tester, item: item);

    expect(_statusText('Selesai'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(_registerButtonKey),
        matching: find.text('Selesai'),
      ),
      findsOneWidget,
    );
    expect(_registerButton(tester).onPressed, isNull);
  });

  testWidgets('closes registration once the activity has started', (
    tester,
  ) async {
    final item = buildAction(
      startsAt: DateTime(2026, 11, 3, 8),
      endsAt: DateTime(2026, 11, 3, 12),
    );

    await _pumpDetail(tester, item: item);

    expect(_statusText('Terbuka'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(_registerButtonKey),
        matching: find.text('Pendaftaran ditutup'),
      ),
      findsOneWidget,
    );
    expect(_registerButton(tester).onPressed, isNull);
  });

  testWidgets('shows the not-found state for an unknown action', (tester) async {
    await _pumpDetail(
      tester,
      item: buildAction(id: 'missing'),
      repository: FakeActionRepository([]),
    );

    expect(
      find.byKey(const ValueKey('action.detail.notFound')),
      findsOneWidget,
    );
    expect(find.text('Aksi tidak ditemukan.'), findsOneWidget);
    expect(find.byKey(_registerButtonKey), findsNothing);
  });

  testWidgets('shows the error state and retries the detail request', (
    tester,
  ) async {
    final item = buildAction();
    final repository = FlakyActionRepository([item]);

    await _pumpDetail(tester, item: item, repository: repository);

    expect(find.byKey(const ValueKey('action.detail.error')), findsOneWidget);
    expect(find.text('Detail aksi gagal dimuat.'), findsOneWidget);

    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();

    expect(find.text(item.title), findsOneWidget);
    expect(find.byKey(const ValueKey('action.detail.error')), findsNothing);
  });

  testWidgets('shows a loading state while the action is fetched', (
    tester,
  ) async {
    final repository = ControlledActionRepository();
    AuthController.instance.setSignedIn(true);
    _setView(tester, const Size(390, 844), 1);

    await tester.pumpWidget(
      wrapPage(
        ActionDetailPage(
          actionId: 'a01',
          repository: repository,
          participationStore: InMemoryActionParticipationStore(),
          tileProvider: FakeTileProvider(),
          now: () => DateTime(2026, 11, 3, 9),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('action.detail.loading')),
      findsOneWidget,
    );

    repository.detailCompleter.complete(buildAction());
    await tester.pumpAndSettle();

    expect(find.text('Bersih Pantai Kuta'), findsOneWidget);
  });

  testWidgets('sends a logged-out user to Login with a detail redirect', (
    tester,
  ) async {
    final item = buildAction();
    final repository = FakeActionRepository([item]);
    await _pumpRouted(
      tester,
      item: item,
      repository: repository,
      signedIn: false,
    );

    await tester.tap(find.byKey(_registerButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('LOGIN:/actions/a01'), findsOneWidget);
    expect(repository.registerCalls, isEmpty);
  });

  testWidgets('registers after confirmation and shows the joined state', (
    tester,
  ) async {
    final item = buildAction();
    final repository = FakeActionRepository([item]);
    final store = InMemoryActionParticipationStore();
    await _pumpRouted(
      tester,
      item: item,
      repository: repository,
      store: store,
    );

    await tester.tap(find.byKey(_registerButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('Konfirmasi Pendaftaran'), findsOneWidget);
    expect(find.text(item.title), findsWidgets);
    expect(find.text('Konfirmasi'), findsOneWidget);
    expect(find.text('Batal'), findsOneWidget);

    await tester.tap(find.text('Konfirmasi'));
    await tester.pumpAndSettle();

    expect(repository.registerCalls, ['a01']);
    expect(store.isRegistered('a01'), isTrue);
    expect(find.text('Terdaftar'), findsOneWidget);
    expect(
      find.text('Pendaftaran berhasil. Sampai jumpa di lokasi!'),
      findsOneWidget,
    );
    expect(_registerButton(tester).onPressed, isNull);
    expect(find.byKey(_reminderSwitchKey), findsOneWidget);
  });

  testWidgets('cancelling the confirmation leaves the user unregistered', (
    tester,
  ) async {
    final item = buildAction();
    final repository = FakeActionRepository([item]);
    final store = InMemoryActionParticipationStore();
    await _pumpRouted(
      tester,
      item: item,
      repository: repository,
      store: store,
    );

    await tester.tap(find.byKey(_registerButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    expect(repository.registerCalls, isEmpty);
    expect(store.isRegistered('a01'), isFalse);
    expect(find.text('Daftar'), findsOneWidget);
    expect(_registerButton(tester).onPressed, isNotNull);
  });

  testWidgets('keeps the register button and reports a failed registration', (
    tester,
  ) async {
    final item = buildAction();
    final repository = FakeActionRepository([item])
      ..shouldFailRegistration = true;
    final store = InMemoryActionParticipationStore();
    await _pumpRouted(
      tester,
      item: item,
      repository: repository,
      store: store,
    );

    await tester.tap(find.byKey(_registerButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Konfirmasi'));
    await tester.pumpAndSettle();

    expect(repository.registerCalls, isEmpty);
    expect(store.isRegistered('a01'), isFalse);
    expect(
      find.text('Pendaftaran gagal. Silakan coba lagi.'),
      findsOneWidget,
    );
    expect(find.text('Daftar'), findsOneWidget);
    expect(_registerButton(tester).onPressed, isNotNull);
  });

  testWidgets('does not open registration when the user is already registered', (
    tester,
  ) async {
    final item = buildAction();
    final repository = FakeActionRepository([item]);
    final store = InMemoryActionParticipationStore();
    await store.setRegistered('a01', true);

    await _pumpRouted(
      tester,
      item: item,
      repository: repository,
      store: store,
    );

    expect(find.text('Terdaftar'), findsOneWidget);
    expect(_registerButton(tester).onPressed, isNull);

    await tester.tap(find.byKey(_registerButtonKey), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Konfirmasi Pendaftaran'), findsNothing);
    expect(repository.registerCalls, isEmpty);
  });

  testWidgets('shows the reminder switch only for registered users', (
    tester,
  ) async {
    final item = buildAction();

    await _pumpDetail(tester, item: item);
    expect(find.byKey(_reminderSwitchKey), findsNothing);

    // A new page instance reads the store again; rebuild the tree so the
    // previous ActionDetailPage state is not reused.
    await tester.pumpWidget(const SizedBox.shrink());

    final store = InMemoryActionParticipationStore();
    await store.setRegistered('a01', true);
    await _pumpDetail(tester, item: item, store: store);

    expect(find.byKey(_reminderSwitchKey), findsOneWidget);
  });

  testWidgets('persists the reminder toggle through the local store', (
    tester,
  ) async {
    final item = buildAction();
    final store = InMemoryActionParticipationStore();
    await store.setRegistered('a01', true);
    await _pumpDetail(tester, item: item, store: store);

    expect(tester.widget<Switch>(find.byKey(_reminderSwitchKey)).value, isFalse);

    await tester.scrollUntilVisible(find.byKey(_reminderSwitchKey), 200);
    await tester.pump();
    await tester.tap(find.byKey(_reminderSwitchKey));
    await tester.pumpAndSettle();

    expect(store.isReminderOn('a01'), isTrue);
    expect(find.text('Pengingat diaktifkan (simulasi).'), findsOneWidget);

    // Simulate reopening the page: the switch value must come from the store,
    // not from the previous page state.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      wrapPage(
        _detailPage(
          actionId: item.id,
          item: item,
          repository: FakeActionRepository([item]),
          store: store,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(find.byKey(_reminderSwitchKey)).value, isTrue);
  });

  testWidgets('offers a back button that falls back to the agenda on a deep '
      'link', (tester) async {
    final item = buildAction();
    await _pumpRouted(
      tester,
      item: item,
      repository: FakeActionRepository([item]),
    );

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('AGENDA'), findsOneWidget);
  });

  testWidgets('opens the organization profile from the organizer section', (
    tester,
  ) async {
    final item = buildAction();
    await _pumpRouted(
      tester,
      item: item,
      repository: FakeActionRepository([item]),
    );

    await tester.scrollUntilVisible(find.byKey(_organizerKey), 250);
    await tester.pump();
    await tester.tap(find.byKey(_organizerKey));
    await tester.pumpAndSettle();

    expect(find.text('ORG:o01'), findsOneWidget);
  });

  testWidgets('the mini map does not block vertical scrolling', (tester) async {
    final item = buildAction(
      description: 'Deskripsi panjang untuk memastikan halaman dapat digulir. ' *
          4,
    );
    await _pumpDetail(tester, item: item, size: const Size(320, 640));

    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.scrollUntilVisible(find.byKey(_mapKey), 200);
    await tester.pump();

    // scrollUntilVisible leaves the list at its maximum; drag back first so
    // there is room left to prove the upward drag scrolls the page.
    await tester.drag(find.byKey(_mapKey), const Offset(0, 240));
    await tester.pumpAndSettle();
    final before = scrollable.position.pixels;

    await tester.drag(find.byKey(_mapKey), const Offset(0, -160));
    await tester.pumpAndSettle();

    expect(scrollable.position.pixels, greaterThan(before));
    expect(tester.takeException(), isNull);
  });

  testWidgets('stays overflow-free at 320dp with large text', (tester) async {
    final item = buildAction(
      title: 'Restorasi Terumbu Karang dan Pembersihan Pantai Bersama Warga',
      description:
          'Kegiatan konservasi ini melibatkan relawan untuk membersihkan '
          'pantai, menanam mangrove, dan memantau kesehatan terumbu karang.',
      locationName: 'Pulau Pramuka, Kepulauan Seribu, DKI Jakarta',
      meetingPoint: 'Dermaga Utama Pulau Pramuka dekat pos koordinasi relawan',
      organizerName: 'Yayasan Konservasi Laut Nusantara',
    );

    await _pumpDetail(
      tester,
      item: item,
      size: const Size(320, 700),
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(find.byKey(_organizerKey), 250);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(_registerButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('Konfirmasi Pendaftaran'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stays usable offline and skips the map tile layer', (
    tester,
  ) async {
    OfflineController.instance.setOffline(true);

    await _pumpDetail(tester);

    expect(find.byType(OfflineBanner), findsOneWidget);
    expect(find.byType(TileLayer), findsNothing);
    expect(find.text('Bersih Pantai Kuta'), findsOneWidget);
    expect(find.byKey(_registerButtonKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders theme colours in dark mode', (tester) async {
    await _pumpDetail(
      tester,
      theme: ThemeData.dark(useMaterial3: true),
    );

    expect(find.text('Bersih Pantai Kuta'), findsOneWidget);
    expect(find.text('Terbuka'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders English copy from the active locale', (tester) async {
    await _pumpDetail(tester, locale: const Locale('en'));

    expect(find.text('Beach Cleanup'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Register'), findsOneWidget);
  });
}

Future<void> _pumpDetail(
  WidgetTester tester, {
  ActionItem? item,
  ActionRepository? repository,
  ActionParticipationStore? store,
  DateTime? now,
  bool signedIn = true,
  Size size = const Size(390, 844),
  double textScale = 1.0,
  Locale locale = const Locale('id'),
  ThemeData? theme,
}) async {
  final action = item ?? buildAction();
  AuthController.instance.setSignedIn(signedIn);
  _setView(tester, size, textScale);

  final page = _detailPage(
    actionId: action.id,
    item: action,
    repository: repository ?? FakeActionRepository([action]),
    store: store,
    now: now,
  );

  await tester.pumpWidget(
    theme == null
        ? wrapPage(page, locale: locale)
        : _wrapWithTheme(page, theme: theme, locale: locale),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpRouted(
  WidgetTester tester, {
  required ActionItem item,
  required FakeActionRepository repository,
  ActionParticipationStore? store,
  bool signedIn = true,
}) async {
  AuthController.instance.setSignedIn(signedIn);
  _setView(tester, const Size(390, 844), 1);

  final router = GoRouter(
    initialLocation: Routes.actionDetailUrl(item.id),
    routes: [
      GoRoute(
        path: Routes.actionDetail,
        builder: (context, state) => _detailPage(
          actionId: state.pathParameters['id'] ?? '',
          item: item,
          repository: repository,
          store: store ?? InMemoryActionParticipationStore(),
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
        path: Routes.orgDetail,
        builder: (context, state) => Scaffold(
          appBar: AppBar(),
          body: Text('ORG:${state.pathParameters['id'] ?? ''}'),
        ),
      ),
      GoRoute(
        path: Routes.actionAgenda,
        builder: (context, state) => Scaffold(
          appBar: AppBar(),
          body: const Text('AGENDA'),
        ),
      ),
    ],
  );

  await tester.pumpWidget(wrapRouter(router));
  await tester.pumpAndSettle();
}

ActionDetailPage _detailPage({
  required String actionId,
  required ActionItem item,
  required ActionRepository repository,
  ActionParticipationStore? store,
  DateTime? now,
}) {
  return ActionDetailPage(
    actionId: actionId,
    repository: repository,
    participationStore: store ?? InMemoryActionParticipationStore(),
    tileProvider: FakeTileProvider(),
    now: () => now ?? DateTime(2026, 11, 3, 9),
  );
}

void _setView(WidgetTester tester, Size size, double textScale) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

FilledButton _registerButton(WidgetTester tester) {
  return tester.widget<FilledButton>(
    find.descendant(
      of: find.byKey(_registerButtonKey),
      matching: find.byType(FilledButton),
    ),
  );
}

Finder _statusText(String text) {
  return find.descendant(
    of: find.byKey(_statusKey),
    matching: find.text(text),
  );
}

Widget _wrapWithTheme(
  Widget child, {
  required ThemeData theme,
  required Locale locale,
}) {
  return MaterialApp(
    theme: theme,
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
