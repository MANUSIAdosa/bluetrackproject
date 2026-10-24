import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/project_card.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/verified_badge.dart';
import '../../explore/data/project_repository.dart';
import '../../explore/domain/project.dart';
import '../../project/data/project_data_repositories.dart';
import '../../project/data/report_repository.dart';
import '../../project/domain/report.dart';
import '../../repositories.dart';
import '../data/organization_repository.dart';
import '../domain/organization.dart';

/// P05 - Organization and implementing-community profile.
///
/// The page works for formal organizations and for local communities. Both
/// kinds of profile use the same checklist format; a community simply also
/// reports its member count and the locations it manages.
class OrgProfilePage extends StatefulWidget {
  const OrgProfilePage({
    super.key,
    required this.orgId,
    this.organizationRepository,
    this.projectRepository,
    this.reportRepository,
  });

  final String orgId;

  /// Test/demo override for the organization data source.
  final OrganizationRepository? organizationRepository;

  /// Test/demo override for the location data source.
  final ProjectRepository? projectRepository;

  /// Test/demo override for the report data source.
  final ReportRepository? reportRepository;

  @override
  State<OrgProfilePage> createState() => _OrgProfilePageState();
}

class _OrgProfilePageState extends State<OrgProfilePage> {
  Organization? _org;
  OrganizationStats? _stats;
  List<_ManagedLocation> _locations = const [];
  List<String> _unavailableLocationIds = const [];
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final org =
          await (widget.organizationRepository ?? Repositories.organizations)
              .getById(widget.orgId);
      if (org == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = true;
          _org = null;
          _stats = null;
          _locations = const [];
          _unavailableLocationIds = const [];
        });
        return;
      }

      final projectRepository =
          widget.projectRepository ?? Repositories.projects;
      final reportRepository =
          widget.reportRepository ?? ProjectDataRepositories.reports;

      final managedIds = org.managedProjectIds;
      final resolvedProjects = managedIds == null
          ? await projectRepository.getProjectsByOrgId(org.id)
          : await _resolveManagedProjects(projectRepository, managedIds);

      // A profile may point at a location that is not in the project data
      // yet. Keep it visible as a disabled row and record it instead of
      // silently dropping it or inventing a route.
      final unavailableIds = <String>{
        if (managedIds != null)
          for (final id in managedIds)
            if (!resolvedProjects.any((project) => project.id == id)) id,
      }.toList();
      for (final id in unavailableIds) {
        debugPrint(
          'P05: managed location "$id" for organization "${org.id}" '
          'is unavailable.',
        );
      }

      final reportLists = await Future.wait(
        resolvedProjects.map(
          (project) => reportRepository.getReportsByLocation(
            project.id,
            verifiedOnly: true,
          ),
        ),
      );

      final locations = <_ManagedLocation>[
        for (var index = 0; index < resolvedProjects.length; index++)
          _ManagedLocation(
            project: resolvedProjects[index],
            latestVerifiedReport: _latestVerified(reportLists[index]),
          ),
      ];

      final stats = OrganizationStats.fromReports(
        locationCount: locations.length,
        reports: reportLists.expand((reports) => reports),
        memberCount: org.memberCount,
      );

      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = false;
        _org = org;
        _stats = stats;
        _locations = locations;
        _unavailableLocationIds = unavailableIds;
      });
    } catch (_) {
      if (!mounted) return;
      // Always clear the loading flag, otherwise a failed read leaves the
      // spinner on screen forever and ErrorState is never reached.
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  /// Resolves explicit location ids in order and drops duplicates.
  Future<List<Project>> _resolveManagedProjects(
    ProjectRepository repository,
    List<String> ids,
  ) async {
    final seen = <String>{};
    final ordered = <String>[
      for (final id in ids)
        if (seen.add(id)) id,
    ];
    final projects = await Future.wait(ordered.map(repository.getProjectById));
    return [for (final project in projects) ?project];
  }

  Report? _latestVerified(List<Report> reports) {
    Report? latest;
    for (final report in reports) {
      if (!report.hasPassedVerification) continue;
      if (latest == null || report.reportedAt.isAfter(latest.reportedAt)) {
        latest = report;
      }
    }
    return latest;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: _OrgProfileSkeleton());
    }
    if (_error || _org == null || _stats == null) {
      return Scaffold(
        appBar: AppBar(),
        body: ErrorState(onRetry: _load),
      );
    }

    final org = _org!;
    final stats = _stats!;
    final lang = Localizations.localeOf(context).languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(org.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _OrgHeader(org: org),
          const SizedBox(height: 16),
          _SummaryCard(org: org, stats: stats, lang: lang),
          const SizedBox(height: 16),
          _ChecklistCard(org: org),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _showMockNotice(context),
            icon: const Icon(Icons.download_outlined),
            label: Text(context.tr('org.downloadAudit')),
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: context.tr('org.contact'),
            icon: Icons.mail_outline,
            onPressed: () => _showContactSheet(context, org),
          ),
          const SizedBox(height: 24),
          Text(
            context.tr('org.locations.title'),
            key: const ValueKey('org-locations-title'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (_locations.isEmpty && _unavailableLocationIds.isEmpty)
            SizedBox(
              height: 220,
              child: EmptyState(
                key: const ValueKey('org-locations-empty'),
                icon: Icons.place_outlined,
                message: context.tr('org.locations.empty'),
              ),
            )
          else ...[
            for (final location in _locations) ...[
              ProjectCard(
                project: location.project,
                onSavedChanged: () => setState(() {}),
              ),
              _LocationCondition(location: location, lang: lang),
            ],
            for (final id in _unavailableLocationIds)
              _UnavailableLocationTile(id: id),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showMockNotice(BuildContext context) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.tr('common.comingSoon'))));
  }

  void _showContactSheet(BuildContext context, Organization org) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  org.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                _ContactRow(
                  icon: Icons.mail_outline,
                  label: context.tr('org.contact.email'),
                  value: org.email,
                ),
                const SizedBox(height: 12),
                _ContactRow(
                  icon: Icons.phone_outlined,
                  label: context.tr('org.contact.phone'),
                  value: org.phone,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Profile header: avatar, name, place/year, type chip and verification state.
class _OrgHeader extends StatelessWidget {
  const _OrgHeader({required this.org});

  final Organization org;

  @override
  Widget build(BuildContext context) {
    final color = _hex(org.color);
    final isCommunity = org.type == OrganizationType.community;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(
            isCommunity ? Icons.groups : Icons.business,
            color: color,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                org.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${org.location} \u00B7 '
                '${context.tr('org.established', {'year': '${org.establishedYear}'})}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _TypeChip(type: org.type),
                  if (org.verified)
                    const VerifiedBadge(
                      key: ValueKey('org-header-verified-badge'),
                    )
                  else
                    const _PendingVerificationBadge(),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Chip that distinguishes a formal organization from a local community.
class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.type});

  final OrganizationType type;

  @override
  Widget build(BuildContext context) {
    final isCommunity = type == OrganizationType.community;
    final color = isCommunity ? AppColors.teal : AppColors.ocean;

    return Chip(
      key: const ValueKey('org-type-chip'),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      backgroundColor: color.withValues(alpha: 0.10),
      side: BorderSide.none,
      avatar: Icon(
        isCommunity ? Icons.groups_outlined : Icons.business_outlined,
        size: 14,
        color: color,
      ),
      label: Text(
        context.tr(
          isCommunity ? 'org.type.community' : 'org.type.organization',
        ),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
      labelPadding: const EdgeInsets.only(left: 2, right: 6),
    );
  }
}

/// Shown instead of [VerifiedBadge] while a profile is still being reviewed.
class _PendingVerificationBadge extends StatelessWidget {
  const _PendingVerificationBadge();

  @override
  Widget build(BuildContext context) {
    return Chip(
      key: const ValueKey('org-pending-verification'),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      backgroundColor: AppColors.warning.withValues(alpha: 0.12),
      side: BorderSide.none,
      avatar: const Icon(Icons.schedule, size: 14, color: AppColors.warning),
      label: Text(
        context.tr('org.pendingVerification'),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.warning,
        ),
      ),
      labelPadding: const EdgeInsets.only(left: 2, right: 6),
    );
  }
}

/// Numeric summary. Report and waste totals come from verified reports, not
/// from fixed numbers in `organizations.json`.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.org,
    required this.stats,
    required this.lang,
  });

  final Organization org;
  final OrganizationStats stats;
  final String lang;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                // Two columns keep the four values readable at 320dp.
                final itemWidth = (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: itemWidth,
                      child: _Stat(
                        key: const ValueKey('org-stat-locations'),
                        valueKey: const ValueKey('org-stat-locations-value'),
                        icon: Icons.place_outlined,
                        value: Formatters.number(stats.locationCount, lang),
                        label: context.tr('org.stats.locations'),
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _Stat(
                        key: const ValueKey('org-stat-reports'),
                        valueKey: const ValueKey('org-stat-reports-value'),
                        icon: Icons.verified_outlined,
                        value: Formatters.number(
                          stats.verifiedReportCount,
                          lang,
                        ),
                        label: context.tr('org.stats.reports'),
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _Stat(
                        key: const ValueKey('org-stat-waste'),
                        valueKey: const ValueKey('org-stat-waste-value'),
                        icon: Icons.delete_outline,
                        value: context.tr('org.stats.wasteValue', {
                          'value': Formatters.number(stats.totalWasteKg, lang),
                        }),
                        label: context.tr('org.stats.waste'),
                      ),
                    ),
                    if (stats.memberCount > 0)
                      SizedBox(
                        width: itemWidth,
                        child: _Stat(
                          key: const ValueKey('org-stat-members'),
                          valueKey: const ValueKey('org-stat-members-value'),
                          icon: Icons.groups_outlined,
                          value: Formatters.number(stats.memberCount, lang),
                          label: context.tr('org.stats.members'),
                        ),
                      ),
                  ],
                );
              },
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Icon(
                  Icons.payments_outlined,
                  size: 18,
                  color: AppColors.ocean,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.tr('org.stats.disbursed'),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    Formatters.currency(org.totalDisbursed, lang),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ocean,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.valueKey,
  });

  final IconData icon;
  final String value;
  final String label;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.ocean),
        const SizedBox(height: 6),
        Text(
          value,
          key: valueKey,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.ocean,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

/// Verification checklist. Organizations and communities use the same four
/// [ChecklistItem] keys, so no new verification rule is introduced here.
class _ChecklistCard extends StatelessWidget {
  const _ChecklistCard({required this.org});

  final Organization org;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const ValueKey('org-checklist'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('org.checklist.title'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            for (final item in org.checklist)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(
                  item.done ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: item.done
                      ? AppColors.success
                      : AppColors.textSecondary,
                ),
                title: Text(context.tr('org.checklist.${item.key}')),
              ),
          ],
        ),
      ),
    );
  }
}

