import 'package:blue_track/core/theme/app_colors.dart';
import 'package:blue_track/shared/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_harness.dart';

void main() {
  testWidgets('button is filled with coral', (tester) async {
    await tester.pumpWidget(
      wrapPage(phoneSized(PrimaryButton(label: 'Lanjut', onPressed: () {}))),
    );
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.style?.backgroundColor?.resolve(<WidgetState>{}),
        AppColors.coral);
  });

  testWidgets('the default fill can be overridden per screen', (tester) async {
    await tester.pumpWidget(
      wrapPage(
        phoneSized(
          PrimaryButton(
            label: 'Lanjut',
            onPressed: () {},
            color: AppColors.ocean,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.style?.backgroundColor?.resolve(<WidgetState>{}),
        AppColors.ocean);
  });

  testWidgets('loading state still shows the spinner and blocks taps',
      (tester) async {
    await tester.pumpWidget(
      wrapPage(
        phoneSized(PrimaryButton(label: 'Lanjut', onPressed: () {}, loading: true)),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Lanjut'), findsNothing);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });
}