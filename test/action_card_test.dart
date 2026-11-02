import 'package:blue_track/core/utils/formatters.dart';
import 'package:blue_track/features/actions/domain/action_item.dart';
import 'package:blue_track/features/actions/presentation/widgets/action_card.dart';
import 'package:blue_track/shared/widgets/verified_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/action_fixtures.dart';
import 'support/test_harness.dart';

void main() {
  testWidgets('shows every action field and the verified badge', (tester) async {
    final item = buildAction();

    await tester.pumpWidget(wrapPage(phoneSized(ActionCard(item: item))));
    await tester.pumpAndSettle();

    expect(find.text('Bersih Pantai Kuta'), findsOneWidget);
    expect(find.text('Bersih Pantai'), findsOneWidget);
    expect(find.text(Formatters.shortDate(item.startsAt, 'id')), findsOneWidget);
    expect(find.textContaining('07.00'), findsOneWidget);
    expect(find.text('Pantai Kuta, Badung'), findsOneWidget);
    expect(find.text('28/40 peserta'), findsOneWidget);
    expect(find.text('Komunitas Laut Bersih'), findsOneWidget);
    expect(find.byType(VerifiedBadge), findsOneWidget);
  });

  testWidgets('omits the badge for an unverified organizer', (tester) async {
    await tester.pumpWidget(
      wrapPage(
        phoneSized(
          ActionCard(item: buildAction(organizerVerified: false)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(VerifiedBadge), findsNothing);
    expect(find.text('Komunitas Laut Bersih'), findsOneWidget);
  });

  testWidgets('shows the full-quota label', (tester) async {
    await tester.pumpWidget(
      wrapPage(
        phoneSized(
          ActionCard(item: buildAction(quota: 20, registered: 20)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('20/20 peserta'), findsOneWidget);
    expect(find.text('Penuh'), findsOneWidget);
  });

  testWidgets('calls onTap', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      wrapPage(
        phoneSized(
          ActionCard(item: buildAction(), onTap: () => tapped = true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ActionCard));
    expect(tapped, isTrue);
  });

  testWidgets('does not overflow at 320dp with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final item = buildAction(
      title: 'Restorasi Terumbu Karang di Kepulauan Seribu',
      type: ActionType.coralRestoration,
      locationName: 'Pulau Pramuka, Kepulauan Seribu',
      organizerName: 'Yayasan Konservasi Laut Nusantara',
    );

    await tester.pumpWidget(wrapPage(ActionCard(item: item)));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('follows the active color scheme in dark mode', (tester) async {
    const darkScheme = ColorScheme.dark(
      primary: Color(0xFF38BDF8),
      secondary: Color(0xFF2DD4BF),
      tertiary: Color(0xFFFF8A80),
      surface: Color(0xFF0F172A),
      onSurface: Color(0xFFF8FAFC),
      onSurfaceVariant: Color(0xFFCBD5E1),
      outline: Color(0xFF334155),
    );

    await tester.pumpWidget(
      wrapPage(
        Theme(
          data: ThemeData(useMaterial3: true, colorScheme: darkScheme),
          child: phoneSized(ActionCard(item: buildAction())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final card = tester.widget<Card>(find.byType(Card));
    expect(card.color, darkScheme.surface);

    final title = tester.widget<Text>(find.text('Bersih Pantai Kuta'));
    expect(title.style?.color, darkScheme.onSurface);

    expect(tester.takeException(), isNull);
  });
}
