import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import 'report_photo_image.dart';

/// 1:1 grid of picked photos plus the "Tambah Foto" tile.
///
/// The add tile disappears once [maxPhotos] is reached. The grid scrolls with
/// its parent, never on its own.
class ReportPhotoGrid extends StatelessWidget {
  const ReportPhotoGrid({
    super.key,
    required this.photoPaths,
    required this.maxPhotos,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> photoPaths;
  final int maxPhotos;

  /// Null disables the add tile while a pick is already running.
  final VoidCallback? onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final showAdd = photoPaths.length < maxPhotos;
    final itemCount = photoPaths.length + (showAdd ? 1 : 0);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        if (index < photoPaths.length) {
          return _PhotoTile(
            path: photoPaths[index],
            index: index,
            onRemove: onRemove,
          );
        }
        return _AddPhotoTile(onTap: onAdd);
      },
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.path,
    required this.index,
    required this.onRemove,
  });

  final String path;
  final int index;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: reportPhotoImage(
            path: path,
            errorBuilder: (context, error, stackTrace) => ColoredBox(
              color: AppColors.border,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.broken_image_outlined,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr('report_photo_load_error'),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              key: Key('report_photo_remove_$index'),
              tooltip: context.tr('report_remove_photo'),
              onPressed: () => onRemove(index),
              icon: Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 18, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.ocean.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: const Key('report_add_photo'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.ocean.withValues(alpha: 0.4)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_a_photo_outlined, color: AppColors.ocean),
              const SizedBox(height: 6),
              Text(
                context.tr('report_add_photo'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ocean,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
