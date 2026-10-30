/// Citizen report (laporan) domain model for P04 and the future P07/P10 pages.
///
/// Reports describe a field observation at one [ProjectLocation]. The mock
/// source lives in `assets/mock/report.json`.
class Report {
  const Report({
    required this.id,
    required this.locationId,
    required this.reporterId,
    required this.reporterName,
    required this.category,
    required this.severity,
    required this.status,
    required this.reportedAt,
    required this.title,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.photoPaths,
    required this.verifierNote,
    required this.wasteKg,
    required this.areaM2,
  });

  /// Unique report id, for example `r001`.
  final String id;

  /// Id of the `ProjectLocation` this report belongs to.
  final String locationId;

  /// Opaque reporter id. No email address or phone number is stored.
  final String reporterId;

  /// Public display name shown in the UI, for example `Ayu Lestari`.
  final String reporterName;
  final ReportCategory category;
  final ReportSeverity severity;
  final ReportStatus status;

  /// Observation time in UTC. Serialized as ISO 8601 in the mock JSON.
  final DateTime reportedAt;
  final String title;
  final String description;
  final double latitude;
  final double longitude;

  /// Local asset paths proving the observation. At least one is required.
  final List<String> photoPaths;

  /// Note from the verifier. Null while the report is still [ReportStatus.submitted].
  final String? verifierNote;

  /// Estimated marine debris in kilograms, required for
  /// [ReportCategory.marineDebris].
  final double? wasteKg;

  /// Affected area in square metres, required for
  /// [ReportCategory.damagedReef] and [ReportCategory.deforestedMangrove].
  final double? areaM2;

  /// Whether the report has at least one photo.
  bool get hasPhoto => photoPaths.isNotEmpty;

  /// Whether the status has passed verification. `Terkirim` has not.
  bool get hasPassedVerification => status.hasPassedVerification;

  /// Severity score used by the monthly condition trend (1–3).
  int get severityScore => severity.score;

  /// Parses one report object from `assets/mock/report.json`.
  ///
  /// Throws a [FormatException] when a required key is missing, has the wrong
  /// type, or contains an unknown enum id.
  factory Report.fromJson(Map<String, dynamic> json) => Report(
    id: json['id'] as String,
    locationId: json['locationId'] as String,
    reporterId: json['reporterId'] as String,
    reporterName: json['reporterName'] as String,
    category: ReportCategory.fromId(json['category'] as String),
    severity: ReportSeverity.fromId(json['severity'] as String),
    status: ReportStatus.fromId(json['status'] as String),
    reportedAt: DateTime.parse(json['reportedAt'] as String).toUtc(),
    title: json['title'] as String,
    description: json['description'] as String,
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    photoPaths: (json['photos'] as List<dynamic>).cast<String>(),
    verifierNote: json['verifierNote'] as String?,
    wasteKg: (json['wasteKg'] as num?)?.toDouble(),
    areaM2: (json['areaM2'] as num?)?.toDouble(),
  );

  /// Serializes this report back to the mock JSON shape.
  Map<String, dynamic> toJson() => {
    'id': id,
    'locationId': locationId,
    'reporterId': reporterId,
    'reporterName': reporterName,
    'category': category.id,
    'severity': severity.id,
    'status': status.id,
    'reportedAt': reportedAt.toUtc().toIso8601String(),
    'title': title,
    'description': description,
    'latitude': latitude,
    'longitude': longitude,
    'photos': photoPaths,
    'verifierNote': verifierNote,
    'wasteKg': wasteKg,
    'areaM2': areaM2,
  };
}

/// Input for `ReportRepository.submitReport`.
///
/// The repository owns the id, timestamp and initial [ReportStatus.submitted]
/// status, so a draft cannot accidentally mark itself verified.
class ReportDraft {
  const ReportDraft({
    required this.locationId,
    required this.reporterId,
    required this.reporterName,
    required this.category,
    required this.severity,
    required this.title,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.photoPaths,
    this.wasteKg,
    this.areaM2,
  });

  /// Existing location id, for example `p01`.
  final String locationId;
  final String reporterId;
  final String reporterName;
  final ReportCategory category;
  final ReportSeverity severity;
  final String title;
  final String description;
  final double latitude;
  final double longitude;

  /// At least one local asset path is required.
  final List<String> photoPaths;
  final double? wasteKg;
  final double? areaM2;
}

/// Report category ids exactly as stored in `report.json`.
enum ReportCategory {
  /// Marine debris / sampah laut. Requires [Report.wasteKg].
  marineDebris('sampah_laut'),

  /// Damaged coral reef / terumbu rusak. Requires [Report.areaM2].
  damagedReef('terumbu_rusak'),

  /// Bare / cleared mangrove / mangrove gundul. Requires [Report.areaM2].
  deforestedMangrove('mangrove_gundul'),

  /// Destructive fishing / tangkapan merusak.
  destructiveFishing('tangkapan_merusak'),

