import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/state/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/progress_bar.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/verification_sheet.dart';
import '../../../shared/widgets/verified_badge.dart';
import '../../explore/domain/project.dart';
import '../../repositories.dart';

/// P04 — Project detail.
///
/// Deep link: `/project/:id?tab=reports` opens directly on the Reports tab.
class ProjectDetailPage extends StatefulWidget {
  const ProjectDetailPage({
    super.key,
    required this.projectId,
    this.initialTab,
  });

  final String projectId;

  /// Value of `?tab=` — 'reports' jumps to the Laporan tab.
  final String? initialTab;

  @override
  State<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends State<ProjectDetailPage>
    with SingleTickerProviderStateMixin {
  Project? _project;
  bool _loading = true;
  bool _error = false;
  int _galleryIndex = 0;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this)
      ..index = widget.initialTab == 'reports' ? 2 : 0;
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final project =
          await Repositories.projects.getProjectById(widget.projectId);
      if (!mounted) return;
      // `_loading` must always be cleared here, otherwise an unknown id leaves
      // the spinner on screen forever and ErrorState is never reached.
      setState(() {
        _loading = false;
        if (project == null) {
          _error = true;
        } else {
          _project = project;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: _ProjectDetailSkeleton());
    }
    if (_error || _project == null) {
      return Scaffold(
        appBar: AppBar(),
        body: ErrorState(onRetry: _load),
      );
    }
    final project = _project!;
    final lang = Localizations.localeOf(context).languageCode;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            leading: _CircleAppBarButton(
              icon: Icons.arrow_back,
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.go('/explore'),
            ),
            actions: [
              _CircleAppBarButton(
                icon: SavedProjectsController.instance.isSaved(project.id)
                    ? Icons.bookmark
                    : Icons.bookmark_outline,
                onPressed: () async {
                  await SavedProjectsController.instance.toggle(project.id);
                  if (!mounted) return;
                  setState(() {});
                },
              ),
              const SizedBox(width: 8),
            ],
            // Title fades in only once the gallery starts scrolling away.
            title: AnimatedOpacity(
              opacity: innerBoxIsScrolled ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: Text(
                project.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: _Gallery(
                colors: project.galleryColors,
                index: _galleryIndex,
                onPageChanged: (i) => setState(() => _galleryIndex = i),
              ),
            ),
          ),
          SliverToBoxAdapter(child: _buildHeader(project, lang)),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabController,
                tabs: [
                  Tab(text: context.tr('project.tab.about')),
                  Tab(text: context.tr('project.tab.budget')),
                  Tab(text: context.tr('project.tab.reports')),
                  Tab(text: context.tr('project.tab.reviews')),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _AboutTab(project: project),
            _BudgetTab(project: project, lang: lang),
            const _ReportsTab(),
            const _ReviewsTab(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: PrimaryButton(
          label: context.tr('project.donate'),
          icon: Icons.favorite,
          onPressed: () => context.push('/donate/${project.id}'),
        ),
      ),
    );
  }

  Widget _buildHeader(Project project, String lang) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Chip(
              label: Text(context.tr('cat.${project.category}')),
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            project.title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => context.push('/org/${project.orgId}'),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.ocean.withValues(alpha: 0.15),
                  child: const Icon(
                    Icons.business,
                    size: 16,
                    color: AppColors.ocean,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    project.orgName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (project.orgVerified)
                  VerifiedBadge(
                    onTap: () =>
                        showVerificationSheet(context, orgId: project.orgId),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _FundingCard(project: project, lang: lang),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Loading placeholder mirroring the real page layout: gallery, category chip,
/// title, org row, funding card.
class _ProjectDetailSkeleton extends StatelessWidget {
  const _ProjectDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Skeleton(height: 200, radius: 16),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: const Skeleton(width: 110, height: 26, radius: 13),
          ),
          const SizedBox(height: 12),
          const Skeleton(height: 20),
          const SizedBox(height: 8),
          const Skeleton(width: 220, height: 20),
          const SizedBox(height: 16),
          const Row(
            children: [
              Skeleton(width: 28, height: 28, radius: 14),
              SizedBox(width: 8),
              Expanded(child: Skeleton(height: 14)),
            ],
          ),
          const SizedBox(height: 16),
          const Skeleton(height: 120, radius: 16),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _FundingCard extends StatelessWidget {
  const _FundingCard({required this.project, required this.lang});

  final Project project;
  final String lang;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProgressBar(value: project.progress),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('project.raised'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      Formatters.currency(project.raisedAmount, lang),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ocean,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      context.tr('project.target'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      Formatters.currency(project.targetAmount, lang),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Gallery extends StatelessWidget {
  const _Gallery({
    required this.colors,
    required this.index,
    required this.onPageChanged,
  });

  final List<String> colors;
  final int index;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PageView.builder(
          itemCount: colors.length,
          onPageChanged: onPageChanged,
          itemBuilder: (context, i) => Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _hex(colors[i]),
                  _hex(colors[(i + 1) % colors.length]),
                ],
              ),
            ),
            child: const Center(
              child: Icon(Icons.image_outlined, size: 64, color: Colors.white70),
            ),
          ),
        ),
        // Photo counter (e.g. 1/3).
        Positioned(
          right: 12,
          bottom: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${index + 1}/${colors.length}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        // Dot indicator overlaid on the image.
        Positioned(
          left: 0,
          right: 0,
          bottom: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < colors.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: index == i ? 18 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: index == i ? Colors.white : Colors.white54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Circular icon button for the gallery app bar, with a translucent backdrop so
/// it stays readable over the image.
class _CircleAppBarButton extends StatelessWidget {
  const _CircleAppBarButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
        tooltip: tooltip,
        constraints: const BoxConstraints.tightFor(width: 40, height: 40),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

Color _hex(String hex) =>
    Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));

class _AboutTab extends StatelessWidget {
  const _AboutTab({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          project.description,
          style: const TextStyle(fontSize: 15, height: 1.6),
        ),
        const SizedBox(height: 12),
        for (final paragraph in project.about) ...[
          Text(
            paragraph,
            style: const TextStyle(fontSize: 15, height: 1.6),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 40),
      ],
    );
  }
}

class _BudgetTab extends StatelessWidget {
  const _BudgetTab({required this.project, required this.lang});

  final Project project;
  final String lang;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      context.tr('project.budget.item'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      context.tr('project.budget.amount'),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      context.tr('project.budget.percent'),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              for (final line in project.budget) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Text(
                          line.item,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          Formatters.currency(line.amount, lang),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${line.percent}%',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.ocean,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportsTab extends StatelessWidget {
  const _ReportsTab();

  @override
  Widget build(BuildContext context) {
    // TODO(impact-repository): load ImpactRepository.getReports(projectId)
    // when assigned in a later week.
    return EmptyState(
      icon: Icons.description_outlined,
      message: context.tr('project.reports.empty'),
    );
  }
}

class _ReviewsTab extends StatelessWidget {
  const _ReviewsTab();

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.rate_review_outlined,
      message: context.tr('project.reviews.empty'),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate(this.tabBar);

  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) =>
      Container(color: Colors.white, child: tabBar);

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => false;
}
