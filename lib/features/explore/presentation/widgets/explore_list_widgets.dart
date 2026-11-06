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
Widget exploreSectionHeader(String text) => Text(
  text,
  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
);

/// Horizontal "Untuk minatmu" rail.
///
/// It bleeds to the screen edges: the last card is cut by the viewport as a
/// scroll hint, and the next card peeks 16dp past the first one. Every card has
/// the same height, so the rail takes the card's own height instead of
/// stretching children.
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
        final cardWidth =
            constraints.maxWidth -
            ExploreSpacing.x16 -
            ExploreSpacing.x12 -
            ExploreSpacing.x16;

        return SizedBox(
          height: ProjectCard.heightFor(context, cardWidth),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: ExploreSpacing.x16),
            itemCount: projects.length,
            separatorBuilder: (_, _) =>
                const SizedBox(width: ExploreSpacing.x12),
            itemBuilder: (context, index) => SizedBox(
              width: cardWidth,
              child: ProjectCard(
                project: projects[index],
                onSavedChanged: onSavedChanged,
              ),
            ),
          ),
        );
      },
    );
  }
}
