import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/error_state.dart';
import '../data/education_repository.dart';
import '../domain/education_article.dart';
import 'l10n/learn_detail_strings.dart';

/// Reader text sizes offered from the app bar: small, normal, large.
const List<double> _bodyFontSizes = [13, 14, 16];

/// Shared for the lifetime of the app session so a choice made on one article
/// also applies to the next article the reader opens.
int _preferredTextSizeIndex = 1;

class LearnArticleDetailPage extends StatefulWidget {
  const LearnArticleDetailPage({
    super.key,
    required this.article,
    this.repository,
    this.initiallySaved = false,
    this.onSavedChanged,
    this.notFound = false,
    this.onRetry,
  });

  const LearnArticleDetailPage.notFound({
    super.key,
    this.repository,
    this.onRetry,
  }) : article = null,
       initiallySaved = false,
       onSavedChanged = null,
       notFound = true;

  final EducationArticle? article;
  final EducationRepository? repository;
  final bool initiallySaved;
  final VoidCallback? onSavedChanged;
  final bool notFound;
  final VoidCallback? onRetry;

  @override
  State<LearnArticleDetailPage> createState() => _LearnArticleDetailPageState();
}

class _LearnArticleDetailPageState extends State<LearnArticleDetailPage> {
  late bool _saved;
  late int _textSizeIndex;
  late final ScrollController _scrollController;
  final ValueNotifier<double> _readingProgress = ValueNotifier<double>(0);
  List<EducationArticle> _related = const [];
  String? _relatedLanguageCode;
  bool _openingRelated = false;

