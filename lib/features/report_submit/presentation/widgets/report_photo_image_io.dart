import 'dart:io';

import 'package:flutter/material.dart';

/// Builds the preview for one picked photo.
///
/// The implementation is platform specific:
/// - mobile/desktop reads the file path returned by `image_picker`;
/// - web receives a `blob:` object URL, which only the browser can resolve.
///
/// Keep this helper's signature identical in both files so the conditional
/// export in `report_photo_image.dart` can swap them.
Widget reportPhotoImage({
  required String path,
  required ImageErrorWidgetBuilder errorBuilder,
}) {
  return Image.file(
    File(path),
    fit: BoxFit.cover,
    errorBuilder: errorBuilder,
  );
}
