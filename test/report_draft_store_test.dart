import 'dart:io';

import 'package:blue_track/features/project/domain/report.dart';
import 'package:blue_track/features/report_submit/data/report_draft_store.dart';
import 'package:blue_track/features/report_submit/domain/report_draft.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('bluetrack_report_draft_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  test('saves, loads and clears the active draft', () async {
    final store = HiveReportDraftStore();
    final updatedAt = DateTime.utc(2026, 10, 30, 12);
    final draft = ReportWizardDraft(
      photoPaths: const ['/tmp/a.jpg', '/tmp/b.jpg'],
      latitude: -8.52,
      longitude: 114.61,
      category: ReportCategory.damagedReef,
      severity: ReportSeverity.high,
      currentStep: 2,
      updatedAt: updatedAt,
    );

    await store.save(draft);
    final loaded = await store.load();

    expect(loaded, isNotNull);
    expect(loaded!.photoPaths, draft.photoPaths);
    expect(loaded.latitude, closeTo(-8.52, 0.0001));
    expect(loaded.longitude, closeTo(114.61, 0.0001));
    expect(loaded.category, ReportCategory.damagedReef);
    expect(loaded.severity, ReportSeverity.high);
    expect(loaded.currentStep, 2);
    expect(loaded.updatedAt, updatedAt);

    await store.clear();
    expect(await store.load(), isNull);
  });

  test('returns null when no draft has been saved', () async {
    final store = HiveReportDraftStore();

    expect(await store.load(), isNull);
  });

  test('survives a store restart with the box reopened from disk', () async {
    final draft = ReportWizardDraft(
      photoPaths: const ['/tmp/a.jpg'],
      currentStep: 2,
      updatedAt: DateTime.utc(2026, 10, 30, 12),
    );
    await HiveReportDraftStore().save(draft);

    await Hive.close();
    await Hive.openBox<dynamic>(HiveReportDraftStore.boxName);

    final loaded = await HiveReportDraftStore().load();
    expect(loaded, isNotNull);
    expect(loaded!.photoPaths, ['/tmp/a.jpg']);
    expect(loaded.currentStep, 2);
  });

  test('ignores a malformed stored draft instead of throwing', () async {
    final store = HiveReportDraftStore();
    final box = await Hive.openBox<dynamic>(HiveReportDraftStore.boxName);
    await box.put(HiveReportDraftStore.activeKey, '{not json');

    expect(await store.load(), isNull);
  });

  test('ignores unknown category and severity ids', () async {
    final store = HiveReportDraftStore();
    final box = await Hive.openBox<dynamic>(HiveReportDraftStore.boxName);
    await box.put(
      HiveReportDraftStore.activeKey,
      '{"photoPaths":["/tmp/a.jpg"],"category":"tidak_dikenal",'
      '"severity":"parah","currentStep":1}',
    );

    final loaded = await store.load();

    expect(loaded, isNotNull);
    expect(loaded!.category, isNull);
    expect(loaded.severity, isNull);
    expect(loaded.photoPaths, ['/tmp/a.jpg']);
  });

  test('clamps the restored step into the four wizard steps', () async {
    final store = HiveReportDraftStore();
    final box = await Hive.openBox<dynamic>(HiveReportDraftStore.boxName);
    await box.put(
      HiveReportDraftStore.activeKey,
      '{"photoPaths":["/tmp/a.jpg"],"currentStep":9}',
    );

    final loaded = await store.load();

    expect(loaded!.currentStep, ReportWizardDraft.lastStep);
  });

  test('does not restore an empty draft as a resumable draft', () async {
    final store = HiveReportDraftStore();
    await store.save(const ReportWizardDraft());

    expect(await store.load(), isNull);
  });
}
