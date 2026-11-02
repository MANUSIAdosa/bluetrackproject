import 'package:blue_track/features/donation/data/donation_flow_store.dart';
import 'package:blue_track/features/donation/domain/donation.dart';
import 'package:blue_track/features/donation/presentation/donate_confirmation_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_harness.dart';

const _cardKey = Key('p06_confirmation_card');

DonationFlowStore storeWith({
  int amount = 100000,
  DonationPurpose purpose = DonationPurpose.project,
}) {
  final store = DonationFlowStore();
  store.save(
    DonationDraft(
      projectId: 'p01',
      amount: amount,
      frequency: DonationFrequency.once,
      purpose: purpose,
    ),
  );
  return store;
}

Future<void> pumpConfirmation(
  WidgetTester tester, {
  required DonationFlowStore store,
  Locale locale = const Locale('id'),
}) async {
  await tester.pumpWidget(
    wrapPage(
      DonateConfirmationPage(
        projectId: 'p01',
        flowStore: store,
        projects: FakeProjectRepository([buildProject()]),
        signedInOverride: true,
      ),
      locale: locale,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('kartu memakai susunan baru tanpa tanda panah', (tester) async {
    await pumpConfirmation(tester, store: storeWith());

    final card = find.byKey(_cardKey);
    expect(card, findsOneWidget);

    final heart = find.descendant(
      of: card,
      matching: find.byIcon(Icons.favorite_rounded),
    );
    final label = find.descendant(of: card, matching: find.text('DONASI ANDA'));
    final amount = find.descendant(of: card, matching: find.text('Rp100.000'));
    final badge = find.descendant(
      of: card,
      matching: find.text('100% UNTUK PROYEK'),
    );
    final project = find.descendant(
      of: card,
      matching: find.text('Peneluruhan Penyu di Pantai Sukamade'),
    );

    expect(heart, findsOneWidget);
    expect(label, findsOneWidget);
    expect(amount, findsOneWidget);
    expect(badge, findsOneWidget);
    expect(project, findsOneWidget);
    expect(find.textContaining('→'), findsNothing);

    double top(Finder finder) => tester.getTopLeft(finder).dy;
    expect(top(heart), lessThan(top(label)));
    expect(top(label), lessThan(top(amount)));
    expect(top(amount), lessThan(top(badge)));
    expect(top(badge), lessThan(top(project)));
  });

  testWidgets('versi Inggris memakai label sesuai desain', (tester) async {
    await pumpConfirmation(
      tester,
      store: storeWith(),
      locale: const Locale('en'),
    );

    final card = find.byKey(_cardKey);
    expect(
      find.descendant(of: card, matching: find.text('YOUR DONATION')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: card,
        matching: find.text('100% GOES TO THE PROJECT'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('Rp100,000')),
      findsOneWidget,
    );
  });

  testWidgets('donasi organisasi tidak memakai klaim 100% proyek', (
    tester,
  ) async {
    await pumpConfirmation(
      tester,
      store: storeWith(purpose: DonationPurpose.organization),
    );

    final card = find.byKey(_cardKey);
    expect(
      find.descendant(
        of: card,
        matching: find.text('100% UNTUK OPERASIONAL PLATFORM'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('100% UNTUK PROYEK')),
      findsNothing,
    );
    expect(
      find.descendant(of: card, matching: find.text('Lembaga Konservasi')),
      findsOneWidget,
    );
  });

  testWidgets('kartu muat di layar 320dp tanpa overflow', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 700);
    addTearDown(tester.view.reset);

    await pumpConfirmation(tester, store: storeWith());

    expect(tester.takeException(), isNull);
    expect(find.byKey(_cardKey), findsOneWidget);
  });

  testWidgets('nominal panjang tetap satu baris di dalam kartu', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 700);
    addTearDown(tester.view.reset);

    await pumpConfirmation(tester, store: storeWith(amount: 999999999));

    expect(tester.takeException(), isNull);

    final card = tester.getRect(find.byKey(_cardKey));
    final amount = tester.getRect(
      find.descendant(
        of: find.byKey(_cardKey),
        matching: find.text('Rp999.999.999'),
      ),
    );

    // One line at 30sp is ~35dp tall; wrapping would make it roughly double.
    expect(amount.height, lessThan(50));
    expect(amount.left, greaterThanOrEqualTo(card.left));
    expect(amount.right, lessThanOrEqualTo(card.right));
  });
}
