import 'package:blue_track/core/state/app_state.dart';
import 'package:blue_track/features/profile/presentation/profile_page.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_harness.dart';

void main() {
  setUp(() {
    // Signing out deletes the mock token through flutter_secure_storage, which
    // has no platform implementation under `flutter test`.
    FlutterSecureStorage.setMockInitialValues({});
    AuthController.instance.setSignedIn(false);
  });

  tearDown(() => AuthController.instance.setSignedIn(false));

  testWidgets('tombol keluar mengikuti status sesi tanpa perlu buka ulang tab', (
    tester,
  ) async {
    await tester.pumpWidget(wrapPage(const ProfilePage()));
    await tester.pump();

    expect(find.text('Keluar'), findsNothing);

    // Mirrors a Profile tab that was first opened while signed out and is kept
    // alive by the app shell. The sign-out row must appear when the session
    // starts, not only after the tab is rebuilt.
    AuthController.instance.setSignedIn(true);
    await tester.pump();

    expect(find.text('Keluar'), findsOneWidget);

    await tester.tap(find.text('Keluar'));
    await tester.pumpAndSettle();

    expect(AuthController.instance.signedIn, isFalse);
    expect(find.text('Keluar'), findsNothing);
  });

  testWidgets('pintasan profil tetap tampil saat belum masuk', (tester) async {
    await tester.pumpWidget(wrapPage(const ProfilePage()));
    await tester.pump();

    expect(find.text('Preferensi Minat'), findsOneWidget);
    expect(find.text('Lapor Temuan'), findsOneWidget);
  });
}
