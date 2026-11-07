import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:blue_track/core/state/app_state.dart';
import 'package:blue_track/core/theme/app_colors.dart';
import 'package:blue_track/features/project/domain/report.dart';
import 'package:blue_track/features/report_submit/data/geocoding_service.dart';
import 'package:blue_track/features/report_submit/data/report_draft_store.dart';
import 'package:blue_track/features/report_submit/data/report_photo_picker.dart';
import 'package:blue_track/features/report_submit/domain/geocoding.dart';
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

class _FakeGeocoding implements GeocodingService {
  GeocodingSearchResult searchResult = const GeocodingSearchResult.failed(
    GeocodingFailure.empty,
  );

  @override
  Future<GeocodingSearchResult> search(
    String query, {
    String languageCode = 'id',
  }) async => searchResult;

  @override
  Future<GeocodingPlaceResult> reverse({
    required double latitude,
    required double longitude,
    String languageCode = 'id',
  }) async => const GeocodingPlaceResult.failed(GeocodingFailure.empty);
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
    GeocodingService? geocoding,
  }) async {
    phoneSurface(tester);
    await tester.pumpWidget(
      wrapPage(
        ReportWizardPage(
          store: store,
          photoPicker: picker ?? _FakePicker(),
          locationService: location ?? locationService,
          geocodingService: geocoding ?? _FakeGeocoding(),
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

  /// Fills the required title and description of step 1.
  Future<void> enterDescription(
    WidgetTester tester, [
    String description = 'Seekor satwa laut terlilit sampah.',
  ]) async {
    final title = find.byKey(const ValueKey('report_title_field'));
    await tester.ensureVisible(title);
    await tester.enterText(title, 'Satwa laut terlilit sampah');
    await tester.pumpAndSettle();

    final field = find.byKey(const ValueKey('report_description_field'));
    await tester.ensureVisible(field);
    await tester.enterText(field, description);
    await tester.pumpAndSettle();
  }

  Future<void> tapMap(WidgetTester tester) async {
    // The step scrolls; a previous ensureVisible may have moved the map out of
    // the viewport, so bring it back before tapping like a person would.
    await tester.ensureVisible(find.byType(FlutterMap));
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(find.byType(FlutterMap)));
    // flutter_map delays single taps by 250 ms to tell them apart from double
    // taps; pump past that before settling.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
  }

  testWidgets('starts on step 1 with required photo and description', (
    tester,
  ) async {
    await pumpWizard(tester, store: _FakeStore());

    expect(find.text('Lapor Temuan'), findsOneWidget);
    expect(find.text('0/3 foto'), findsOneWidget);
    expect(find.text('Deskripsi temuan'), findsOneWidget);
    expect(find.text('Foto'), findsOneWidget);
    expect(find.text('Lokasi'), findsOneWidget);
    expect(find.text('Jenis'), findsOneWidget);
    expect(find.text('Tinjau'), findsOneWidget);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Lanjut'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('step 1 requires a title before continuing', (tester) async {
    final store = _FakeStore();
    await pumpWizard(
      tester,
      store: store,
      picker: _FakePicker(paths: photoPaths.take(1).toList()),
    );

    await addFromGallery(tester);
    final titleField = find.byKey(const ValueKey('report_title_field'));
    expect(titleField, findsOneWidget);

    await tester.enterText(titleField, '   ');
    await tester.tap(find.widgetWithText(FilledButton, 'Lanjut'));
    await tester.pumpAndSettle();

    expect(find.text('Judul laporan wajib diisi.'), findsOneWidget);
    expect(find.text('Tandai lokasi temuan'), findsNothing);

    await tester.enterText(titleField, 'Penyu terjerat jaring');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Lanjut'));
    await tester.pumpAndSettle();

    // The description is still required after the title is filled.
    expect(find.text('Deskripsi temuan wajib diisi.'), findsOneWidget);
    expect(find.text('Tandai lokasi temuan'), findsNothing);
    await tester.pump(const Duration(milliseconds: 600));
    expect(store.draft!.title, 'Penyu terjerat jaring');
  });

  testWidgets('step 1 requires a description before continuing', (
    tester,
  ) async {
    final store = _FakeStore();
    await pumpWizard(
      tester,
      store: store,
      picker: _FakePicker(paths: photoPaths.take(1).toList()),
    );

    await addFromGallery(tester);
    final titleField = find.byKey(const ValueKey('report_title_field'));
    await tester.ensureVisible(titleField);
    await tester.enterText(titleField, 'Penyu terjerat jaring');

    final descriptionField = find.byKey(
      const ValueKey('report_description_field'),
    );
    expect(descriptionField, findsOneWidget);

    await tester.enterText(descriptionField, '   ');
    await tester.tap(find.widgetWithText(FilledButton, 'Lanjut'));
    await tester.pumpAndSettle();

    expect(find.text('Deskripsi temuan wajib diisi.'), findsOneWidget);
    expect(find.text('Tandai lokasi temuan'), findsNothing);

    await tester.enterText(
      descriptionField,
      'Seekor penyu terlilit jaring plastik.',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Lanjut'));
    await tester.pumpAndSettle();

    expect(find.text('Tandai lokasi temuan'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    expect(store.draft!.description, 'Seekor penyu terlilit jaring plastik.');
  });

  testWidgets('adds photos from the gallery and keeps them across steps', (
    tester,
  ) async {
    final picker = _FakePicker(paths: photoPaths.take(2).toList());
    final store = _FakeStore();
    await pumpWizard(tester, store: store, picker: picker);

    await addFromGallery(tester);
    await enterDescription(tester);

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
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('report_description_field')),
          )
          .initialValue,
      'Seekor satwa laut terlilit sampah.',
    );
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

    // Starting over discards the draft, so it is styled as destructive.
    final startNew = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Mulai baru'),
    );
    expect(startNew.style?.foregroundColor?.resolve({}), AppColors.danger);

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
    await enterDescription(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Lanjut'));
    await tester.pumpAndSettle();

    expect(find.text('Tandai lokasi temuan'), findsOneWidget);
    expect(find.text('Lokasi saya'), findsOneWidget);
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
    expect(find.text('Jenis temuan'), findsOneWidget);
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
    await enterDescription(tester);
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
    await enterDescription(tester);
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
    await enterDescription(tester);
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
      find.text('Mode offline - menampilkan data tersimpan'),
      findsOneWidget,
    );

    await addFromGallery(tester);
    await enterDescription(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Lanjut'));
    await tester.pumpAndSettle();

    expect(find.byType(TileLayer), findsNothing);
    await tapMap(tester);
    await tester.pump(const Duration(milliseconds: 600));

    expect(store.draft!.hasLocation, isTrue);
  });

  testWidgets('a chosen address moves the pin and fills the draft', (
    tester,
  ) async {
    final store = _FakeStore()
      ..draft = ReportWizardDraft(
        photoPaths: photoPaths.take(1).toList(),
        title: 'Temuan di pesisir',
        description: 'Temuan di pesisir.',
        currentStep: ReportWizardDraft.locationStep,
        updatedAt: DateTime.utc(2026, 10, 30, 9),
      );
    final geocoding = _FakeGeocoding()
      ..searchResult = const GeocodingSearchResult.success([
        GeocodingPlace(
          displayName: 'Taman Nasional Meru Betiri',
          latitude: -8.6,
          longitude: 113.9,
        ),
      ]);

    await pumpWizard(tester, store: store, geocoding: geocoding);
    await tester.tap(find.text('Lanjutkan draf'));
    await tester.pumpAndSettle();

    final openSearch = find.byKey(const ValueKey('report_address_search'));
    await tester.ensureVisible(openSearch);
    await tester.pumpAndSettle();
    await tester.tap(openSearch);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('report_address_field')),
      'Meru Betiri',
    );
    await tester.tap(find.byKey(const ValueKey('report_address_sheet_search')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('report_address_result_0')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 600));

    expect(store.draft!.latitude, closeTo(-8.6, 0.0001));
    expect(store.draft!.longitude, closeTo(113.9, 0.0001));
    expect(store.draft!.areaName, 'Taman Nasional Meru Betiri');
    expect(store.draft!.locationDetail, isEmpty);
  });

  ReportWizardDraft typeStepDraft({
    ReportCategory? category,
    ReportSeverity? severity,
  }) {
    return ReportWizardDraft(
      photoPaths: photoPaths.take(1).toList(),
      latitude: -8.52,
      longitude: 114.61,
      category: category,
      severity: severity,
      title: 'Temuan di pesisir',
      description: 'Temuan terlihat jelas pada foto.',
      currentStep: ReportWizardDraft.typeStep,
      updatedAt: DateTime.utc(2026, 10, 30, 9),
    );
  }

  Future<void> openTypeStep(WidgetTester tester, _FakeStore store) async {
    await pumpWizard(tester, store: store);
    await tester.tap(find.text('Lanjutkan draf'));
    await tester.pumpAndSettle();
  }

  testWidgets('step 3 shows both sections and validates an empty continue', (
    tester,
  ) async {
    final store = _FakeStore()..draft = typeStepDraft();
    await openTypeStep(tester, store);

    expect(find.text('Jenis temuan'), findsOneWidget);
    expect(find.text('Sampah'), findsOneWidget);
    expect(find.text('Terumbu rusak'), findsOneWidget);
    expect(find.text('Mangrove'), findsOneWidget);
    expect(find.text('Tangkapan merusak'), findsOneWidget);
    expect(find.text('Satwa terdampak'), findsOneWidget);
    expect(find.text('Tingkat'), findsOneWidget);
    expect(find.text('Ringan'), findsOneWidget);
    expect(find.text('Sedang'), findsOneWidget);
    expect(find.text('Berat'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Lanjut'))
          .onPressed,
      isNull,
    );

    // Tapping the disabled CTA still explains what is missing.
    await tester.tap(find.widgetWithText(FilledButton, 'Lanjut'));
    await tester.pumpAndSettle();

    expect(find.text('Pilih jenis temuan terlebih dahulu.'), findsOneWidget);
    expect(find.text('Pilih tingkat temuan terlebih dahulu.'), findsOneWidget);
  });

  testWidgets('choosing a type and severity saves them and enables continue', (
    tester,
  ) async {
    final store = _FakeStore()..draft = typeStepDraft();
    await openTypeStep(tester, store);

    final reef = find.byKey(
      const ValueKey('report_type_category_terumbu_rusak'),
    );
    await tester.ensureVisible(reef);
    await tester.tap(reef);
    await tester.pumpAndSettle();

    // The type is remembered, but continue stays disabled until a severity
    // is picked; attempting it flags only the missing section.
    await tester.tap(find.widgetWithText(FilledButton, 'Lanjut'));
    await tester.pumpAndSettle();
    expect(find.text('Pilih jenis temuan terlebih dahulu.'), findsNothing);
    expect(find.text('Pilih tingkat temuan terlebih dahulu.'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Lanjut'))
          .onPressed,
      isNull,
    );

    final severe = find.byKey(const ValueKey('report_type_severity_berat'));
    await tester.ensureVisible(severe);
    await tester.tap(severe);
    await tester.pumpAndSettle();

    expect(find.text('Pilih tingkat temuan terlebih dahulu.'), findsNothing);
    expect(
      find.text('Kerusakan parah dan mendesak ditangani.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Lanjut'))
          .onPressed,
      isNotNull,
    );

    await tester.pump(const Duration(milliseconds: 600));
    expect(store.draft!.category, ReportCategory.damagedReef);
    expect(store.draft!.severity, ReportSeverity.high);

    await tester.tap(find.widgetWithText(FilledButton, 'Lanjut'));
    await tester.pumpAndSettle();
    expect(find.text('Tinjau laporan'), findsOneWidget);
  });

  testWidgets('restores and updates the saved type and severity', (
    tester,
  ) async {
    final store = _FakeStore()
      ..draft = typeStepDraft(
        category: ReportCategory.marineDebris,
        severity: ReportSeverity.low,
      );
    await openTypeStep(tester, store);

    expect(
      find.text('Kerusakan kecil dan masih bisa pulih sendiri.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.check_circle), findsNWidgets(2));

    final mangrove = find.byKey(
      const ValueKey('report_type_category_mangrove_gundul'),
    );
    await tester.ensureVisible(mangrove);
    await tester.tap(mangrove);
    await tester.pump(const Duration(milliseconds: 600));

    expect(store.draft!.category, ReportCategory.deforestedMangrove);
    expect(store.draft!.severity, ReportSeverity.low);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await openTypeStep(tester, store);

    expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
    expect(
      find.text('Kerusakan kecil dan masih bisa pulih sendiri.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Lanjut'))
          .onPressed,
      isNotNull,
    );
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
      find.text('Mode offline - menampilkan data tersimpan'),
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

    // Dialog actions sit on one row: the global button theme asks for an
    // unbounded width, so the dialog overrides it with a finite minimum.
    final cancelCenter = tester.getCenter(
      find.widgetWithText(TextButton, 'Batal'),
    );
    final leaveCenter = tester.getCenter(
      find.widgetWithText(FilledButton, 'Keluar'),
    );
    expect((cancelCenter.dy - leaveCenter.dy).abs(), lessThan(1));
    expect(cancelCenter.dx, lessThan(leaveCenter.dx));

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
