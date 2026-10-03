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

      // --- Legal (Privacy Policy / Terms) ---
      'legal.privacy.title': 'Kebijakan Privasi',
      'legal.privacy.intro':
          'Kebijakan ini menjelaskan bagaimana BlueTrack mengumpulkan, '
          'menggunakan, dan melindungi data Anda selama menggunakan aplikasi.',
      'legal.privacy.s1.title': 'Data yang Kami Kumpulkan',
      'legal.privacy.s1.body':
          'Kami mengumpulkan data yang Anda berikan saat mendaftar (email dan '
          'nomor telepon), minat konservasi yang dipilih saat onboarding, '
          'riwayat donasi, serta proyek yang Anda simpan. Informasi kartu '
          'pembayaran tidak disimpan di dalam aplikasi.',
      'legal.privacy.s2.title': 'Cara Kami Menggunakan Data',
      'legal.privacy.s2.body':
          'Data digunakan untuk memverifikasi akun Anda melalui kode OTP, '
          'menampilkan riwayat donasi dan dampak, mengurutkan proyek sesuai '
          'minat, dan mengirimkan notifikasi terkait donasi. Data Anda tidak '
          'digunakan untuk iklan pihak ketiga.',
      'legal.privacy.s3.title': 'Keamanan Data',
      'legal.privacy.s3.body':
          'Token autentikasi disimpan di penyimpanan aman perangkat, dan data '
          'proyek serta laporan yang tersimpan tetap dapat diakses tanpa koneksi '
          'internet. Kami tidak menyimpan kata sandi dalam bentuk teks biasa.',
      'legal.privacy.s4.title': 'Berbagi dengan Pihak Ketiga',
      'legal.privacy.s4.body':
          'Kami tidak menjual atau menyewakan data pribadi Anda. Informasi '
          'donasi hanya ditampilkan sebagaimana tercantum di halaman '
          'Transparansi demi akuntabilitas publik. Sponsor tidak memiliki akses '
          'ke keputusan konservasi atau prioritas proyek.',
      'legal.privacy.s5.title': 'Hak Anda',
      'legal.privacy.s5.body':
          'Anda dapat menghapus data tersimpan dari perangkat melalui halaman '
          'Pengaturan, dan meminta penutupan akun kapan saja. Untuk pertanyaan '
          'seputar data pribadi, hubungi: privasi@bluetrack.app.',
      'legal.terms.title': 'Syarat & Ketentuan',
      'legal.terms.intro':
          'Dengan menggunakan BlueTrack, Anda menyetujui ketentuan berikut. '
          'Harap membacanya sebelum melanjutkan.',
      'legal.terms.s1.title': 'Penerimaan Ketentuan',
      'legal.terms.s1.body':
          'Ketentuan ini berlaku untuk seluruh pengguna aplikasi BlueTrack. '
          'Jika Anda tidak setuju dengan salah satu ketentuan, mohon tidak '
          'menggunakan aplikasi ini.',
      'legal.terms.s2.title': 'Akun dan Verifikasi',
      'legal.terms.s2.body':
          'Anda bertanggung jawab atas keamanan perangkat dan akun Anda. '
          'Verifikasi dilakukan melalui kode sekali pakai yang dikirim ke nomor '
          'telepon Anda, dengan batas percobaan untuk mencegah penyalahgunaan.',
      'legal.terms.s3.title': 'Donasi dan Penggunaan Dana',
      'legal.terms.s3.body':
          'Donasi program (Dana A) disalurkan 100% ke proyek konservasi, '
          'sedangkan donasi operasional dan sponsor (Dana B) digunakan untuk '
          'biaya operasional platform. Kedua dana tidak pernah dicampur. '
          'Rincian penyaluran ditampilkan di halaman Transparansi.',
      'legal.terms.s4.title': 'Perilaku Pengguna',
      'legal.terms.s4.body':
          'Anda dilarang memberikan informasi yang menyesatkan saat mengajukan '
          'proposal, menyalahgunakan fitur platform, atau melakukan tindakan '
          'yang merugikan proyek konservasi dan pengguna lain.',
      'legal.terms.s5.title': 'Perubahan Ketentuan',
      'legal.terms.s5.body':
          'Ketentuan ini dapat diperbarui sewaktu-waktu, dan perubahan penting '
          'akan diinformasikan melalui aplikasi. Penggunaan lanjutan setelah '
          'perubahan berlaku berarti Anda menerima ketentuan yang baru.',

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

      // --- Legal (Privacy Policy / Terms) ---
      'legal.privacy.title': 'Privacy Policy',
      'legal.privacy.intro':
          'This policy explains how BlueTrack collects, uses, and protects '
          'your data while you use the app.',
      'legal.privacy.s1.title': 'Data We Collect',
      'legal.privacy.s1.body':
          'We collect the data you provide when signing up (email and phone '
          'number), the conservation interests chosen during onboarding, your '
          'donation history, and the projects you save. Payment card details '
          'are not stored in the app.',
      'legal.privacy.s2.title': 'How We Use Data',
      'legal.privacy.s2.body':
          'Data is used to verify your account via OTP code, show your '
          'donation history and impact, sort projects by your interests, and '
          'send donation-related notifications. Your data is not used for '
          'third-party advertising.',
      'legal.privacy.s3.title': 'Data Security',
      'legal.privacy.s3.body':
          'Auth tokens are stored in the device\'s secure storage, and saved '
          'project and report data remains accessible offline. We never store '
          'passwords in plain text.',
      'legal.privacy.s4.title': 'Sharing with Third Parties',
      'legal.privacy.s4.body':
          'We do not sell or rent your personal data. Donation information is '
          'only shown as listed on the Transparency page for public '
          'accountability. Sponsors have no access to conservation decisions '
          'or project priorities.',
      'legal.privacy.s5.title': 'Your Rights',
      'legal.privacy.s5.body':
          'You can remove saved data from your device via the Settings page '
          'and request account deletion at any time. For questions about '
          'personal data, contact: privasi@bluetrack.app.',
      'legal.terms.title': 'Terms & Conditions',
      'legal.terms.intro':
          'By using BlueTrack, you agree to the following terms. Please read '
          'them before continuing.',
      'legal.terms.s1.title': 'Acceptance of Terms',
      'legal.terms.s1.body':
          'These terms apply to all BlueTrack users. If you do not agree with '
          'any of them, please do not use this app.',
      'legal.terms.s2.title': 'Account and Verification',
      'legal.terms.s2.body':
          'You are responsible for the security of your device and account. '
          'Verification is done via a one-time code sent to your phone number, '
          'with an attempt limit to prevent abuse.',
      'legal.terms.s3.title': 'Donations and Use of Funds',
      'legal.terms.s3.body':
          'Program donations (Fund A) are passed 100% to conservation '
          'projects, while operational and sponsor donations (Fund B) cover '
          'platform operating costs. The two funds are never mixed. '
          'Disbursement details are shown on the Transparency page.',
      'legal.terms.s4.title': 'User Conduct',
      'legal.terms.s4.body':
          'You may not provide misleading information when submitting '
          'proposals, misuse platform features, or take actions that harm '
          'conservation projects and other users.',
      'legal.terms.s5.title': 'Changes to Terms',
      'legal.terms.s5.body':
          'These terms may be updated at any time, and significant changes '
          'will be announced in the app. Continued use after changes take '
          'effect means you accept the new terms.',

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
