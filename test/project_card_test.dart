import 'package:blue_track/shared/widgets/progress_bar.dart';
import 'package:blue_track/shared/widgets/progress_ring.dart';
import 'package:blue_track/shared/widgets/project_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/test_harness.dart';

GoRouter _cardRouter({required Widget card}) => GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => wrapPage(phoneSized(card)),
        ),
        GoRoute(
          path: '/project/:id',
          builder: (_, state) =>
              wrapPage(Text('project:${state.pathParameters['id']}')),
        ),
        GoRoute(
          path: '/donate/:projectId',
          builder: (_, state) =>
              wrapPage(Text('donate:${state.pathParameters['projectId']}')),
        ),
      ],
    );

void main() {
  testWidgets('gallery keeps a 16:9 ratio', (tester) async {
    await tester.pumpWidget(
      wrapPage(phoneSized(ProjectCard(project: buildProject()))),
    );
    await tester.pumpAndSettle();

    final ratio = tester.widget<AspectRatio>(find.byType(AspectRatio));
    expect(ratio.aspectRatio, closeTo(16 / 9, 0.001));
  });

  testWidgets('funding progress uses ProgressBar, not a percentage ring',
      (tester) async {
    await tester.pumpWidget(
      wrapPage(phoneSized(ProjectCard(project: buildProject()))),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ProgressBar), findsOneWidget);
    expect(find.byType(ProgressRing), findsNothing);
  });

  testWidgets('Donasi button opens the donation route of that project',
      (tester) async {
    final router = _cardRouter(
      card: ProjectCard(project: buildProject(id: 'p04')),
    );
    await tester.pumpWidget(wrapRouter(router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Donasi'));
    await tester.pumpAndSettle();

    expect(find.text('donate:p04'), findsOneWidget);
    expect(find.text('project:p04'), findsNothing);
  });

  testWidgets('Donasi is outlined so the coral primary stays unique',
      (tester) async {
    await tester.pumpWidget(
      wrapPage(phoneSized(ProjectCard(project: buildProject()))),
    );
    await tester.pumpAndSettle();

    expect(find.byType(OutlinedButton), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('compact card hides the Donasi button', (tester) async {
    await tester.pumpWidget(
      wrapPage(
        phoneSized(
          ProjectCard(project: buildProject(), showDonateButton: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Donasi'), findsNothing);
  });

  testWidgets('tapping the card still opens the project detail route',
      (tester) async {
    final router = _cardRouter(card: ProjectCard(project: buildProject()));
    await tester.pumpWidget(wrapRouter(router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Peneluruhan Penyu di Pantai Sukamade'));
    await tester.pumpAndSettle();

    expect(find.text('project:p01'), findsOneWidget);
  });
}