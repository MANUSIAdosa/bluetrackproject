import 'package:blue_track/core/utils/formatters.dart';
import 'package:blue_track/features/explore/data/project_repository.dart';
import 'package:blue_track/features/organization/data/organization_repository.dart';
import 'package:blue_track/features/organization/domain/organization.dart';
import 'package:blue_track/features/organization/presentation/org_profile_page.dart';
import 'package:blue_track/features/project/data/report_repository.dart';
import 'package:blue_track/features/project/presentation/project_detail_page.dart';
import 'package:blue_track/shared/widgets/empty_state.dart';
import 'package:blue_track/shared/widgets/error_state.dart';
import 'package:blue_track/shared/widgets/project_card.dart';
import 'package:blue_track/shared/widgets/verified_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/organization_fixtures.dart';
import 'support/report_fixtures.dart';
import 'support/review_fixtures.dart';
import 'support/test_harness.dart';

void _setScreen(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpOrg(
  WidgetTester tester, {
  String orgId = 'c01',
  OrganizationRepository? organizationRepository,
  ProjectRepository? projectRepository,
  ReportRepository? reportRepository,
  Locale locale = const Locale('id'),
  Size size = const Size(500, 1400),
}) async {
  _setScreen(tester, size);
  await tester.pumpWidget(
    wrapPage(
      OrgProfilePage(
        orgId: orgId,
        organizationRepository:
            organizationRepository ?? InMemoryOrganizationRepository(),
        projectRepository:
            projectRepository ?? FakeProjectRepository(mockProjects()),
        reportRepository: reportRepository ?? InMemoryReportRepository(),
      ),
      locale: locale,
    ),
  );
  await tester.pumpAndSettle();
}

String _statValue(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P05 organization and community profile', () {
    test('organizations.json has two original organizations and three '
        'communities', () {
      final organizations = mockOrganizations();

      expect(organizations.length, greaterThanOrEqualTo(5));
      expect(
        organizations.map((organization) => organization.id),
        containsAll(['o01', 'o02']),
      );
      expect(mockOrganization('o01').type, OrganizationType.organization);
      expect(mockOrganization('o02').type, OrganizationType.organization);

      final communities = organizations
          .where(
            (organization) => organization.type == OrganizationType.community,
          )
          .toList();
      expect(communities, hasLength(3));
      expect(
        communities.where((organization) => organization.verified),
        hasLength(2),
      );
      expect(
        communities.where((organization) => !organization.verified),
        hasLength(1),
      );
      expect(
        communities.map((organization) => organization.name),
        containsAll([
          'Kelompok Nelayan Pantai Sukamade',
          'Komunitas Pecinta Alam Pesisir',
          'Karang Taruna Pesisir Makassar',
        ]),
      );
    });

    testWidgets('summary values match a manual count from the mock JSON', (
      tester,
    ) async {
      const orgId = 'c01';
      final organization = mockOrganization(orgId);
      final managedIds = organization.managedProjectIds!;
      final locations = mockProjects()
          .where((project) => managedIds.contains(project.id))
          .toList();
      final reports = mockReports()
          .where(
            (report) =>
                managedIds.contains(report.locationId) &&
                report.hasPassedVerification,
          )
          .toList();
      final expectedWaste = reports.fold<double>(
        0,
        (total, report) => total + (report.wasteKg ?? 0),
      );

      // Documented mock values, checked independently of the widget.
      expect(locations, hasLength(2));
      expect(reports, hasLength(11));
      expect(expectedWaste, closeTo(88.5, 0.0001));
      expect(organization.memberCount, 48);

      await _pumpOrg(tester, orgId: orgId);

      expect(
        _statValue(tester, 'org-stat-locations-value'),
        Formatters.number(locations.length, 'id'),
      );
      expect(
        _statValue(tester, 'org-stat-reports-value'),
        Formatters.number(reports.length, 'id'),
      );
      expect(
        _statValue(tester, 'org-stat-waste-value'),
        '${Formatters.number(expectedWaste, 'id')} kg',
      );
      expect(
        _statValue(tester, 'org-stat-members-value'),
        Formatters.number(organization.memberCount, 'id'),
      );
    });

    testWidgets('an organization without member data keeps its disbursed '
        'total and project fallback', (tester) async {
      const orgId = 'o01';
      final organization = mockOrganization(orgId);
      final locations = mockProjects()
          .where((project) => project.orgId == orgId)
          .toList();
      final reports = mockReports()
          .where(
            (report) =>
                locations.any((project) => project.id == report.locationId) &&
                report.hasPassedVerification,
          )
          .toList();
      final expectedWaste = reports.fold<double>(
        0,
        (total, report) => total + (report.wasteKg ?? 0),
      );

      await _pumpOrg(tester, orgId: orgId, size: const Size(500, 2600));

      expect(find.byType(ProjectCard), findsNWidgets(locations.length));
      expect(
        _statValue(tester, 'org-stat-locations-value'),
        '${locations.length}',
      );
      expect(_statValue(tester, 'org-stat-reports-value'), '${reports.length}');
      expect(
        _statValue(tester, 'org-stat-waste-value'),
        '${Formatters.number(expectedWaste, 'id')} kg',
      );
      expect(find.byKey(const ValueKey('org-stat-members')), findsNothing);
      expect(find.textContaining('485.000.000'), findsOneWidget);
      expect(organization.memberCount, 0);
    });

    testWidgets('shows the community type chip and a badge only for a '
        'verified profile', (tester) async {
      await _pumpOrg(tester, orgId: 'c01');

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('org-type-chip')),
          matching: find.text('Komunitas'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('org-header-verified-badge')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('org-pending-verification')),
        findsNothing,
      );
    });

    testWidgets('an unverified community shows the pending label instead of '
        'a badge', (tester) async {
      await _pumpOrg(tester, orgId: 'c03');

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('org-type-chip')),
          matching: find.text('Komunitas'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('org-header-verified-badge')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('org-pending-verification')),
        findsOneWidget,
      );
      expect(find.text('Menunggu verifikasi'), findsOneWidget);
      expect(find.byType(VerifiedBadge), findsNothing);
    });

    testWidgets('English copy localizes the profile, summary and locations', (
      tester,
    ) async {
      await _pumpOrg(
        tester,
        orgId: 'c01',
        locale: const Locale('en'),
        size: const Size(500, 2600),
      );

      expect(find.text('Community'), findsOneWidget);
      expect(find.text('Locations monitored'), findsOneWidget);
      expect(find.text('Verified reports'), findsOneWidget);
      expect(find.text('Waste collected'), findsOneWidget);
      expect(find.text('Members'), findsOneWidget);
      expect(find.text('Managed locations'), findsOneWidget);
      expect(find.text('Current condition'), findsWidgets);
      expect(find.text('88.5 kg'), findsOneWidget);
    });

    testWidgets('a community without managed locations shows EmptyState only '
        'in that section', (tester) async {
      await _pumpOrg(tester, orgId: 'c03');

      expect(find.byKey(const ValueKey('org-locations-empty')), findsOneWidget);
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('Belum ada lokasi yang dikelola.'), findsOneWidget);
      expect(find.text('Lokasi yang dikelola'), findsOneWidget);
      expect(find.byType(ProjectCard), findsNothing);
      // The rest of the profile is still rendered.
      expect(find.text('Checklist verifikasi'), findsOneWidget);
      expect(find.text('Hubungi'), findsOneWidget);
    });

    testWidgets('an unknown organization id shows ErrorState', (tester) async {
      await _pumpOrg(
        tester,
        orgId: 'missing',
        organizationRepository: InMemoryOrganizationRepository(
          <Organization>[],
        ),
      );

      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.text('Gagal memuat. Periksa koneksi Anda.'), findsOneWidget);
    });

    testWidgets('condition info sits outside the card and tapping a location '
        'opens P04 on its default tab', (tester) async {
      _setScreen(tester, const Size(500, 2000));

      final router = GoRouter(
        initialLocation: '/org/c01',
        routes: [
          GoRoute(
            path: '/org/:id',
            builder: (_, state) => OrgProfilePage(
              orgId: state.pathParameters['id']!,
              organizationRepository: InMemoryOrganizationRepository(),
              projectRepository: FakeProjectRepository(mockProjects()),
              reportRepository: InMemoryReportRepository(),
            ),
          ),
          GoRoute(
            path: '/project/:id',
            builder: (_, state) => ProjectDetailPage(
              projectId: state.pathParameters['id']!,
              projectRepository: FakeProjectRepository(mockProjects()),
              reportRepository: InMemoryReportRepository(),
              reviewRepository: InMemoryReviewRepository(),
            ),
          ),
        ],
      );

      await tester.pumpWidget(wrapRouter(router));
      await tester.pumpAndSettle();

      final condition = find.byKey(
        const ValueKey('org-location-condition-p01'),
      );
      expect(condition, findsOneWidget);
      expect(
        find.ancestor(of: condition, matching: find.byType(ProjectCard)),
        findsNothing,
      );
      expect(find.text('Kritis'), findsOneWidget);
      expect(find.text('Perlu pemantauan'), findsOneWidget);

      final p01 = mockProjects().firstWhere((project) => project.id == 'p01');
      final p05 = mockProjects().firstWhere((project) => project.id == 'p05');
      final scrollable = find.byType(Scrollable).first;

      await tester.scrollUntilVisible(
        find.text(p01.title),
        300,
        scrollable: scrollable,
      );
      await tester.tap(find.text(p01.title));
      await tester.pumpAndSettle();

      expect(find.byType(ProjectDetailPage), findsOneWidget);
      expect(find.text(p01.description), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.byType(OrgProfilePage), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text(p05.title),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text(p05.title));
      await tester.pumpAndSettle();

      // Reopening from P05 does not carry a changed tab into P04.
      expect(find.byType(ProjectDetailPage), findsOneWidget);
      expect(find.text(p05.description), findsOneWidget);
    });

    testWidgets('an unavailable managed location is disabled and recorded', (
      tester,
    ) async {
      final messages = <String>[];
      final originalDebugPrint = debugPrint;
      try {
        debugPrint = (message, {wrapWidth}) {
          if (message != null) messages.add(message);
        };

        final json = mockOrganizationJson('c01');
        json['managedProjectIds'] = ['p01', 'missing-location'];
        final organization = Organization.fromJson(json);

        await _pumpOrg(
          tester,
          orgId: 'c01',
          organizationRepository: InMemoryOrganizationRepository([
            organization,
          ]),
          size: const Size(500, 2200),
        );

        final tileCard = find.byKey(
          const ValueKey('org-location-unavailable-missing-location'),
        );
        expect(tileCard, findsOneWidget);

        final tile = tester.widget<ListTile>(
          find.descendant(of: tileCard, matching: find.byType(ListTile)),
        );
        expect(tile.enabled, isFalse);
        expect(tile.onTap, isNull);
        expect(messages.join('\n'), contains('missing-location'));
        expect(find.byType(ProjectCard), findsOneWidget);
      } finally {
        debugPrint = originalDebugPrint;
      }
    });

    testWidgets('lays out without overflow at 320dp', (tester) async {
      await _pumpOrg(tester, orgId: 'c01', size: const Size(320, 1200));
      expect(tester.takeException(), isNull);

      final scrollable = find.byType(Scrollable).first;
      await tester.drag(scrollable, const Offset(0, -700));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.drag(scrollable, const Offset(0, -700));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
