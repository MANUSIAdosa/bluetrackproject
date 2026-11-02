import 'package:blue_track/core/theme/app_colors.dart';
import 'package:blue_track/shared/widgets/donation_timeline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_harness.dart';

DonationTimelineStep step(
  String label, {
  bool complete = false,
  String? time,
}) => DonationTimelineStep(label: label, isComplete: complete, timeLabel: time);

List<DonationTimelineStep> fourSteps({int complete = 0}) => [
  step(
    'Diterima',
    complete: complete > 0,
    time: complete > 0 ? '12 Okt' : null,
  ),
  step(
    'Diteruskan ke penyelenggara',
    complete: complete > 1,
    time: complete > 1 ? '13 Okt' : null,
  ),
  step('Bukti', complete: complete > 2, time: complete > 2 ? '15 Okt' : null),
  step(
    'Update lapangan',
    complete: complete > 3,
    time: complete > 3 ? '20 Okt' : null,
  ),
];

Color? dotBorderColor(WidgetTester tester, int index) {
  final dot = tester.widget<Container>(
    find.byKey(ValueKey('donationTimeline.dot.$index')),
  );
  return (dot.decoration! as BoxDecoration).border!.top.color;
}

Color? dotColor(WidgetTester tester, int index) {
  final dot = tester.widget<Container>(
    find.byKey(ValueKey('donationTimeline.dot.$index')),
  );
  return (dot.decoration! as BoxDecoration).color;
}

Color? connectorColor(WidgetTester tester, int index) {
  final line = tester.widget<Container>(
    find.byKey(ValueKey('donationTimeline.connector.$index')),
  );
  return line.color;
}

void main() {
  testWidgets('renders every milestone in order, including pending ones', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapPage(DonationTimeline(steps: fourSteps(complete: 1))),
    );
    await tester.pump();

    expect(find.text('Diterima'), findsOneWidget);
    expect(find.text('Diteruskan ke penyelenggara'), findsOneWidget);
    expect(find.text('Bukti'), findsOneWidget);
    expect(find.text('Update lapangan'), findsOneWidget);
    expect(find.text('12 Okt'), findsOneWidget);
    // Only the first milestone happened.
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('pending milestones are gray and have no date', (tester) async {
    await tester.pumpWidget(
      wrapPage(DonationTimeline(steps: fourSteps(complete: 1))),
    );
    await tester.pump();

    final done = tester.widget<Text>(find.text('Diterima'));
    final pending = tester.widget<Text>(find.text('Bukti'));

    expect(done.style?.color, AppColors.textPrimary);
    expect(pending.style?.color, AppColors.textSecondary);
    expect(dotColor(tester, 0), AppColors.ocean);
    expect(dotBorderColor(tester, 0), AppColors.ocean);
    expect(dotColor(tester, 2), AppColors.surface);
    expect(dotBorderColor(tester, 2), AppColors.inactiveTab);
  });

  testWidgets('connectors turn ocean only as far as the progress goes', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapPage(DonationTimeline(steps: fourSteps(complete: 2))),
    );
    await tester.pump();

    // Step 1 -> 2 are both complete; step 2 -> 3 is still ahead.
    expect(connectorColor(tester, 0), AppColors.ocean);
    expect(connectorColor(tester, 1), AppColors.border);
    expect(connectorColor(tester, 2), AppColors.border);
    expect(
      find.byKey(const ValueKey('donationTimeline.connector.3')),
      findsNothing,
    );
  });

  testWidgets('marks all four milestones when the journey is complete', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapPage(DonationTimeline(steps: fourSteps(complete: 4))),
    );
    await tester.pump();

    expect(find.byIcon(Icons.check), findsNWidgets(4));
    expect(find.text('12 Okt'), findsOneWidget);
    expect(find.text('13 Okt'), findsOneWidget);
    expect(find.text('15 Okt'), findsOneWidget);
    expect(find.text('20 Okt'), findsOneWidget);
  });
}
