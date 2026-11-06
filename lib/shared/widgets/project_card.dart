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
import 'wave_placeholder.dart';

/// Project card used by Explore (vertical list + "for you" rail) and Org
/// Profile.
///
/// The vertical list lets the card size to its content, so a one-line title
/// does not leave a reserved gap. The rail ([rail]) needs every card to be the
/// same height: it sits in a fixed-height row and pins the funding block to the
/// bottom, with the leftover space absorbed between the text and funding
/// blocks. All line heights are explicit so [heightFor] can give the rail the
/// exact cross-axis extent a horizontal `ListView` needs.
class ProjectCard extends StatelessWidget {
  const ProjectCard({
    super.key,
    required this.project,
    this.onSavedChanged,
    this.rail = false,
  });

  static const double _gap4 = 4;
  static const double _gap8 = 8;
  static const double _gap12 = 12;
  static const double _padding = 16;
  static const double _donateHeight = 48;
  static const double _progressHeight = 8;

  static const double _titleSize = 18;
  static const double _titleHeight = 1.3;
  static const double _orgSize = 14;
  static const double _orgHeight = 1.3;
  static const double _locationSize = 12;
  static const double _locationHeight = 1.2;
  static const double _percentSize = 12;
  static const double _percentHeight = 1.2;
  static const double _amountSize = 20;
  static const double _amountHeight = 1.2;
  static const double _targetSize = 12;
  static const double _targetHeight = 1.2;
  static const double _iconSize = 14;
  static const double _badgeSize = 16;

  final Project project;
  final VoidCallback? onSavedChanged;

  /// Rail mode: fixed height from [heightFor], bottom block pinned to the
  /// card's bottom edge. False lets the card follow its content.
  final bool rail;

  static double _line(double size, double height, double scale) =>
      size * height * scale;

  static double _orgRowHeight(double scale) =>
      math.max(_line(_orgSize, _orgHeight, scale), _badgeSize);

  static double _locationRowHeight(double scale) =>
      math.max(_line(_locationSize, _locationHeight, scale), _iconSize);

  static double _titleAreaHeight(double scale) =>
      (_line(_titleSize, _titleHeight, scale) * 2).ceilToDouble();

  /// Exact height of a rail card at [width]. The horizontal rail cannot ask a
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
        2; // guard against fractional line heights
  }

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    final saved = SavedProjectsController.instance.isSaved(project.id);
    final text = _CardText.of(context);

    final gallery = AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          WavePlaceholder(colors: project.galleryColors, seed: project.id),
          // 60% black at the top keeps white icons above 4.5:1 even on the
          // lightest mock gallery colour and the white wave bands.
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
            child: _CategoryBadge(category: project.category, text: text),
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
    );

    final body = Padding(
      padding: const EdgeInsets.all(_padding),
      child: _body(context, lang, text),
    );

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
          mainAxisSize: rail ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            gallery,
            if (rail) Expanded(child: body) else body,
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, String lang, _CardText text) {
    final percent = (project.progress * 100).round();

    return Column(
      mainAxisSize: rail ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top text block.
        Text(
          project.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: text.title,
        ),
        const SizedBox(height: _gap8),
        Row(
          children: [
            Expanded(
              child: Text(
                project.orgName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.org,
              ),
            ),
            if (project.orgVerified) const VerifiedBadge(compact: true),
          ],
        ),
        const SizedBox(height: _gap4),
        Row(
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
                style: text.location,
              ),
            ),
          ],
        ),
        // The rail absorbs its extra height here, between the text and the
        // funding block, so the bottom block sits on the card's bottom edge.
        if (rail) const Spacer() else const SizedBox(height: _gap12),
        // Bottom block.
        Text(
          context.tr('p03_percent_funded', {'n': '$percent'}),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.percent,
        ),
        const SizedBox(height: _gap4),
        SizedBox(
          width: double.infinity,
          child: ProgressBar(value: project.progress, height: _progressHeight),
        ),
        const SizedBox(height: _gap12),
        Text(
          Formatters.currency(project.raisedAmount, lang),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.amount,
        ),
        Text(
          '${context.tr('project.target')}: '
          '${Formatters.currency(project.targetAmount, lang)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.target,
        ),
        const SizedBox(height: _gap12),
        SizedBox(
          width: double.infinity,
          height: _donateHeight,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.ocean,
              minimumSize: const Size.fromHeight(_donateHeight),
              padding: const EdgeInsets.symmetric(horizontal: _padding),
            ),
            onPressed: () => context.push('/donate/${project.id}'),
            child: Text(context.tr('project.donate')),
          ),
        ),
      ],
    );
  }
}

/// Card typography derived from the app text theme. Sizes are the card scale
/// from the review; line-height factors are what [ProjectCard.heightFor] uses.
class _CardText {
  const _CardText({
    required this.title,
    required this.org,
    required this.location,
    required this.percent,
    required this.amount,
    required this.target,
    required this.badge,
  });

  factory _CardText.of(BuildContext context) {
    final base = Theme.of(context).textTheme;
    return _CardText(
      title: base.titleMedium?.copyWith(
        fontSize: ProjectCard._titleSize,
        fontWeight: FontWeight.w700,
        height: ProjectCard._titleHeight,
        color: AppColors.textPrimary,
      ),
      org: base.bodyMedium?.copyWith(
        fontSize: ProjectCard._orgSize,
        height: ProjectCard._orgHeight,
        color: AppColors.textSecondary,
      ),
      location: base.bodySmall?.copyWith(
        fontSize: ProjectCard._locationSize,
        height: ProjectCard._locationHeight,
        color: AppColors.textSecondary,
      ),
      percent: base.labelMedium?.copyWith(
        fontSize: ProjectCard._percentSize,
        fontWeight: FontWeight.w700,
        height: ProjectCard._percentHeight,
        color: AppColors.ocean,
      ),
      amount: base.headlineSmall?.copyWith(
        fontSize: ProjectCard._amountSize,
        fontWeight: FontWeight.w800,
        height: ProjectCard._amountHeight,
        color: AppColors.ocean,
      ),
      target: base.bodySmall?.copyWith(
        fontSize: ProjectCard._targetSize,
        height: ProjectCard._targetHeight,
        color: AppColors.textSecondary,
      ),
      badge: base.labelSmall?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
    );
  }

  final TextStyle? title;
  final TextStyle? org;
  final TextStyle? location;
  final TextStyle? percent;
  final TextStyle? amount;
  final TextStyle? target;
  final TextStyle? badge;
}

/// Category badge over the gallery: an 8dp colour dot plus the category name.
/// The glyphs belonged to the map markers; the card only needs the colour cue.
class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.category, required this.text});

  final String category;
  final _CardText text;

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
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: CategoryIcons.colorFor(category),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(context.tr('cat.$category'), style: text.badge),
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
    final animate = !MediaQuery.of(context).disableAnimations;

    return Material(
      color: Colors.black.withValues(alpha: 0.24),
      shape: const CircleBorder(),
      child: IconButton(
        key: ValueKey('projectCard.save.${project.id}'),
        tooltip: context.tr(saved ? 'p03_saved' : 'p03_save'),
        isSelected: saved,
        icon: AnimatedSwitcher(
          duration: animate ? const Duration(milliseconds: 150) : Duration.zero,
          transitionBuilder: (child, animation) =>
              ScaleTransition(scale: animation, child: child),
          child: Icon(
            saved ? Icons.bookmark : Icons.bookmark_outline,
            key: ValueKey(saved),
            color: Colors.white,
          ),
        ),
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
