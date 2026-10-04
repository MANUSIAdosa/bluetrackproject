import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/verified_badge.dart';
import '../../explore/domain/project.dart';
import '../../explore/presentation/widgets/project_card.dart';
import '../../repositories.dart';
import '../domain/organization.dart';

/// P05 — Organization profile.
class OrgProfilePage extends StatefulWidget {
  const OrgProfilePage({super.key, required this.orgId});

  final String orgId;

  @override
  State<OrgProfilePage> createState() => _OrgProfilePageState();
}

class _OrgProfilePageState extends State<OrgProfilePage> {
  Organization? _org;
  bool _loading = true;
  bool _error = false;

  List<Project> _projects = const [];
  bool _projectsLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
      _projectsLoading = true;
    });
    try {
      final org = await Repositories.organizations.getById(widget.orgId);
      final projects =
          await Repositories.projects.getProjectsByOrgId(widget.orgId);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _org = org;
        _error = org == null;
        _projects = projects;
        _projectsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      // Must clear `_loading`, otherwise a failed read leaves the spinner on
      // screen forever and ErrorState is never reached.
      setState(() {
        _loading = false;
        _error = true;
        _projectsLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: _OrgProfileSkeleton());
    }
    if (_error || _org == null) {
      return Scaffold(
        appBar: AppBar(),
        body: ErrorState(onRetry: _load),
      );
    }
    final org = _org!;
    final lang = Localizations.localeOf(context).languageCode;

    return Scaffold(
      appBar: AppBar(title: Text(org.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header.
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor:
                    _hex(org.color).withValues(alpha: 0.15),
                child: Icon(Icons.business, color: _hex(org.color)),
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
                      '${org.location} • '
                      '${context.tr('org.established', {'year': '${org.establishedYear}'})}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (org.verified) ...[
                      const SizedBox(height: 6),
                      const VerifiedBadge(),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Numeric summary card.
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Stat(
                    value: '${org.totalProjects}',
                    label: context.tr('org.stats.projects'),
                  ),
                  _Stat(
                    value: Formatters.currency(org.totalDisbursed, lang),
                    label: context.tr('org.stats.disbursed'),
                    // Currency needs more room than a plain count, otherwise
                    // it shrinks to an unreadable size on narrow screens.
                    flexible: true,
                  ),
                  _Stat(
                    value: '${org.communitiesServed}',
                    label: context.tr('org.stats.communities'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Verification checklist.
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('org.checklist.title'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final item in org.checklist)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: Icon(
                        item.done
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: item.done
                            ? AppColors.success
                            : AppColors.textSecondary,
                      ),
                      title: Text(context.tr('org.checklist.${item.key}')),
                    ),
                ],
              ),
            ),
          ),
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
          // Projects from this organization.
          Text(
            context.tr('org.projects.title'),
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          if (_projectsLoading)
            const Skeleton(height: 140, radius: 16)
          else if (_projects.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                context.tr('org.projects.empty'),
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            for (final project in _projects) ...[
              ProjectCard(
                project: project,
                onSavedChanged: () => setState(() {}),
              ),
              const SizedBox(height: 12),
            ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showMockNotice(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr('common.comingSoon'))),
    );
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
              Text(
                value,
                style: const TextStyle(fontSize: 15),
              ),
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

/// Loading placeholder mirroring the real page layout: header row, numeric
/// summary card, verification checklist.
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
          const Skeleton(height: 96, radius: 16),
          const SizedBox(height: 16),
          const Skeleton(height: 180, radius: 16),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    this.flexible = false,
  });

  final String value;
  final String label;

  /// When true the value needs extra width (long currency strings). A plain
  /// FittedBox would shrink it until it is unreadable on narrow screens, so
  /// this one takes a larger flex share and clips with an ellipsis instead.
  final bool flexible;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flexible ? 3 : 2,
      child: Column(
        crossAxisAlignment:
            flexible ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          if (flexible)
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.ocean,
              ),
            )
          else
            FittedBox(
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ocean,
                ),
              ),
            ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign:
                flexible ? TextAlign.start : TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

Color _hex(String hex) =>
    Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
