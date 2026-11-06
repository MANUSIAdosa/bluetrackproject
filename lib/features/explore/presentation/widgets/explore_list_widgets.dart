import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/project_card.dart';
import '../../domain/project.dart';

/// Local spacing scale (4/8/12/16/24). The theme is outside this change's
/// scope, so the Explore list keeps its own tokens here.
abstract final class ExploreSpacing {
  static const double x4 = 4;
  static const double x8 = 8;
  static const double x12 = 12;
  static const double x16 = 16;
  static const double x24 = 24;
}

/// Section heading used by the Jelajahi list. Horizontal page padding is the
/// caller's job, so both headings share the inset of the content below them.
Widget exploreSectionHeader(BuildContext context, String text) => Text(
  text,
  style: Theme.of(context).textTheme.titleLarge
      ?.copyWith(fontSize: 18, fontWeight: FontWeight.w800),
);

/// Horizontal "Untuk minatmu" rail.
///
/// The card shares the list's grid: on phones it spans the page margins, on
/// wide screens it is one column of the two-column list. It snaps one card at
/// a time and reports the visible card below the rail, so the swipe is
/// discoverable without a peeking card at the edge.
class ForYouRail extends StatefulWidget {
  const ForYouRail({
    super.key,
    required this.projects,
    required this.onSavedChanged,
  });

  final List<Project> projects;
  final VoidCallback onSavedChanged;

  @override
  State<ForYouRail> createState() => _ForYouRailState();
}

class _ForYouRailState extends State<ForYouRail> {
  final _controller = ScrollController();

  /// Extent of one card + gap, written by [build] so [_onScroll] can turn the
  /// offset back into a card index.
  double _itemExtent = 0;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(ForYouRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    _page = _page.clamp(0, math.max(0, widget.projects.length - 1));
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_itemExtent <= 0 || !_controller.hasClients) return;
    final page = (_controller.position.pixels / _itemExtent).round().clamp(
      0,
      widget.projects.length - 1,
    );
    if (page != _page) setState(() => _page = page);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 600;
        // Same grid as the list below: two equal columns and a 16dp gap from
        // 600dp, one full-width card under it.
        final cardWidth = wide
            ? (constraints.maxWidth - ExploreSpacing.x16 * 3) / 2
            : constraints.maxWidth - ExploreSpacing.x16 * 2;
        final itemExtent = cardWidth + ExploreSpacing.x16;
        _itemExtent = itemExtent;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: ProjectCard.heightFor(context, cardWidth),
              child: ListView.separated(
                key: const ValueKey('explore.forYouList'),
                controller: _controller,
                scrollDirection: Axis.horizontal,
                physics: _SnapToItemPhysics(itemExtent: itemExtent),
                padding: const EdgeInsets.symmetric(
                  horizontal: ExploreSpacing.x16,
                ),
                itemCount: widget.projects.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: ExploreSpacing.x16),
                itemBuilder: (context, index) => SizedBox(
                  width: cardWidth,
                  child: ProjectCard(
                    project: widget.projects[index],
                    rail: true,
                    onSavedChanged: widget.onSavedChanged,
                  ),
                ),
              ),
            ),
            if (widget.projects.length > 1) ...[
              const SizedBox(height: ExploreSpacing.x8),
              // "1 / 3" rather than dots: the number stays readable at large
              // text scales and says how many cards are left.
              Text(
                '${_page + 1} / ${widget.projects.length}',
                key: const ValueKey('explore.forYouPageIndicator'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Snaps a horizontal rail to whole item extents: `pixels` multiples of
/// [itemExtent] put the next card on the page margin after each swipe.
class _SnapToItemPhysics extends ScrollPhysics {
  const _SnapToItemPhysics({required this.itemExtent, super.parent});

  final double itemExtent;

  static final SpringDescription _spring = SpringDescription.withDampingRatio(
    mass: 0.5,
    stiffness: 100.0,
    ratio: 1.1,
  );

  @override
  _SnapToItemPhysics applyTo(ScrollPhysics? ancestor) =>
      _SnapToItemPhysics(itemExtent: itemExtent, parent: buildParent(ancestor));

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if (position.outOfRange) {
      return super.createBallisticSimulation(position, velocity);
    }
    final tolerance = toleranceFor(position);
    final snap = (position.pixels / itemExtent).roundToDouble() * itemExtent;
    final target = snap
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if ((position.pixels - target).abs() < 0.5 &&
        velocity.abs() < tolerance.velocity) {
      return super.createBallisticSimulation(position, velocity);
    }
    return ScrollSpringSimulation(
      _spring,
      position.pixels,
      target,
      velocity,
      tolerance: tolerance,
    );
  }
}
