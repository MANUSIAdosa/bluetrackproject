import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../features/explore/data/saved_project_store.dart';
import '../../features/explore/domain/project.dart';
import 'category_icon.dart';
import 'progress_bar.dart';
import 'verified_badge.dart';

/// Project card used by Explore (list + "for you" rail) and Org Profile.
///
/// The card sizes itself from its content; hosts that need a fixed height
/// (the horizontal rail) must measure it instead of guessing — see
/// `ForYouRail`.
class ProjectCard extends StatelessWidget {
  const ProjectCard({
    super.key,
    required this.project,
    this.onSavedChanged,
    this.showDonateButton = true,
  });

  final Project project;
  final VoidCallback? onSavedChanged;

  /// The donate CTA is an outlined button (the coral primary belongs to one
  /// button per screen). Horizontal cards hide it to stay compact.
  final bool showDonateButton;

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    final saved = SavedProjectsController.instance.isSaved(project.id);
    final percent = (project.progress * 100).round();

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: () => context.push('/project/${project.id}'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gallery placeholder (mock data has colors, not images).
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: _galleryGradient(project.galleryColors),
                    ),
                  ),
                  // Scrim keeps the white category badge readable on any
                  // gallery colour.
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x33000000), Colors.transparent],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: _CategoryBadge(category: project.category),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _SaveButton(
                      project: project,
                      saved: saved,
                      onSavedChanged: onSavedChanged,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          project.orgName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      if (project.orgVerified)
                        const VerifiedBadge(compact: true),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.place_outlined,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          project.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.tr('p03_percent_funded', {'n': '$percent'}),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ocean,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ProgressBar(value: project.progress),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              Formatters.currency(project.raisedAmount, lang),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: AppColors.ocean,
                              ),
                            ),
                            Text(
                              '${context.tr('project.target')}: '
                              '${Formatters.currency(project.targetAmount, lang)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (showDonateButton) ...[
                        const SizedBox(width: 12),
                        _DonateButton(projectId: project.id),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Category badge over the gallery: the same glyph and colour the map markers
/// and the category selector use.
class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CategoryIcon(category: category, size: 14),
          const SizedBox(width: 6),
          Text(
            context.tr('cat.$category'),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Frosted bookmark over the gallery. One tap flips the saved id *and* writes
/// the offline snapshot the saved collection reads offline.
class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.project,
    required this.saved,
    this.onSavedChanged,
  });

  final Project project;
  final bool saved;
  final VoidCallback? onSavedChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.24),
      shape: CircleBorder(
        side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: IconButton(
        key: ValueKey('projectCard.save.${project.id}'),
        tooltip: context.tr(saved ? 'p03_saved' : 'p03_save'),
        icon: Icon(
          saved ? Icons.bookmark : Icons.bookmark_outline,
          color: Colors.white,
        ),
        onPressed: () async {
          await toggleSavedProject(project);
          onSavedChanged?.call();
        },
      ),
    );
  }
}

/// Outlined donate CTA → the existing donation route for that project.
class _DonateButton extends StatelessWidget {
  const _DonateButton({required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      onPressed: () => context.push('/donate/$projectId'),
      child: Text(context.tr('project.donate')),
    );
  }
}

Color _hexToColor(String hex) {
  final normalized = hex.replaceFirst('#', '');
  return Color(int.parse('FF$normalized', radix: 16));
}

/// Gallery gradient from the mock colours.
///
/// A single colour is a valid mock entry but `LinearGradient` asserts on fewer
/// than two stops, so the colour is repeated instead of crashing the card.
LinearGradient _galleryGradient(List<String> colors) {
  final parsed = colors.isEmpty
      ? const [AppColors.ocean, AppColors.teal]
      : colors.map(_hexToColor).toList();
  return LinearGradient(
    colors: parsed.length >= 2 ? parsed : [parsed.first, parsed.first],
  );
}
