import 'package:blue_track/features/project/domain/report.dart';
import 'package:blue_track/features/my_reports/data/my_reports_store.dart';
import 'package:blue_track/features/report_submit/data/report_submission_service.dart';
import 'package:blue_track/features/report_submit/domain/report_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'mock submission preserves user description and location detail',
    () async {
      final store = MyReportsStore();
      final service = MockReportSubmissionService(
        delay: Duration.zero,
        store: store,
      );

      final report = await service.submit(
        const ReportWizardDraft(
          photoPaths: ['/tmp/finding.jpg'],
          latitude: -8.5236,
          longitude: 114.6131,
          category: ReportCategory.affectedWildlife,
          severity: ReportSeverity.high,
          title: 'Turtle entangled in netting',
          description: 'A turtle is entangled in plastic netting.',
          locationDetail: 'About 2 nautical miles north of the island.',
        ),
      );

      expect(report.title, 'Turtle entangled in netting');
      expect(report.description, 'A turtle is entangled in plastic netting.');
      expect(
        report.locationDetail,
        'About 2 nautical miles north of the island.',
      );
      expect(store.byId(report.id), same(report));
    },
  );

  test('report JSON keeps optional location detail backwards compatible', () {
    final report = Report(
      id: 'RPT-0001',
      locationId: 'p01',
      reporterId: 'u01',
      reporterName: 'Ayu Lestari',
      category: ReportCategory.affectedWildlife,
      severity: ReportSeverity.high,
      status: ReportStatus.submitted,
      reportedAt: DateTime.utc(2026, 11, 6),
      title: 'Turtle entangled in netting',
      description: 'A turtle is entangled in plastic netting.',
      locationDetail: 'About 2 nautical miles north of the island.',
      latitude: -8.5236,
      longitude: 114.6131,
      photoPaths: ['/tmp/finding.jpg'],
      verifierNote: null,
      wasteKg: null,
      areaM2: null,
    );

    final encoded = report.toJson();
    final restored = Report.fromJson(encoded);
    final legacyJson = Map<String, dynamic>.from(encoded)
      ..remove('locationDetail');
    final legacyRestored = Report.fromJson(legacyJson);

    expect(
      restored.locationDetail,
      'About 2 nautical miles north of the island.',
    );
    expect(legacyRestored.locationDetail, isNull);
  });
}
