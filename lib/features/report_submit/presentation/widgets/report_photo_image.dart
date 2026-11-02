/// Picks the right photo preview for the running platform.
///
/// `dart.library.js_interop` is true on the web, where the picker returns a
/// `blob:` URL, and false on mobile/desktop, where it returns a file path.
library;

export 'report_photo_image_io.dart'
    if (dart.library.js_interop) 'report_photo_image_web.dart';
