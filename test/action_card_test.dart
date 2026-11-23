import 'package:blue_track/core/utils/formatters.dart';
import 'package:blue_track/features/actions/domain/action_item.dart';
import 'package:blue_track/features/actions/presentation/widgets/action_card.dart';
import 'package:blue_track/shared/widgets/verified_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/action_fixtures.dart';
import 'support/test_harness.dart';

/// Mirrors the page: the card is always given a bounded height (the list wraps
/// it in `IntrinsicHeight`) because its body stretches to even out row heights.
Widget cardBox(Widget child) => phoneSized(IntrinsicHeight(child: child));

void main() {
  // Fixed clock so activity status and the action hint stay deterministic.
  final now = DateTime(2026, 11, 3, 9);

  testWidgets('shows every action field and the verified badge', (tester) async {
    final item = buildAction();

    await tester.pumpWidget(
      wrapPage(cardBox(ActionCard(item: item, now: now))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bersih Pantai Kuta'), findsOneWidget);
    expect(find.text('Bersih Pantai'), findsOneWidget);
    expect(find.text(Formatters.shortDate(item.startsAt, 'id')), findsOneWidget);
    expect(find.textContaining('07.00'), findsOneWidget);
    expect(find.text('Pantai Kuta, Badung'), findsOneWidget);
    expect(find.text('28 dari 40 · sisa 12'), findsOneWidget);
    expect(find.text('Komunitas Laut Bersih'), findsOneWidget);
    expect(find.byType(VerifiedBadge), findsOneWidget);
    expect(find.text('Terbuka'), findsOneWidget);
    expect(find.text('Lihat & daftar'), findsOneWidget);
  });

  testWidgets('omits the badge for an unverified organizer', (tester) async {
    await tester.pumpWidget(
      wrapPage(
        cardBox(
          ActionCard(item: buildAction(organizerVerified: false), now: now),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(VerifiedBadge), findsNothing);
    expect(find.text('Komunitas Laut Bersih'), findsOneWidget);
  });

  testWidgets('shows the full-quota status and label', (tester) async {
    await tester.pumpWidget(
      wrapPage(
        cardBox(ActionCard(item: buildAction(quota: 20, registered: 20), now: now)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('20 dari 20 · kuota penuh'), findsOneWidget);
    expect(find.text('Penuh'), findsOneWidget);
    // Registration is closed, so the card only offers the detail view.
    expect(find.text('Lihat detail'), findsOneWidget);
    expect(find.text('Lihat & daftar'), findsNothing);
  });

  testWidgets('shows Berlangsung and Selesai instead of the old open state', (
    tester,
  ) async {
    final ongoing = buildAction(
      startsAt: DateTime(2026, 11, 3, 8),
      endsAt: DateTime(2026, 11, 3, 12),
    );
    await tester.pumpWidget(
      wrapPage(cardBox(ActionCard(item: ongoing, now: now))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Berlangsung'), findsOneWidget);
    expect(find.text('Terbuka'), findsNothing);
    expect(find.text('Lihat detail'), findsOneWidget);

    final ended = buildAction(
      startsAt: DateTime(2026, 11, 1, 7),
      endsAt: DateTime(2026, 11, 1, 10),
    );
    await tester.pumpWidget(
      wrapPage(cardBox(ActionCard(item: ended, now: now))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Selesai'), findsOneWidget);
    expect(find.text('Lihat detail'), findsOneWidget);
  });

  testWidgets('marks a registered action over the cover', (tester) async {
    await tester.pumpWidget(
      wrapPage(
        cardBox(ActionCard(item: buildAction(), registered: true, now: now)),
      ),
    );
    await tester.pumpAndSettle();

    final badge = find.byKey(const ValueKey('actionCard.registered'));
    expect(badge, findsOneWidget);
    expect(find.text('Terdaftar'), findsOneWidget);
    // The activity itself is still open, so both labels are shown together.
    expect(find.text('Terbuka'), findsOneWidget);
    expect(find.text('Lihat & daftar'), findsNothing);
    expect(find.text('Lihat detail'), findsOneWidget);

    // The badge sits in the bottom-left corner of the 16:9 cover.
    final cover = tester.getRect(
      find.byKey(const ValueKey('actionCard.a01.cover')),
    );
    final badgeRect = tester.getRect(badge);
    expect(badgeRect.top, greaterThan(cover.top + cover.height / 2));
    expect(badgeRect.left, closeTo(cover.left + 8, 0.1));
    expect(badgeRect.left, lessThan(cover.center.dx));
  });

  testWidgets('keeps full and ended cards tappable', (tester) async {
    var taps = 0;
    for (final item in [
      buildAction(quota: 20, registered: 20),
      buildAction(
        startsAt: DateTime(2026, 11, 1, 7),
        endsAt: DateTime(2026, 11, 1, 10),
      ),
    ]) {
      await tester.pumpWidget(
        wrapPage(
          cardBox(ActionCard(item: item, now: now, onTap: () => taps++)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ActionCard));
      await tester.pumpAndSettle();
    }

    expect(taps, 2);
  });

  testWidgets('calls onTap', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      wrapPage(
        cardBox(
          ActionCard(item: buildAction(), now: now, onTap: () => tapped = true),
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

    await tester.pumpWidget(wrapPage(cardBox(ActionCard(item: item, now: now))));
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
          child: cardBox(ActionCard(item: buildAction(), now: now)),
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
