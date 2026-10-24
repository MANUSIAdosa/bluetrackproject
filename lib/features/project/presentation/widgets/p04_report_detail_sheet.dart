import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../../../shared/widgets/zoomable_photo_viewer.dart';
import '../../data/report_repository.dart';
import '../../domain/data_failure.dart';
import '../../domain/report.dart';
import '../p04_format.dart';
import '../p04_report_visuals.dart';

/// Opens the P04 report detail as a modal bottom sheet.
///
/// Only [reportId] is passed in; the sheet loads the report itself so it can
/// show a skeleton while the repository responds and an error state when the id
/// no longer exists. The sheet uses the platform navigator, so the system back
/// button closes the sheet (or the full-screen photo dialog on top of it)
/// before the page moves. No named route is added.
Future<void> showP04ReportDetailSheet(
  BuildContext context, {
  required String reportId,
  required String locationName,
  required ReportRepository repository,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppDimens.cardRadius),
      ),
    ),
    builder: (_) {
      // A fixed height (instead of a DraggableScrollableSheet) means one
      // downward swipe can dismiss the sheet straight away. The percentage
      // comes from the space the modal actually offers, so the drag handle and
      // a device notch can never push the sheet past the screen.
      return LayoutBuilder(
        builder: (context, constraints) {
          final available = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : MediaQuery.sizeOf(context).height;
          return SizedBox(
            height: available * 0.94,
            child: _ReportDetailSheet(
              reportId: reportId,
              locationName: locationName,
              repository: repository,
            ),
          );
        },
      );
    },
  );
}

class _ReportDetailSheet extends StatefulWidget {
  const _ReportDetailSheet({
    required this.reportId,
    required this.locationName,
    required this.repository,
  });

  final String reportId;
  final String locationName;
  final ReportRepository repository;

  @override
  State<_ReportDetailSheet> createState() => _ReportDetailSheetState();
}

