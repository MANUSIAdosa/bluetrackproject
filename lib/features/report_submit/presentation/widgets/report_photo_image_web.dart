import 'package:flutter/material.dart';

/// Web version of [reportPhotoImage].
///
/// `image_picker_for_web` hands back a `blob:` object URL instead of a file
/// path, and `dart:io` only exists as a throwing stub in the browser. Loading
/// the URL through the browser's `<img>` element is what actually renders the
/// picked photo.
Widget reportPhotoImage({
  required String path,
  required ImageErrorWidgetBuilder errorBuilder,
}) {
  return Image.network(
    path,
    fit: BoxFit.cover,
    errorBuilder: errorBuilder,
  );
}
