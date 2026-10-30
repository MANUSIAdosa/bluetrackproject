import '../../project/domain/report.dart';

/// Whether a P05 profile is a formal organization or a local implementing
/// community (fisher group, nature lovers, youth group).
enum OrganizationType {
  organization('organization'),
  community('community');

  const OrganizationType(this.id);

  /// Value stored in `organizations.json`.
  final String id;

  /// Parses a type id; absent values stay [organization] for the two original
  /// entries, whose data must not change.
  static OrganizationType fromId(String? id) => values.firstWhere(
    (value) => value.id == id,
    orElse: () => OrganizationType.organization,
  );
}

/// Organization/community domain model (P05).
class Organization {
  const Organization({
    required this.id,
    required this.name,
    required this.verified,
    required this.location,
    required this.establishedYear,
    required this.totalProjects,
    required this.totalDisbursed,
    required this.communitiesServed,
    required this.color,
    required this.email,
    required this.phone,
    required this.checklist,
    this.type = OrganizationType.organization,
    this.memberCount = 0,
    this.managedProjectIds,
  });

  final String id;
  final String name;
  final bool verified;
  final String location;
  final int establishedYear;
  final int totalProjects;
  final int totalDisbursed;
  final int communitiesServed;

  /// Hex color used as avatar placeholder.
  final String color;
  final String email;
  final String phone;
  final List<ChecklistItem> checklist;

  /// Organization or implementing community.
  final OrganizationType type;

  /// Number of community members. Zero when the source has no member data,
  /// which is the case for the two original organization entries.
  final int memberCount;

  /// Locations this profile manages.
  ///
  /// `null` keeps the original behavior: locations are the projects whose
  /// `orgId` matches [id]. An empty list means the profile has no locations,
  /// while a non-empty list points at existing project ids (communities reuse
  /// the locations already available in `projects.json`).
  final List<String>? managedProjectIds;

  factory Organization.fromJson(Map<String, dynamic> json) => Organization(
    id: json['id'] as String,
    name: json['name'] as String,
    verified: json['verified'] as bool? ?? false,
    location: json['location'] as String,
    establishedYear: json['establishedYear'] as int,
    totalProjects: json['totalProjects'] as int,
    totalDisbursed: json['totalDisbursed'] as int,
    communitiesServed: json['communitiesServed'] as int,
    color: json['color'] as String,
    email: json['email'] as String,
    phone: json['phone'] as String,
    checklist: (json['checklist'] as List<dynamic>)
        .map((e) => ChecklistItem.fromJson(e as Map<String, dynamic>))
        .toList(),
    type: OrganizationType.fromId(json['type'] as String?),
    memberCount: json['memberCount'] as int? ?? 0,
    managedProjectIds: (json['managedProjectIds'] as List<dynamic>?)
        ?.cast<String>(),
  );
}

class ChecklistItem {
  const ChecklistItem({required this.key, required this.done});

  /// Checklist key: legal | audit | field | finance (localized in the UI).
  final String key;
  final bool done;

  factory ChecklistItem.fromJson(Map<String, dynamic> json) =>
      ChecklistItem(key: json['key'] as String, done: json['done'] as bool);
}

/// Numbers shown in the P05 summary card.
///
/// All report numbers are derived from verified reports, never from fixed
/// totals stored in `organizations.json`.
class OrganizationStats {
  const OrganizationStats({
    required this.locationCount,
    required this.verifiedReportCount,
    required this.totalWasteKg,
    required this.memberCount,
  });

  /// Builds the summary from the reports of every managed location.
  ///
  /// Reports that have not passed verification (`Terkirim`) are ignored even
  /// if the caller passes an unfiltered list.
  factory OrganizationStats.fromReports({
    required int locationCount,
    required Iterable<Report> reports,
    required int memberCount,
  }) {
    var verified = 0;
    var waste = 0.0;
    for (final report in reports) {
      if (!report.hasPassedVerification) continue;
      verified++;
      waste += report.wasteKg ?? 0;
    }
    return OrganizationStats(
      locationCount: locationCount,
      verifiedReportCount: verified,
      totalWasteKg: waste,
      memberCount: memberCount,
    );
  }

  /// Number of locations that could be resolved and are shown on the page.
  final int locationCount;

  /// Reports that passed verification across those locations.
  final int verifiedReportCount;

  /// Sum of [Report.wasteKg] from verified reports.
  final double totalWasteKg;

  /// Members of the community, from `organizations.json`.
  final int memberCount;
}