/// Condition of one managed location, derived from its latest verified report.
///
/// This sits below the unmodified [ProjectCard] so the card stays the single
/// shared location card used by Explore and P05.
class _LocationCondition extends StatelessWidget {
  const _LocationCondition({required this.location, required this.lang});

  final _ManagedLocation location;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final report = location.latestVerifiedReport;
    final (labelKey, color, icon) = switch (report?.severity) {
      ReportSeverity.low => (
        'p03_condition_baik',
        AppColors.success,
        Icons.check_circle_outline,
      ),
      ReportSeverity.medium => (
        'p03_condition_pemantauan',
        AppColors.warning,
        Icons.visibility_outlined,
      ),
      ReportSeverity.high => (
        'p03_condition_kritis',
        AppColors.danger,
        Icons.warning_amber_outlined,
      ),
      null => (
        'org.location.noReports',
        AppColors.textSecondary,
        Icons.info_outline,
      ),
    };

    return Container(
      key: ValueKey('org-location-condition-${location.project.id}'),
      margin: const EdgeInsets.only(top: 8, bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('org.location.condition'),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.tr(labelKey),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                if (report != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    context.tr('org.location.latestReport', {
                      'date': Formatters.date(report.reportedAt, lang),
                    }),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Disabled row for a managed location whose project data is not available.
///
/// It deliberately does not navigate: the P04 route is only opened through the
/// existing [ProjectCard] for a location that actually exists.
class _UnavailableLocationTile extends StatelessWidget {
  const _UnavailableLocationTile({required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: ValueKey('org-location-unavailable-$id'),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        enabled: false,
        leading: const Icon(Icons.location_off_outlined),
        title: Text(context.tr('org.locations.unavailable')),
        subtitle: Text(id),
      ),
    );
  }
}

class _ManagedLocation {
  const _ManagedLocation({required this.project, this.latestVerifiedReport});

  final Project project;
  final Report? latestVerifiedReport;
}

/// Email / phone row with a copy-to-clipboard action.
class _ContactRow extends StatelessWidget {
  const _ContactRow({
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
      children: [
        Icon(icon, size: 18, color: AppColors.ocean),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(value, style: const TextStyle(fontSize: 15)),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.copy, size: 18),
          tooltip: context.tr('common.copy'),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: value));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(content: Text(context.tr('common.copied'))),
              );
          },
        ),
      ],
    );
  }
}

/// Loading placeholder mirroring the real page layout: header row, summary
/// card, verification checklist and locations.
class _OrgProfileSkeleton extends StatelessWidget {
  const _OrgProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Row(
            children: [
              Skeleton(width: 56, height: 56, radius: 28),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(height: 18),
                    SizedBox(height: 8),
                    Skeleton(width: 180, height: 13),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Skeleton(height: 150, radius: 16),
          const SizedBox(height: 16),
          const Skeleton(height: 180, radius: 16),
          const SizedBox(height: 16),
          const Skeleton(height: 44, radius: 12),
          const SizedBox(height: 16),
          const Skeleton(height: 160, radius: 16),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

Color _hex(String hex) =>
    Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
