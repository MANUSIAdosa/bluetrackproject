import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:blue_track/core/state/app_state.dart';
import 'package:blue_track/features/report_submit/data/report_draft_store.dart';
import 'package:blue_track/features/report_submit/data/report_photo_picker.dart';
import 'package:blue_track/features/report_submit/domain/report_draft.dart';
import 'package:blue_track/features/report_submit/domain/report_location.dart';
import 'package:blue_track/features/report_submit/presentation/pages/report_wizard_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/fake_report_location_service.dart';
import 'support/fake_tile_provider.dart';
import 'support/test_harness.dart';

const _addPhotoKey = Key('report_add_photo');
Key _removePhotoKey(int index) => Key('report_photo_remove_$index');

/// 1x1 transparent PNG so `Image.file` has a real file to decode in tests.
final _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8'
  '/x8AAwMCAO+ip1sAAAAASUVORK5CYII=',
);

class _FakeStore implements ReportDraftStore {
  ReportWizardDraft? draft;
  int saveCount = 0;

  @override
  Future<ReportWizardDraft?> load() async => draft;

  @override
  Future<void> save(ReportWizardDraft draft) async {
    this.draft = draft;
    saveCount++;
  }

  @override
  Future<void> clear() async {
    draft = null;
  }
}

class _FakePicker implements ReportPhotoPicker {
  _FakePicker({this.paths = const [], this.failure});

  List<String> paths;
  ReportPhotoFailure? failure;
  bool truncated = false;

  ReportPhotoSource? lastSource;
  int? lastRemaining;

  @override
  Future<ReportPhotoPickResult> pick({
    required ReportPhotoSource source,
    required int remaining,
  }) async {
    lastSource = source;
    lastRemaining = remaining;
    if (failure != null) {
      return ReportPhotoPickResult(failure: failure!);
    }
    final selected = paths;
    return ReportPhotoPickResult(
      paths: selected.take(remaining).toList(),
      truncated: truncated || selected.length > remaining,
    );
  }
}

