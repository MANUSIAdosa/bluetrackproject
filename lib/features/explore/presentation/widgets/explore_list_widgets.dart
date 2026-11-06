import 'dart:math' as math;

import 'package:flutter/material.dart';

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
/// It bleeds to the screen edges and snaps one card at a time: after a swipe
/// the active card's left edge rests on the page's 16dp margin, while the next
/// card peeks 16dp. Every card has the same height, so the rail takes the
/// card's own height instead of stretching children.
class ForYouRail extends StatelessWidget {
  const ForYouRail({
    super.key,
    required this.projects,
    required this.onSavedChanged,
  });

  final List<Project> projects;
  final VoidCallback onSavedChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // One card + one peek: 340 card + 16 left margin + 12 gap + 16 peek
        // = 384. Wider screens keep that width so the peek can never exceed
        // the card's own 16dp inner padding; otherwise the next card's text
        // would start showing at the edge.
        final viewport = math.min(
          constraints.maxWidth,
          340.0 + ExploreSpacing.x16 + ExploreSpacing.x12 + ExploreSpacing.x16,
        );
        // peek = viewport - (margin 16 + card + gap 12) = 16 = inner padding.
        final cardWidth =
            viewport -
            ExploreSpacing.x16 -
            ExploreSpacing.x12 -
            ExploreSpacing.x16;
        final itemExtent = cardWidth + ExploreSpacing.x12;

        return Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: viewport,
            height: ProjectCard.heightFor(context, cardWidth),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: _SnapToItemPhysics(itemExtent: itemExtent),
              // The extra 12dp on the right lets the last card reach the 16dp
              // margin when it snaps, instead of stopping short.
              padding: const EdgeInsets.only(
                left: ExploreSpacing.x16,
                right: ExploreSpacing.x16 + ExploreSpacing.x12,
              ),
              itemCount: projects.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(width: ExploreSpacing.x12),
              itemBuilder: (context, index) => SizedBox(
                width: cardWidth,
                child: ProjectCard(
                  project: projects[index],
                  rail: true,
                  onSavedChanged: onSavedChanged,
                ),
              ),
            ),
          ),
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
