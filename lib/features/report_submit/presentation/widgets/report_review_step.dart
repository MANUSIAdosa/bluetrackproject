import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/state/app_state.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../project/domain/report.dart';
import '../../../project/presentation/p04_report_visuals.dart';
import 'report_photo_image.dart';
import 'report_photo_viewer.dart';

/// Step 4 of "Lapor Temuan": review every choice before sending.
///
/// Nothing here edits the draft directly: each "Ubah" goes back to the step
/// that owns the value, and the stored draft keeps everything else intact.
/// Photos open a full-screen viewer; the small map is read-only.
class ReportReviewStep extends StatelessWidget {
  const ReportReviewStep({
    super.key,
    required this.photoPaths,
    required this.title,
    required this.description,
    this.areaName = '',
    this.locationDetail = '',
    required this.latitude,
    required this.longitude,
    required this.category,
    required this.severity,
    required this.reportedAt,
    required this.onEditReport,
    required this.onEditLocation,
    required this.onEditClassification,
    this.showSubmitError = false,
    this.onRetry,
    this.tileProvider,
  });

  final List<String> photoPaths;
  final String title;
  final String description;
  final String areaName;
  final String locationDetail;
  final double? latitude;
  final double? longitude;
  final ReportCategory? category;
  final ReportSeverity? severity;

  /// Time shown as the finding time; stamped when the draft was last changed.
  final DateTime reportedAt;

  final VoidCallback onEditReport;
  final VoidCallback onEditLocation;
  final VoidCallback onEditClassification;

  /// True after a failed send; shows the error card with [onRetry].
  final bool showSubmitError;
  final VoidCallback? onRetry;

  /// Test seam for the small map; defaults to the OSM network tiles.
  final TileProvider? tileProvider;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('report_review_title'),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          context.tr('report_review_subtitle'),
          style: const TextStyle(
            fontSize: 14,
            height: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(
                  title: context.tr('report_review_photos'),
                  hint: context.tr('report_review_edit_report_hint'),
                  editKey: const ValueKey('report_review_edit_photos'),
                  onEdit: onEditReport,
                ),
                _PhotoSection(photoPaths: photoPaths),
                const Divider(height: 24),
                _SectionHeader(
                  title: context.tr('report_review_details_group'),
                  hint: context.tr('report_review_edit_report_hint'),
                  editKey: const ValueKey('report_review_edit_report'),
                  onEdit: onEditReport,
                ),
                Text(
                  title.trim().isEmpty
                      ? context.tr('report_review_empty_value')
                      : title.trim(),
                  key: const ValueKey('report_review_title_value'),
                  style: const TextStyle(
                    fontSize: 17,
                    height: 1.3,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                _DescriptionPreview(
                  key: const ValueKey('report_review_description'),
                  text: description.trim().isEmpty
                      ? context.tr('report_review_empty_value')
                      : description.trim(),
                ),
                const Divider(height: 24),
                _SectionHeader(
                  title: context.tr('report_review_location'),
                  hint: context.tr('report_review_edit_location_hint'),
                  editKey: const ValueKey('report_review_edit_location'),
                  onEdit: onEditLocation,
                ),
                _LocationSection(
                  latitude: latitude,
                  longitude: longitude,
                  areaName: areaName,
                  locationDetail: locationDetail,
                  tileProvider: tileProvider,
                ),
                const Divider(height: 24),
                _SectionHeader(
                  title: context.tr('report_review_classification'),
                  hint: context.tr('report_review_edit_classification_hint'),
                  editKey: const ValueKey('report_review_edit_classification'),
                  onEdit: onEditClassification,
                ),
                _DetailRow(
                  icon: category == null
                      ? Icons.category_outlined
                      : context.p04CategoryIcon(category!),
                  color: category == null
                      ? AppColors.inactiveTab
                      : context.p04CategoryColor(category!),
                  value: category == null
                      ? context.tr('report_review_empty_value')
                      : context.p04CategoryLabel(category!),
                ),
                const SizedBox(height: 4),
                _DetailRow(
                  icon: severity == null
                      ? Icons.speed_outlined
                      : Icons.warning_amber_rounded,
                  color: severity == null
                      ? AppColors.inactiveTab
                      : context.p04SeverityColor(severity!),
                  value: severity == null
                      ? context.tr('report_review_empty_value')
                      : context.p04SeverityLabel(severity!),
                ),
                const Divider(height: 24),
                _SectionHeader(title: context.tr('report_review_time')),
                _DetailRow(
                  key: const ValueKey('report_review_time_value'),
                  icon: Icons.schedule_outlined,
                  color: AppColors.ocean,
                  value: Formatters.dateTime(reportedAt, locale),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.verified_outlined,
              size: 16,
              color: AppColors.teal,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                context.tr('report_review_verification_note'),
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ListenableBuilder(
          listenable: OfflineController.instance,
          builder: (context, _) {
            if (!OfflineController.instance.offline) {
              return const SizedBox.shrink();
            }
            return const _WarningCard(
              key: ValueKey('report_review_offline'),
              icon: Icons.cloud_off,
              color: AppColors.warning,
              titleKey: 'report_submit_offline_title',
              bodyKey: 'report_submit_offline_body',
            );
          },
        ),
        if (showSubmitError) ...[
          const SizedBox(height: 12),
          _WarningCard(
            key: const ValueKey('report_review_submit_error'),
            icon: Icons.error_outline,
            color: AppColors.danger,
            titleKey: 'report_submit_error_title',
            bodyKey: 'report_submit_error_body',
            actionLabel: context.tr('report_submit_retry'),
            onAction: onRetry,
          ),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.hint,
    this.editKey,
    this.onEdit,
  });

  final String title;

  /// Tooltip for the shared "Ubah" label, so each edit targets a named group.
  final String? hint;
  final Key? editKey;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        if (onEdit != null)
          Tooltip(
            message: hint ?? context.tr('report_review_edit'),
            child: TextButton(
              key: editKey,
              onPressed: onEdit,
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(context.tr('report_review_edit')),
            ),
          ),
      ],
    );
  }
}