  @override
  void initState() {
    super.initState();
    _saved = widget.initiallySaved;
    _textSizeIndex = _preferredTextSizeIndex;
    _scrollController = ScrollController()..addListener(_updateReadingProgress);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final languageCode = Localizations.localeOf(context).languageCode;
    if (_relatedLanguageCode == languageCode) return;
    _relatedLanguageCode = languageCode;
    _loadRelated(languageCode);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_updateReadingProgress)
      ..dispose();
    _readingProgress.dispose();
    super.dispose();
  }

  void _updateReadingProgress() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final maxExtent = position.maxScrollExtent;
    final value = maxExtent <= 0
        ? 0.0
        : (position.pixels / maxExtent).clamp(0.0, 1.0);
    if ((_readingProgress.value - value).abs() > 0.0001) {
      _readingProgress.value = value;
    }
  }

  Future<void> _loadRelated(String languageCode) async {
    final article = widget.article;
    final repository = widget.repository;
    final ids = article?.relatedIds ?? const <String>[];
    if (article == null || repository == null || ids.isEmpty) return;

    try {
      final resolved = await Future.wait([
        for (final id in ids.take(3))
          repository.getArticleById(id, languageCode: languageCode),
      ]);
      if (!mounted) return;
      setState(() {
        _related = [for (final item in resolved) ?item];
      });
    } catch (_) {
      // Related cards are an enhancement; a failed lookup must not hide the
      // rest of an otherwise readable article.
      if (!mounted) return;
      setState(() => _related = const []);
    }
  }

  Future<void> _toggleSaved() async {
    final article = widget.article;
    final repository = widget.repository;
    if (article == null || repository == null) return;
    final nextSaved = !_saved;
    try {
      if (nextSaved) {
        await repository.saveArticle(article);
      } else {
        await repository.removeArticle(article.id);
      }
      if (!mounted) return;
      setState(() => _saved = nextSaved);
      widget.onSavedChanged?.call();
    } catch (_) {
      if (!mounted) return;
      _showMessage(
        context,
        nextSaved ? 'p16_save_failed' : 'p16_remove_saved_failed',
      );
    }
  }

  Future<void> _share() async {
    final article = widget.article;
    if (article == null) return;
    // TODO: Replace clipboard copy with the system share feature.
    await Clipboard.setData(
      ClipboardData(text: 'https://bluetrack.app/learn/${article.id}'),
    );
    if (!mounted) return;
    _showMessage(context, 'p16_share_copied');
  }

  void _setTextSize(int index) {
    if (index == _textSizeIndex) return;
    setState(() => _textSizeIndex = index);
    _preferredTextSizeIndex = index;
  }

  Future<void> _openRelated(EducationArticle related) async {
    final repository = widget.repository;
    if (repository == null || _openingRelated) return;

    setState(() => _openingRelated = true);
    var initiallySaved = false;
    try {
      final saved = await repository.getSavedArticles(
        languageCode: Localizations.localeOf(context).languageCode,
      );
      initiallySaved = saved.any((item) => item.id == related.id);
    } catch (_) {
      // The save state is cosmetic here; the article can still be opened.
    }
    if (!mounted) return;
    setState(() => _openingRelated = false);

    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => LearnArticleDetailPage(
          article: related,
          repository: repository,
          initiallySaved: initiallySaved,
          onSavedChanged: widget.onSavedChanged,
        ),
      ),
    );
  }

  void _showMessage(BuildContext context, String key) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(context.tr(key))));
  }

  List<PopupMenuEntry<int>> _textSizeItems(
    LearnDetailStrings strings,
    ColorScheme scheme,
  ) {
    return [
      _textSizeItem(0, strings.small, 13, scheme),
      _textSizeItem(1, strings.medium, 14, scheme),
      _textSizeItem(2, strings.large, 16, scheme),
    ];
  }

  CheckedPopupMenuItem<int> _textSizeItem(
    int index,
    String label,
    int size,
    ColorScheme scheme,
  ) {
    return CheckedPopupMenuItem<int>(
      key: ValueKey('p16-text-size-$size'),
      value: index,
      checked: _textSizeIndex == index,
      child: Text(
        '$label · ${size}sp',
        style: TextStyle(
          fontSize: 14,
          fontWeight: _textSizeIndex == index
              ? FontWeight.w700
              : FontWeight.w500,
          color: _textSizeIndex == index
              ? scheme.primary
              : AppColors.textPrimary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final article = widget.article;
    final strings = LearnDetailStrings.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(context.tr('p16_detail_title')),
        actions: [
          if (article != null)
            PopupMenuButton<int>(
              key: const ValueKey('p16-detail-text-size'),
              tooltip: strings.textSize,
              initialValue: _textSizeIndex,
              icon: const Icon(Icons.text_fields),
              onSelected: _setTextSize,
              itemBuilder: (context) => _textSizeItems(strings, scheme),
            ),
          if (article != null && widget.repository != null)
            IconButton(
              key: const ValueKey('p16-detail-save'),
              tooltip: context.tr(_saved ? 'p16_remove_saved' : 'p16_save'),
              icon: Icon(_saved ? Icons.bookmark : Icons.bookmark_outline),
              onPressed: _toggleSaved,
            ),
        ],
        bottom: article == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: ValueListenableBuilder<double>(
                  valueListenable: _readingProgress,
                  builder: (context, value, child) => LinearProgressIndicator(
                    key: const ValueKey('p16-reading-progress'),
                    value: value,
                    minHeight: 3,
                    backgroundColor: AppColors.border,
                    color: scheme.primary,
                  ),
                ),
              ),
      ),
      body: widget.notFound || article == null
          ? ErrorState(
              message: context.tr('p16_article_not_found'),
              onRetry: widget.onRetry,
            )
          : _DetailBody(
              article: article,
              onShare: _share,
              scrollController: _scrollController,
              bodyFontSize: _bodyFontSizes[_textSizeIndex],
              related: _related,
              onOpenRelated: widget.repository == null ? null : _openRelated,
            ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.article,
    required this.onShare,
    required this.scrollController,
    required this.bodyFontSize,
    required this.related,
    required this.onOpenRelated,
  });

  final EducationArticle article;
  final VoidCallback onShare;
  final ScrollController scrollController;
  final double bodyFontSize;
  final List<EducationArticle> related;
  final ValueChanged<EducationArticle>? onOpenRelated;

  @override
  Widget build(BuildContext context) {
    final languageCode = Localizations.localeOf(context).languageCode;
    final strings = LearnDetailStrings.of(context);
    final fallbackParagraphs = article.content
        .split(RegExp(r'\n\s*\n'))
        .where((paragraph) => paragraph.trim().isNotEmpty)
        .toList();

    return ListView(
      key: const ValueKey('p16-detail-scroll'),
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(
        AppDimens.padding,
        0,
        AppDimens.padding,
        24,
      ),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.asset(
              article.imageAsset,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const _ImagePlaceholder(),
            ),
          ),
        ),
        const SizedBox(height: AppDimens.gap),
        Align(
          alignment: Alignment.centerLeft,
          child: Chip(
            label: Text(context.tr('p16_category.${article.category}')),
            labelStyle: const TextStyle(
              color: AppColors.ocean,
              fontWeight: FontWeight.w700,
            ),
            backgroundColor: AppColors.ocean.withValues(alpha: 0.08),
            side: BorderSide.none,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          article.title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        ),
        if (article.author.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          _AuthorRow(
            key: const ValueKey('p16-author-row'),
            author: article.author,
          ),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            _MetaItem(
              icon: Icons.schedule,
              text: context.tr('p16_reading_time', {
                'n': '${article.readingMinutes}',
              }),
            ),
            _MetaItem(
              icon: Icons.calendar_today_outlined,
              text: context.tr('p16_published', {
                'date': Formatters.date(article.publishedAt, languageCode),
              }),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(height: 1, color: AppColors.border),
        const SizedBox(height: 20),
        if (article.keyPoints.isNotEmpty) ...[
          _KeyPointsCard(
            points: article.keyPoints.take(3).toList(),
            bodyFontSize: bodyFontSize,
          ),
          const SizedBox(height: 20),
        ],
        if (article.sections.isNotEmpty)
          for (var index = 0; index < article.sections.length; index++)
            _SectionBlock(
              key: ValueKey('p16-section-$index'),
              section: article.sections[index],
              bodyFontSize: bodyFontSize,
            )
        else
          for (final paragraph in fallbackParagraphs) ...[
            Text(
              paragraph,
              style: TextStyle(
                fontSize: bodyFontSize,
                height: 1.5,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppDimens.gap),
          ],
        if (article.funFact.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          _FunFactCard(fact: article.funFact, bodyFontSize: bodyFontSize),
          const SizedBox(height: 20),
        ],
        if (article.sources.isNotEmpty) ...[
          _SourcesSection(sources: article.sources),
          const SizedBox(height: 20),
        ],
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            key: const ValueKey('p16-share-button'),
            onPressed: onShare,
            icon: const Icon(Icons.share_outlined),
            label: Text(context.tr('p16_share')),
          ),
        ),
        if (related.isNotEmpty && onOpenRelated != null) ...[
          const SizedBox(height: 28),
          Text(
            strings.related,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          _RelatedArticles(articles: related, onOpen: onOpenRelated!),
        ],
      ],
    );
  }
}

