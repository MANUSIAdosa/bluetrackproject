import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/error_state.dart';
import '../data/education_repository.dart';
import '../domain/education_article.dart';

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

  @override
  void initState() {
    super.initState();
    _saved = widget.initiallySaved;
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

  void _showMessage(BuildContext context, String key) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(context.tr(key))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(context.tr('p16_detail_title')),
        actions: [
          if (widget.article != null && widget.repository != null)
            IconButton(
              key: const ValueKey('p16-detail-save'),
              tooltip: context.tr(_saved ? 'p16_remove_saved' : 'p16_save'),
              icon: Icon(_saved ? Icons.bookmark : Icons.bookmark_outline),
              onPressed: _toggleSaved,
            ),
        ],
      ),
      body: widget.notFound || widget.article == null
          ? ErrorState(
              message: context.tr('p16_article_not_found'),
              onRetry: widget.onRetry,
            )
          : _DetailBody(article: widget.article!, onShare: _share),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.article, required this.onShare});

  final EducationArticle article;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final languageCode = Localizations.localeOf(context).languageCode;
    final paragraphs = article.content.split(RegExp(r'\n\s*\n'));

    return ListView(
      key: const ValueKey('p16-detail-scroll'),
      padding: const EdgeInsets.fromLTRB(
        AppDimens.padding,
        0,
        AppDimens.padding,
        AppDimens.padding,
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
        const SizedBox(height: AppDimens.padding),
        for (final paragraph in paragraphs) ...[
          Text(
            paragraph,
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppDimens.gap),
        ],
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onShare,
            icon: const Icon(Icons.share_outlined),
            label: Text(context.tr('p16_share')),
          ),
        ),
      ],
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
        Text(
          text,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