void main() {
  late Directory tempDir;
  late List<String> photoPaths;
  late FakeReportLocationService locationService;
  late FakeTileProvider tileProvider;

  /// 390x844 at dpr 1 is a typical phone; the wizard must fit and its add tile
  /// must stay reachable without a scroll.
  void phoneSurface(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('bluetrack_report_photos_');
    photoPaths = [];
    for (var i = 0; i < 3; i++) {
      final file = File('${tempDir.path}/photo_$i.png');
      await file.writeAsBytes(_onePixelPng);
      photoPaths.add(file.path);
    }
    locationService = FakeReportLocationService();
    tileProvider = FakeTileProvider();
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  Future<void> pumpWizard(
    WidgetTester tester, {
    required _FakeStore store,
    _FakePicker? picker,
    FakeReportLocationService? location,
  }) async {
    phoneSurface(tester);
    await tester.pumpWidget(
      wrapPage(
        ReportWizardPage(
          store: store,
          photoPicker: picker ?? _FakePicker(),
          locationService: location ?? locationService,
          locationTileProvider: tileProvider,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> addFromGallery(WidgetTester tester) async {
    await tester.tap(find.byKey(_addPhotoKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Galeri'));
    await tester.pumpAndSettle();
  }

  Future<void> tapMap(WidgetTester tester) async {
    await tester.tapAt(tester.getCenter(find.byType(FlutterMap)));
    // flutter_map delays single taps by 250 ms to tell them apart from double
    // taps; pump past that before settling.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
  }

  testWidgets('starts on step 1 with continue disabled until a photo exists', (
    tester,
  ) async {
    await pumpWizard(tester, store: _FakeStore());

    expect(find.text('Lapor Temuan'), findsOneWidget);
    expect(find.text('0/3 foto'), findsOneWidget);
    expect(find.text('Foto'), findsOneWidget);
    expect(find.text('Lokasi'), findsOneWidget);
    expect(find.text('Jenis'), findsOneWidget);
    expect(find.text('Tinjau'), findsOneWidget);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Lanjut'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('adds photos from the gallery and keeps them across steps', (
    tester,
  ) async {
    final picker = _FakePicker(paths: photoPaths.take(2).toList());
    final store = _FakeStore();
    await pumpWizard(tester, store: store, picker: picker);

    await addFromGallery(tester);

    expect(find.text('2/3 foto'), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(2));
    expect(picker.lastSource, ReportPhotoSource.gallery);
    expect(picker.lastRemaining, 3);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Lanjut'))
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Lanjut'));
    await tester.pumpAndSettle();
    expect(find.text('Tandai lokasi temuan'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Kembali'));
    await tester.pumpAndSettle();

    expect(find.text('2/3 foto'), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(2));
  });

  testWidgets('removes a photo and brings the add tile back', (tester) async {
    final picker = _FakePicker(paths: photoPaths);
    await pumpWizard(tester, store: _FakeStore(), picker: picker);

    await addFromGallery(tester);
    expect(find.text('3/3 foto'), findsOneWidget);
    expect(find.byKey(_addPhotoKey), findsNothing);

    await tester.tap(find.byKey(_removePhotoKey(0)));
    await tester.pumpAndSettle();

    expect(find.text('2/3 foto'), findsOneWidget);
    expect(find.byKey(_addPhotoKey), findsOneWidget);
  });

  testWidgets(
    'truncates a gallery selection that exceeds the remaining slots',
    (tester) async {
      final picker = _FakePicker(paths: photoPaths.take(2).toList());
      await pumpWizard(tester, store: _FakeStore(), picker: picker);

      await addFromGallery(tester);
      expect(find.text('2/3 foto'), findsOneWidget);

      picker.paths = photoPaths;
      await addFromGallery(tester);

      expect(find.text('3/3 foto'), findsOneWidget);
      expect(picker.lastRemaining, 1);
      expect(
        find.text('Hanya 1 foto ditambahkan karena batas maksimal 3.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('resumes a stored draft from the resume dialog', (tester) async {
    final store = _FakeStore()
      ..draft = ReportWizardDraft(
        photoPaths: photoPaths.take(1).toList(),
        currentStep: 1,
        updatedAt: DateTime.utc(2026, 10, 30, 9),
      );

    await pumpWizard(tester, store: store);

    expect(find.text('Lanjutkan draf?'), findsOneWidget);
    await tester.tap(find.text('Lanjutkan draf'));
    await tester.pumpAndSettle();

    expect(find.text('1/3 foto'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('restores the last opened step when resuming', (tester) async {
    final store = _FakeStore()
      ..draft = ReportWizardDraft(
        photoPaths: photoPaths.take(1).toList(),
        currentStep: 2,
        updatedAt: DateTime.utc(2026, 10, 30, 9),
      );

    await pumpWizard(tester, store: store);
    await tester.tap(find.text('Lanjutkan draf'));
    await tester.pumpAndSettle();

    expect(find.text('Tandai lokasi temuan'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Kembali'));
    await tester.pumpAndSettle();
    expect(find.text('1/3 foto'), findsOneWidget);
  });

  testWidgets('step 2 enables continue only after a pin is placed', (
    tester,
  ) async {
    final store = _FakeStore();
    await pumpWizard(
      tester,
      store: store,
      picker: _FakePicker(paths: photoPaths.take(1).toList()),
    );

    await addFromGallery(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Lanjut'));
    await tester.pumpAndSettle();

    expect(find.text('Tandai lokasi temuan'), findsOneWidget);
    expect(find.text('Gunakan lokasi saya'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Lanjut'))
          .onPressed,
      isNull,
    );

    await tapMap(tester);

    expect(find.text('Geser pin ke lokasi temuan'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Lanjut'))
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Lanjut'));
    await tester.pumpAndSettle();
    expect(find.text('Segera hadir.'), findsOneWidget);
  });

  testWidgets('keeps photos and the pin when moving back to step 1', (
    tester,
  ) async {
    final store = _FakeStore();
    await pumpWizard(
      tester,
      store: store,
      picker: _FakePicker(paths: photoPaths.take(1).toList()),
    );

    await addFromGallery(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Lanjut'));
    await tester.pumpAndSettle();
    await tapMap(tester);

    final latitude = tester
        .widget<Text>(
          find.byKey(const ValueKey('report_location_latitude_value')),
        )
        .data;
    final longitude = tester
        .widget<Text>(
          find.byKey(const ValueKey('report_location_longitude_value')),
        )
        .data;

    await tester.tap(find.widgetWithText(OutlinedButton, 'Kembali'));
    await tester.pumpAndSettle();
    expect(find.text('1/3 foto'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Lanjut'));
    await tester.pumpAndSettle();

    expect(find.text('Tandai lokasi temuan'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('report_location_pin_drag')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('report_location_latitude_value')),
          )
          .data,
      latitude,
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('report_location_longitude_value')),
          )
          .data,
      longitude,
    );
  });

  testWidgets('persists the pin and restores it after reopening', (
    tester,
  ) async {
    final store = _FakeStore();
    await pumpWizard(
      tester,
      store: store,
      picker: _FakePicker(paths: photoPaths.take(1).toList()),
    );

    await addFromGallery(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Lanjut'));
    await tester.pumpAndSettle();
    await tapMap(tester);
    await tester.pump(const Duration(milliseconds: 600));

    final saved = store.draft!;
    expect(saved.hasLocation, isTrue);
    expect(saved.currentStep, 2);
    expect(saved.photoCount, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    await pumpWizard(tester, store: store);
    await tester.tap(find.text('Lanjutkan draf'));
    await tester.pumpAndSettle();

    expect(find.text('Tandai lokasi temuan'), findsOneWidget);
    expect(find.text(saved.latitude!.toStringAsFixed(6)), findsOneWidget);
    expect(find.text(saved.longitude!.toStringAsFixed(6)), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Lanjut'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('a denied GPS request still allows a manual pin', (tester) async {
    locationService.result = const ReportLocationResult.failed(
      ReportLocationFailure.permissionDenied,
    );
    final store = _FakeStore();
    await pumpWizard(
      tester,
      store: store,
      picker: _FakePicker(paths: photoPaths.take(1).toList()),
    );

    await addFromGallery(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Lanjut'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('report_location_gps')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('report_location_gps')));
    await tester.pumpAndSettle();

    expect(find.text('Lokasi tidak tersedia'), findsOneWidget);
    await tester.tap(find.text('Tandai manual'));
    await tester.pumpAndSettle();

    await tapMap(tester);
    await tester.pump(const Duration(milliseconds: 600));

    expect(store.draft!.hasLocation, isTrue);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Lanjut'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('offline still saves a manually placed pin', (tester) async {
    OfflineController.instance.setOffline(true);
    addTearDown(() => OfflineController.instance.setOffline(false));

    final store = _FakeStore();
    await pumpWizard(
      tester,
      store: store,
      picker: _FakePicker(paths: photoPaths.take(1).toList()),
    );
    expect(
      find.text('Anda sedang offline. Menampilkan data tersimpan.'),
      findsOneWidget,
    );

    await addFromGallery(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Lanjut'));
    await tester.pumpAndSettle();

    expect(find.byType(TileLayer), findsNothing);
    await tapMap(tester);
    await tester.pump(const Duration(milliseconds: 600));

    expect(store.draft!.hasLocation, isTrue);
  });

  testWidgets('starts a new draft when the user declines the stored one', (
    tester,
  ) async {
    final store = _FakeStore()
      ..draft = ReportWizardDraft(
        photoPaths: photoPaths.take(2).toList(),
        currentStep: 1,
        updatedAt: DateTime.utc(2026, 10, 30, 9),
      );

    await pumpWizard(tester, store: store);
    await tester.tap(find.text('Mulai baru'));
    await tester.pumpAndSettle();

    expect(find.text('0/3 foto'), findsOneWidget);
    expect(store.draft, isNull);
  });

  testWidgets('shows the offline banner while still allowing photos', (
    tester,
  ) async {
    OfflineController.instance.setOffline(true);
    addTearDown(() => OfflineController.instance.setOffline(false));

    await pumpWizard(tester, store: _FakeStore());

    expect(
      find.text('Anda sedang offline. Menampilkan data tersimpan.'),
      findsOneWidget,
    );
    expect(find.byKey(_addPhotoKey), findsOneWidget);
  });

  testWidgets('shows a clear message when camera permission is denied', (
    tester,
  ) async {
    final picker = _FakePicker(
      failure: ReportPhotoFailure.cameraPermissionDenied,
    );
    await pumpWizard(tester, store: _FakeStore(), picker: picker);

    await tester.tap(find.byKey(_addPhotoKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kamera'));
    await tester.pumpAndSettle();

    expect(find.text('Izin diperlukan'), findsOneWidget);
    expect(find.textContaining('Pengaturan'), findsWidgets);

    await tester.tap(find.text('Mengerti'));
    await tester.pumpAndSettle();

    expect(find.text('Izin diperlukan'), findsNothing);
    expect(find.text('0/3 foto'), findsOneWidget);
  });

  testWidgets('autosaves the draft after the debounce', (tester) async {
    final store = _FakeStore();
    final picker = _FakePicker(paths: photoPaths.take(1).toList());
    await pumpWizard(tester, store: store, picker: picker);

    await addFromGallery(tester);
    await tester.pump(const Duration(milliseconds: 600));

    expect(store.draft, isNotNull);
    expect(store.draft!.photoPaths, photoPaths.take(1).toList());
  });

  testWidgets('asks before leaving step 1 with a filled draft', (tester) async {
    final store = _FakeStore();
    final picker = _FakePicker(paths: photoPaths.take(1).toList());
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('Beranda')),
        ),
        GoRoute(
          path: '/report',
          builder: (context, state) =>
              ReportWizardPage(store: store, photoPicker: picker),
        ),
      ],
    );
    addTearDown(router.dispose);

    phoneSurface(tester);
    await tester.pumpWidget(wrapRouter(router));
    await tester.pumpAndSettle();
    // `push` completes when the route is popped, so it must not be awaited.
    unawaited(router.push('/report'));
    await tester.pumpAndSettle();

    await addFromGallery(tester);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('Simpan draf dan keluar?'), findsOneWidget);

    await tester.tap(find.text('Keluar'));
    await tester.pumpAndSettle();

    expect(find.text('Beranda'), findsOneWidget);
    expect(store.draft?.photoPaths, photoPaths.take(1).toList());
  });

  testWidgets('stays in the wizard when the exit confirmation is cancelled', (
    tester,
  ) async {
    final picker = _FakePicker(paths: photoPaths.take(1).toList());
    await pumpWizard(tester, store: _FakeStore(), picker: picker);

    await addFromGallery(tester);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    expect(find.text('1/3 foto'), findsOneWidget);
    expect(find.text('Simpan draf dan keluar?'), findsNothing);
  });
}
