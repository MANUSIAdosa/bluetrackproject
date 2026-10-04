import 'package:blue_track/core/theme/app_colors.dart';
import 'package:blue_track/shared/widgets/verified_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_harness.dart';

void main() {
  testWidgets('badge is teal', (tester) async {
    await tester.pumpWidget(wrapPage(const VerifiedBadge()));
    await tester.pumpAndSettle();

    final label = tester.widget<Text>(find.text('Terverifikasi'));
    expect(label.style?.color, AppColors.teal);
    final icon = tester.widget<Icon>(find.byIcon(Icons.verified));
    expect(icon.color, AppColors.teal);
  });

  testWidgets('compact badge is teal too', (tester) async {
    await tester.pumpWidget(wrapPage(const VerifiedBadge(compact: true)));
    await tester.pumpAndSettle();

    final icon = tester.widget<Icon>(find.byIcon(Icons.verified));
    expect(icon.color, AppColors.teal);
  });

  testWidgets('tapping opens the verification explanation sheet', (
    tester,
  ) async {
    await tester.pumpWidget(wrapPage(const VerifiedBadge()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Terverifikasi'));
    await tester.pumpAndSettle();

    expect(find.text('Tentang badge Terverifikasi'), findsOneWidget);
    expect(find.text('Checklist verifikasi'), findsOneWidget);
    expect(find.text('Badan hukum terdaftar'), findsOneWidget);
  });

  testWidgets('sheet has 24dp top corners and a drag handle', (tester) async {
    await tester.pumpWidget(wrapPage(const VerifiedBadge()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Terverifikasi'));
    await tester.pumpAndSettle();

    final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
    expect(sheet.showDragHandle, isTrue);

    final radius = (sheet.shape! as RoundedRectangleBorder).borderRadius
        .resolve(TextDirection.ltr);
    expect(radius.topLeft.x, 24);
    expect(radius.topRight.x, 24);
    expect(radius.bottomLeft.x, 0);
  });

  testWidgets('dragging the handle down closes the sheet', (tester) async {
    await tester.pumpWidget(wrapPage(const VerifiedBadge()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Terverifikasi'));
    await tester.pumpAndSettle();

    final sheet = find.byType(BottomSheet);
    final handle = tester
        .getTopLeft(sheet)
        .translate(tester.getSize(sheet).width / 2, 24);
    await tester.dragFrom(handle, const Offset(0, 400));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('sheet copy follows the active locale', (tester) async {
    await tester.pumpWidget(
      wrapPage(const VerifiedBadge(), locale: const Locale('en')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Verified'));
    await tester.pumpAndSettle();

    expect(find.text('About the Verified badge'), findsOneWidget);
    expect(find.text('Verification checklist'), findsOneWidget);
  });

  testWidgets('compact badge is tappable too', (tester) async {
    await tester.pumpWidget(wrapPage(const VerifiedBadge(compact: true)));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.verified));
    await tester.pumpAndSettle();

    expect(find.text('Tentang badge Terverifikasi'), findsOneWidget);
  });

  testWidgets('onTap overrides the default sheet', (tester) async {
    var taps = 0;
    await tester.pumpWidget(wrapPage(VerifiedBadge(onTap: () => taps++)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Terverifikasi'));
    await tester.pumpAndSettle();

    expect(taps, 1);
    expect(find.byType(BottomSheet), findsNothing);
  });
}
