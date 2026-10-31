import '../../project/domain/report.dart';

/// In-progress state of the four-step "Lapor Temuan" wizard.
///
/// Named `ReportWizardDraft` (not `ReportDraft`) because
/// `features/project/domain/report.dart` already owns `ReportDraft`, the
/// payload handed to `ReportRepository.submitReport`. Keeping the two separate
/// lets the wizard persist half-filled forms without pretending they are ready
/// to submit.
///
/// The category and severity enums are reused from the report domain so the
/// wizard and the published report can never drift apart.
class ReportWizardDraft {
  const ReportWizardDraft({
    this.photoPaths = const [],
    this.latitude,
    this.longitude,
    this.category,
    this.severity,
    this.currentStep = firstStep,
    this.updatedAt,
  });

  /// The wizard has exactly four steps, numbered 1–4 in the UI and in storage.
  static const int firstStep = 1;
  static const int lastStep = 4;

  /// Local paths of the photos picked for this finding.
  ///
  /// TODO(lapor): image_picker returns cache files. Copy them into the app
  /// documents directory once `path_provider` is approved; otherwise the OS
  /// may delete a draft's photos between sessions. The path is stored as-is
  /// for now, as instructed.
  final List<String> photoPaths;

  /// Pin location picked on step 2. Null until the user sets a pin.
  final double? latitude;
  final double? longitude;

  /// Finding type and severity picked on step 3.
  final ReportCategory? category;
  final ReportSeverity? severity;

  /// Last step the user opened, 1-based. Used to resume the draft.
  final int currentStep;

  /// When the draft was last changed. Stamped by the wizard, not the store.
  final DateTime? updatedAt;

  /// Number of photos already attached.
  int get photoCount => photoPaths.length;

  /// Whether there is anything worth resuming.
  ///
  /// An untouched wizard (no photos, no pin, no type, still on step 1) is not
  /// a draft, so opening the page never asks to resume an empty form.
  bool get hasContent =>
      photoPaths.isNotEmpty ||
      latitude != null ||
      longitude != null ||
      category != null ||
      severity != null ||
      currentStep > firstStep;

  ReportWizardDraft copyWith({
    List<String>? photoPaths,
    double? latitude,
    double? longitude,
    ReportCategory? category,
    ReportSeverity? severity,
    int? currentStep,
    DateTime? updatedAt,
  }) {
    return ReportWizardDraft(
      photoPaths: photoPaths ?? this.photoPaths,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      category: category ?? this.category,
      severity: severity ?? this.severity,
      currentStep: currentStep ?? this.currentStep,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Plain JSON shape stored in Hive. Nullable fields are written as `null` so
  /// an older draft can be read back without a schema version.
  Map<String, dynamic> toJson() => {
    'photoPaths': photoPaths,
    'latitude': latitude,
    'longitude': longitude,
    'category': category?.id,
    'severity': severity?.id,
    'currentStep': currentStep,
    'updatedAt': updatedAt?.toUtc().toIso8601String(),
  };

  /// Reads a stored draft defensively.
  ///
  /// Unknown enum ids become null and an out-of-range step is clamped, so a
  /// draft written by a newer build can still be restored instead of crashing
  /// the wizard. Values of the wrong type throw, which the Hive store catches
  /// and treats as "no usable draft".
  factory ReportWizardDraft.fromJson(Map<String, dynamic> json) {
    final paths = <String>[];
    final rawPaths = json['photoPaths'];
    if (rawPaths is List) {
      for (final path in rawPaths) {
        if (path is String && path.trim().isNotEmpty) paths.add(path);
      }
    }

    final rawStep = json['currentStep'];
    final step = rawStep is num ? rawStep.toInt() : firstStep;

    final rawUpdatedAt = json['updatedAt'];
    return ReportWizardDraft(
      photoPaths: paths,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      category: _categoryFromId(json['category']),
      severity: _severityFromId(json['severity']),
      currentStep: step.clamp(firstStep, lastStep),
      updatedAt: rawUpdatedAt is String
          ? DateTime.tryParse(rawUpdatedAt)
          : null,
    );
  }

  static ReportCategory? _categoryFromId(Object? id) {
    if (id is! String) return null;
    for (final value in ReportCategory.values) {
      if (value.id == id) return value;
    }
    return null;
  }

  static ReportSeverity? _severityFromId(Object? id) {
    if (id is! String) return null;
    for (final value in ReportSeverity.values) {
      if (value.id == id) return value;
    }
    return null;
  }
}
