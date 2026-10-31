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
    var value =
        _values[locale.languageCode]?[key] ?? _values['id']![key] ?? key;
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
      // `nav.*.description` is the one-line purpose of a tab, owned by the App
      // Shell tab configuration and reused by placeholder tab pages.
      'nav.jelajahi': 'Jelajahi',
      'nav.aksi': 'Aksi',
      'nav.aksi.description':
          'Lapor, pantau, dan dukung aksi bersama untuk laut.',
      'nav.transparency': 'Transparansi',
      'nav.transparency.description': 'Lihat ke mana donasi mengalir, terbuka untuk semua tanpa perlu login.',
      'nav.grants': 'Hibah',
      'nav.impact': 'Dampakku',
      'nav.impact.description':
          'Lihat dampak dari donasi yang sudah kamu berikan.',
      'nav.profile': 'Profil',
      'nav.profile.description':
          'Kelola akun dan pengaturanmu, serta akses proposal, notifikasi, '
          'dan materi belajar.',
      'shell.offline': 'Mode offline - menampilkan data tersimpan',
      'shell.notifications': 'Notifikasi',

      // --- Detail placeholders (part 3) ---
      // Verification pages for routes registered in Part 3; the parameter
      // label is identical in both locales so tests can lock onto it.
      'detail.action': 'Detail Aksi',
      'detail.settings': 'Pengaturan',
      'detail.learn': 'Belajar',
      'detail.report': 'Lapor Temuan',
      'detail.myReports': 'Laporan Saya',
      'detail.myActions': 'Aksi Saya',
      'detail.communityApply': 'Ajukan Aksi Komunitas',
      'detail.donationTrace': 'Jejak Dukungan',
      'placeholder.paramValue': '{name}: {value}',

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
      // Revised interest set (P01 part 4). The old categories above stay:
      // `assets/mock/projects.json` and filters.json still speak them.
      'cat.sampah_laut': 'Sampah Laut',
      'cat.terumbu_karang': 'Terumbu Karang',
      'cat.perikanan': 'Perikanan Berkelanjutan',
      'cat.satwa_laut': 'Satwa Laut',

      // --- Onboarding (P01) ---
      // Slide facts are NOT localized here: their single source is
      // `assets/mock/ocean_facts.json` (draft copy, see file TODO).
      'p01.skip': 'Lewati',
      'p01.next': 'Berikutnya',
      'p01.chooseInterests': 'Pilih Minat',
      'p01.start': 'Mulai',
      'p01.interests.title': 'Pilih Minatmu',
      'p01.interests.manage': 'Preferensi Minat',
      'p01.interests.later': 'Minat bisa diubah kapan saja melalui Profil.',
      'p01.interests.save': 'Simpan minat',
      'p01.interests.saveError': 'Minat belum tersimpan. Coba lagi.',
      'p01.interests.subtitle': 'Kami akan mengurutkan proyek sesuai minatmu.',
      'p01.minOne': 'Pilih minimal satu',

      // --- Auth (P02) ---
      // The title lives in the body heading, not the app bar, so there is one
      // clear anchor per step instead of two competing ones.
      'auth.email.title': 'Selamat datang kembali',
      'auth.email.subtitle':
          'Masuk untuk melihat proyek dan donasi yang Anda dukung.',
      'auth.email.label': 'Email',
      'auth.email.hint': 'nama@email.com',
      'auth.email.invalid': 'Format email tidak valid',
      'auth.phone.title': 'Nomor telepon Anda',
      'auth.phone.subtitle': 'Kami akan mengirim kode verifikasi ke nomor ini.',
      'auth.phone.label': 'Nomor telepon',
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
      // Split around the two inline document links so each document name stays a
      // separately tappable span instead of being parsed back out of a string.
      'auth.privacy.lead': 'Dengan melanjutkan, Anda menyetujui',
      'auth.privacyPolicy': 'Kebijakan Privasi',
      'auth.privacy.and': 'dan',
      'auth.terms': 'Syarat & Ketentuan',

      // --- Explore (P03) ---
      'explore.title': 'Jelajahi',
      'explore.searchHint': 'Cari proyek, organisasi, atau lokasi',
      'explore.forYou': 'Untuk minatmu',
      'explore.projects': 'Proyek',
      'explore.viewList': 'Daftar',
      'explore.viewMap': 'Peta',
      'explore.empty.title': 'Tidak ada proyek',
      'explore.empty.body': 'Coba ubah kata kunci atau kategori.',
      'explore.emptySaved.title':
          'Belum ada proyek tersimpan. Simpan lewat ikon bookmark di '
          'Detail Proyek.',
      'explore.emptySaved.body':
          'Simpan proyek agar bisa diakses saat offline.',
      'explore.emptySavedFiltered.title':
          'Tidak ada proyek tersimpan yang cocok',
      'explore.savedFilter.on': 'Tampilkan proyek tersimpan',
      'explore.savedFilter.off': 'Tampilkan semua proyek',
      'explore.resetFilter': 'Atur ulang filter',
      'explore.viewAll': 'Lihat semua proyek',
      'explore.mapUnavailable': 'Mode peta belum tersedia pada subproyek ini.',

      // P03 map, filters and offline collection. New keys use the `p03_`
      // prefix; the `explore.*` keys above stay for the list page.
      'p03_filter_action': 'Filter',
      'p03_filter_category': 'Kategori',
      'p03_filter_distance': 'Jarak',
      'p03_distance_reference': 'Jarak dari {place} (mock)',
      'p03_distance_semua': 'Semua',
      'p03_distance_dekat': '<250 km',
      'p03_distance_sedang': '250–1000 km',
      'p03_distance_jauh': '>1000 km',
      'p03_filter_condition': 'Status kondisi',
      'p03_condition_baik': 'Baik',
      'p03_condition_pemantauan': 'Perlu pemantauan',
      'p03_condition_kritis': 'Kritis',
      'p03_filter_reset': 'Atur ulang',
      'p03_filter_apply': 'Terapkan',
      'p03_filter_active': '{n} filter aktif',
      'p03_map_layer_conservation': 'Kawasan konservasi',
      'p03_map_count': '{n} proyek di peta',
      'p03_map_empty': 'Tidak ada proyek di peta untuk filter ini.',
      'p03_map_open_project': 'Lihat proyek',
      'p03_map_zoom_in': 'Perbesar peta',
      'p03_map_zoom_out': 'Perkecil peta',
      'p03_map_distance': '{n} km dari {place} (mock)',
      'p03_save': 'Simpan proyek',
      'p03_saved': 'Hapus dari tersimpan',
      'p03_map_condition': 'Kondisi',
      'p03_offline_empty_title': 'Belum ada proyek tersimpan',
      'p03_offline_reload': 'Muat ulang daftar tersimpan',
      'p03_simulate_offline': 'Simulasikan offline',
      'p03_scope_explore': 'Jelajahi',
      'p03_scope_saved': 'Tersimpan',
      'p03_category_label': 'Kategori',
      'p03_clear_all': 'Hapus semua',
      'p03_filter_title': 'Filter',
      'p03_filter_close': 'Tutup filter',
      'p03_filter_all': 'Semua',
      'p03_filter_category_helper': 'Pilih satu kategori',
      'p03_filter_condition_helper': 'Status pemantauan proyek',
      'p03_filter_result_count': 'Tampilkan {n} proyek',
      'p03_percent_funded': '{n}% terkumpul',
      'p03_map_legend': 'Keterangan kondisi',
      'p03_search_hint': 'Cari proyek atau organisasi',

      // --- Project detail (P04) ---
      'project.tab.about': 'Tentang',
      'p04_tab_funding': 'Pendanaan',
      'project.tab.reports': 'Laporan',
      'project.tab.reviews': 'Ulasan',
      'project.raised': 'Terkumpul',
      'project.target': 'Target',
      'project.remaining': 'Sisa dana',
      'project.donate': 'Donasi',
      'project.location': 'Lokasi proyek',
      'project.funding.item': 'Pos pendanaan',
      'project.funding.amount': 'Jumlah',
      'project.funding.percent': 'Porsi',
      'project.funding.total': 'Total',
      'project.reports.empty': 'Belum ada laporan.',
      'project.reviews.empty': 'Belum ada ulasan.',

      // --- P04 reports ---
      'p04_period_label': 'Periode',
      'p04_period_1m': '1 bulan',
      'p04_period_3m': '3 bulan',
      'p04_period_6m': '6 bulan',
      'p04_period_all': 'Semua',
      'p04_metrics_title': 'Ringkasan kondisi',
      'p04_metric_waste_label': 'Total estimasi sampah',
      'p04_metric_area_label': 'Total luas terdampak',
      'p04_metric_verified_label': 'Laporan terverifikasi',
      'p04_metric_waste_value': '{value} kg',
      'p04_metric_area_value': '{value} m²',
      'p04_metric_count_value': '{value}',
      'p04_chart_title': 'Tren kondisi lokasi',
      'p04_chart_subtitle': 'Rata-rata tingkat keparahan laporan terverifikasi',
      'p04_chart_hint': 'Makin rendah makin baik',
      'p04_chart_empty': 'Belum cukup data untuk menampilkan tren.',
      'p04_chart_tooltip': '{month} · skor {value}\n{n} laporan',
      'p04_severity_low': 'Ringan',
      'p04_severity_medium': 'Sedang',
      'p04_severity_high': 'Berat',
      'p04_status_submitted': 'Terkirim',
      'p04_status_verified': 'Diverifikasi',
      'p04_status_followed_up': 'Ditindaklanjuti',
      'p04_status_completed': 'Selesai',
      'p04_category_marine_debris': 'Sampah laut',
      'p04_category_damaged_reef': 'Terumbu rusak',
      'p04_category_deforested_mangrove': 'Mangrove gundul',
      'p04_category_destructive_fishing': 'Tangkapan merusak',
      'p04_category_affected_wildlife': 'Satwa terdampak',
      'p04_reports_title': 'Laporan warga',
      'p04_reports_empty': 'Belum ada laporan terverifikasi pada periode ini.',
      'p04_reports_load_more': 'Muat lebih banyak',
      'p04_reports_error': 'Gagal memuat laporan.',
      'p04_reports_count': '{n} laporan',
      'p04_reports_count_one': '{n} laporan',
      'p04_detail_title': 'Detail laporan',
      'p04_detail_close': 'Tutup',
      'p04_detail_reporter': 'Pelapor',
      'p04_detail_location': 'Lokasi',
      'p04_detail_time': 'Waktu',
      'p04_detail_category': 'Kategori',
      'p04_detail_severity': 'Tingkat',
      'p04_detail_status': 'Status',
      'p04_detail_metrics': 'Metrik',
      'p04_detail_waste': 'Sampah',
      'p04_detail_area': 'Luas terdampak',
      'p04_detail_description': 'Deskripsi',
      'p04_detail_verifier_note': 'Catatan verifikator',
      'p04_detail_no_note': 'Belum ada catatan verifikator.',
      'p04_detail_no_metrics': 'Tidak ada metrik kuantitatif.',
      'p04_detail_not_found': 'Laporan tidak ditemukan.',
      'p04_photo_error': 'Foto tidak dapat dimuat.',
      'p04_photo_counter': '{current}/{total}',
      'p04_photo_open': 'Perbesar foto',
      'p04_photo_label': 'Foto laporan',
      'p04_photo_close': 'Tutup foto',
      'p04_zoom_hint': 'Cubit atau ketuk dua kali untuk memperbesar',
      'p04_reviews_summary_title': 'Ringkasan ulasan',
      'p04_reviews_average': 'Rata-rata',
      'p04_reviews_count': '{n} ulasan',
      'p04_reviews_count_one': '{n} ulasan',
      'p04_reviews_sort_label': 'Urutkan',
      'p04_reviews_sort_newest': 'Terbaru',
      'p04_reviews_sort_highest': 'Rating tertinggi',
      'p04_reviews_sort_lowest': 'Rating terendah',
      'p04_reviews_load_more': 'Muat lebih banyak',
      'p04_reviews_read_more': 'Selengkapnya',
      'p04_reviews_read_less': 'Sembunyikan',
      'p04_reviews_empty': 'Belum ada ulasan',
      'p04_reviews_error': 'Gagal memuat ulasan.',

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
      'org.contact.email': 'Email',
      'org.contact.phone': 'Telepon',
      'org.projects.title': 'Proyek organisasi',
      'org.projects.empty': 'Belum ada proyek dari organisasi ini.',
      'org.type.organization': 'Organisasi',
      'org.type.community': 'Komunitas',
      'org.pendingVerification': 'Menunggu verifikasi',
      'org.stats.locations': 'Lokasi dipantau',
      'org.stats.reports': 'Laporan terverifikasi',
      'org.stats.waste': 'Sampah terkumpul',
      'org.stats.wasteValue': '{value} kg',
      'org.stats.members': 'Anggota',
      'org.locations.title': 'Lokasi yang dikelola',
      'org.locations.empty': 'Belum ada lokasi yang dikelola.',
      'org.locations.unavailable': 'Lokasi belum tersedia',
      'org.location.condition': 'Kondisi terkini',
      'org.location.noReports': 'Belum ada laporan terverifikasi',
      'org.location.latestReport': 'Laporan terverifikasi terbaru: {date}',
      'common.copy': 'Salin',
      'common.copied': 'Tersalin',
      'org.verified.explanation': 'Status terverifikasi disertai checklist pemeriksaan organisasi berikut.',

      // --- Verification badge sheet ---
      'verify.sheet.title': 'Tentang badge Terverifikasi',
      'verify.sheet.body':
          'Badge Terverifikasi berarti organisasi telah lolos pemeriksaan '
          'dokumentasi dan lapangan BlueTrack, sehingga setiap donasi dapat '
          'dilacak sampai ke laporan kegiatan proyek.',

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

      // --- Donation (P06, confirmation & result) ---
      'p06_confirm_title': 'Konfirmasi Donasi',
      'p06_confirm_big_text': '{amount} → 100% ke {project}',
      'p06_confirm_min_hint': 'Minimal donasi {amount}',
      'p06_confirm_summary_title': 'Ringkasan donasi',
      'p06_confirm_amount': 'Nominal',
      'p06_confirm_frequency': 'Frekuensi',
      'p06_confirm_frequency_once': 'Sekali',
      'p06_confirm_frequency_monthly': 'Bulanan',
      'p06_confirm_purpose': 'Tujuan',
      'p06_confirm_purpose_project': 'Proyek · {name}',
      'p06_confirm_purpose_org': 'Organisasi · {name}',
      'p06_confirm_method': 'Metode pembayaran',
      'p06_confirm_method_va': 'Transfer VA',
      'p06_confirm_method_ewallet': 'E-wallet',
      'p06_confirm_method_card': 'Kartu',
      'p06_confirm_method_empty': 'Belum dipilih',
      'p06_confirm_method_required': 'Pilih metode pembayaran',
      'p06_confirm_show_name': 'Tampilkan nama saya di laporan tahunan',
      'p06_confirm_pay_button': 'Bayar Sekarang',
      'p06_confirm_pay_error': 'Pembayaran belum bisa diproses. Coba lagi.',
      'p06_confirm_login_title': 'Masuk untuk melanjutkan',
      'p06_confirm_login_body':
          'Isian donasimu tersimpan. Masuk untuk menyelesaikan pembayaran.',
      'p06_confirm_empty_title': 'Isian donasi tidak ditemukan',
      'p06_confirm_empty_body':
          'Kembali ke langkah nominal untuk memulai donasi.',
      'p06_confirm_back_to_amount': 'Kembali ke nominal',
      'p06_confirm_project_error':
          'Gagal memuat proyek. Periksa koneksi lalu coba lagi.',
      'p06_confirm_processing': 'Memproses pembayaran...',
      'p06_result_title': 'Hasil Pembayaran',
      'p06_result_loading': 'Memuat status donasi...',
      'p06_result_not_found':
          'Donasi tidak ditemukan. Periksa tautan atau coba lagi.',
      'p06_result_load_error':
          'Gagal memuat status donasi. Periksa koneksi lalu coba lagi.',
      'p06_result_success_title': 'Donasi Berhasil',
      'p06_result_success_body':
          'Terima kasih. Donasimu tercatat dan 100% disalurkan ke proyek.',
      'p06_result_failed_title': 'Pembayaran Gagal',
      'p06_result_failed_body':
          'Isian donasimu aman. Coba lagi tanpa mengisi ulang.',
      'p06_result_pending_title': 'Menunggu Pembayaran',
      'p06_result_pending_body':
          'Selesaikan pembayaran sesuai instruksi. Status akan diperbarui '
          'setelah terkonfirmasi.',
      'p06_result_still_pending': 'Status masih menunggu',
      'p06_result_summary_title': 'Ringkasan donasi',
      'p06_result_amount': 'Nominal',
      'p06_result_project': 'Proyek',
      'p06_result_receipt': 'Nomor donasi',
      'p06_result_view_trace': 'Lihat Jejak dan E-Receipt',
      'p06_result_try_again': 'Coba Lagi',
      'p06_result_check_status': 'Cek Status',
      'p06_result_back_explore': 'Kembali ke Jelajahi',
      'p06_result_operational_title': 'Dukung Operasional Platform',
      'p06_result_operational_body':
          'Donasi operasional membantu biaya layanan tanpa mengurangi dana '
          'proyek.',
      'p06_result_operational_cta': 'Dukung',
      'p06_operational_card_dismiss': 'Tutup',
      'p06_result_success_semantics': 'Pembayaran berhasil',
      'p06_result_failed_semantics': 'Pembayaran gagal',
      'p06_result_pending_semantics': 'Menunggu pembayaran',
      'p06_failure_title': 'Kenapa pembayaran gagal?',
      'p06_failure_solution_label': 'Solusi',
      'p06_failure_mock_ending_one':
          'Nominal donasi berakhiran 1. Karena aplikasi masih memakai data '
          'mock, nominal seperti ini sengaja dibuat gagal untuk pengujian.',
      'p06_failure_mock_ending_one_solution':
          'Gunakan nominal lain yang tidak berakhiran 1, misalnya {amount}, '
          'lalu coba lagi.',
      'p06_failure_mock_generic':
          'Pembayaran gagal diproses. Aplikasi masih memakai data mock.',
      'p06_failure_mock_generic_solution':
          'Periksa metode pembayaran, lalu coba lagi.',

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
      'profile.title': 'Profil',
      'profile.signOut': 'Keluar',
      'notifications.title': 'Notifikasi',
      'notifications.donationNews':
          'Kabar tentang donasimu akan muncul di sini.',

      // --- Report wizard (Lapor Temuan) ---
      'report_title': 'Lapor Temuan',
      'report_step_photos': 'Foto',
      'report_step_location': 'Lokasi',
      'report_step_type': 'Jenis',
      'report_step_review': 'Tinjau',
      'report_photos_title': 'Foto temuan',
      'report_photos_body': 'Tambahkan 1–3 foto temuanmu.',
      'report_photo_counter': '{n}/{max} foto',
      'report_add_photo': 'Tambah Foto',
      'report_remove_photo': 'Hapus foto',
      'report_photo_load_error': 'Foto tidak dapat dimuat.',
      'report_source_title': 'Pilih sumber foto',
      'report_source_camera': 'Kamera',
      'report_source_gallery': 'Galeri',
      'report_max_photos': 'Maksimal {max} foto.',
      'report_photos_truncated':
          'Hanya {n} foto ditambahkan karena batas maksimal {max}.',
      'report_draft_banner': 'Draf tersimpan otomatis.',
      'report_resume_title': 'Lanjutkan draf?',
      'report_resume_body':
          'Kami menemukan draf Lapor Temuan yang belum dikirim.',
      'report_resume_continue': 'Lanjutkan draf',
      'report_resume_new': 'Mulai baru',
      'report_exit_title': 'Simpan draf dan keluar?',
      'report_exit_body': 'Draf akan tersimpan dan bisa dilanjutkan nanti.',
      'report_exit_confirm': 'Keluar',
      'report_back': 'Kembali',
      'report_coming_soon': 'Segera hadir.',
      'report_permission_title': 'Izin diperlukan',
      'report_permission_camera':
          'Akses kamera ditolak. Izinkan akses kamera di Pengaturan perangkat, '
          'lalu coba lagi.',
      'report_permission_gallery':
          'Akses galeri ditolak. Izinkan akses foto di Pengaturan perangkat, '
          'lalu coba lagi.',
      'report_permission_settings_hint':
          'Buka Pengaturan > Aplikasi > BlueTrack > Izin.',
      'report_photo_error_title': 'Gagal mengambil foto',
      'report_photo_unavailable':
          'Sumber foto tidak tersedia di perangkat ini.',
      'report_photo_failed': 'Foto tidak dapat diambil. Coba lagi.',
      'report_permission_dismiss': 'Mengerti',
      'report_location_title': 'Tandai lokasi temuan',
      'report_location_body':
          'Gunakan lokasi saat ini atau ketuk peta untuk menempatkan pin di '
          'titik temuan.',
      'report_location_hint': 'Geser pin ke lokasi temuan',
      'report_location_gps': 'Gunakan lokasi saya',
      'report_location_gps_loading': 'Mengambil lokasi...',
      'report_location_card_title': 'Koordinat temuan',
      'report_location_latitude': 'Lintang',
      'report_location_longitude': 'Bujur',
      'report_location_empty_hint':
          'Ketuk peta atau gunakan lokasi saya untuk mengisi koordinat.',
      'report_location_error_title': 'Lokasi tidak tersedia',
      'report_location_permission_denied':
          'Izin lokasi ditolak. Kamu tetap bisa menandai lokasi manual dengan '
          'mengetuk peta.',
      'report_location_permission_denied_forever':
          'Izin lokasi diblokir. Buka pengaturan untuk mengizinkannya, atau '
          'tandai lokasi manual di peta.',
      'report_location_service_disabled': 'Layanan lokasi mati. Aktifkan GPS, atau tandai lokasi manual di peta.',
      'report_location_timeout':
          'GPS tidak merespons. Geser pin secara manual di peta.',
      'report_location_unavailable':
          'Lokasi tidak dapat diambil. Tandai lokasi manual di peta.',
      'report_location_manual': 'Tandai manual',
      'report_location_open_settings': 'Buka pengaturan',
      'report_location_open_location_settings': 'Buka pengaturan lokasi',
      'report_location_settings_failed':
          'Pengaturan tidak dapat dibuka. Tandai lokasi manual di peta.',
      'report_type_title': 'Jenis temuan',
      'report_type_category_marine_debris': 'Sampah',
      'report_type_category_marine_debris_desc':
          'Sampah plastik atau limbah di sekitar lokasi.',
      'report_type_category_damaged_reef': 'Terumbu rusak',
      'report_type_category_damaged_reef_desc':
          'Karang patah, memutih, atau rusak.',
      'report_type_category_deforested_mangrove': 'Mangrove',
      'report_type_category_deforested_mangrove_desc':
          'Mangrove gundul atau area yang dibuka.',
      'report_type_category_destructive_fishing': 'Tangkapan merusak',
      'report_type_category_destructive_fishing_desc':
          'Alat atau cara tangkap yang merusak.',
      'report_type_category_affected_wildlife': 'Satwa terdampak',
      'report_type_category_affected_wildlife_desc':
          'Satwa laut terluka atau terjerat.',
      'report_type_severity_title': 'Tingkat',
      'report_type_severity_low': 'Ringan',
      'report_type_severity_low_desc':
          'Kerusakan kecil dan masih bisa pulih sendiri.',
      'report_type_severity_medium': 'Sedang',
      'report_type_severity_medium_desc':
          'Kerusakan cukup luas dan perlu tindakan.',
      'report_type_severity_high': 'Berat',
      'report_type_severity_high_desc':
          'Kerusakan parah dan mendesak ditangani.',
      'report_type_category_error': 'Pilih jenis temuan terlebih dahulu.',
      'report_type_severity_error': 'Pilih tingkat temuan terlebih dahulu.',
      'report_review_title': 'Tinjau laporan',
      'report_review_subtitle': 'Periksa kembali isianmu sebelum mengirim.',
      'report_review_photos': 'Foto',
      'report_review_location': 'Lokasi',
      'report_review_type': 'Jenis temuan',
      'report_review_severity': 'Tingkat kerusakan',
      'report_review_time': 'Waktu',
      'report_review_edit': 'Ubah',
      'report_review_empty_value': 'Belum diisi',
      'report_review_photo_label': 'Perbesar foto {n}',
      'report_review_verification_note':
          'Laporan akan diverifikasi sebelum tayang ke publik.',
      'report_review_login_title': 'Masuk untuk mengirim laporan',
      'report_review_login_body':
          'Laporanmu tetap tersimpan. Masuk dulu, lalu kembali ke langkah ini.',
      'report_submit': 'Kirim Laporan',
      'report_submit_retry': 'Coba lagi',
      'report_submit_error_title': 'Gagal mengirim laporan',
      'report_submit_error_body':
          'Laporanmu masih tersimpan. Periksa koneksi lalu coba lagi.',
      'report_submit_offline_title': 'Butuh koneksi internet',
      'report_submit_offline_body':
          'Sambungkan perangkat ke internet untuk mengirim laporan.',
      'report_submit_missing_photos': 'Lengkapi foto temuan terlebih dahulu.',
      'report_submit_missing_location': 'Tandai lokasi temuan terlebih dahulu.',
      'report_submit_missing_type':
          'Pilih jenis dan tingkat temuan terlebih dahulu.',
      'report_success_title': 'Laporan terkirim',
      'report_success_body':
          'Terima kasih. Laporanmu akan diverifikasi sebelum tayang ke publik.',
      'report_success_coordinates': 'Koordinat',
      'report_success_number': 'Nomor laporan',
      'report_success_status': 'Status',
      'report_success_view_reports': 'Lihat Laporan Saya',
      'report_success_new_report': 'Buat Laporan Lain',
      'report_success_not_found': 'Laporan tidak ditemukan di sesi ini.',
      'report_mine_title': 'Laporan Saya',
      'report_mine_empty':
          'Belum ada laporan. Laporan yang kamu kirim akan muncul di sini.',
      'report_mine_new': 'Buat Laporan',
      'report_photo_viewer_counter': '{current}/{total}',
      'report_photo_viewer_close': 'Tutup',

      // --- Notifications (P13) ---
      // TODO(P13, minggu 12-13): the list, mark-read and delete flows are fed
      // by mock data only; copy may change once real triggers exist.
      'p13.title': 'Notifikasi',
      'p13.markAllRead': 'Tandai semua dibaca',
      'p13.group.today': 'Hari ini',
      'p13.group.thisWeek': 'Minggu ini',
      'p13.group.older': 'Lebih lama',
      'p13.empty': 'Belum ada notifikasi.',
      'p13.errorBody': 'Notifikasi gagal dimuat.',
      'p13.retry': 'Coba lagi',
      'p13.type.reportStatus': 'Status laporan',
      'p13.type.actionReminder': 'Pengingat aksi',
      'p13.type.locationUpdate': 'Update lokasi',
      'p13.semanticUnread': 'Belum dibaca',
      'p13.delete': 'Hapus',
      'p13.targetUnavailable': 'Halaman tujuan notifikasi ini belum tersedia.',
      'p13.loginPrompt.title': 'Lacak notifikasi personal',
      'p13.loginPrompt.body': 'Masuk untuk melihat laporan dan aksi yang terkait akunmu. Notifikasi tetap tampil tanpa masuk.',
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
      'nav.aksi': 'Action',
      'nav.aksi.description':
          'Report, monitor, and support community action for the ocean.',
      'nav.transparency': 'Transparency',
      'nav.transparency.description': 'See where donations are disbursed, open to everyone without signing in.',
      'nav.grants': 'Grants',
      'nav.impact': 'My Impact',
      'nav.impact.description':
          'See the impact of the donations you have made.',
      'nav.profile': 'Profile',
      'nav.profile.description':
          'Manage your account and settings, and access proposals, '
          'notifications, and learning materials.',
      'shell.offline': 'Offline mode - showing saved data',
      'shell.notifications': 'Notifications',

      // --- Detail placeholders (part 3) ---
      'detail.action': 'Action Detail',
      'detail.settings': 'Settings',
      'detail.learn': 'Learn',
      'detail.report': 'Report a Finding',
      'detail.myReports': 'My Reports',
      'detail.myActions': 'My Actions',
      'detail.communityApply': 'Propose Community Action',
      'detail.donationTrace': 'Donation Trace',
      'placeholder.paramValue': '{name}: {value}',

      // --- Login prompt ---
      'login.prompt.title': 'Sign in required',
      'login.prompt.body': 'Sign in to continue. You will return to this page.',
      'login.prompt.button': 'Sign in',

      // --- Categories / interests ---
      'cat.semua': 'All',
      'cat.penyu': 'Turtle',
      'cat.karang': 'Coral',
      'cat.mangrove': 'Mangrove',
      'cat.mamalia_laut': 'Marine mammals',
      'cat.lamun': 'Seagrass',
      'cat.tersimpan': 'Saved',
      // Revised interest set (P01 part 4). The old categories above stay:
      // `assets/mock/projects.json` and filters.json still speak them.
      'cat.sampah_laut': 'Marine Waste',
      'cat.terumbu_karang': 'Coral Reefs',
      'cat.perikanan': 'Sustainable Fisheries',
      'cat.satwa_laut': 'Marine Wildlife',

      // --- Onboarding (P01) ---
      // Slide facts are NOT localized here: their single source is
      // `assets/mock/ocean_facts.json` (draft copy, see file TODO).
      'p01.skip': 'Skip',
      'p01.next': 'Next',
      'p01.chooseInterests': 'Choose Interests',
      'p01.start': 'Start',
      'p01.interests.title': 'Pick Your Interests',
      'p01.interests.manage': 'Interest Preferences',
      'p01.interests.later':
          'You can change your interests anytime from Profile.',
      'p01.interests.save': 'Save interests',
      'p01.interests.saveError': 'Could not save your interests. Try again.',
      'p01.interests.subtitle': "We'll sort projects to match your interests.",
      'p01.minOne': 'Pick at least one',

      // --- Auth (P02) ---
      // The title lives in the body heading, not the app bar, so there is one
      // clear anchor per step instead of two competing ones.
      'auth.email.title': 'Welcome back',
      'auth.email.subtitle':
          'Sign in to see the projects and donations you support.',
      'auth.email.label': 'Email',
      'auth.email.hint': 'name@email.com',
      'auth.email.invalid': 'Invalid email format',
      'auth.phone.title': 'Your phone number',
      'auth.phone.subtitle': "We'll send a verification code to this number.",
      'auth.phone.label': 'Phone number',
      'auth.phone.hint': '8123456789',
      'auth.phone.invalid': 'Invalid phone number',
      'auth.sendCode': 'Send Code',
      'auth.otp.title': 'Enter verification code',
      'auth.otp.subtitle': 'Code sent to {phone}',
      'auth.otp.mismatch': "Code doesn't match",
      'auth.otp.attemptsLeft': 'Attempts left: {n}',
      'auth.otp.locked': 'Too many attempts. Resend the code to continue.',
      'auth.otp.resendIn': 'Resend in {s}s',
      'auth.otp.resend': 'Resend code',
      'auth.otp.sent': 'Verification code sent (mock: 123456)',
      'auth.verify': 'Verify',
      // Split around the two inline document links so each document name stays a
      // separately tappable span instead of being parsed back out of a string.
      'auth.privacy.lead': 'By continuing, you agree to the',
      'auth.privacyPolicy': 'Privacy Policy',
      'auth.privacy.and': 'and',
      'auth.terms': 'Terms & Conditions',

      // --- Explore (P03) ---
      'explore.title': 'Explore',
      'explore.searchHint': 'Search projects, organizations, or places',
      'explore.forYou': 'For you',
      'explore.projects': 'Projects',
      'explore.viewList': 'List',
      'explore.viewMap': 'Map',
      'explore.empty.title': 'No projects',
      'explore.empty.body': 'Try a different keyword or category.',
      'explore.emptySaved.title':
          'No saved projects yet. Save one with the bookmark icon on '
          'Project Detail.',
      'explore.emptySaved.body': 'Save projects to access them while offline.',
      'explore.emptySavedFiltered.title': 'No saved projects match',
      'explore.savedFilter.on': 'Show saved projects',
      'explore.savedFilter.off': 'Show all projects',
      'explore.resetFilter': 'Reset filters',
      'explore.viewAll': 'View all projects',
      'explore.mapUnavailable': 'Map mode is not available in this subproject.',

      // --- Explore map (P03) ---
      'p03_filter_action': 'Filter',
      'p03_filter_category': 'Category',
      'p03_filter_distance': 'Distance',
      'p03_distance_reference': 'Distance from {place} (mock)',
      'p03_distance_semua': 'All',
      'p03_distance_dekat': '<250 km',
      'p03_distance_sedang': '250–1000 km',
      'p03_distance_jauh': '>1000 km',
      'p03_filter_condition': 'Condition',
      'p03_condition_baik': 'Good',
      'p03_condition_pemantauan': 'Needs monitoring',
      'p03_condition_kritis': 'Critical',
      'p03_filter_reset': 'Reset',
      'p03_filter_apply': 'Apply',
      'p03_filter_active': '{n} filters active',
      'p03_map_layer_conservation': 'Conservation areas',
      'p03_map_count': '{n} projects on the map',
      'p03_map_empty': 'No projects on the map for these filters.',
      'p03_map_open_project': 'View project',
      'p03_map_zoom_in': 'Zoom in',
      'p03_map_zoom_out': 'Zoom out',
      'p03_map_distance': '{n} km from {place} (mock)',
      'p03_save': 'Save project',
      'p03_saved': 'Remove from saved',
      'p03_map_condition': 'Condition',
      'p03_offline_empty_title': 'No saved projects yet',
      'p03_offline_reload': 'Reload saved projects',
      'p03_simulate_offline': 'Simulate offline',
      'p03_scope_explore': 'Explore',
      'p03_scope_saved': 'Saved',
      'p03_category_label': 'Category',
      'p03_clear_all': 'Clear all',
      'p03_filter_title': 'Filter',
      'p03_filter_close': 'Close filter',
      'p03_filter_all': 'All',
      'p03_filter_category_helper': 'Choose one category',
      'p03_filter_condition_helper': 'Project monitoring status',
      'p03_filter_result_count': 'Show {n} projects',
      'p03_percent_funded': '{n}% funded',
      'p03_map_legend': 'Condition legend',
      'p03_search_hint': 'Search projects or organizations',

      // --- Project detail (P04) ---
      'project.tab.about': 'About',
      'p04_tab_funding': 'Funding',
      'project.tab.reports': 'Reports',
      'project.tab.reviews': 'Reviews',
      'project.raised': 'Raised',
      'project.target': 'Target',
      'project.remaining': 'Remaining',
      'project.donate': 'Donate',
      'project.location': 'Project location',
      'project.funding.item': 'Funding item',
      'project.funding.amount': 'Amount',
      'project.funding.percent': 'Share',
      'project.funding.total': 'Total',
      'project.reports.empty': 'No reports yet.',
      'project.reviews.empty': 'No reviews yet.',

      // --- P04 reports ---
      'p04_period_label': 'Period',
      'p04_period_1m': '1 month',
      'p04_period_3m': '3 months',
      'p04_period_6m': '6 months',
      'p04_period_all': 'All',
      'p04_metrics_title': 'Condition summary',
      'p04_metric_waste_label': 'Estimated waste total',
      'p04_metric_area_label': 'Affected area total',
      'p04_metric_verified_label': 'Verified reports',
      'p04_metric_waste_value': '{value} kg',
      'p04_metric_area_value': '{value} m²',
      'p04_metric_count_value': '{value}',
      'p04_chart_title': 'Location condition trend',
      'p04_chart_subtitle': 'Average severity of verified reports',
      'p04_chart_hint': 'Lower is better',
      'p04_chart_empty': 'Not enough data to show a trend.',
      'p04_chart_tooltip': '{month} · score {value}\n{n} reports',
      'p04_severity_low': 'Low',
      'p04_severity_medium': 'Moderate',
      'p04_severity_high': 'Severe',
      'p04_status_submitted': 'Submitted',
      'p04_status_verified': 'Verified',
      'p04_status_followed_up': 'Followed up',
      'p04_status_completed': 'Completed',
      'p04_category_marine_debris': 'Marine debris',
      'p04_category_damaged_reef': 'Damaged reef',
      'p04_category_deforested_mangrove': 'Bare mangrove',
      'p04_category_destructive_fishing': 'Destructive fishing',
      'p04_category_affected_wildlife': 'Affected wildlife',
      'p04_reports_title': 'Citizen reports',
      'p04_reports_empty': 'No verified reports in this period.',
      'p04_reports_load_more': 'Load more',
      'p04_reports_error': 'Failed to load reports.',
      'p04_reports_count': '{n} reports',
      'p04_reports_count_one': '{n} report',
      'p04_detail_title': 'Report details',
      'p04_detail_close': 'Close',
      'p04_detail_reporter': 'Reporter',
      'p04_detail_location': 'Location',
      'p04_detail_time': 'Time',
      'p04_detail_category': 'Category',
      'p04_detail_severity': 'Severity',
      'p04_detail_status': 'Status',
      'p04_detail_metrics': 'Metrics',
      'p04_detail_waste': 'Waste',
      'p04_detail_area': 'Affected area',
      'p04_detail_description': 'Description',
      'p04_detail_verifier_note': 'Verifier note',
      'p04_detail_no_note': 'No verifier note yet.',
      'p04_detail_no_metrics': 'No quantitative metrics.',
      'p04_detail_not_found': 'Report not found.',
      'p04_photo_error': 'Photo could not be loaded.',
      'p04_photo_counter': '{current}/{total}',
      'p04_photo_open': 'Zoom photo',
      'p04_photo_label': 'Report photo',
      'p04_photo_close': 'Close photo',
      'p04_zoom_hint': 'Pinch or double-tap to zoom',
      'p04_reviews_summary_title': 'Review summary',
      'p04_reviews_average': 'Average',
      'p04_reviews_count': '{n} reviews',
      'p04_reviews_count_one': '{n} review',
      'p04_reviews_sort_label': 'Sort by',
      'p04_reviews_sort_newest': 'Newest',
      'p04_reviews_sort_highest': 'Highest rating',
      'p04_reviews_sort_lowest': 'Lowest rating',
      'p04_reviews_load_more': 'Load more',
      'p04_reviews_read_more': 'Read more',
      'p04_reviews_read_less': 'Show less',
      'p04_reviews_empty': 'No reviews yet',
      'p04_reviews_error': 'Failed to load reviews.',

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
      'org.contact.email': 'Email',
      'org.contact.phone': 'Phone',
      'org.projects.title': 'Organization projects',
      'org.projects.empty': 'No projects from this organization yet.',
      'org.type.organization': 'Organization',
      'org.type.community': 'Community',
      'org.pendingVerification': 'Awaiting verification',
      'org.stats.locations': 'Locations monitored',
      'org.stats.reports': 'Verified reports',
      'org.stats.waste': 'Waste collected',
      'org.stats.wasteValue': '{value} kg',
      'org.stats.members': 'Members',
      'org.locations.title': 'Managed locations',
      'org.locations.empty': 'No managed locations yet.',
      'org.locations.unavailable': 'Location unavailable',
      'org.location.condition': 'Current condition',
      'org.location.noReports': 'No verified reports yet',
      'org.location.latestReport': 'Latest verified report: {date}',
      'common.copy': 'Copy',
      'common.copied': 'Copied',
      'org.verified.explanation': "Verified status with the organization's verification checklist below.",

      // --- Verification badge sheet ---
      'verify.sheet.title': 'About the Verified badge',
      'verify.sheet.body':
          'A Verified badge means the organization passed BlueTrack\'s '
          'documentation and field checks, so every donation can be traced to '
          'the project\'s activity reports.',

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

      // --- Donation (P06, confirmation & result) ---
      'p06_confirm_title': 'Confirm Donation',
      'p06_confirm_big_text': '{amount} → 100% to {project}',
      'p06_confirm_min_hint': 'Minimum donation {amount}',
      'p06_confirm_summary_title': 'Donation summary',
      'p06_confirm_amount': 'Amount',
      'p06_confirm_frequency': 'Frequency',
      'p06_confirm_frequency_once': 'One-time',
      'p06_confirm_frequency_monthly': 'Monthly',
      'p06_confirm_purpose': 'Purpose',
      'p06_confirm_purpose_project': 'Project · {name}',
      'p06_confirm_purpose_org': 'Organization · {name}',
      'p06_confirm_method': 'Payment method',
      'p06_confirm_method_va': 'VA transfer',
      'p06_confirm_method_ewallet': 'E-wallet',
      'p06_confirm_method_card': 'Card',
      'p06_confirm_method_empty': 'Not selected',
      'p06_confirm_method_required': 'Choose a payment method',
      'p06_confirm_show_name': 'Show my name in the annual report',
      'p06_confirm_pay_button': 'Pay Now',
      'p06_confirm_pay_error': "Payment couldn't be processed. Try again.",
      'p06_confirm_login_title': 'Sign in to continue',
      'p06_confirm_login_body':
          'Your donation details are saved. Sign in to complete the payment.',
      'p06_confirm_empty_title': 'Donation details not found',
      'p06_confirm_empty_body':
          'Go back to the amount step to start a donation.',
      'p06_confirm_back_to_amount': 'Back to amount',
      'p06_confirm_project_error':
          'Could not load the project. Check your connection and try again.',
      'p06_confirm_processing': 'Processing payment...',
      'p06_result_title': 'Payment Result',
      'p06_result_loading': 'Loading donation status...',
      'p06_result_not_found':
          'Donation not found. Check the link or try again.',
      'p06_result_load_error':
          'Could not load the donation status. Check your connection and try '
          'again.',
      'p06_result_success_title': 'Donation Successful',
      'p06_result_success_body':
          'Thank you. Your donation is recorded and 100% goes to the project.',
      'p06_result_failed_title': 'Payment Failed',
      'p06_result_failed_body':
          'Your donation details are safe. Try again without re-entering them.',
      'p06_result_pending_title': 'Awaiting Payment',
      'p06_result_pending_body':
          'Complete the payment as instructed. The status will update once '
          'confirmed.',
      'p06_result_still_pending': 'Status is still pending',
      'p06_result_summary_title': 'Donation summary',
      'p06_result_amount': 'Amount',
      'p06_result_project': 'Project',
      'p06_result_receipt': 'Donation number',
      'p06_result_view_trace': 'View Trace and E-Receipt',
      'p06_result_try_again': 'Try Again',
      'p06_result_check_status': 'Check Status',
      'p06_result_back_explore': 'Back to Explore',
      'p06_result_operational_title': 'Support Platform Operations',
      'p06_result_operational_body':
          'Operational donations cover platform costs without reducing '
          'project funds.',
      'p06_result_operational_cta': 'Support',
      'p06_operational_card_dismiss': 'Dismiss',
      'p06_result_success_semantics': 'Payment successful',
      'p06_result_failed_semantics': 'Payment failed',
      'p06_result_pending_semantics': 'Awaiting payment',
      'p06_failure_title': 'Why did the payment fail?',
      'p06_failure_solution_label': 'Solution',
      'p06_failure_mock_ending_one':
          'The donation amount ends in 1. Because the app still uses mock '
          'data, amounts like this are intentionally failed for testing.',
      'p06_failure_mock_ending_one_solution':
          'Use another amount that does not end in 1, for example {amount}, '
          'then try again.',
      'p06_failure_mock_generic':
          'The payment could not be processed. The app still uses mock data.',
      'p06_failure_mock_generic_solution':
          'Check the payment method, then try again.',

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
      'profile.title': 'Profile',
      'profile.signOut': 'Sign out',
      'notifications.title': 'Notifications',
      'notifications.donationNews':
          'News about your donations will appear here.',

      // --- Report wizard (Lapor Temuan) ---
      'report_title': 'Report a Finding',
      'report_step_photos': 'Photo',
      'report_step_location': 'Location',
      'report_step_type': 'Type',
      'report_step_review': 'Review',
      'report_photos_title': 'Photos of the finding',
      'report_photos_body': 'Add 1–3 photos of your finding.',
      'report_photo_counter': '{n}/{max} photos',
      'report_add_photo': 'Add Photo',
      'report_remove_photo': 'Remove photo',
      'report_photo_load_error': 'The photo could not be loaded.',
      'report_source_title': 'Choose a photo source',
      'report_source_camera': 'Camera',
      'report_source_gallery': 'Gallery',
      'report_max_photos': 'Maximum {max} photos.',
      'report_photos_truncated':
          'Only {n} photo(s) added because the limit is {max}.',
      'report_draft_banner': 'Draft saved automatically.',
      'report_resume_title': 'Resume draft?',
      'report_resume_body':
          'We found a Report a Finding draft you have not sent.',
      'report_resume_continue': 'Resume draft',
      'report_resume_new': 'Start new',
      'report_exit_title': 'Save the draft and leave?',
      'report_exit_body': 'The draft will be saved and you can continue later.',
      'report_exit_confirm': 'Leave',
      'report_back': 'Back',
      'report_coming_soon': 'Coming soon.',
      'report_permission_title': 'Permission required',
      'report_permission_camera':
          'Camera access was denied. Allow camera access in your device '
          'Settings, then try again.',
      'report_permission_gallery':
          'Gallery access was denied. Allow photo access in your device '
          'Settings, then try again.',
      'report_permission_settings_hint':
          'Open Settings > Apps > BlueTrack > Permissions.',
      'report_photo_error_title': 'Could not take photo',
      'report_photo_unavailable':
          'The photo source is not available on this device.',
      'report_photo_failed': 'The photo could not be taken. Try again.',
      'report_permission_dismiss': 'Got it',
      'report_location_title': 'Mark the finding location',
      'report_location_body':
          'Use your current location or tap the map to place a pin on the '
          'finding.',
      'report_location_hint': 'Drag the pin to the finding location',
      'report_location_gps': 'Use my location',
      'report_location_gps_loading': 'Getting location...',
      'report_location_card_title': 'Finding coordinates',
      'report_location_latitude': 'Latitude',
      'report_location_longitude': 'Longitude',
      'report_location_empty_hint':
          'Tap the map or use my location to fill in the coordinates.',
      'report_location_error_title': 'Location unavailable',
      'report_location_permission_denied':
          'Location permission was denied. You can still mark the location '
          'manually by tapping the map.',
      'report_location_permission_denied_forever':
          'Location permission is blocked. Open settings to allow it, or mark '
          'the location manually on the map.',
      'report_location_service_disabled':
          'Location services are off. Turn on GPS, or mark the location '
          'manually on the map.',
      'report_location_timeout':
          'GPS is not responding. Drag the pin manually on the map.',
      'report_location_unavailable':
          'The location could not be retrieved. Mark it manually on the map.',
      'report_location_manual': 'Mark manually',
      'report_location_open_settings': 'Open settings',
      'report_location_open_location_settings': 'Open location settings',
      'report_location_settings_failed': 'Settings could not be opened. Mark the location manually on the map.',
      'report_type_title': 'Finding type',
      'report_type_category_marine_debris': 'Debris',
      'report_type_category_marine_debris_desc':
          'Plastic or other waste around the site.',
      'report_type_category_damaged_reef': 'Damaged reef',
      'report_type_category_damaged_reef_desc':
          'Broken, bleached, or damaged coral.',
      'report_type_category_deforested_mangrove': 'Mangrove',
      'report_type_category_deforested_mangrove_desc':
          'Cleared or bare mangrove area.',
      'report_type_category_destructive_fishing': 'Destructive fishing',
      'report_type_category_destructive_fishing_desc':
          'Damaging gear or fishing method.',
      'report_type_category_affected_wildlife': 'Affected wildlife',
      'report_type_category_affected_wildlife_desc':
          'Injured or entangled marine wildlife.',
      'report_type_severity_title': 'Severity',
      'report_type_severity_low': 'Minor',
      'report_type_severity_low_desc':
          'Small damage that can recover on its own.',
      'report_type_severity_medium': 'Moderate',
      'report_type_severity_medium_desc':
          'Moderate damage that needs intervention.',
      'report_type_severity_high': 'Severe',
      'report_type_severity_high_desc':
          'Severe damage that needs urgent action.',
      'report_type_category_error': 'Choose a finding type first.',
      'report_type_severity_error': 'Choose a severity level first.',
      'report_review_title': 'Review report',
      'report_review_subtitle': 'Check your answers before sending.',
      'report_review_photos': 'Photos',
      'report_review_location': 'Location',
      'report_review_type': 'Finding type',
      'report_review_severity': 'Damage severity',
      'report_review_time': 'Time',
      'report_review_edit': 'Edit',
      'report_review_empty_value': 'Not set',
      'report_review_photo_label': 'Enlarge photo {n}',
      'report_review_verification_note':
          'The report will be verified before it is published.',
      'report_review_login_title': 'Sign in to send the report',
      'report_review_login_body':
          'Your report is kept. Sign in first, then come back to this step.',
      'report_submit': 'Send Report',
      'report_submit_retry': 'Try again',
      'report_submit_error_title': 'Could not send the report',
      'report_submit_error_body':
          'Your report is still saved. Check your connection and try again.',
      'report_submit_offline_title': 'Internet connection required',
      'report_submit_offline_body':
          'Connect the device to the internet to send the report.',
      'report_submit_missing_photos': 'Add the finding photo first.',
      'report_submit_missing_location': 'Mark the finding location first.',
      'report_submit_missing_type':
          'Choose the finding type and severity first.',
      'report_success_title': 'Report sent',
      'report_success_body':
          'Thank you. Your report will be verified before it is published.',
      'report_success_coordinates': 'Coordinates',
      'report_success_number': 'Report number',
      'report_success_status': 'Status',
      'report_success_view_reports': 'View My Reports',
      'report_success_new_report': 'Create Another Report',
      'report_success_not_found':
          'This report is no longer available in this session.',
      'report_mine_title': 'My Reports',
      'report_mine_empty': 'No reports yet. Reports you send will appear here.',
      'report_mine_new': 'Create Report',
      'report_photo_viewer_counter': '{current}/{total}',
      'report_photo_viewer_close': 'Close',

      // --- Notifications (P13) ---
      // TODO(P13, minggu 12-13): the list, mark-read and delete flows are fed
      // by mock data only; copy may change once real triggers exist.
      'p13.title': 'Notifications',
      'p13.markAllRead': 'Mark all as read',
      'p13.group.today': 'Today',
      'p13.group.thisWeek': 'This week',
      'p13.group.older': 'Older',
      'p13.empty': 'No notifications yet.',
      'p13.errorBody': 'Notifications failed to load.',
      'p13.retry': 'Try again',
      'p13.type.reportStatus': 'Report status',
      'p13.type.actionReminder': 'Action reminder',
      'p13.type.locationUpdate': 'Location update',
      'p13.semanticUnread': 'Unread',
      'p13.delete': 'Delete',
      'p13.targetUnavailable':
          "This notification's target page is not available yet.",
      'p13.loginPrompt.title': 'Track personal notifications',
      'p13.loginPrompt.body': 'Sign in to see reports and actions linked to your account. Notifications stay visible without signing in.',
    },
  };
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['id', 'en'].contains(locale.languageCode);

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
