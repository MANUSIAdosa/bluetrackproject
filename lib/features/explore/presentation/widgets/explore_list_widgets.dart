import 'package:flutter/material.dart';

import '../../../../shared/widgets/project_card.dart';
import '../../domain/project.dart';

/// Section heading used by the Jelajahi list ("Untuk minatmu").
Widget exploreSectionHeader(String text) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 8),
  child: Text(
    text,
    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
  ),
);

/// Horizontal "Untuk minatmu" rail.
///
/// Its height is measured from the cards themselves ([IntrinsicHeight]) rather
/// than pinned to a constant, so it can never be shorter than a card: a
/// one-line or two-line title, a longer location or a large text scale are all
/// fine. Cards are compact — no donate CTA — and stretched to one height.
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
    return IntrinsicHeight(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < projects.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              SizedBox(
                width: 260,
                child: ProjectCard(
                  project: projects[i],
                  showDonateButton: false,
                  onSavedChanged: onSavedChanged,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