class _PhotoSection extends StatelessWidget {
  const _PhotoSection({required this.photoPaths});

  final List<String> photoPaths;

  @override
  Widget build(BuildContext context) {
    if (photoPaths.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          context.tr('report_review_empty_value'),
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < photoPaths.length; i++)
            _PhotoTile(index: i, path: photoPaths[i], photoPaths: photoPaths),
        ],
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.index,
    required this.path,
    required this.photoPaths,
  });

  final int index;
  final String path;
  final List<String> photoPaths;

  @override
  Widget build(BuildContext context) {
    final label = context.tr('report_review_photo_label', {
      'n': '${index + 1}',
    });

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: SizedBox(
        width: 92,
        height: 92,
        child: Material(
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          color: AppColors.border,
          child: InkWell(
            key: ValueKey('report_review_photo_$index'),
            onTap: () => ReportPhotoViewer.show(
              context,
              photoPaths: photoPaths,
              initialIndex: index,
            ),
            child: reportPhotoImage(
              path: path,
              errorBuilder: (context, error, stackTrace) => const ColoredBox(
                color: AppColors.border,
                child: Icon(
                  Icons.broken_image_outlined,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LocationSection extends StatelessWidget {
  const _LocationSection({
    required this.latitude,
    required this.longitude,
    this.areaName = '',
    this.locationDetail = '',
    this.tileProvider,
  });

  final double? latitude;
  final double? longitude;
  final String areaName;
  final String locationDetail;
  final TileProvider? tileProvider;

  @override
  Widget build(BuildContext context) {
    final latitude = this.latitude;
    final longitude = this.longitude;
    if (latitude == null || longitude == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          context.tr('report_review_empty_value'),
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
      );
    }

    final point = LatLng(latitude, longitude);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 140,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ListenableBuilder(
                listenable: OfflineController.instance,
                builder: (context, _) {
                  final offline = OfflineController.instance.offline;
                  return FlutterMap(
                    key: const ValueKey('report_review_map'),
                    options: MapOptions(
                      initialCenter: point,
                      initialZoom: 15,
                      backgroundColor: AppColors.ocean.withValues(alpha: 0.08),
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.none,
                      ),
                    ),
                    children: [
                      if (!offline)
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'app.bluetrack',
                          tileProvider: tileProvider,
                        ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: point,
                            width: 36,
                            height: 36,
                            child: const Icon(
                              Icons.location_on,
                              size: 36,
                              color: AppColors.coral,
                            ),
                          ),
                        ],
                      ),
                      const RichAttributionWidget(
                        alignment: AttributionAlignment.bottomRight,
                        attributions: [
                          TextSourceAttribution('OpenStreetMap contributors'),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          if (areaName.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              areaName.trim(),
              key: const ValueKey('report_review_area_value'),
              style: const TextStyle(
                fontSize: 15,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
            key: const ValueKey('report_review_coordinates'),
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          // The reporter's own note is secondary, so it stays last and folded.
          if (locationDetail.trim().isNotEmpty)
            _LandmarkDetails(text: locationDetail.trim()),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    super.key,
    required this.icon,
    required this.color,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({
    super.key,
    required this.icon,
    required this.color,
    required this.titleKey,
    required this.bodyKey,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final Color color;
  final String titleKey;
  final String bodyKey;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(titleKey),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.tr(bodyKey),
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (actionLabel != null && onAction != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      key: const ValueKey('report_review_retry'),
                      onPressed: onAction,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        padding: EdgeInsets.zero,
                      ),
                      child: Text(actionLabel!),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The reporter's own landmark note, kept out of the way until asked for.
///
/// The summary leads with the area name and coordinates; the free-text
/// landmark stays available for checking without cluttering the card.
class _LandmarkDetails extends StatefulWidget {
  const _LandmarkDetails({required this.text});

  final String text;

  @override
  State<_LandmarkDetails> createState() => _LandmarkDetailsState();
}

class _LandmarkDetailsState extends State<_LandmarkDetails> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const ValueKey('report_review_details_toggle'),
            onPressed: () => setState(() => _open = !_open),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(48, 48),
            ),
            icon: Icon(_open ? Icons.expand_less : Icons.expand_more, size: 18),
            label: Text(
              context.tr(
                _open ? 'report_review_hide_details' : 'report_review_details',
              ),
            ),
          ),
        ),
        if (_open) ...[
          Text(
            context.tr('report_review_landmark_label'),
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            widget.text,
            key: const ValueKey('report_review_landmark_value'),
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
        ],
      ],
    );
  }
}

/// Description preview: three lines, with a "Show more" control only when the
/// text actually overflows. The description is required, so at least a preview
/// stays visible; the toggle keeps long reports scannable.
class _DescriptionPreview extends StatefulWidget {
  const _DescriptionPreview({super.key, required this.text});

  final String text;

  @override
  State<_DescriptionPreview> createState() => _DescriptionPreviewState();
}

class _DescriptionPreviewState extends State<_DescriptionPreview> {
  static const int _maxLines = 3;
  static const TextStyle _style = TextStyle(fontSize: 14, height: 1.45);

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: _style),
          maxLines: _maxLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              key: const ValueKey('report_review_description_value'),
              maxLines: _expanded ? null : _maxLines,
              overflow: _expanded
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
              style: _style,
            ),
            if (overflows)
              TextButton.icon(
                key: const ValueKey('report_review_description_toggle'),
                onPressed: () => setState(() => _expanded = !_expanded),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(48, 40),
                ),
                icon: Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                ),
                label: Text(
                  context.tr(
                    _expanded ? 'report_review_less' : 'report_review_more',
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