  /// Affected wildlife / satwa terdampak.
  affectedWildlife('satwa_terdampak');

  const ReportCategory(this.id);

  /// Value stored in JSON and exposed to the UI.
  final String id;

  /// Whether a report in this category must carry [Report.wasteKg].
  bool get requiresWasteKg => this == ReportCategory.marineDebris;

  /// Whether a report in this category must carry [Report.areaM2].
  bool get requiresAreaM2 =>
      this == ReportCategory.damagedReef ||
      this == ReportCategory.deforestedMangrove;

  /// Parses a category id. Throws a [FormatException] for unknown ids.
  static ReportCategory fromId(String id) => values.firstWhere(
    (value) => value.id == id,
    orElse: () => throw FormatException('Unknown report category: $id'),
  );
}

/// Severity level and its trend score.
enum ReportSeverity {
  /// Ringan — score 1.
  low('ringan', 1),

  /// Sedang — score 2.
  medium('sedang', 2),

  /// Berat — score 3.
  high('berat', 3);

  const ReportSeverity(this.id, this.score);

  /// Value stored in JSON.
  final String id;

  /// Score used by the monthly condition trend: 1, 2 or 3.
  final int score;

  /// Parses a severity id. Throws a [FormatException] for unknown ids.
  static ReportSeverity fromId(String id) => values.firstWhere(
    (value) => value.id == id,
    orElse: () => throw FormatException('Unknown report severity: $id'),
  );
}

/// Workflow status of a report.
enum ReportStatus {
  /// Terkirim — submitted, not verified yet.
  submitted('terkirim'),

  /// Diverifikasi — verified by an organization.
  verified('diverifikasi'),

  /// Ditindaklanjuti — action is in progress.
  followedUp('ditindaklanjuti'),

  /// Selesai — action completed.
  completed('selesai');

  const ReportStatus(this.id);

  /// Value stored in JSON.
  final String id;

  /// `Terkirim` is the only status that has not passed verification.
  bool get hasPassedVerification => this != ReportStatus.submitted;

  /// Parses a status id. Throws a [FormatException] for unknown ids.
  static ReportStatus fromId(String id) => values.firstWhere(
    (value) => value.id == id,
    orElse: () => throw FormatException('Unknown report status: $id'),
  );
}

/// Time window used by the report queries.
///
/// Windows are calendar months ending with the mock reference month, so the
/// results stay stable even when the device clock differs from the mock data.
enum ReportPeriod {
  /// The reference month only.
  oneMonth,

  /// The reference month and the two months before it.
  threeMonths,

  /// The reference month and the five months before it.
  sixMonths,

  /// No lower bound.
  all;

  /// First day (UTC) of this window for [referenceDate], or null for [all].
  ///
  /// For example, with a reference date of 24 October 2026,
  /// [threeMonths] starts on 1 August 2026.
  DateTime? startFrom(DateTime referenceDate) {
    final reference = referenceDate.toUtc();
    return switch (this) {
      ReportPeriod.oneMonth => DateTime.utc(reference.year, reference.month),
      ReportPeriod.threeMonths => DateTime.utc(
        reference.year,
        reference.month - 2,
      ),
      ReportPeriod.sixMonths => DateTime.utc(
        reference.year,
        reference.month - 5,
      ),
      ReportPeriod.all => null,
    };
  }

  /// Whether [date] falls inside this window around [referenceDate].
  ///
  /// The upper bound is exclusive and points at the first day of the month
  /// after the reference month. [all] accepts every date.
  bool contains(DateTime date, DateTime referenceDate) {
    final start = startFrom(referenceDate);
    if (start == null) return true;
    final reference = referenceDate.toUtc();
    final end = DateTime.utc(reference.year, reference.month + 1);
    final utcDate = date.toUtc();
    return !utcDate.isBefore(start) && utcDate.isBefore(end);
  }
}

/// Aggregate metrics for one location.
class ReportSummary {
  const ReportSummary({
    required this.totalWasteKg,
    required this.totalAreaM2,
    required this.verifiedReportCount,
    required this.totalReportCount,
  });

  /// Sum of [Report.wasteKg] for every report that carries a value.
  final double totalWasteKg;

  /// Sum of [Report.areaM2] for every report that carries a value.
  final double totalAreaM2;

  /// Reports whose status has passed verification (Diverifikasi,
  /// Ditindaklanjuti or Selesai).
  final int verifiedReportCount;

  /// All reports in the requested window, including Terkirim.
  final int totalReportCount;

  /// Whether the window contained no reports at all.
  bool get isEmpty => totalReportCount == 0;
}

/// One point of the monthly condition trend.
class MonthlyConditionPoint {
  const MonthlyConditionPoint({
    required this.month,
    required this.averageScore,
    required this.reportCount,
  });

  /// First day of the month in UTC.
  final DateTime month;

  /// Average [ReportSeverity.score] of verified reports in [month].
  final double averageScore;

  /// Number of verified reports that contributed to [averageScore].
  final int reportCount;
}
