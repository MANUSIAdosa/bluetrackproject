import 'package:blue_track/core/theme/app_colors.dart';
import 'package:blue_track/shared/widgets/login_prompt_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_harness.dart';

/// Resolved fill color of the card's primary CTA.
Color _ctaColor(WidgetTester tester) {
  final button = tester.widget<FilledButton>(find.byType(FilledButton));
  return button.style?.backgroundColor?.resolve(<WidgetState>{}) ??
      AppColors.coral;
}

void main() {
  testWidgets('tombol "Masuk" memakai biru ocean, sama dengan P02', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapPage(
        phoneSized(const LoginPromptCard(returnLocation: '/impact')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Masuk'), findsOneWidget);
    expect(_ctaColor(tester), AppColors.ocean);
  });

  testWidgets('tombol "Sign in" versi Inggris memakai biru ocean', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapPage(
        phoneSized(const LoginPromptCard(returnLocation: '/impact')),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsOneWidget);
    expect(_ctaColor(tester), AppColors.ocean);
  });
}