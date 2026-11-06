import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/education_article.dart';

const double _gap = 8;

class ArticleCard extends StatelessWidget {
  const ArticleCard({
    super.key,
    required this.article,
    this.onTap,
    this.saved = false,
    this.onSavedChanged,
  });

  final EducationArticle article;
  final VoidCallback? onTap;
  final bool saved;
  final Future<void> Function()? onSavedChanged;

  @override
  Widget build(BuildContext context) {
    final localeCode = Localizations.localeOf(context).languageCode;
    final readingTime = context.tr('learn.readingTime', {
      'n': '${article.readingMinutes}',
    });
    final published = Formatters.shortDate(article.publishedAt, localeCode);

    return Card(
      key: ValueKey('learn-article-${article.id}'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        article.imageAsset,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _ImagePlaceholder(),
                      ),
                      Positioned(
                        left: 12,
                        top: 12,
                        child: _CategoryChip(category: article.category),
                      ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Material(
                          color: Colors.black.withValues(alpha: 0.28),
                          shape: const CircleBorder(),
                          child: IconButton(
                            key: ValueKey('learn-article-save-${article.id}'),
                            tooltip: context.tr(
                              saved ? 'p16_remove_saved' : 'p16_save',
                            ),
                            icon: Icon(
                              saved ? Icons.bookmark : Icons.bookmark_outline,
                              color: Colors.white,
                            ),
                            onPressed: onSavedChanged,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: _gap),
              Text(
                article.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: _gap),
              Text(
                article.summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: _gap),
              _MetaRow(
                icon: Icons.schedule,
                text: '$readingTime · $published',
              ),
              const SizedBox(height: _gap),
              _MetaRow(
                icon: Icons.person_outline,
                text: context.tr('learn.byAuthor', {'author': article.author}),
              ),
              const SizedBox(height: _gap),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.tr('learn.readMore'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ocean,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward,
                    size: 20,
                    color: AppColors.ocean,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
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

class _ImagePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: AppColors.textSecondary,
          size: 32,
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        context.tr('learn.category.$category'),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.ocean,
        ),
      ),
    );
  }
}
