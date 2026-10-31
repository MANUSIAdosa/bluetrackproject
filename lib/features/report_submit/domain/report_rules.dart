/// Fixed limits for the "Lapor Temuan" wizard.
///
/// TODO(lapor): confirm with the product owner that at least one photo is
/// mandatory, then move these values into `core/config/app_config.dart` so all
/// fixed numbers live in one place.
abstract final class ReportRules {
  /// A report without evidence is not useful, so step 1 requires one photo.
  static const int minPhotos = 1;

  /// Gallery picks and new camera shots beyond this are discarded.
  static const int maxPhotos = 3;
}