class _ReportDetailSheetState extends State<_ReportDetailSheet> {
  late Future<Report> _report;
  double _pulledDown = 0;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _report = widget.repository.getReportById(widget.reportId);
  }

  @override
  void didUpdateWidget(covariant _ReportDetailSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reportId != widget.reportId ||
        oldWidget.repository != widget.repository) {
      _report = widget.repository.getReportById(widget.reportId);
    }
  }

  void _retry() {
    setState(() {
      _report = widget.repository.getReportById(widget.reportId);
    });
  }

  /// Dismisses the sheet when the user drags the content down while it is
  /// already scrolled to the top. The modal's own drag recognizer only wins
  /// outside the scrollable area, so the list needs this fallback.
  bool _handleScrollNotification(ScrollNotification notification) {
    if (_dismissing) return false;
    // Only the vertical detail list may dismiss the sheet; the horizontal
    // gallery PageView also dispatches scroll notifications.
    if (notification.metrics.axis != Axis.vertical) return false;
    if (notification is ScrollStartNotification ||
        notification is ScrollEndNotification ||
        notification is ScrollUpdateNotification) {
      _pulledDown = 0;
    } else if (notification is OverscrollNotification &&
        notification.overscroll < 0) {
      _pulledDown += -notification.overscroll;
      if (_pulledDown >= 96) {
        _dismissing = true;
        Navigator.of(context).maybePop();
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.padding,
            0,
            AppDimens.padding,
            8,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  context.tr('p04_detail_title'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('p04-detail-close'),
                onPressed: () => Navigator.of(context).maybePop(),
                tooltip: context.tr('p04_detail_close'),
                icon: const Icon(Icons.close),
                constraints: const BoxConstraints.tightFor(
                  width: 48,
                  height: 48,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: FutureBuilder<Report>(
            future: _report,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const _DetailSkeleton();
              }
              if (snapshot.hasError) {
                final notFound = snapshot.error is ReportNotFoundException;
                return ErrorState(
                  message: notFound ? context.tr('p04_detail_not_found') : null,
                  onRetry: _retry,
                );
              }
              if (!snapshot.hasData) return const _DetailSkeleton();
              return NotificationListener<ScrollNotification>(
                onNotification: _handleScrollNotification,
                child: _DetailContent(
                  report: snapshot.data!,
                  locationName: widget.locationName,
                  lang: lang,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('p04-detail-skeleton'),
      primary: false,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppDimens.padding),
      children: const [
        Skeleton(height: 162, radius: 16),
        SizedBox(height: 16),
        Skeleton(width: 220, height: 20),
        SizedBox(height: 10),
        Skeleton(width: 150, height: 14),
        SizedBox(height: 20),
        Skeleton(height: 30, radius: 12),
        SizedBox(height: 20),
        Skeleton(height: 14),
        SizedBox(height: 8),
        Skeleton(height: 14),
        SizedBox(height: 8),
        Skeleton(width: 180, height: 14),
      ],
    );
  }
}

class _DetailContent extends StatelessWidget {
  const _DetailContent({
    required this.report,
    required this.locationName,
    required this.lang,
  });

  final Report report;
  final String locationName;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final categoryColor = context.p04CategoryColor(report.category);
    return ListView(
      key: const ValueKey('p04-detail-scroll'),
      primary: false,
      // Always scrollable so a downward drag at the top can be detected even
      // when the content is shorter than the sheet.
      physics: const AlwaysScrollableScrollPhysics(
        parent: ClampingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppDimens.padding,
        12,
        AppDimens.padding,
        24,
      ),
      children: [
        _DetailGallery(photos: report.photoPaths),
        const SizedBox(height: AppDimens.gap),
        Text(
          report.title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppDimens.gap),
        Wrap(
          spacing: AppDimens.gap,
          runSpacing: AppDimens.gap,
          children: [
            _DetailChip(
              icon: context.p04CategoryIcon(report.category),
              label: context.p04CategoryLabel(report.category),
              color: categoryColor,
            ),
            _DetailChip(
              icon: Icons.speed_outlined,
              label: context.p04SeverityLabel(report.severity),
              color: context.p04SeverityColor(report.severity),
            ),
            _DetailChip(
              icon: context.p04StatusIcon(report.status),
              label: context.p04StatusLabel(report.status),
              color: context.p04StatusColor(report.status),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.gap),
        _DetailRow(
          icon: Icons.person_outline,
          label: context.tr('p04_detail_reporter'),
          value: report.reporterName,
        ),
        _DetailRow(
          icon: Icons.place_outlined,
          label: context.tr('p04_detail_location'),
          value: locationName,
        ),
        _DetailRow(
          icon: Icons.schedule_outlined,
          label: context.tr('p04_detail_time'),
          value: P04Format.dateTime(report.reportedAt.toLocal(), lang),
        ),
        const Divider(height: AppDimens.padding * 2),
        Text(
          context.tr('p04_detail_metrics'),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        if (report.wasteKg == null && report.areaM2 == null)
          Text(
            context.tr('p04_detail_no_metrics'),
            style: const TextStyle(color: AppColors.textSecondary),
          )
        else ...[
          if (report.wasteKg != null)
            _MetricRow(
              icon: Icons.delete_outline,
              label: context.tr('p04_detail_waste'),
              value: context.tr('p04_metric_waste_value', {
                'value': P04Format.number(report.wasteKg!, lang),
              }),
            ),
          if (report.areaM2 != null)
            _MetricRow(
              icon: Icons.aspect_ratio_outlined,
              label: context.tr('p04_detail_area'),
              value: context.tr('p04_metric_area_value', {
                'value': P04Format.number(report.areaM2!, lang),
              }),
            ),
        ],
        const Divider(height: AppDimens.padding * 2),
        Text(
          context.tr('p04_detail_description'),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          report.description,
          style: const TextStyle(fontSize: 14, height: 1.6),
        ),
        const Divider(height: AppDimens.padding * 2),
        Text(
          context.tr('p04_detail_verifier_note'),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          report.verifierNote ?? context.tr('p04_detail_no_note'),
          style: const TextStyle(
            fontSize: 14,
            height: 1.6,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _DetailGallery extends StatefulWidget {
  const _DetailGallery({required this.photos});

  final List<String> photos;

  @override
  State<_DetailGallery> createState() => _DetailGalleryState();
}

class _DetailGalleryState extends State<_DetailGallery> {
  int _index = 0;

  void _openViewer(BuildContext context) {
    final photos = widget.photos;
    if (photos.isEmpty) return;
    showDialog<void>(
      context: context,
      useSafeArea: false,
      barrierDismissible: false,
      barrierColor: AppColors.textPrimary,
      builder: (dialogContext) => Dialog.fullscreen(
        backgroundColor: AppColors.textPrimary,
        child: ZoomablePhotoViewer(
          photoPaths: photos,
          initialIndex: _index,
          closeLabel: dialogContext.tr('p04_photo_close'),
          errorLabel: dialogContext.tr('p04_photo_error'),
          counterLabel: (current, total) => dialogContext.tr(
            'p04_photo_counter',
            {'current': '${current + 1}', 'total': '$total'},
          ),
          zoomHint: dialogContext.tr('p04_zoom_hint'),
          onClose: () => Navigator.of(dialogContext).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: _PhotoPlaceholder(message: context.tr('p04_photo_error')),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimens.cardRadius),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          children: [
            PageView.builder(
              key: const ValueKey('p04-detail-gallery'),
              itemCount: widget.photos.length,
              onPageChanged: (index) => setState(() => _index = index),
              itemBuilder: (context, index) {
                return Semantics(
                  button: true,
                  label: context.tr('p04_photo_open'),
                  child: GestureDetector(
                    key: const ValueKey('p04-detail-photo'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _openViewer(context),
                    child: Image.asset(
                      widget.photos[index],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _PhotoPlaceholder(
                            message: context.tr('p04_photo_error'),
                          ),
                    ),
                  ),
                );
              },
            ),
            // Photo counter (e.g. 1/2), mirroring the P04 header gallery.
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.textPrimary.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(AppDimens.cardRadius),
                ),
                child: Text(
                  context.tr('p04_photo_counter', {
                    'current': '${_index + 1}',
                    'total': '${widget.photos.length}',
                  }),
                  style: const TextStyle(
                    color: AppColors.surface,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            // Dot indicator overlaid on the image, same treatment as P04.
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < widget.photos.length; i++)
                    AnimatedContainer(
                      key: ValueKey('p04-detail-dot-$i'),
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: _index == i ? 18 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: _index == i
                            ? AppColors.surface
                            : AppColors.surface.withValues(alpha: 0.54),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.border,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(AppDimens.padding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.broken_image_outlined,
            color: AppColors.textSecondary,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.ocean),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
