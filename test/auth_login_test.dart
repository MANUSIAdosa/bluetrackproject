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
const _termsLabel = 'Syarat\u00a0&\u00a0Ketentuan';
const _identifierKey = Key('auth_identifier_field');

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

Finder identifierField() => find.byKey(_identifierKey);
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
  await tester.enterText(identifierField(), email);
  await tester.tap(find.byKey(const Key('auth_consent_checkbox')));
  await tester.pump();
  await tester.tap(find.text('Lanjut'));
  await pumpFrames(tester);
}

/// Enters a code without submitting it.
Future<void> fillOtp(WidgetTester tester, String code) async {
  for (var i = 0; i < code.length; i++) {
    await tester.enterText(otpField(i), code[i]);
  }
  await pumpFrames(tester);
}

/// Enters a code and submits it through the explicit Verify action.
Future<void> enterOtp(WidgetTester tester, String code) async {
  await fillOtp(tester, code);
  await tester.tap(find.text('Verifikasi'));
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

  testWidgets('satu kolom untuk email atau nomor telepon', (tester) async {
    await tester.pumpWidget(wrapRouter(buildLoginRouter()));
    await tester.pumpAndSettle();

    expect(find.text('Selamat datang kembali'), findsOneWidget);
    expect(identifierField(), findsOneWidget);
    expect(find.text('Email atau nomor telepon'), findsOneWidget);
    // No second field, no separator, no country prefix.
    expect(find.text('ATAU'), findsNothing);
    expect(find.text('+62'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Lanjut'), findsOneWidget);
    expect(otpField(0), findsNothing);
  });

  testWidgets('versi Inggris memakai satu kolom identifier', (tester) async {
    await tester.pumpWidget(
      wrapRouter(buildLoginRouter(), locale: const Locale('en')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Email or phone number'), findsOneWidget);
    expect(find.text('OR'), findsNothing);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('urutan dan jarak: judul, subjudul, kolom, persetujuan, tombol', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrapRouter(buildLoginRouter()));
    await tester.pumpAndSettle();

    double top(Finder f) => tester.getTopLeft(f).dy;
    double bottom(Finder f) => tester.getBottomLeft(f).dy;

    final title = find.text('Selamat datang kembali');
    final subtitle = find.text('Masuk dengan email atau nomor telepon.');
    final button = find.byType(FilledButton);

    expect(top(subtitle) - bottom(title), inInclusiveRange(8, 12));
    expect(top(identifierField()) - bottom(subtitle), inInclusiveRange(24, 32));
    expect(
      top(find.byKey(const Key('auth_consent_checkbox'))) -
          bottom(identifierField()),
      inInclusiveRange(12, 20),
    );
    expect(top(button) - bottom(legalNotice()), closeTo(32, 2));
    expect(top(title), lessThan(top(identifierField())));
    expect(top(identifierField()), lessThan(top(button)));
    expect(tester.getSize(identifierField()).height, inInclusiveRange(56, 60));
    expect(tester.getSize(button).height, inInclusiveRange(52, 56));
  });

  testWidgets('form tetap di atas dengan persetujuan tepat sebelum tombol', (
    tester,
  ) async {
    await tester.pumpWidget(wrapRouter(buildLoginRouter()));
    await tester.pumpAndSettle();

    // Dead centring put the field at 261, then 296 — a vertically centred field
    // is what the mobile keyboard covers. Top alignment puts it around 178.
    final fieldTop = tester.getTopLeft(identifierField()).dy;
    final subtitleBottom = tester
        .getBottomLeft(find.text('Masuk dengan email atau nomor telepon.'))
        .dy;
    expect(fieldTop, greaterThan(100));
    expect(fieldTop, lessThan(240));
    expect(fieldTop - subtitleBottom, inInclusiveRange(28, 40));

    final consentTop = tester.getTopLeft(legalNotice()).dy;
    final consentBottom = tester.getBottomLeft(legalNotice()).dy;
    final phoneBottom = tester.getBottomLeft(identifierField()).dy;
    final buttonTop = tester.getTopLeft(find.byType(FilledButton)).dy;
    expect(consentTop, greaterThan(phoneBottom));
    expect(buttonTop, greaterThan(consentBottom));
    expect(consentTop - phoneBottom, inInclusiveRange(20, 36));
    expect(buttonTop - consentBottom, inInclusiveRange(28, 56));
    // The notice hugs the field more than the primary action.
    expect(consentTop - phoneBottom, lessThan(buttonTop - consentBottom));
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
      expect(
        tester.getBottomLeft(identifierField()).dy,
        lessThan(viewport.bottom),
      );
      expect(
        tester.getBottomLeft(identifierField()).dy,
        lessThan(viewport.bottom),
      );
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

  testWidgets(
    'OTP dan tombol Verifikasi tetap terlihat saat keyboard terbuka',
    (tester) async {
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = const Size(1170, 2532); // 390 x 844
      tester.view.viewInsets = const FakeViewPadding(bottom: 1020); // 340
      addTearDown(tester.view.reset);

      await tester.pumpWidget(wrapRouter(buildLoginRouter()));
      await tester.pumpAndSettle();
      await openOtpWithEmail(tester);

      final viewport = tester.getRect(find.byType(SingleChildScrollView));
      expect(tester.getBottomLeft(otpField(0)).dy, lessThan(viewport.bottom));
      expect(
        tester.getBottomLeft(find.text('Verifikasi')).dy,
        lessThan(viewport.bottom),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('kalimat persetujuan satu baris pada layar lebar', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrapRouter(buildLoginRouter()));
    await tester.pumpAndSettle();

    final sentence = find.textContaining('Saya menyetujui');
    // One line at 12sp with height 1.4 is roughly 17dp.
    expect(tester.getSize(sentence).height, lessThan(24));
    expect(tester.takeException(), isNull);
  });

  testWidgets('huruf persetujuan tidak pernah lebih kecil dari 9 sp', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;

    for (final width in const [320.0, 390.0, 800.0]) {
      tester.view.physicalSize = Size(width, 900);
      await tester.pumpWidget(wrapRouter(buildLoginRouter()));
      await tester.pumpAndSettle();

      final text = tester.widget<Text>(find.textContaining('Saya menyetujui'));
      final span = text.textSpan! as TextSpan;
      expect(
        span.style!.fontSize,
        greaterThanOrEqualTo(9),
        reason: 'width $width',
      );
      expect(tester.takeException(), isNull, reason: 'width $width');
    }
    addTearDown(tester.view.reset);
  });

  testWidgets('contoh format hilang saat kolom aktif', (tester) async {
    await tester.pumpWidget(wrapRouter(buildLoginRouter()));
    await tester.pumpAndSettle();

    expect(find.text('nama@email.com atau 8123456789'), findsOneWidget);

    await tester.tap(identifierField());
    await tester.pumpAndSettle();

    expect(find.text('nama@email.com atau 8123456789'), findsNothing);
    // The floating label still says what the field is for.
    expect(find.text('Email atau nomor telepon'), findsOneWidget);
  });

  testWidgets('kode negara muncul otomatis saat mengetik angka', (
    tester,
  ) async {
    await tester.pumpWidget(wrapRouter(buildLoginRouter()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('auth_dial_code')), findsNothing);

    await tester.enterText(identifierField(), 'penyayang@contoh.id');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('auth_dial_code')), findsNothing);

    await tester.enterText(identifierField(), '8123456789');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('auth_dial_code')), findsOneWidget);
    expect(find.text('+62'), findsOneWidget);
  });

  testWidgets('kode negara terpilih dipakai pada nomor tujuan OTP', (
    tester,
  ) async {
    await tester.pumpWidget(wrapRouter(buildLoginRouter()));
    await tester.pumpAndSettle();

    await tester.enterText(identifierField(), '8123456789');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('auth_dial_code')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('MY  +60'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('auth_consent_checkbox')));
    await tester.pump();
    await tester.tap(find.text('Lanjut'));
    await pumpFrames(tester);

    expect(find.text('Kode dikirim ke +608123456789'), findsOneWidget);
  });

  testWidgets('kalimat persetujuan tidak terpotong di layar kecil', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrapRouter(buildLoginRouter()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final text = tester.widget<Text>(find.textContaining('Saya menyetujui'));
    // Wrapped rather than clipped when one line would need tiny type.
    expect(text.maxLines, isNull);
    expect(text.softWrap, isNot(false));
    // Two or more lines means the tail is on screen instead of cut off.
    expect(
      tester.getSize(find.textContaining('Saya menyetujui')).height,
      greaterThan(30),
    );
  });

  testWidgets('kalimat persetujuan utuh pada layar sangat sempit', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(280, 640);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      wrapRouter(buildLoginRouter(), locale: const Locale('en')),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final sentence = find.textContaining('I agree');
    expect(sentence, findsOneWidget);
    expect(tester.getSize(sentence).height, greaterThan(30));
  });

  testWidgets('label kolom tetap terbaca setelah diisi', (tester) async {
    await tester.pumpWidget(wrapRouter(buildLoginRouter()));
    await tester.pumpAndSettle();

    expect(find.text('Email atau nomor telepon'), findsOneWidget);

    await tester.enterText(identifierField(), 'penyayang@contoh.id');
    await tester.pumpAndSettle();

    expect(find.text('Email atau nomor telepon'), findsOneWidget);
  });

  testWidgets('tanpa isian, lanjut menampilkan error dan tidak membuka OTP', (
    tester,
  ) async {
    await tester.pumpWidget(wrapRouter(buildLoginRouter()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lanjut'));
    await tester.pump();

    expect(find.text('Masukkan email atau nomor telepon.'), findsOneWidget);
    expect(otpField(0), findsNothing);
  });

  testWidgets('persetujuan belum dicentang mencegah lanjut ke OTP', (
    tester,
  ) async {
    await tester.pumpWidget(wrapRouter(buildLoginRouter()));
    await tester.pumpAndSettle();

    await tester.enterText(identifierField(), 'penyayang@contoh.id');
    await tester.tap(find.text('Lanjut'));
    await tester.pump();

    expect(find.byKey(const Key('auth_consent_error')), findsOneWidget);
    expect(otpField(0), findsNothing);
  });

  testWidgets('mencentang persetujuan menghapus pesan validasi', (
    tester,
  ) async {
    await tester.pumpWidget(wrapRouter(buildLoginRouter()));
    await tester.pumpAndSettle();

    await tester.enterText(identifierField(), 'penyayang@contoh.id');
    await tester.tap(find.text('Lanjut'));
    await tester.pump();
    expect(find.byKey(const Key('auth_consent_error')), findsOneWidget);

    await tester.tap(find.byKey(const Key('auth_consent_checkbox')));
    await tester.pump();
    expect(find.byKey(const Key('auth_consent_error')), findsNothing);
  });

  testWidgets('persetujuan yang dicentang mengizinkan lanjut ke OTP', (
    tester,
  ) async {
    await tester.pumpWidget(wrapRouter(buildLoginRouter()));
    await tester.pumpAndSettle();

    await tester.enterText(identifierField(), 'penyayang@contoh.id');
    await tester.tap(find.byKey(const Key('auth_consent_checkbox')));
    await tester.pump();
    await tester.tap(find.text('Lanjut'));
    await pumpFrames(tester);

    expect(otpField(0), findsOneWidget);
    expect(find.byKey(const Key('auth_consent_error')), findsNothing);
  });

  testWidgets('checkbox persetujuan hanya tampil di layar masuk', (
    tester,
  ) async {
    await tester.pumpWidget(wrapRouter(buildLoginRouter()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('auth_consent_checkbox')), findsOneWidget);
    await openOtpWithEmail(tester);

    expect(find.byKey(const Key('auth_consent_checkbox')), findsNothing);
    expect(legalNotice(), findsNothing);
  });

  testWidgets('enam digit tidak terkirim sebelum tombol Verifikasi ditekan', (
    tester,
  ) async {
    await tester.pumpWidget(wrapRouter(buildLoginRouter()));
    await tester.pumpAndSettle();

    await openOtpWithEmail(tester);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    await fillOtp(tester, '123456');
    expect(
      List.generate(
        6,
        (index) => tester.widget<TextField>(otpField(index)).controller!.text,
      ).join(),
      '123456',
    );

    expect(find.byType(LoginPage), findsOneWidget);
    expect(AuthController.instance.signedIn, isFalse);
    expect(find.text('Verifikasi'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );

    await tester.tap(find.text('Verifikasi'));
    await pumpFrames(tester);
    expect(AuthController.instance.signedIn, isTrue);
    expect(find.text('EXPLORE'), findsOneWidget);
  });

  testWidgets('jarak di OTP mengelompokkan input, tombol, dan resend', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrapRouter(buildLoginRouter()));
    await tester.pumpAndSettle();
    await openOtpWithEmail(tester);

    double top(Finder finder) => tester.getTopLeft(finder).dy;
    double bottom(Finder finder) => tester.getBottomLeft(finder).dy;

    final subtitle = find.text('Kode dikirim ke penyayang@contoh.id');
    final firstOtp = otpField(0);
    final verify = find.byType(FilledButton);
    final resendPrompt = find.text('Belum menerima kode?');
    final countdown = find.textContaining('Kirim ulang dalam');

    // Previous proportions: 50dp boxes, 8dp gaps, inside the page margin.
    expect(
      tester.getSize(find.byKey(const Key('auth_otp_row'))).width,
      closeTo(340, 0.5),
    );

    final boxWidth = tester.getSize(otpField(0)).width;
    expect(boxWidth, closeTo(50, 0.5));
    for (var index = 0; index < 6; index++) {
      final size = tester.getSize(otpField(index));
      expect(size.width, closeTo(boxWidth, 0.01));
      // Comfortable tap target, height from the text and field padding.
      expect(size.height, greaterThanOrEqualTo(48));
    }
    for (var index = 0; index < 5; index++) {
      final gap =
          tester.getTopLeft(otpField(index + 1)).dx -
          tester.getTopRight(otpField(index)).dx;
      expect(gap, closeTo(8, 0.5));
    }

    final headingGap = top(firstOtp) - bottom(subtitle);
    final actionGap = top(verify) - bottom(firstOtp);
    final resendGap = top(resendPrompt) - bottom(verify);
    final countdownGap = top(countdown) - bottom(resendPrompt);

    expect(headingGap, inInclusiveRange(28, 40));
    expect(actionGap, inInclusiveRange(12, 24));
    expect(resendGap, inInclusiveRange(20, 32));
    expect(countdownGap, inInclusiveRange(4, 16));
  });

  testWidgets('jarak judul ke isian sama di tahap email dan OTP', (
    tester,
  ) async {
    await tester.pumpWidget(wrapRouter(buildLoginRouter()));
    await tester.pumpAndSettle();

    final identifierGap =
        tester.getTopLeft(identifierField()).dy -
        tester
            .getBottomLeft(find.text('Masuk dengan email atau nomor telepon.'))
            .dy;

    await openOtpWithEmail(tester);

    final otpGap =
        tester.getTopLeft(otpField(0)).dy -
        tester
            .getBottomLeft(find.text('Kode dikirim ke penyayang@contoh.id'))
            .dy;

    expect((identifierGap - otpGap).abs(), lessThan(2));
  });

  testWidgets('resend menampilkan prompt dan countdown dengan jelas', (
    tester,
  ) async {
    await tester.pumpWidget(wrapRouter(buildLoginRouter()));
    await tester.pumpAndSettle();

    await openOtpWithEmail(tester);

    expect(find.text('Belum menerima kode?'), findsOneWidget);
    expect(find.textContaining('Kirim ulang dalam'), findsOneWidget);
    expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
    expect(find.byKey(const Key('auth_resend_button')), findsNothing);

    await tester.pump(const Duration(seconds: 60));
    await tester.pump();
    expect(find.byKey(const Key('auth_resend_button')), findsOneWidget);
    expect(find.text('Kirim ulang kode'), findsOneWidget);

    await tester.tap(find.byKey(const Key('auth_resend_button')));
    await tester.pump();
    expect(find.textContaining('Kirim ulang dalam'), findsOneWidget);
  });

  testWidgets('email tidak valid ditolak dengan pesan inline', (tester) async {
    await tester.pumpWidget(wrapRouter(buildLoginRouter()));
    await tester.pumpAndSettle();

    await tester.enterText(identifierField(), 'bukan@email');
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

    await tester.enterText(identifierField(), '123');
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

    await tester.enterText(identifierField(), 'bukan@email');
    await tester.tap(find.text('Lanjut'));
    await tester.pump();
    expect(find.text('Format email tidak valid'), findsOneWidget);

    await tester.enterText(identifierField(), 'penyayang@contoh.id');
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

    await tester.enterText(identifierField(), '8123456789');
    await tester.tap(find.byKey(const Key('auth_consent_checkbox')));
    await tester.pump();
    await tester.tap(find.text('Lanjut'));
    await pumpFrames(tester);

    expect(find.text('Masukkan kode verifikasi'), findsOneWidget);
    expect(find.text('Kode dikirim ke +628123456789'), findsOneWidget);
    expect(otpField(0), findsOneWidget);
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
    expect(identifierField(), findsOneWidget);
    expect(
      tester
          .widget<Checkbox>(find.byKey(const Key('auth_consent_checkbox')))
          .value,
      isTrue,
    );
    expect(
      tester.widget<TextField>(identifierField()).controller?.text,
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

      await tester.enterText(identifierField(), '8123456789');
      await tester.tap(find.byKey(const Key('auth_consent_checkbox')));
      await tester.pump();
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
