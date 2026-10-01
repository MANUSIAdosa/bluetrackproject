import 'package:flutter/widgets.dart';

/// Lightweight localization: Indonesian (default) and English.
///
/// Keys are plain strings grouped by feature. Placeholders use `{name}` and are
/// substituted via [AppLocalizations.text] arguments.
class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const supportedLocales = [Locale('id'), Locale('en')];

  String text(String key, [Map<String, String> args = const {}]) {
    var value = _values[locale.languageCode]?[key] ?? _values['id']![key] ?? key;
    args.forEach((k, v) => value = value.replaceAll('{$k}', v));
    return value;
  }

  /// Exposed for locale-parity tests.
  static Map<String, Map<String, String>> get values => _values;

  static const Map<String, Map<String, String>> _values = {
    'id': {
      // --- Common ---
      'common.retry': 'Coba lagi',
      'common.loading': 'Memuat...',
      'common.continue': 'Lanjut',
      'common.next': 'Berikutnya',
      'common.cancel': 'Batal',
      'common.comingSoon':
          'Halaman ini akan tersedia pada subproyek berikutnya.',
      'common.error': 'Terjadi kesalahan.',
      'common.errorRetry': 'Gagal memuat. Periksa koneksi Anda.',

      // --- Shell / navigation ---
      'nav.jelajahi': 'Jelajahi',
      'nav.transparency': 'Transparansi',
      'nav.impact': 'Dampakku',
      'nav.profile': 'Profil',
      'shell.offline': 'Anda sedang offline. Menampilkan data tersimpan.',
      'shell.notifications': 'Notifikasi',

      // --- Login prompt ---
      'login.prompt.title': 'Fitur ini butuh masuk',
      'login.prompt.body':
          'Masuk untuk melanjutkan. Anda akan kembali ke halaman ini.',
      'login.prompt.button': 'Masuk',

      // --- Categories / interests ---
      'cat.semua': 'Semua',
      'cat.penyu': 'Penyu',
      'cat.karang': 'Karang',
      'cat.mangrove': 'Mangrove',
      'cat.mamalia_laut': 'Mamalia laut',
      'cat.lamun': 'Lamun',
      'cat.tersimpan': 'Tersimpan',

      // --- Onboarding (P01) ---
      'onboarding.skip': 'Lewati',
      'onboarding.chooseInterests': 'Pilih Minat',
      'onboarding.start': 'Mulai',
      'onboarding.slide1.title': 'Laut Menyerap Karbon',
      'onboarding.slide1.body':
          'Laut menyerap lebih dari sepertiga karbon yang dilepas manusia setiap tahun.',
      'onboarding.slide2.title': 'Terumbu Karang Rumah Ikan',
      'onboarding.slide2.body':
          'Lima persen dasar laut menampung seperempat spesies laut dunia.',
      'onboarding.slide3.title': 'Penyu Butuh Bantuanmu',
      'onboarding.slide3.body':
          'Ribuan tukik gagal mencapai laut karena sampah dan hilangnya habitat.',
      'onboarding.interests.title': 'Pilih Minatmu',
      'onboarding.interests.subtitle':
          'Kami akan mengurutkan proyek sesuai minatmu.',
      'onboarding.minOne': 'Pilih minimal satu',

      // --- Auth (P02) ---
      'auth.title': 'Masuk ke BlueTrack',
      'auth.step.email': 'Email',
      'auth.step.phone': 'Telepon',
      'auth.step.otp': 'Kode',
      'auth.email.hint': 'nama@email.com',
      'auth.email.invalid': 'Format email tidak valid',
      'auth.phone.hint': '8123456789',
      'auth.phone.invalid': 'Nomor telepon tidak valid',
      'auth.sendCode': 'Kirim Kode',
      'auth.otp.title': 'Masukkan kode verifikasi',
      'auth.otp.subtitle': 'Kode dikirim ke {phone}',
      'auth.otp.mismatch': 'Kode tidak cocok',
      'auth.otp.attemptsLeft': 'Sisa percobaan: {n}',
      'auth.otp.locked':
          'Terlalu banyak percobaan. Kirim ulang kode untuk melanjutkan.',
      'auth.otp.resendIn': 'Kirim ulang dalam {s} detik',
      'auth.otp.resend': 'Kirim ulang kode',
      'auth.otp.sent': 'Kode verifikasi terkirim (mock: 123456)',
      'auth.verify': 'Verifikasi',
      'auth.privacy':
          'Dengan melanjutkan, Anda menyetujui Kebijakan Privasi dan Syarat & Ketentuan.',
      'auth.privacyPolicy': 'Kebijakan Privasi',
      'auth.terms': 'Syarat & Ketentuan',
      'auth.skipLogin': 'Lanjut tanpa masuk',

      // --- Explore (P03) ---
      'explore.title': 'Jelajahi',
      'explore.searchHint': 'Cari proyek, organisasi, atau lokasi',
      'explore.forYou': 'Untuk minatmu',
      'explore.projects': 'Proyek',
      'explore.viewList': 'Daftar',
      'explore.viewMap': 'Peta',
      'explore.empty.title': 'Tidak ada proyek',
      'explore.empty.body': 'Coba ubah kata kunci atau kategori.',
      'explore.emptySaved.title': 'Belum ada proyek tersimpan',
      'explore.emptySaved.body':
          'Simpan proyek agar bisa diakses saat offline.',
      'explore.mapUnavailable':
          'Mode peta belum tersedia pada subproyek ini.',

      // --- Project detail (P04) ---
      'project.tab.about': 'Tentang',
      'project.tab.budget': 'Anggaran',
      'project.tab.reports': 'Laporan',
      'project.tab.reviews': 'Ulasan',
      'project.raised': 'Terkumpul',
      'project.target': 'Target',
      'project.donate': 'Donasi',
      'project.budget.item': 'Pos anggaran',
      'project.budget.amount': 'Jumlah',
      'project.budget.percent': 'Porsi',
      'project.reports.empty': 'Belum ada laporan.',
      'project.reviews.empty': 'Belum ada ulasan.',

      // --- Organization (P05) ---
      'org.verified': 'Terverifikasi',
      'org.stats.projects': 'Proyek',
      'org.stats.disbursed': 'Dana disalurkan',
      'org.stats.communities': 'Komunitas',
      'org.checklist.title': 'Checklist verifikasi',
      'org.checklist.legal': 'Badan hukum terdaftar',
      'org.checklist.audit': 'Laporan audit tersedia',
      'org.checklist.field': 'Verifikasi lapangan',
      'org.checklist.finance': 'Pelaporan keuangan',
      'org.established': 'Berdiri {year}',
      'org.downloadAudit': 'Unduh laporan audit',
      'org.contact': 'Hubungi',

      // --- Donation (P06, amount step) ---
      'donate.title': 'Donasi',
      'donate.step1': 'Nominal',
      'donate.step2': 'Tujuan',
      'donate.step3': 'Konfirmasi',
      'donate.step4': 'Hasil',
      'donate.quickAmount': 'Nominal cepat',
      'donate.customAmount': 'Nominal lainnya',
      'donate.amountInvalid': 'Masukkan nominal donasi',
      'donate.frequency': 'Frekuensi',
      'donate.once': 'Sekali',
      'donate.monthly': 'Bulanan',
      'donate.stepPending':
          'Langkah berikutnya akan tersedia pada subproyek berikutnya.',

      // --- Placeholder tab pages ---
      'transparency.title': 'Transparansi',
      'impact.title': 'Dampakku',
      'impact.empty': 'Belum ada data dampak.',
      'profile.title': 'Profil',
      'profile.signOut': 'Keluar',
      'notifications.title': 'Notifikasi',
    },
    'en': {
      // --- Common ---
      'common.retry': 'Retry',
      'common.loading': 'Loading...',
      'common.continue': 'Continue',
      'common.next': 'Next',
      'common.cancel': 'Cancel',
      'common.comingSoon':
          'This page will be available in the next subproject.',
      'common.error': 'Something went wrong.',
      'common.errorRetry': 'Failed to load. Check your connection.',

      // --- Shell / navigation ---
      'nav.jelajahi': 'Explore',
      'nav.transparency': 'Transparency',
      'nav.impact': 'My Impact',
      'nav.profile': 'Profile',
      'shell.offline': "You're offline. Showing saved data.",
      'shell.notifications': 'Notifications',

      // --- Login prompt ---
      'login.prompt.title': 'Sign in required',
      'login.prompt.body':
          'Sign in to continue. You will return to this page.',
      'login.prompt.button': 'Sign in',

      // --- Categories / interests ---
      'cat.semua': 'All',
      'cat.penyu': 'Turtle',
      'cat.karang': 'Coral',
      'cat.mangrove': 'Mangrove',
      'cat.mamalia_laut': 'Marine mammals',
      'cat.lamun': 'Seagrass',
      'cat.tersimpan': 'Saved',

      // --- Onboarding (P01) ---
      'onboarding.skip': 'Skip',
      'onboarding.chooseInterests': 'Choose Interests',
      'onboarding.start': 'Start',
      'onboarding.slide1.title': 'The Ocean Absorbs Carbon',
      'onboarding.slide1.body':
          'The ocean absorbs more than a third of the carbon humans emit each year.',
      'onboarding.slide2.title': 'Coral Reefs Are Fish Homes',
      'onboarding.slide2.body':
          'Five percent of the seafloor shelters a quarter of all marine species.',
      'onboarding.slide3.title': 'Turtles Need Your Help',
      'onboarding.slide3.body':
          'Thousands of hatchlings never reach the sea due to waste and habitat loss.',
      'onboarding.interests.title': 'Pick Your Interests',
      'onboarding.interests.subtitle':
          "We'll sort projects to match your interests.",
      'onboarding.minOne': 'Pick at least one',

      // --- Auth (P02) ---
      'auth.title': 'Sign in to BlueTrack',
      'auth.step.email': 'Email',
      'auth.step.phone': 'Phone',
      'auth.step.otp': 'Code',
      'auth.email.hint': 'name@email.com',
      'auth.email.invalid': 'Invalid email format',
      'auth.phone.hint': '8123456789',
      'auth.phone.invalid': 'Invalid phone number',
      'auth.sendCode': 'Send Code',
      'auth.otp.title': 'Enter verification code',
      'auth.otp.subtitle': 'Code sent to {phone}',
      'auth.otp.mismatch': "Code doesn't match",
      'auth.otp.attemptsLeft': 'Attempts left: {n}',
      'auth.otp.locked':
          'Too many attempts. Resend the code to continue.',
      'auth.otp.resendIn': 'Resend in {s}s',
      'auth.otp.resend': 'Resend code',
      'auth.otp.sent': 'Verification code sent (mock: 123456)',
      'auth.verify': 'Verify',
      'auth.privacy':
          'By continuing, you agree to the Privacy Policy and Terms & Conditions.',
      'auth.privacyPolicy': 'Privacy Policy',
      'auth.terms': 'Terms & Conditions',
      'auth.skipLogin': 'Continue without signing in',

      // --- Explore (P03) ---
      'explore.title': 'Explore',
      'explore.searchHint': 'Search projects, organizations, or places',
      'explore.forYou': 'For you',
      'explore.projects': 'Projects',
      'explore.viewList': 'List',
      'explore.viewMap': 'Map',
      'explore.empty.title': 'No projects',
      'explore.empty.body': 'Try a different keyword or category.',
      'explore.emptySaved.title': 'No saved projects yet',
      'explore.emptySaved.body':
          'Save projects to access them while offline.',
      'explore.mapUnavailable': 'Map mode is not available in this subproject.',

      // --- Project detail (P04) ---
      'project.tab.about': 'About',
      'project.tab.budget': 'Budget',
      'project.tab.reports': 'Reports',
      'project.tab.reviews': 'Reviews',
      'project.raised': 'Raised',
      'project.target': 'Target',
      'project.donate': 'Donate',
      'project.budget.item': 'Budget item',
      'project.budget.amount': 'Amount',
      'project.budget.percent': 'Share',
      'project.reports.empty': 'No reports yet.',
      'project.reviews.empty': 'No reviews yet.',

      // --- Organization (P05) ---
      'org.verified': 'Verified',
      'org.stats.projects': 'Projects',
      'org.stats.disbursed': 'Funds disbursed',
      'org.stats.communities': 'Communities',
      'org.checklist.title': 'Verification checklist',
      'org.checklist.legal': 'Registered legal entity',
      'org.checklist.audit': 'Audit report available',
      'org.checklist.field': 'Field verification',
      'org.checklist.finance': 'Financial reporting',
      'org.established': 'Established {year}',
      'org.downloadAudit': 'Download audit report',
      'org.contact': 'Contact',

      // --- Donation (P06, amount step) ---
      'donate.title': 'Donate',
      'donate.step1': 'Amount',
      'donate.step2': 'Purpose',
      'donate.step3': 'Confirmation',
      'donate.step4': 'Result',
      'donate.quickAmount': 'Quick amount',
      'donate.customAmount': 'Custom amount',
      'donate.amountInvalid': 'Enter a donation amount',
      'donate.frequency': 'Frequency',
      'donate.once': 'One-time',
      'donate.monthly': 'Monthly',
      'donate.stepPending':
          'The next step will be available in the next subproject.',

      // --- Placeholder tab pages ---
      'transparency.title': 'Transparency',
      'impact.title': 'My Impact',
      'impact.empty': 'No impact data yet.',
      'profile.title': 'Profile',
      'profile.signOut': 'Sign out',
      'notifications.title': 'Notifications',
    },
  };
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['id', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension L10n on BuildContext {
  String tr(String key, [Map<String, String> args = const {}]) =>
      AppLocalizations.of(this).text(key, args);
}
