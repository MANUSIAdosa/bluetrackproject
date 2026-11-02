import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import 'report_photo_image.dart';

/// Full-screen viewer for the photos picked in step 1.
///
/// Picked photos are local files (or `blob:` URLs on web), so the shared
/// [ZoomablePhotoViewer] — which loads assets — cannot show them. This viewer
/// reuses the platform-aware [reportPhotoImage] helper instead.
class ReportPhotoViewer extends StatefulWidget {
  const ReportPhotoViewer({
    super.key,
    required this.photoPaths,
    this.initialIndex = 0,
  });

  final List<String> photoPaths;
  final int initialIndex;

  /// Opens the viewer above the current route.
  static Future<void> show(
    BuildContext context, {
    required List<String> photoPaths,
    int initialIndex = 0,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => ReportPhotoViewer(
          photoPaths: photoPaths,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  State<ReportPhotoViewer> createState() => _ReportPhotoViewerState();
}

class _ReportPhotoViewerState extends State<ReportPhotoViewer> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.photoPaths.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.photoPaths.length - 1).toInt();
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photoPaths;
    return Material(
      key: const ValueKey('report_photo_viewer'),
      color: Colors.black,
      child: SafeArea(
        child: Stack(
          children: [
            if (photos.isEmpty)
              Center(
                child: Text(
                  context.tr('report_photo_load_error'),
                  style: const TextStyle(color: Colors.white),
                ),
              )
            else
              PageView.builder(
                controller: _controller,
                onPageChanged: (index) => setState(() => _index = index),
                itemCount: photos.length,
                itemBuilder: (context, index) => InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: reportPhotoImage(
                      path: photos[index],
                      errorBuilder: (context, error, stackTrace) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.broken_image_outlined,
                            size: 48,
                            color: AppColors.inactiveTab,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.tr('report_photo_load_error'),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: IconButton(
                      key: const ValueKey('report_photo_viewer_close'),
                      tooltip: context.tr('report_photo_viewer_close'),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        context.tr('report_photo_viewer_counter', {
                          'current': '${photos.isEmpty ? 0 : _index + 1}',
                          'total': '${photos.length}',
                        }),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48, height: 48),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
