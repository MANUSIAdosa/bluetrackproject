import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Full-screen photo viewer with swipe navigation, pinch zoom and double-tap
/// zoom.
///
/// The widget owns no page-specific copy: callers pass every label so it can be
/// reused by P04 today and P10 later without duplicating strings. Zoom stays in
/// the 1x–4x range and a double tap toggles between 1x and 2x.
class ZoomablePhotoViewer extends StatefulWidget {
  const ZoomablePhotoViewer({
    super.key,
    required this.photoPaths,
    required this.closeLabel,
    required this.errorLabel,
    required this.counterLabel,
    this.initialIndex = 0,
    this.zoomHint,
    this.onClose,
  });

  /// Local asset paths to display. An empty list renders the error placeholder.
  final List<String> photoPaths;

  /// Accessible label and tooltip for the 48dp close button.
  final String closeLabel;

  /// Copy shown when one image cannot be decoded.
  final String errorLabel;

  /// Builds the `2/3` counter from zero-based [current] and [total].
  final String Function(int current, int total) counterLabel;

  /// Optional gesture hint shown at the bottom of the screen.
  final String? zoomHint;

  /// First page to show, clamped to the available range.
  final int initialIndex;

  /// Overrides the default `Navigator.maybePop` close behaviour.
  final VoidCallback? onClose;

  @override
  State<ZoomablePhotoViewer> createState() => _ZoomablePhotoViewerState();
}

class _ZoomablePhotoViewerState extends State<ZoomablePhotoViewer> {
  late final PageController _pageController;
  late final TransformationController _transformationController;
  late int _index;
  Offset? _lastDoubleTapPosition;

  @override
  void initState() {
    super.initState();
    _index = widget.photoPaths.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.photoPaths.length - 1).toInt();
    _pageController = PageController(initialPage: _index);
    _transformationController = TransformationController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _close() {
    final onClose = widget.onClose;
    if (onClose != null) {
      onClose();
      return;
    }
    Navigator.of(context).maybePop();
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  void _onPageChanged(int index) {
    setState(() => _index = index);
    _resetZoom();
  }

  void _toggleZoom(Size size) {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    if (currentScale > 1.05) {
      _resetZoom();
      return;
    }

    final focal = _lastDoubleTapPosition ?? size.center(Offset.zero);
    _transformationController.value = Matrix4.identity()
      ..translateByDouble(focal.dx, focal.dy, 0, 1)
      ..scaleByDouble(2, 2, 1, 1)
      ..translateByDouble(-focal.dx, -focal.dy, 0, 1);
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photoPaths;
    return Material(
      color: AppColors.textPrimary,
      child: SafeArea(
        child: Stack(
          children: [
            if (photos.isEmpty)
              _PhotoError(message: widget.errorLabel)
            else
              PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: photos.length,
                itemBuilder: (context, index) {
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onDoubleTapDown: (details) =>
                            _lastDoubleTapPosition = details.localPosition,
                        onDoubleTap: () => _toggleZoom(constraints.biggest),
                        child: InteractiveViewer(
                          transformationController: _transformationController,
                          minScale: 1,
                          maxScale: 4,
                          child: Center(
                            child: Image.asset(
                              photos[index],
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  _PhotoError(message: widget.errorLabel),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Row(
                children: [
                  IconButton(
                    onPressed: _close,
                    tooltip: widget.closeLabel,
                    icon: const Icon(Icons.close, color: AppColors.surface),
                    constraints: const BoxConstraints.tightFor(
                      width: 48,
                      height: 48,
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        widget.counterLabel(_index, photos.length),
                        style: const TextStyle(
                          color: AppColors.surface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48, height: 48),
                ],
              ),
            ),
            if (widget.zoomHint != null)
              Positioned(
                left: AppDimens.padding,
                right: AppDimens.padding,
                bottom: AppDimens.padding,
                child: Text(
                  widget.zoomHint!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.surface.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PhotoError extends StatelessWidget {
  const _PhotoError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.padding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.broken_image_outlined,
              color: AppColors.inactiveTab,
              size: 48,
            ),
            const SizedBox(height: AppDimens.gap),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.surface),
            ),
          ],
        ),
      ),
    );
  }
}
