import 'package:blue_track/core/state/app_state.dart';
import 'package:blue_track/core/theme/app_colors.dart';
import 'package:blue_track/features/auth/presentation/login_page.dart';
import 'package:blue_track/features/legal/presentation/legal_page.dart';
import 'package:blue_track/shared/widgets/step_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/test_harness.dart';

const _privacyLabel = 'Kebijakan Privasi';
const _termsLabel = 'Syarat & Ketentuan';

/// Mirrors the real `/auth` entry point plus the destinations it navigates to.
GoRouter buildLoginRouter({String initialLocation = '/auth'}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/origin',
        builder: (context, state) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => context.push('/auth?redirect=/origin'),
              child: const Text('MASUK'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => LoginPage(
          redirect: state.uri.queryParameters['redirect'],
        ),
      ),
      GoRoute(
        path: '/legal/privacy',
        builder: (context, state) => const LegalPage(documentKey: 'privacy'),
      ),
      GoRoute(
        path: '/legal/terms',
        builder: (context, state) => const LegalPage(documentKey: 'terms'),
      ),
      GoRoute(
        path: '/explore',
        builder: (context, state) => const Scaffold(body: Text('EXPLORE')),
      ),
      GoRoute(
        path: '/impact',
        builder: (context, state) => const Scaffold(body: Text('IMPACT')),
      ),
    ],
  );
}

/// The legal sentence is a single inline [RichText], so match it by content
/// rather than by a private widget type.
Finder legalNotice() => find.byWidgetPredicate(
  (w) => w is RichText && w.text.toPlainText().contains('menyetujui'),
  description: 'inline legal notice sentence',
);

/// The login flow ticks the OTP resend countdown every second, so
/// `pumpAndSettle` would time out instead of failing. Pump a fixed number of
/// frames instead.
Future<void> pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

/// Resolved fill color of the screen's primary CTA.
Color primaryButtonColor(WidgetTester tester) {
  final button = tester.widget<FilledButton>(find.byType(FilledButton).first);
  return button.style?.backgroundColor?.resolve(<WidgetState>{}) ??
      AppColors.coral;
}

void main() {
  setUp(() {
    // Signing in writes a mock token through flutter_secure_storage, which has
    // no platform implementation under `flutter test`.
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('layar sign-in tidak menampilkan step indicator', (tester) async {
    await tester.pumpWidget(wrapRouter(buildLoginRouter()));
    await tester.pumpAndSettle();

    expect(find.byType(StepIndicator), findsNothing);
  });

  testWidgets('tombol utama sign-in diisi biru ocean', (tester) async {
    await tester.pumpWidget(wrapRouter(buildLoginRouter()));
    await tester.pumpAndSettle();

    expect(primaryButtonColor(tester), AppColors.ocean);

    // The phone and OTP steps carry the same CTA fill.
    await tester.enterText(find.byType(TextField), 'penyayang@contoh.id');
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();
    expect(primaryButtonColor(tester), AppColors.ocean);

    await tester.enterText(find.byType(TextField), '8123456789');
    await tester.tap(find.text('Kirim Kode'));
    await pumpFrames(tester);
    expect(primaryButtonColor(tester), AppColors.ocean);
  });

  testWidgets('langkah email tidak punya tombol/link di bawah', (
    tester,
  ) async {
    await tester.pumpWidget(wrapRouter(buildLoginRouter()));
    await tester.pumpAndSettle();

    // The only actionable control left on the screen is the primary CTA.
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('catatan hukum dirender sebagai satu kalimat dengan tautan inline', (
    tester,
  ) async {
    await tester.pumpWidget(wrapRouter(buildLoginRouter()));
    await tester.pumpAndSettle();

    expect(legalNotice(), findsOneWidget);

    final sentence = tester.widget<RichText>(legalNotice()).text;
    final plain = sentence.toPlainText();
    expect(plain, contains(_privacyLabel));
    expect(plain, contains(_termsLabel));

    // The documents must be tappable spans inside that one sentence, not plain
    // text and not a row of separate buttons.
    final links = <InlineSpan>[];
    void collect(InlineSpan span) {
      if (span is TextSpan) {
        if (span.recognizer != null) links.add(span);
        for (final child in span.children ?? const <InlineSpan>[]) {
          collect(child);
        }
      }
    }

    collect(sentence);
    expect(links, hasLength(2));
  });

  testWidgets('tautan inline membuka dokumen yang tepat', (tester) async {
    final router = buildLoginRouter();
    await tester.pumpWidget(wrapRouter(router));
    await tester.pumpAndSettle();

    await tester.tapOnText(find.textRange.ofSubstring(_privacyLabel));
    await tester.pumpAndSettle();
    expect(
      tester.widget<LegalPage>(find.byType(LegalPage)).documentKey,
      'privacy',
    );

    router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);

    await tester.tapOnText(find.textRange.ofSubstring(_termsLabel));
    await tester.pumpAndSettle();
    expect(
      tester.widget<LegalPage>(find.byType(LegalPage)).documentKey,
      'terms',
    );
  });

  testWidgets('panah kembali dari langkah telepon ke langkah email', (
    tester,
  ) async {
    await tester.pumpWidget(wrapRouter(buildLoginRouter()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'penyayang@contoh.id');
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();
    expect(find.text('+62'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('+62'), findsNothing);
    expect(find.text('nama@email.com'), findsOneWidget);
  });

  testWidgets('panah kembali di langkah awal kembali ke halaman asal', (
    tester,
  ) async {
    final router = buildLoginRouter(initialLocation: '/origin');
    await tester.pumpWidget(wrapRouter(router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('MASUK'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsNothing);
    expect(find.text('MASUK'), findsOneWidget);
  });

  testWidgets('tanpa halaman sebelumnya, panah kembali mengikuti redirect', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapRouter(buildLoginRouter(initialLocation: '/auth?redirect=/impact')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsNothing);
    expect(find.text('IMPACT'), findsOneWidget);
  });

  testWidgets('kode OTP yang benar menandai masuk dan kembali ke redirect', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapRouter(buildLoginRouter(initialLocation: '/auth?redirect=/impact')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'penyayang@contoh.id');
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '8123456789');
    await tester.tap(find.text('Kirim Kode'));
    await pumpFrames(tester);

    final otpFields = find.byType(TextField);
    expect(otpFields, findsNWidgets(6));

    const code = '123456';
    for (var i = 0; i < code.length; i++) {
      await tester.enterText(otpFields.at(i), code[i]);
    }
    await pumpFrames(tester);

    expect(AuthController.instance.signedIn, isTrue);
    expect(find.byType(LoginPage), findsNothing);
    expect(find.text('IMPACT'), findsOneWidget);
  });
}