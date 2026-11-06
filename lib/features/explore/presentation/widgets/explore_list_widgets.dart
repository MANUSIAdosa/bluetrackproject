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

/// A conventional horizontal, freely scrolling row of recommended projects.
/// Cards have a fixed width so the next card is visible as a hint to swipe.
class ForYouList extends StatelessWidget {
  const ForYouList({
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
        final cardWidth = math.min(320.0, constraints.maxWidth * 0.82);
        return SizedBox(
          height: ProjectCard.heightFor(context, cardWidth),
          child: ListView.separated(
            key: const ValueKey('explore.forYouList'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: ExploreSpacing.x16),
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
        );
      },
    );
  }
}
