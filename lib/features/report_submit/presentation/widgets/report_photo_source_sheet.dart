import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/report_photo_picker.dart';

/// Bottom sheet asking whether the next photo comes from the camera or the
/// gallery. Returns null when the user dismisses it.
class ReportPhotoSourceSheet extends StatelessWidget {
  const ReportPhotoSourceSheet({super.key});

  static Future<ReportPhotoSource?> show(BuildContext context) {
    return showModalBottomSheet<ReportPhotoSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => const ReportPhotoSourceSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              context.tr('report_source_title'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(
              Icons.photo_camera_outlined,
              color: AppColors.ocean,
            ),
            title: Text(context.tr('report_source_camera')),
            onTap: () => Navigator.pop(context, ReportPhotoSource.camera),
          ),
          ListTile(
            leading: const Icon(
              Icons.photo_library_outlined,
              color: AppColors.ocean,
            ),
            title: Text(context.tr('report_source_gallery')),
            onTap: () => Navigator.pop(context, ReportPhotoSource.gallery),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
