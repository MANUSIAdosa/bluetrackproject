import 'dart:convert';
import 'dart:io';

import 'package:blue_track/features/project/domain/location.dart';
import 'package:blue_track/features/project/domain/report.dart';
import 'package:blue_track/features/project/domain/review.dart';
import 'package:flutter_test/flutter_test.dart';

List<Map<String, dynamic>> _readList(String path) =>
    (jsonDecode(File(path).readAsStringSync()) as List<dynamic>)
        .cast<Map<String, dynamic>>();

void main() {
  final locations = _readList('assets/mock/locations.json')
      .map(ProjectLocation.fromJson)
      .toList();
  final reports = _readList('assets/mock/report.json')
      .map(Report.fromJson)
      .toList();
  final reviews = _readList('assets/mock/review.json')
      .map(Review.fromJson)
      .toList();

  group('mock reporting data', () {
    test('all three JSON files parse into domain models', () {
      expect(locations, isNotEmpty);
      expect(reports, isNotEmpty);
      expect(reviews, isNotEmpty);

      for (final location in locations) {
        expect(location.id, isNotEmpty);
        expect(location.projectId, isNotEmpty);
        expect(location.name, isNotEmpty);
        expect(location.region, isNotEmpty);
        expect(location.latitude, inInclusiveRange(-90, 90));
        expect(location.longitude, inInclusiveRange(-180, 180));
      }
      for (final report in reports) {
        expect(report.id, isNotEmpty);
        expect(report.title, isNotEmpty);
        expect(report.description, isNotEmpty);
        expect(report.reporterId, isNotEmpty);
        expect(report.reporterName, isNotEmpty);
        expect(report.photoPaths, isNotEmpty);
        expect(report.latitude, inInclusiveRange(-90, 90));
        expect(report.longitude, inInclusiveRange(-180, 180));
      }
      for (final review in reviews) {
        expect(review.id, isNotEmpty);
        expect(review.comment, isNotEmpty);
        expect(review.rating, inInclusiveRange(1, 5));
        expect(review.authorName, isNotEmpty);
      }
    });

    test('ids are unique and every reference points at a known location', () {
      expect(reports.map((r) => r.id).toSet(), hasLength(reports.length));
      expect(reviews.map((r) => r.id).toSet(), hasLength(reviews.length));
      expect(locations.map((l) => l.id).toSet(), hasLength(locations.length));

      final locationIds = locations.map((l) => l.id).toSet();
      for (final report in reports) {
        expect(locationIds, contains(report.locationId), reason: report.id);
      }
      for (final review in reviews) {
        expect(locationIds, contains(review.locationId), reason: review.id);
      }
    });

    test('location ids are the same ids P04 uses for its projects', () {
      final projectIds = _readList('assets/mock/projects.json')
          .map((json) => json['id'] as String)
          .toSet();

      for (final location in locations) {
        expect(location.id, location.projectId);
        expect(projectIds, contains(location.id));
      }
    });

    test('report photos exist on disk', () {
      for (final report in reports) {
        expect(report.photoPaths, isNotEmpty, reason: report.id);
        for (final path in report.photoPaths) {
          expect(
            File(path).existsSync(),
            isTrue,
            reason: '$path (${report.id})',
          );
        }
      }
    });

    test('all categories, severities and statuses are represented', () {
      expect(
        reports.map((r) => r.category).toSet(),
        ReportCategory.values.toSet(),
      );
      expect(
        reports.map((r) => r.severity).toSet(),
        ReportSeverity.values.toSet(),
      );
      expect(reports.map((r) => r.status).toSet(), ReportStatus.values.toSet());
    });

    test('reports cover at least 24 records and six consecutive months', () {
      expect(reports.length, greaterThanOrEqualTo(24));

      final months =
          reports
              .map(
                (report) =>
                    report.reportedAt.year * 12 + report.reportedAt.month,
              )
              .toSet()
              .toList()
            ..sort();
      expect(months.length, greaterThanOrEqualTo(6));
      for (var i = 1; i < months.length; i++) {
        expect(
          months[i] - months[i - 1],
          1,
          reason: 'months must be consecutive',
        );
      }
    });

    test('at least four locations have five reports and one has none', () {
      final counts = <String, int>{
        for (final location in locations)
          location.id: reports.where((r) => r.locationId == location.id).length,
      };
      final withReports = counts.entries
          .where((entry) => entry.value > 0)
          .toList();

      expect(withReports.length, greaterThanOrEqualTo(4));
      for (final entry in withReports) {
        expect(entry.value, greaterThanOrEqualTo(5), reason: entry.key);
      }
      expect(
        counts.values.where((count) => count == 0).length,
        1,
        reason: 'exactly one location must have no reports',
      );
    });

    test('category-specific metrics and verifier notes are valid', () {
      for (final report in reports) {
        if (report.category.requiresWasteKg) {
          expect(report.wasteKg, isNotNull, reason: report.id);
          expect(report.wasteKg, greaterThan(0), reason: report.id);
        }
        if (report.category.requiresAreaM2) {
          expect(report.areaM2, isNotNull, reason: report.id);
          expect(report.areaM2, greaterThan(0), reason: report.id);
        }
        if (report.status == ReportStatus.submitted) {
          expect(report.hasPassedVerification, isFalse);
          expect(report.verifierNote, isNull, reason: report.id);
        } else {
          expect(report.hasPassedVerification, isTrue);
          expect(report.verifierNote, isNotNull, reason: report.id);
          expect(report.verifierNote, isNotEmpty, reason: report.id);
        }
      }
    });

    test('reporter and reviewer names expose no email or phone number', () {
      final contactPattern = RegExp(r'[@+]|0[0-9]{8,}|62[0-9]{8,}');
      for (final report in reports) {
        expect(contactPattern.hasMatch(report.reporterName), isFalse);
      }
      for (final review in reviews) {
        expect(contactPattern.hasMatch(review.authorName), isFalse);
      }
    });

    test('reviews cover five locations, one location has none', () {
      final counts = <String, int>{
        for (final location in locations)
          location.id: reviews.where((r) => r.locationId == location.id).length,
      };
      final withReviews = counts.entries
          .where((entry) => entry.value >= 5)
          .toList();

      expect(withReviews.length, greaterThanOrEqualTo(3));
      expect(
        counts.values.where((count) => count == 0).length,
        1,
        reason: 'exactly one location must have no reviews',
      );
      expect(
        reviews.map((r) => r.rating).toSet(),
        containsAll([1, 2, 3, 4, 5]),
      );
    });
  });
}
