import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/report_metadata_chip.dart';
import '../../../../shared/widgets/zoomable_photo_viewer.dart';
import '../../../project/domain/report.dart';
import '../../../project/presentation/p04_format.dart';
import '../../../project/presentation/p04_report_visuals.dart';

/// Opens the full detail of one of the user's reports.
///
/// The report is already loaded by the list, so the sheet does not fetch again:
/// it shows the status tracker, the zoomable photo, a small map, the verifier
/// note and the description. Followed-up and finished reports also expose a
/// secondary link to the general Aksi agenda.
Future<void> showMyReportDetailSheet(
  BuildContext context, {
  required Report report,
  TileProvider? mapTileProvider,
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
      return LayoutBuilder(
        builder: (context, constraints) {
          final available = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : MediaQuery.sizeOf(context).height;
          return SizedBox(
            height: available * 0.92,
            child: _MyReportDetailSheet(
              report: report,
              mapTileProvider: mapTileProvider,
            ),
          );
        },
      );
    },
  );
}

class _MyReportDetailSheet extends StatelessWidget {
  const _MyReportDetailSheet({
    required this.report,
    required this.mapTileProvider,
  });

  final Report report;
  final TileProvider? mapTileProvider;

  bool get _showActionsAgenda =>
      report.status == ReportStatus.followedUp ||
      report.status == ReportStatus.completed;

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
            children: [
              Expanded(
                child: Text(
                  context.tr('p04_detail_title'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('my-report-sheet-close'),
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
          child: ListView(
            key: const ValueKey('my-report-sheet-scroll'),
            primary: false,
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
              _ReportPhoto(photoPaths: report.photoPaths),
              const SizedBox(height: AppDimens.gap),
              Text(
                report.title,
                style: const TextStyle(
                  fontSize: 20,
                  height: 1.3,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              _DateRow(
                label: context.tr('my_reports.report_date'),
                value: P04Format.date(report.reportedAt.toLocal(), lang),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ReportMetadataChip(
                    icon: context.p04CategoryIcon(report.category),
                    label: context.p04CategoryLabel(report.category),
                    color: context.p04CategoryColor(report.category),
                  ),
                  ReportMetadataChip(
                    icon: Icons.speed_outlined,
                    label: context.p04SeverityLabel(report.severity),
                    color: context.p04SeverityColor(report.severity),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _CurrentStatusPanel(status: report.status),
              const SizedBox(height: 12),
              _SectionCard(
                icon: Icons.timeline,
                title: context.tr('my_reports.tracker'),
                child: _StatusTracker(status: report.status),
              ),
              if (report.status == ReportStatus.completed) ...[
                const SizedBox(height: 12),
                _SectionCard(
                  icon: Icons.fact_check_outlined,
                  title: context.tr('my_reports.completion_proof'),
                  child: report.completionProof == null
                      ? const _CompletionProofEmptyState()
                      : _CompletionProofDetails(
                          proof: report.completionProof!,
                          languageCode: lang,
                        ),
                ),
              ],
              const SizedBox(height: 12),
              _SectionCard(
                icon: Icons.notes_outlined,
                title: context.tr('p04_detail_description'),
                child: Text(
                  report.description,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                icon: Icons.rate_review_outlined,
                title: context.tr('p04_detail_verifier_note'),
                child: _VerifierNote(note: report.verifierNote),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                icon: Icons.place_outlined,
                title: context.tr('p04_detail_location'),
                child: _MiniMap(report: report, tileProvider: mapTileProvider),
              ),
              if (_showActionsAgenda) ...[
                const SizedBox(height: 12),
                const _OpenActionsRow(),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ReportPhoto extends StatelessWidget {
  const _ReportPhoto({required this.photoPaths});

  final List<String> photoPaths;

  void _openViewer(BuildContext context) {
    showDialog<void>(
      context: context,
      useSafeArea: false,
      barrierDismissible: false,
      barrierColor: AppColors.textPrimary,
      builder: (dialogContext) => Dialog.fullscreen(
        backgroundColor: AppColors.textPrimary,
        child: ZoomablePhotoViewer(
          photoPaths: photoPaths,
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
    if (photoPaths.isEmpty) {
      return const AspectRatio(aspectRatio: 16 / 9, child: _PhotoPlaceholder());
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimens.cardRadius),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Semantics(
              button: true,
              label: context.tr('p04_photo_open'),
              child: GestureDetector(
                key: const ValueKey('my-report-photo'),
                behavior: HitTestBehavior.opaque,
                onTap: () => _openViewer(context),
                child: Image.asset(
                  photoPaths.first,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const _PhotoPlaceholder(),
                ),
              ),
            ),
            Positioned(
              left: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.textPrimary.withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.zoom_in,
                      size: 14,
                      color: AppColors.surface,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      context.tr('p04_photo_open'),
                      style: const TextStyle(
                        color: AppColors.surface,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (photoPaths.length > 1)
              Positioned(
                right: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    context.tr('p04_photo_counter', {
                      'current': '1',
                      'total': '${photoPaths.length}',
                    }),
                    style: const TextStyle(
                      color: AppColors.surface,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder();

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
            context.tr('p04_photo_error'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// The report's present state, promoted above the step-by-step tracker.
class _CurrentStatusPanel extends StatelessWidget {
  const _CurrentStatusPanel({required this.status});

  final ReportStatus status;

  @override
  Widget build(BuildContext context) {
    final color = context.p04StatusColor(status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              context.p04StatusIcon(status),
              size: 20,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('my_reports.current_status'),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.p04StatusLabel(status),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${status.index + 1}/${ReportStatus.values.length}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusTracker extends StatelessWidget {
  const _StatusTracker({required this.status});

  final ReportStatus status;

  @override
  Widget build(BuildContext context) {
    final steps = ReportStatus.values;
    final currentIndex = status.index;

    return Column(
      key: const ValueKey('my-report-tracker'),
      children: [
        for (var i = 0; i < steps.length; i++)
          _TrackerRow(
            status: steps[i],
            reached: i <= currentIndex,
            current: i == currentIndex,
            isLast: i == steps.length - 1,
            nextReached: i + 1 <= currentIndex,
          ),
      ],
    );
  }
}

class _TrackerRow extends StatelessWidget {
  const _TrackerRow({
    required this.status,
    required this.reached,
    required this.current,
    required this.isLast,
    required this.nextReached,
  });

  final ReportStatus status;
  final bool reached;
  final bool current;
  final bool isLast;
  final bool nextReached;

  @override
  Widget build(BuildContext context) {
    final color = context.p04StatusColor(status);

    return IntrinsicHeight(
      child: Row(
        key: ValueKey('my-report-tracker-${status.id}'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: reached ? color : AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: reached ? color : AppColors.inactiveTab,
                      width: 1.5,
                    ),
                  ),
                  child: reached
                      ? const Icon(
                          Icons.check,
                          size: 14,
                          color: AppColors.surface,
                        )
                      : null,
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      color: nextReached
                          ? color.withValues(alpha: 0.45)
                          : AppColors.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 2, bottom: isLast ? 0 : 14),
              child: Text(
                context.p04StatusLabel(status),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: current ? FontWeight.w800 : FontWeight.w600,
                  color: reached
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.calendar_today_outlined,
          size: 18,
          color: AppColors.ocean,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _VerifierNote extends StatelessWidget {
  const _VerifierNote({required this.note});

  final String? note;

  @override
  Widget build(BuildContext context) {
    final trimmed = note?.trim();
    final waiting = trimmed == null || trimmed.isEmpty;
    final message = waiting
        ? context.tr('my_reports.waiting_verification')
        : trimmed;
    final color = waiting ? AppColors.warning : AppColors.ocean;

    return Container(
      key: const ValueKey('my-report-verifier-note'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            waiting ? Icons.schedule : Icons.verified_outlined,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              key: waiting
                  ? const ValueKey('my-report-waiting-verification')
                  : null,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                fontWeight: waiting ? FontWeight.w600 : FontWeight.w500,
                color: waiting
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMap extends StatelessWidget {
  const _MiniMap({required this.report, required this.tileProvider});

  final Report report;
  final TileProvider? tileProvider;

  @override
  Widget build(BuildContext context) {
    final point = LatLng(report.latitude, report.longitude);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 160,
        child: Stack(
          children: [
            Positioned.fill(
              child: FlutterMap(
                key: const ValueKey('my-report-map'),
                options: MapOptions(
                  initialCenter: point,
                  initialZoom: 13,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                  backgroundColor: AppColors.ocean.withValues(alpha: 0.08),
                ),
                children: [
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
                        width: 44,
                        height: 44,
                        child: const Icon(
                          Icons.location_on,
                          key: ValueKey('my-report-marker'),
                          size: 40,
                          color: AppColors.coral,
                          shadows: [
                            Shadow(
                              color: Colors.black26,
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              right: 6,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                color: AppColors.surface.withValues(alpha: 0.82),
                child: const Text(
                  '© OpenStreetMap',
                  style: TextStyle(fontSize: 9, color: AppColors.textSecondary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpenActionsRow extends StatelessWidget {
  const _OpenActionsRow();

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(AppDimens.cardRadius);

    return Material(
      color: AppColors.ocean.withValues(alpha: 0.06),
      borderRadius: borderRadius,
      child: InkWell(
        key: const ValueKey('my-report-open-actions'),
        borderRadius: borderRadius,
        onTap: () {
          final router = GoRouter.of(context);
          Navigator.of(context).pop();
          router.go(Routes.actionAgenda);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            border: Border.all(color: AppColors.ocean.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.ocean.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.volunteer_activism_outlined,
                  size: 18,
                  color: AppColors.ocean,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('my_reports.open_actions'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.tr('my_reports.open_actions_hint'),
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.35,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, size: 20, color: AppColors.ocean),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompletionProofEmptyState extends StatelessWidget {
  const _CompletionProofEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('my-report-completion-proof-empty'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.tr('my_reports.completion_proof_missing'),
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletionProofDetails extends StatelessWidget {
  const _CompletionProofDetails({
    required this.proof,
    required this.languageCode,
  });

  final CompletionProof proof;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (proof.photoPaths.isEmpty)
          const _CompletionProofPhotoMissing()
        else
          _ReportPhoto(photoPaths: proof.photoPaths),
        const SizedBox(height: 12),
        Text(
          context.tr('my_reports.completion_proof_note'),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          proof.note,
          style: const TextStyle(
            fontSize: 14,
            height: 1.5,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        _CompletionProofInfoRow(
          icon: Icons.calendar_today_outlined,
          label: context.tr('my_reports.completion_date'),
          value: P04Format.date(proof.completedAt.toLocal(), languageCode),
        ),
        const SizedBox(height: 8),
        _CompletionProofInfoRow(
          icon: Icons.person_outline,
          label: context.tr('my_reports.completion_by'),
          value: proof.completedBy,
        ),
      ],
    );
  }
}

class _CompletionProofPhotoMissing extends StatelessWidget {
  const _CompletionProofPhotoMissing();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(AppDimens.padding),
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        ),
        child: Text(
          context.tr('my_reports.completion_photo_missing'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _CompletionProofInfoRow extends StatelessWidget {
  const _CompletionProofInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

/// One titled block of the detail sheet, with a soft panel behind it.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.ocean),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
