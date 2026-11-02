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
const _emailKey = Key('auth_email_field');
const _phoneKey = Key('auth_phone_field');

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
        builder: (context, state) =>
            LoginPage(redirect: state.uri.queryParameters['redirect']),
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

Finder emailField() => find.byKey(_emailKey);
Finder phoneField() => find.byKey(_phoneKey);
Finder otpField(int index) => find.byKey(ValueKey('auth_otp_$index'));

/// The login flow ticks the OTP resend countdown every second, so
/// `pumpAndSettle` would time out instead of failing. Pump a fixed number of
/// frames instead.
Future<void> pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

/// Fills the email field and opens the OTP step.
Future<void> openOtpWithEmail(
  WidgetTester tester, {
  String email = 'penyayang@contoh.id',
}) async {
  await tester.enterText(emailField(), email);
  await tester.tap(find.text('Lanjut'));
  await pumpFrames(tester);
}

/// Types a six-digit code; the sixth digit triggers mock verification.
Future<void> enterOtp(WidgetTester tester, String code) async {
  for (var i = 0; i < code.length; i++) {
    await tester.enterText(otpField(i), code[i]);
  }
  await pumpFrames(tester);
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
    AuthController.instance.setSignedIn(false);
  });

  testWidgets('email dan nomor telepon tampil di satu halaman dengan pemisah', (
    tester,
  ) async {
    await tester.pumpWidget(wrapRouter(buildLoginRouter()));
    await tester.pumpAndSettle();

    expect(find.text('Selamat datang kembali'), findsOneWidget);
    expect(emailField(), findsOneWidget);
    expect(find.text('ATAU'), findsOneWidget);
    expect(phoneField(), findsOneWidget);
    expect(find.text('+62'), findsOneWidget);
    expect(find.text('Lanjut'), findsOneWidget);
    expect(otpField(0), findsNothing);
  });

  testWidgets('versi Inggris memakai Welcome back dan OR', (tester) async {
    await tester.pumpWidget(
      wrapRouter(buildLoginRouter(), locale: const Locale('en')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('OR'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Phone number'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('urutannya judul, email, OR, telepon, tombol, lalu privasi', (
    tester,
  ) async {
    await tester.pumpWidget(wrapRouter(buildLoginRouter()));
    await tester.pumpAndSettle();

    double top(Finder finder) => tester.getTopLeft(finder).dy;
    double bottom(Finder finder) => tester.getBottomLeft(finder).dy;

    expect(
      top(find.text('Selamat datang kembali')),
      lessThan(top(emailField())),
    );
    expect(top(emailField()), lessThan(top(find.text('ATAU'))));
    expect(top(find.text('ATAU')), lessThan(top(phoneField())));
    expect(top(phoneField()), lessThan(top(find.byType(FilledButton))));
    expect(bottom(find.byType(FilledButton)), lessThan(top(legalNotice())));
  });

  testWidgets('form di bagian atas, catatan hukum mengikuti form', (
    tester,
  ) async {
    await tester.pumpWidget(wrapRouter(buildLoginRouter()));
    await tester.pumpAndSettle();

    // Dead centring put the field at 261, then 296 — a vertically centred field
    // is what the mobile keyboard covers. Top alignment puts it around 178.
    final fieldTop = tester.getTopLeft(emailField()).dy;
    expect(fieldTop, greaterThan(100));
    expect(fieldTop, lessThan(240));

    // The notice flows after the button instead of being pinned to the bottom
    // of the viewport, so it never separates from the form it belongs to.
    final gap =
        tester.getTopLeft(legalNotice()).dy -
        tester.getBottomLeft(find.byType(FilledButton)).dy;
    expect(gap, greaterThanOrEqualTo(20));
    expect(gap, lessThan(80));
  });

  testWidgets(
    'keyboard muncul: field dan tombol tetap terlihat, halaman bisa di-scroll',
    (tester) async {
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = const Size(1170, 2532); // 390 x 844
      tester.view.viewInsets = const FakeViewPadding(bottom: 1020); // 340
      addTearDown(tester.view.reset);

      await tester.pumpWidget(wrapRouter(buildLoginRouter()));
      await tester.pumpAndSettle();

      final viewport = tester.getRect(find.byType(SingleChildScrollView));

      // Both fields and the CTA stay above the keyboard on a normal phone.
      expect(tester.getBottomLeft(emailField()).dy, lessThan(viewport.bottom));
      expect(tester.getBottomLeft(phoneField()).dy, lessThan(viewport.bottom));
      expect(
        tester.getBottomLeft(find.byType(FilledButton)).dy,
        lessThan(viewport.bottom),
      );
      expect(tester.takeException(), isNull);

      // The notice can still be brought fully into view.
      await tester.scrollUntilVisible(
        legalNotice(),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(legalNotice(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('field punya label yang bertahan setelah diisi', (tester) async {
    await tester.pumpWidget(wrapRouter(buildLoginRouter()));
    await tester.pumpAndSettle();

    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Nomor telepon'), findsOneWidget);

    await tester.enterText(emailField(), 'penyayang@contoh.id');
    await tester.pumpAndSettle();

    // The label floats up and stays put once the field has content. The hint
    // widget lingers in the tree at zero opacity, so only the label is
    // asserted here.
    expect(find.text('Email'), findsOneWidget);
  });

  testWidgets('tanpa isian, lanjut menampilkan error dan tidak membuka OTP', (
    tester,
  ) async {
    await tester.pumpWidget(wrapRouter(buildLoginRouter()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lanjut'));
    await tester.pump();

    expect(find.text('Masukkan email atau nomor telepon.'), findsOneWidget);
    expect(find.byKey(const Key('auth_identifier_error')), findsOneWidget);
    expect(otpField(0), findsNothing);
  });

  testWidgets('email tidak valid ditolak dengan pesan inline', (tester) async {
    await tester.pumpWidget(wrapRouter(buildLoginRouter()));
    await tester.pumpAndSettle();

    await tester.enterText(emailField(), 'bukan-email');
    await tester.tap(find.text('Lanjut'));
    await tester.pump();

    expect(find.text('Format email tidak valid'), findsOneWidget);
    expect(otpField(0), findsNothing);
  });

  testWidgets('nomor telepon tidak valid ditolak dengan pesan inline', (
    tester,
  ) async {
    await tester.pumpWidget(wrapRouter(buildLoginRouter()));
    await tester.pumpAndSettle();

    await tester.enterText(phoneField(), '123');
    await tester.tap(find.text('Lanjut'));
    await tester.pump();

    expect(find.text('Nomor telepon tidak valid'), findsOneWidget);
    expect(otpField(0), findsNothing);
  });

  testWidgets('memperbaiki field langsung menghapus pesan error', (
    tester,
  ) async {
    await tester.pumpWidget(wrapRouter(buildLoginRouter()));
    await tester.pumpAndSettle();

    await tester.enterText(emailField(), 'bukan-email');
    await tester.tap(find.text('Lanjut'));
    await tester.pump();
    expect(find.text('Format email tidak valid'), findsOneWidget);

    await tester.enterText(emailField(), 'penyayang@contoh.id');
    await tester.pump();

    expect(find.text('Format email tidak valid'), findsNothing);
  });

  testWidgets('email saja membuka OTP dengan tujuan email', (tester) async {
    await tester.pumpWidget(wrapRouter(buildLoginRouter()));
    await tester.pumpAndSettle();

    await openOtpWithEmail(tester);

    expect(find.text('Masukkan kode verifikasi'), findsOneWidget);
    expect(find.text('Kode dikirim ke penyayang@contoh.id'), findsOneWidget);
    expect(otpField(0), findsOneWidget);
    expect(find.text('Selamat datang kembali'), findsNothing);
  });

  testWidgets('nomor telepon saja membuka OTP dengan awalan +62', (
    tester,
  ) async {
    await tester.pumpWidget(wrapRouter(buildLoginRouter()));
    await tester.pumpAndSettle();

    await tester.enterText(phoneField(), '8123456789');
    await tester.tap(find.text('Lanjut'));
    await pumpFrames(tester);

    expect(find.text('Masukkan kode verifikasi'), findsOneWidget);
    expect(find.text('Kode dikirim ke +628123456789'), findsOneWidget);
    expect(otpField(0), findsOneWidget);
  });

  testWidgets('bila keduanya diisi, email dipakai lebih dulu', (tester) async {
    await tester.pumpWidget(wrapRouter(buildLoginRouter()));
    await tester.pumpAndSettle();

    await tester.enterText(emailField(), 'penyayang@contoh.id');
    await tester.enterText(phoneField(), '8123456789');
    await tester.tap(find.text('Lanjut'));
    await pumpFrames(tester);

    expect(find.text('Kode dikirim ke penyayang@contoh.id'), findsOneWidget);
  });

  testWidgets('di layar pendek halaman tetap bisa di-scroll tanpa overflow', (
    tester,
  ) async {
    // Short and narrow: the legal notice wraps to several lines, so the block
    // no longer fits and the page has to scroll.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 280);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrapRouter(buildLoginRouter()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text('Lanjut'),
      60,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Lanjut'), findsOneWidget);

    await tester.scrollUntilVisible(
      legalNotice(),
      60,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
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

    await openOtpWithEmail(tester);
    expect(primaryButtonColor(tester), AppColors.ocean);
  });

  testWidgets('form tidak punya tombol/link di bawah', (tester) async {
    await tester.pumpWidget(wrapRouter(buildLoginRouter()));
    await tester.pumpAndSettle();

    // The only actionable control left on the form is the primary CTA; the
    // legal documents are inline spans, not separate buttons.
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets(
    'catatan hukum dirender sebagai satu kalimat dengan tautan inline',
    (tester) async {
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
    },
  );

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

  testWidgets('panah kembali dari OTP ke form dengan isian utuh', (
    tester,
  ) async {
    await tester.pumpWidget(wrapRouter(buildLoginRouter()));
    await tester.pumpAndSettle();

    await openOtpWithEmail(tester);
    expect(otpField(0), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('Masukkan kode verifikasi'), findsNothing);
    expect(emailField(), findsOneWidget);
    expect(phoneField(), findsOneWidget);
    expect(find.text('+62'), findsOneWidget);
    expect(
      tester.widget<TextField>(emailField()).controller?.text,
      'penyayang@contoh.id',
    );
  });

  testWidgets('panah kembali di form kembali ke halaman asal', (tester) async {
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

    await openOtpWithEmail(tester);
    await enterOtp(tester, '123456');

    expect(AuthController.instance.signedIn, isTrue);
    expect(find.byType(LoginPage), findsNothing);
    expect(find.text('IMPACT'), findsOneWidget);

    final token = await AuthRepository.instance.readToken();
    expect(token, contains('penyayang@contoh.id'));
  });

  testWidgets(
    'login lewat nomor telepon menyimpan nomor sebagai subjek token',
    (tester) async {
      await tester.pumpWidget(wrapRouter(buildLoginRouter()));
      await tester.pumpAndSettle();

      await tester.enterText(phoneField(), '8123456789');
      await tester.tap(find.text('Lanjut'));
      await pumpFrames(tester);
      await enterOtp(tester, '123456');

      expect(AuthController.instance.signedIn, isTrue);
      expect(find.text('EXPLORE'), findsOneWidget);

      final token = await AuthRepository.instance.readToken();
      expect(token, contains('+628123456789'));
    },
  );

  testWidgets(
    'kode salah mengurangi percobaan lalu terkunci setelah tiga kali',
    (tester) async {
      await tester.pumpWidget(wrapRouter(buildLoginRouter()));
      await tester.pumpAndSettle();

      await openOtpWithEmail(tester);

      await enterOtp(tester, '000000');
      expect(find.text('Kode tidak cocok'), findsOneWidget);
      expect(find.text('Sisa percobaan: 2'), findsOneWidget);

      await enterOtp(tester, '000000');
      expect(find.text('Sisa percobaan: 1'), findsOneWidget);

      await enterOtp(tester, '000000');
      expect(
        find.text(
          'Terlalu banyak percobaan. Kirim ulang kode untuk melanjutkan.',
        ),
        findsOneWidget,
      );
      expect(tester.widget<TextField>(otpField(0)).enabled, isFalse);
    },
  );
}
