import 'package:blue_track/core/localization/app_localizations.dart';
import 'package:blue_track/features/shell/app_shell.dart';
import 'package:blue_track/features/shell/tab_placeholder.dart';
import 'package:blue_track/features/transparency/presentation/transparency_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_harness.dart';

void main() {
  group('TabPlaceholder', () {
    testWidgets('shows the tab icon, name, purpose, and a coming-soon note', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapPage(const TabPlaceholder(location: '/actions')),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.task_alt), findsOneWidget);
      expect(find.text('Aksi'), findsOneWidget);
      expect(
        find.text('Lapor, pantau, dan dukung aksi bersama untuk laut.'),
        findsOneWidget,
      );
      expect(
        find.text('Halaman ini akan tersedia pada subproyek berikutnya.'),
        findsOneWidget,
      );
    });

    testWidgets('copy follows the active locale', (tester) async {
      await tester.pumpWidget(
        wrapPage(
          const TabPlaceholder(location: '/profile'),
          locale: const Locale('en'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Profile'), findsOneWidget);
      expect(
        find.text(
          'Manage your account and settings, and access proposals, '
          'notifications, and learning materials.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('unknown location falls back to the generic note', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapPage(const TabPlaceholder(location: '/nope')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Halaman ini akan tersedia pada subproyek berikutnya.'),
        findsOneWidget,
      );
    });
  });

  group('shell tab configuration', () {
    test('purpose sentences live on the concept tabs that have them', () {
      expect(ShellTabs.byLocation('/explore')?.descriptionKey, isNull);
      expect(
        ShellTabs.byLocation('/actions')?.descriptionKey,
        'nav.aksi.description',
      );
      expect(
        ShellTabs.byLocation('/impact')?.descriptionKey,
        'nav.impact.description',
      );
      expect(
        ShellTabs.byLocation('/profile')?.descriptionKey,
        'nav.profile.description',
      );
    });

    test('release exposes four tabs in order, Aksi replacing Transparansi', () {
      expect(
        ShellTabs.active.map((t) => t.location).toList(),
        ['/explore', '/actions', '/impact', '/profile'],
      );
    });
  });

  testWidgets('transparency AppBar title follows the active locale', (
    tester,
  ) async {
    await tester.pumpWidget(wrapPage(const TransparencyPage()));
    await tester.pumpAndSettle();
    expect(find.text('Transparansi'), findsWidgets);

    await tester.pumpWidget(
      wrapPage(const TransparencyPage(), locale: const Locale('en')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Transparency'), findsWidgets);
  });

  test('description keys resolve in every supported locale', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = AppLocalizations(locale);
      for (final tab in ShellTabs.active) {
        final key = tab.descriptionKey;
        if (key == null) continue;
        expect(
          l10n.text(key),
          isNot(key),
          reason: 'Missing description for ${tab.location} in '
              '${locale.languageCode}',
        );
      }
    }
  });
}