class _AuthorRow extends StatelessWidget {
  const _AuthorRow({super.key, required this.author});

  final String author;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.person_outline,
          size: 16,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            context.tr('learn.byAuthor', {'author': author}),
            style: const TextStyle(
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _KeyPointsCard extends StatelessWidget {
  const _KeyPointsCard({required this.points, required this.bodyFontSize});

  final List<String> points;
  final double bodyFontSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final strings = LearnDetailStrings.of(context);

    return Container(
      key: const ValueKey('p16-key-points'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              key: const ValueKey('p16-key-points-accent'),
              width: 4,
              color: scheme.primary,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.push_pin_outlined,
                      size: 18,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        strings.keyPoints,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (var index = 0; index < points.length; index++)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: index == points.length - 1 ? 0 : 8,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(top: 7),
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            points[index],
                            style: TextStyle(
                              fontSize: bodyFontSize,
                              height: 1.45,
                              color: scheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
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

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({
    super.key,
    required this.section,
    required this.bodyFontSize,
  });

  final ArticleSection section;
  final double bodyFontSize;

  @override
  Widget build(BuildContext context) {
    final paragraphs = section.body
        .split(RegExp(r'\n\s*\n'))
        .where((paragraph) => paragraph.trim().isNotEmpty)
        .toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.heading,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.3,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          for (var index = 0; index < paragraphs.length; index++)
            Padding(
              padding: EdgeInsets.only(
                bottom: index == paragraphs.length - 1 ? 0 : 8,
              ),
              child: Text(
                paragraphs[index],
                style: TextStyle(
                  fontSize: bodyFontSize,
                  height: 1.5,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FunFactCard extends StatelessWidget {
  const _FunFactCard({required this.fact, required this.bodyFontSize});

  final String fact;
  final double bodyFontSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final strings = LearnDetailStrings.of(context);

    return Container(
      key: const ValueKey('p16-fun-fact'),
      padding: const EdgeInsets.all(AppDimens.padding),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lightbulb_outline,
            size: 24,
            color: scheme.onSecondaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.funFact,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  fact,
                  style: TextStyle(
                    fontSize: bodyFontSize,
                    height: 1.5,
                    color: scheme.onSecondaryContainer,
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

class _SourcesSection extends StatelessWidget {
  const _SourcesSection({required this.sources});

  final List<String> sources;

  @override
  Widget build(BuildContext context) {
    final strings = LearnDetailStrings.of(context);

    return Column(
      key: const ValueKey('p16-sources'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.sources,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        for (var index = 0; index < sources.length; index++)
          Padding(
            padding: EdgeInsets.only(
              bottom: index == sources.length - 1 ? 0 : 6,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${index + 1}.',
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    sources[index],
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RelatedArticles extends StatelessWidget {
  const _RelatedArticles({required this.articles, required this.onOpen});

  final List<EducationArticle> articles;
  final ValueChanged<EducationArticle> onOpen;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final extraHeight = ((textScale - 1).clamp(0.0, 0.8)) * 56;

    return SizedBox(
      height: 246 + extraHeight,
      child: ListView.separated(
        key: const ValueKey('p16-related-list'),
        scrollDirection: Axis.horizontal,
        itemCount: articles.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final article = articles[index];
          return _RelatedArticleCard(
            key: ValueKey('p16-related-${article.id}'),
            article: article,
            onTap: () => onOpen(article),
          );
        },
      ),
    );
  }
}

class _RelatedArticleCard extends StatelessWidget {
  const _RelatedArticleCard({
    super.key,
    required this.article,
    required this.onTap,
  });

  final EducationArticle article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.cardRadius),
          side: const BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 104,
                child: Image.asset(
                  article.imageAsset,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const _ImagePlaceholder(),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('learn.category.${article.category}'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                          color: AppColors.ocean,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: Text(
                          article.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule,
                            size: 12,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              context.tr('learn.readingTime', {
                                'n': '${article.readingMinutes}',
                              }),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: Center(
        child: Text(
          context.tr('p16_image_unavailable'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
