import 'package:flutter/services.dart' show PlatformException;
import 'package:image_picker/image_picker.dart';

/// Where the user wants to pick a photo from.
enum ReportPhotoSource { camera, gallery }

/// Why a photo pick did not return a usable path.
enum ReportPhotoFailure {
  /// Camera access was denied or restricted by the OS.
  cameraPermissionDenied,

  /// Photo library access was denied or restricted by the OS.
  galleryPermissionDenied,

  /// The platform has no camera/gallery implementation (for example Linux
  /// desktop or a missing plugin registration).
  unavailable,

  /// Anything else, including a platform error we do not recognize.
  unknown,
}

/// Outcome of one pick attempt.
///
/// A cancelled picker is a success with no paths. [truncated] is true when the
/// user selected more images than the wizard could accept, so the page can tell
/// them how many were kept.
class ReportPhotoPickResult {
  const ReportPhotoPickResult({
    this.paths = const [],
    this.truncated = false,
    this.failure,
  });

  const ReportPhotoPickResult.failure(ReportPhotoFailure this.failure)
    : paths = const [],
      truncated = false;

  final List<String> paths;
  final bool truncated;
  final ReportPhotoFailure? failure;

  bool get isFailure => failure != null;
}

/// Picks photos for the wizard.
///
/// The page depends on this interface rather than `ImagePicker` directly, so
/// permission and limit behaviour can be driven deterministically in tests.
abstract interface class ReportPhotoPicker {
  /// Picks up to [remaining] photos. [remaining] is the number of free slots,
  /// never zero or negative (the page checks the limit first).
  Future<ReportPhotoPickResult> pick({
    required ReportPhotoSource source,
    required int remaining,
  });
}

/// [ReportPhotoPicker] backed by `image_picker`.
class ImagePickerReportPhotoPicker implements ReportPhotoPicker {
  ImagePickerReportPhotoPicker({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<ReportPhotoPickResult> pick({
    required ReportPhotoSource source,
    required int remaining,
  }) async {
    if (remaining <= 0) return const ReportPhotoPickResult();

    try {
      if (source == ReportPhotoSource.camera) {
        final file = await _picker.pickImage(source: ImageSource.camera);
        if (file == null) return const ReportPhotoPickResult();
        final path = file.path.trim();
        return ReportPhotoPickResult(paths: path.isEmpty ? const [] : [path]);
      }

      final files = await _picker.pickMultiImage(limit: remaining);
      final paths = files
          .map((file) => file.path.trim())
          .where((path) => path.isNotEmpty)
          .toList();
      return ReportPhotoPickResult(
        paths: paths.take(remaining).toList(),
        truncated: paths.length > remaining,
      );
    } on PlatformException catch (error) {
      return ReportPhotoPickResult.failure(_failureFor(error, source));
    } catch (_) {
      // Missing plugin, no camera app, unsupported desktop, etc.
      return const ReportPhotoPickResult.failure(
        ReportPhotoFailure.unavailable,
      );
    }
  }

  ReportPhotoFailure _failureFor(
    PlatformException error,
    ReportPhotoSource source,
  ) {
    switch (error.code) {
      case 'camera_access_denied':
      case 'camera_access_restricted':
        return ReportPhotoFailure.cameraPermissionDenied;
      case 'photo_access_denied':
      case 'photo_access_restricted':
        return ReportPhotoFailure.galleryPermissionDenied;
      default:
        // Some Android builds report a denied camera as a generic error; keep
        // the source so the message still points at the right permission.
        if (source == ReportPhotoSource.camera &&
            error.code.toLowerCase().contains('camera')) {
          return ReportPhotoFailure.cameraPermissionDenied;
        }
        if (source == ReportPhotoSource.gallery &&
            (error.code.toLowerCase().contains('photo') ||
                error.code.toLowerCase().contains('gallery'))) {
          return ReportPhotoFailure.galleryPermissionDenied;
        }
        return ReportPhotoFailure.unknown;
    }
  }
}
