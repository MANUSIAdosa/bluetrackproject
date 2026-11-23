# Lapor Temuan: Deskripsi, Lokasi, dan Halaman Sukses

## Tujuan
Melengkapi informasi laporan lapangan dan memastikan laporan yang baru dikirim dapat ditemukan melalui halaman Laporan Saya yang sudah terdaftar.

## Keputusan yang disetujui
- Pertahankan wizard empat langkah: foto + deskripsi → lokasi → jenis/keparahan → tinjau.
- Deskripsi wajib di langkah 1, setelah area foto. Hanya nilai non-kosong setelah trim yang valid. Jangan menetapkan batas karakter yang belum ditentukan.
- Langkah lokasi mempertahankan peta, pin, dan koordinat GPS. Tambahkan patokan/area sekitar opsional sebagai teks manual. Tidak ada pencarian alamat otomatis, geocoding, tombol salin koordinat di alur pengirim, backend, atau dependency baru.
- Draf menyimpan dan memulihkan deskripsi serta patokan. Layanan mock meneruskan nilai pengguna ke model laporan, bukan memakai deskripsi generik.
- Tinjau menampilkan informasi yang telah diisi dan memberi akses untuk mengubahnya.
- Halaman sukses menampilkan konfirmasi, nomor laporan, status terkirim yang belum diverifikasi, dan ringkasan laporan. Tombol Laporan Saya tetap ada dan aktif menuju `/my-reports`.
- Halaman daftar resmi (`features/my_reports`) harus menggabungkan laporan sesi (`MyReportsStore`) dengan hasil repository tanpa duplikasi, agar laporan yang baru dikirim langsung terlihat. ID reporter mock menjadi satu sumber (`AppConfig.reportCurrentUserId`) yang sama dengan filter pemilik halaman daftar.
- Jika repository masih memuat atau gagal, laporan sesi tetap terlihat; status muat/error dan aksi coba lagi ditampilkan tanpa mengganti daftar sesi.
- Teks UI baru tersedia dalam bahasa Indonesia dan Inggris.

## Alternatif yang dipertimbangkan
1. Deskripsi bersama foto pada langkah 1 (dipilih): konteks narasi dibuat saat pengguna menambahkan bukti dan langkah kategori/keparahan tetap fokus.
2. Deskripsi pada langkah kategori/keparahan atau langkah terpisah: ditolak karena mencampur narasi dengan klasifikasi atau menambah langkah.

Untuk lokasi, patokan manual + koordinat dipilih daripada autocomplete karena cocok untuk laut dan tidak memerlukan layanan geocoding.

## Arah antarmuka dan batasan
Gunakan tema BlueTrack yang ada: ocean `#0284C7`, teal `#14B8A6`, coral `#FF6F61`, latar `#F6F9FC`, Plus Jakarta Sans, Material 3, padding dasar 16 dp, radius kartu 16 dp. Pertahankan 8 Golden Rules: konsistensi, universal usability, feedback, closure, pencegahan error, koreksi sebelum kirim, kendali pengguna atas pin, dan ringkasan untuk mengurangi beban ingatan.

## Di luar cakupan
Geocoding/pencarian alamat otomatis, halaman detail laporan baru, perubahan alur verifikasi, serta pengungkapan koordinat publik yang lebih luas.
