import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/filter_chip_row.dart';
import '../data/education_repository.dart';
import '../domain/education_article.dart';
import 'learn_article_detail_page.dart';
import 'widgets/article_card.dart';
import 'widgets/article_card_skeleton.dart';

const _learnCategories = [
  'semua',
  'polusi',
  'ekosistem',
  'perikanan_berkelanjutan',
  'kawasan_konservasi',
  'tersimpan',
];

const _savedCategory = 'tersimpan';

const _saveFailureMessage = 'p16_save_failed';
const _removeFailureMessage = 'p16_remove_saved_failed';
const _loadSavedFailureMessage = 'p16_saved_load_failed';

void _showLearnMessage(BuildContext context, String key) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(context.tr(key))));
}

/// P16 — Learn (`/learn`), public and reachable without signing in.
///
/// Three Material 3 tabs: Artikel, Infografis, Kuis. Only Artikel has content
/// in this stage; the other two explain that their content follows later.
class LearnPage extends StatefulWidget {
  const LearnPage({super.key, this.repository});

  final EducationRepository? repository;

  @override
  State<LearnPage> createState() => _LearnPageState();
}

class _LearnPageState extends State<LearnPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late Future<List<EducationArticle>> _articles;
  String? _languageCode;
  List<EducationArticle> _savedArticles = const [];
  EducationRepository get _repository =>
      widget.repository ?? MockEducationRepository();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final languageCode = Localizations.localeOf(context).languageCode;
    if (_languageCode == languageCode) return;
    _languageCode = languageCode;
    _articles = _repository.getArticles(languageCode: languageCode);
    _loadSavedArticles(languageCode);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.explore);
    }
  }

  Future<void> _loadSavedArticles(String languageCode) async {
    try {
      final saved = await _repository.getSavedArticles(
        languageCode: languageCode,
      );
      if (!mounted) return;
      setState(() {
        _savedArticles = saved;
      });
    } catch (error) {
      if (!mounted) return;
      _showLearnMessage(context, _loadSavedFailureMessage);
    }
  }

  void _reloadArticles() {
    final languageCode = _languageCode ?? 'id';
    setState(() {
      _articles = _repository.getArticles(languageCode: languageCode);
    });
    _loadSavedArticles(languageCode);
  }

  Future<void> _toggleSaved(EducationArticle article) async {
    final isSaved = _savedArticles.any((saved) => saved.id == article.id);
    try {
      if (isSaved) {
        await _repository.removeArticle(article.id);
      } else {
        await _repository.saveArticle(article);
      }
      await _loadSavedArticles(_languageCode ?? 'id');
    } catch (_) {
      if (!mounted) return;
      _showLearnMessage(
        context,
        isSaved ? _removeFailureMessage : _saveFailureMessage,
      );
    }
  }

  Future<void> _openArticle(EducationArticle article) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LearnArticleDetailPage(
          article: article,
          repository: _repository,
          initiallySaved: _savedArticles.any((saved) => saved.id == article.id),
          onSavedChanged: () => _loadSavedArticles(_languageCode ?? 'id'),
        ),
      ),
    );
    if (mounted) await _loadSavedArticles(_languageCode ?? 'id');
  }

  Future<void> _openArticleById(String id) async {
    final saved = _savedArticles.where((article) => article.id == id);
    if (saved.isNotEmpty) {
      await _openArticle(saved.first);
      return;
    }
    try {
      final article = await _repository.getArticleById(
        id,
        languageCode: _languageCode ?? 'id',
      );
      if (!mounted) return;
      if (article == null) {
        await _openArticleNotFound();
        return;
      }
      await _openArticle(article);
    } catch (_) {
      if (!mounted) return;
      await _openArticleNotFound();
    }
  }

  Future<void> _openArticleNotFound() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            LearnArticleDetailPage.notFound(onRetry: _reloadArticles),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _back(context),
        ),
        title: Text(context.tr('learn.title')),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: context.tr('learn.tab.articles')),
            Tab(text: context.tr('learn.tab.infographics')),
            Tab(text: context.tr('learn.tab.quiz')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ArticlesTab(
            articles: _articles,
            repository: _repository,
            onRetry: _reloadArticles,
            onArticleTap: _openArticleById,
            savedArticles: _savedArticles,
            onSavedChanged: _toggleSaved,
          ),
          _LearnPlaceholder(
            icon: Icons.insights_outlined,
            titleKey: 'learn.tab.infographics',
            bodyKey: 'learn.infographics.body',
          ),
          _LearnPlaceholder(
            icon: Icons.quiz_outlined,
            titleKey: 'learn.tab.quiz',
            bodyKey: 'learn.quiz.body',
          ),
        ],
      ),
    );
  }
}

