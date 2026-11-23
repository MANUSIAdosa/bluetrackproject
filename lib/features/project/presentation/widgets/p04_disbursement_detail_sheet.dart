import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../explore/data/disbursement_repository.dart';
import '../../domain/data_failure.dart';
import '../../domain/disbursement.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../p04_format.dart';

/// Opens the P04 fund disbursement detail as a modal bottom sheet.
///
/// Only [disbursementId] is passed in; the sheet loads the disbursement itself
/// so it can show a skeleton while the repository responds and an error state
/// when the id no longer exists. No named route is added.
Future<void> showP04DisbursementDetailSheet(
  BuildContext context, {
  required String disbursementId,
  required DisbursementRepository repository,
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
            height: available * 0.94,
            child: _DisbursementDetailSheet(
              disbursementId: disbursementId,
              repository: repository,
            ),
          );
        },
      );
    },
  );
}

class _DisbursementDetailSheet extends StatefulWidget {
  const _DisbursementDetailSheet({
    required this.disbursementId,
    required this.repository,
  });

  final String disbursementId;
  final DisbursementRepository repository;

  @override
  State<_DisbursementDetailSheet> createState() =>
      _DisbursementDetailSheetState();
}

class _DisbursementDetailSheetState extends State<_DisbursementDetailSheet> {
  late Future<Disbursement> _disbursement;

  @override
  void initState() {
    super.initState();
    _disbursement = widget.repository.getDisbursementById(widget.disbursementId);
  }

  @override
  void didUpdateWidget(covariant _DisbursementDetailSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.disbursementId != widget.disbursementId ||
        oldWidget.repository != widget.repository) {
      _disbursement = widget.repository.getDisbursementById(widget.disbursementId);
    }
  }

  void _retry() {
    setState(() {
      _disbursement = widget.repository.getDisbursementById(widget.disbursementId);
    });
  }

  @override
  Widget build(BuildContext context) {
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
                  context.tr('p04_disbursement_detail_title'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('p04-disbursement-detail-close'),
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
          child: FutureBuilder<Disbursement>(
            future: _disbursement,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const _DisbursementDetailSkeleton();
              }
              if (snapshot.hasError) {
                final notFound =
                    snapshot.error is DisbursementNotFoundException;
                return ErrorState(
                  message: notFound
                      ? context.tr('p04_detail_not_found')
                      : context.tr('p04_disbursement_error'),
                  onRetry: _retry,
                );
              }
              if (!snapshot.hasData) return const _DisbursementDetailSkeleton();
              return _DisbursementDetailContent(
                disbursement: snapshot.data!,
                lang: Localizations.localeOf(context).languageCode,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DisbursementDetailSkeleton extends StatelessWidget {
  const _DisbursementDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('p04-disbursement-detail-skeleton'),
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
      ],
    );
  }
}

class _DisbursementDetailContent extends StatelessWidget {
  const _DisbursementDetailContent({
    required this.disbursement,
    required this.lang,
  });

  final Disbursement disbursement;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final color = switch (disbursement.status) {
      DisbursementStatus.disalurkan => AppColors.success,
      DisbursementStatus.menunggu => AppColors.warning,
    };
    final statusLabel = context.tr(
      disbursement.status == DisbursementStatus.disalurkan
          ? 'p04_disbursement_status_disbursed'
          : 'p04_disbursement_status_pending',
    );
    return ListView(
      key: const ValueKey('p04-disbursement-detail-scroll'),
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
        _DisbursementPhoto(proofPhoto: disbursement.proofPhoto),
        const SizedBox(height: AppDimens.gap),
        Text(
          disbursement.category,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppDimens.gap),
        Wrap(
          spacing: AppDimens.gap,
          runSpacing: AppDimens.gap,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDimens.cardRadius),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    disbursement.status == DisbursementStatus.disalurkan
                        ? Icons.check_circle_outline
                        : Icons.schedule_outlined,
                    size: 14,
                    color: color,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.gap),
        Row(
          children: [
            Text(
              context.tr('p04_disbursement_detail_amount'),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              Formatters.currency(disbursement.amount, lang),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.ocean,
              ),
            ),
          ],
        ),
        _DetailRow(
          icon: Icons.person_outline,
          label: context.tr('p04_disbursement_detail_executor'),
          value: disbursement.executor,
        ),
        _DetailRow(
          icon: Icons.schedule_outlined,
          label: context.tr('p04_disbursement_detail_date'),
          value: P04Format.dateTime(disbursement.dueDate.toLocal(), lang),
        ),
      ],
    );
  }
}

class _DisbursementPhoto extends StatelessWidget {
  const _DisbursementPhoto({required this.proofPhoto});

  final String proofPhoto;

  @override
  Widget build(BuildContext context) {
    if (proofPhoto.isEmpty) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          color: AppColors.border,
          alignment: Alignment.center,
          child: const Icon(
            Icons.broken_image_outlined,
            color: AppColors.textSecondary,
            size: 32,
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimens.cardRadius),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.asset(
          proofPhoto,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: AppColors.border,
            alignment: Alignment.center,
            child: const Icon(
              Icons.broken_image_outlined,
              color: AppColors.textSecondary,
              size: 32,
            ),
          ),
        ),
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
