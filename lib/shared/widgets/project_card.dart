import 'dart:math' as math;

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

/// Project card used by Explore (vertical list + "for you" rail) and Org
/// Profile.
///
/// Every instance shows the same Donate CTA; only its width differs. The title
/// area is reserved for two lines, so a one-line and a two-line title produce
/// the same card height. All line heights are explicit, which lets
/// [heightFor] give the horizontal rail the exact cross-axis extent a
/// `ListView.separated` needs.
class ProjectCard extends StatelessWidget {
  const ProjectCard({
    super.key,
    required this.project,
    this.onSavedChanged,
  });

  static const double _gap4 = 4;
  static const double _gap8 = 8;
  static const double _gap12 = 12;
  static const double _padding = 16;
  static const double _donateHeight = 48;
  static const double _progressHeight = 8;

  static const double _titleSize = 16;
  static const double _titleHeight = 1.3;
  static const double _orgSize = 13;
  static const double _orgHeight = 1.3;
  static const double _locationSize = 12;
  static const double _locationHeight = 1.2;
  static const double _percentSize = 12;
  static const double _percentHeight = 1.2;
  static const double _amountSize = 15;
  static const double _amountHeight = 1.2;
  static const double _targetSize = 11;
  static const double _targetHeight = 1.2;
  static const double _iconSize = 14;
  static const double _badgeSize = 16;

  final Project project;
  final VoidCallback? onSavedChanged;

  static double _line(double size, double height, double scale) =>
      size * height * scale;

  static double _orgRowHeight(double scale) =>
      math.max(_line(_orgSize, _orgHeight, scale), _badgeSize);

  static double _locationRowHeight(double scale) =>
      math.max(_line(_locationSize, _locationHeight, scale), _iconSize);

  static double _titleAreaHeight(double scale) =>
      (_line(_titleSize, _titleHeight, scale) * 2).ceilToDouble();

  /// Exact height of the card at [width]. The horizontal rail cannot ask a
  /// `ListView` for an intrinsic height, so it asks the card instead.
  static double heightFor(BuildContext context, double width) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return width * 9 / 16 +
        _padding * 2 +
        _titleAreaHeight(scale) +
        _gap8 +
        _orgRowHeight(scale) +
        _gap4 +
        _locationRowHeight(scale) +
        _gap12 +
        _line(_percentSize, _percentHeight, scale) +
        _gap4 +
        _progressHeight +
        _gap12 +
        _line(_amountSize, _amountHeight, scale) +
        _line(_targetSize, _targetHeight, scale) +
        _gap12 +
        _donateHeight +
        1; // guard against fractional line heights
  }

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    final saved = SavedProjectsController.instance.isSaved(project.id);
    final percent = (project.progress * 100).round();
    final scale = MediaQuery.textScalerOf(context).scale(1);

    return Card(
      elevation: 0,
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
                  // 60% black at the top keeps white icons above 4.5:1 even on
                  // the lightest mock gallery colour.
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x99000000), Color(0x00000000)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: _gap12,
                    top: _gap12,
                    child: _CategoryBadge(category: project.category),
                  ),
                  Positioned(
                    top: _gap8,
                    right: _gap8,
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
              padding: const EdgeInsets.all(_padding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: _titleAreaHeight(scale),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        project.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: _titleSize,
                          height: _titleHeight,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: _gap8),
                  SizedBox(
                    height: _orgRowHeight(scale),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            project.orgName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: _orgSize,
                              height: _orgHeight,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        if (project.orgVerified)
                          const VerifiedBadge(compact: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: _gap4),
                  SizedBox(
                    height: _locationRowHeight(scale),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          size: _iconSize,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: _gap4),
                        Expanded(
                          child: Text(
                            project.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: _locationSize,
                              height: _locationHeight,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: _gap12),
                  Text(
                    context.tr('p03_percent_funded', {'n': '$percent'}),
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: _percentSize,
                      height: _percentHeight,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ocean,
                    ),
                  ),
                  const SizedBox(height: _gap4),
                  ProgressBar(
                    value: project.progress,
                    height: _progressHeight,
                  ),
                  const SizedBox(height: _gap12),
                  // Nominal and target stay on one line each; the ellipsis is a
                  // last-resort guard, the required widths fit without it.
                  Text(
                    Formatters.currency(project.raisedAmount, lang),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      height: _amountHeight,
                      fontWeight: FontWeight.w800,
                      fontSize: _amountSize,
                      color: AppColors.ocean,
                    ),
                  ),
                  Text(
                    '${context.tr('project.target')}: '
                    '${Formatters.currency(project.targetAmount, lang)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      height: _targetHeight,
                      fontSize: _targetSize,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: _gap12),
                  SizedBox(
                    width: double.infinity,
                    height: _donateHeight,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(_donateHeight),
                        padding: const EdgeInsets.symmetric(
                          horizontal: _padding,
                        ),
                      ),
                      onPressed: () =>
                          context.push('/donate/${project.id}'),
                      child: Text(context.tr('project.donate')),
                    ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
          const SizedBox(width: 4),
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
      shape: const CircleBorder(),
      child: IconButton(
        key: ValueKey('projectCard.save.${project.id}'),
        tooltip: context.tr(saved ? 'p03_saved' : 'p03_save'),
        isSelected: saved,
        icon: const Icon(Icons.bookmark_outline, color: Colors.white),
        selectedIcon: const Icon(Icons.bookmark, color: Colors.white),
        style: IconButton.styleFrom(
          minimumSize: const Size.square(48),
          maximumSize: const Size.square(48),
        ),
        onPressed: () async {
          await toggleSavedProject(project);
          onSavedChanged?.call();
        },
      ),
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