class _ArticlesTab extends StatefulWidget {
  const _ArticlesTab({
    required this.articles,
    required this.repository,
    required this.onRetry,
    required this.onArticleTap,
    required this.savedArticles,
    required this.onSavedChanged,
  });

  final Future<List<EducationArticle>> articles;
  final EducationRepository repository;
  final VoidCallback onRetry;
  final ValueChanged<String> onArticleTap;
  final List<EducationArticle> savedArticles;
  final Future<void> Function(EducationArticle article) onSavedChanged;

  @override
  State<_ArticlesTab> createState() => _ArticlesTabState();
}

class _ArticlesTabState extends State<_ArticlesTab> {
  String _selectedCategory = 'semua';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<EducationArticle>>(
      future: widget.articles,
      builder: (context, snapshot) {
        return Column(
          children: [
            const SizedBox(height: 8),
            FilterChipRow(
              options: [
                for (final category in _learnCategories)
                  ChipOption(
                    id: category,
                    label: category == _savedCategory
                        ? context.tr('p16_saved')
                        : context.tr(
                            category == 'semua'
                                ? 'learn.category.all'
                                : 'learn.category.$category',
                          ),
                  ),
              ],
              selectedId: _selectedCategory,
              onSelected: (category) {
                setState(() => _selectedCategory = category);
              },
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildBody(context, snapshot)),
          ],
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    AsyncSnapshot<List<EducationArticle>> snapshot,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return ListView(
        padding: const EdgeInsets.all(AppDimens.padding),
        children: const [
          ArticleCardSkeleton(),
          SizedBox(height: AppDimens.gap),
          ArticleCardSkeleton(),
        ],
      );
    }

    final source = snapshot.hasError
        ? widget.savedArticles
        : snapshot.data ?? const <EducationArticle>[];
    if (_selectedCategory == _savedCategory && widget.savedArticles.isEmpty) {
      return EmptyState(
        icon: Icons.bookmark_outline,
        message: context.tr('p16_empty_saved'),
      );
    }
    if (snapshot.hasError && source.isEmpty) {
      return ErrorState(onRetry: widget.onRetry);
    }

    final items = _selectedCategory == _savedCategory
        ? widget.savedArticles
        : widget.repository.filterArticles(source, category: _selectedCategory);
    if (items.isEmpty) {
      return EmptyState(
        icon: _selectedCategory == _savedCategory
            ? Icons.bookmark_outline
            : Icons.search_off,
        message: context.tr(
          _selectedCategory == _savedCategory
              ? 'p16_empty_saved'
              : 'learn.emptyCategory',
        ),
      );
    }

    return ListView.separated(
      key: const PageStorageKey<String>('learn-articles'),
      padding: const EdgeInsets.all(AppDimens.padding),
      itemCount: items.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppDimens.gap),
      itemBuilder: (context, index) {
        final article = items[index];
        final saved = widget.savedArticles.any(
          (candidate) => candidate.id == article.id,
        );
        return ArticleCard(
          article: article,
          saved: saved,
          onSavedChanged: () => widget.onSavedChanged(article),
          onTap: () => widget.onArticleTap(article.id),
        );
      },
    );
  }
}

class _LearnPlaceholder extends StatelessWidget {
  const _LearnPlaceholder({
    required this.icon,
    required this.titleKey,
    required this.bodyKey,
  });

  final IconData icon;
  final String titleKey;
  final String bodyKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.ocean.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 36, color: AppColors.ocean),
              ),
              const SizedBox(height: 16),
              Text(
                context.tr(titleKey),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.tr(bodyKey),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
