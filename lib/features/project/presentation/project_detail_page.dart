import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/progress_bar.dart';
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
      if (project == null) {
        setState(() => _error = true);
      } else {
        setState(() {
          _project = project;
          _loading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
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
            leading: const BackButton(),
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
        child: FilledButton.icon(
          onPressed: () => context.push('/donate/${project.id}'),
          icon: const Icon(Icons.favorite),
          label: Text(context.tr('project.donate')),
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
          // Dot indicator.
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < project.galleryColors.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _galleryIndex == i ? 18 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: _galleryIndex == i
                          ? AppColors.ocean
                          : AppColors.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
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
                if (project.orgVerified) const VerifiedBadge(),
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
      ],
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
