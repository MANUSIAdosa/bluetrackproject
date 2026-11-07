# Nama Area dan Pencarian Alamat (Nominatim Publik)

## Tujuan
Menjawab keluhan dosen bahwa lokasi laporan hanya berupa latitude/longitude: pengguna dapat melihat nama area dari pin dan mencari lokasi lewat teks alamat, sambil tetap memakai pin dan koordinat sebagai data lokasi utama.

## Keputusan yang diminta persetujuan
- Menambahkan dependensi langsung `http` (versi 1.6.0 sudah ada sebagai dependensi transitif).
- Memakai layanan publik `nominatim.openstreetmap.org` dari aplikasi klien, tanpa backend BlueTrack.
- Menerapkan **keduanya**: reverse geocoding (pin → nama area) dan forward geocoding (teks alamat → hasil → pin berpindah).

## Tujuan (goals)
- Langkah 2 menampilkan nama area untuk pin saat ini setelah pengguna menekan tombol.
- Pengguna dapat mengetik alamat, menekan cari, melihat maksimal 5 hasil, lalu memilih satu; pin dan koordinat berpindah ke hasil tersebut.
- Hasil pencarian dan nama area menampilkan atribusi "Data © OpenStreetMap contributors".
- Semua kegagalan (offline, timeout, hasil kosong, batas laju, galat server) tampil sebagai pesan inline; pin manual tetap dapat dipakai.

## Bukan tujuan (non-goals)
- Saran alamat otomatis saat mengetik.
- Menyimpan riwayat pencarian atau mengirim data ke server lain.
- Reverse geocoding otomatis setiap kali pin digeser.
- Mengubah model laporan, backend, alur empat langkah, atau halaman sukses.

## Batasan
- Kebijakan Nominatim publik: maksimum absolut 1 permintaan/detik, identitas aplikasi jelas, atribusi, dan hanya penggunaan yang dipicu pengguna. Karena itu pencarian hanya berjalan lewat tombol/Enter, bukan setiap ketikan.
- Klien membatasi jarak antarpermintaan minimal 1,1 detik dan menonaktifkan tombol selama permintaan berjalan.
- `User-Agent` diset untuk Android/desktop; peramban web melarang header itu, sehingga web mengandalkan `Referer` otomatis.
- Tidak ada permintaan jaringan di tes: `GeocodingService` diinjeksi dan tes memakai klien HTTP palsu.
- Koordinat dan kueri dikirim ke server publik OSM; ini dicatat di dokumentasi, bukan disembunyikan.
- Pin dan latitude/longitude tetap data lokasi utama; alamat hanya pelengkap.

## Pendekatan yang dipilih
1. Reverse saja — paling sedikit permintaan, tetapi tidak bisa mencari tempat yang belum terlihat di peta.
2. Forward saja — mirip Gojek, tetapi lokasi laut tetap butuh nama area dari pin.
3. **Keduanya (dipilih)** — dua permukaan UI kecil di satu langkah, dengan satu layanan dan satu set status.

## Rancangan
```text
Titik temuan
[ Peta dengan pin ]

Nama area                    [Cari nama area]
Dekat Pantai Sukamade, Banyuwangi
Data © OpenStreetMap contributors

Cari alamat
[ Contoh: Pantai Sukamade ]        [Cari]
· Pantai Sukamade, Banyuwangi
· Taman Nasional Meru Betiri
Data © OpenStreetMap contributors

Patokan atau area sekitar (opsional)
[ Contoh: dekat dermaga utara ]
```

Keputusan saya (dapat dikoreksi):
- Maksimal 5 hasil, satu permintaan per tekan tombol; tombol nonaktif saat memuat, offline, atau kueri kosong.
- Menekan "Cari nama area" memakai koordinat pin saat ini; hasil terakhir disimpan per koordinat dibulatkan 4 desimal agar tidak mengulang permintaan yang sama.
- Nama area hasil geocoding **mengisi kolom patokan hanya bila kolom itu masih kosong**, dan pengguna tetap dapat menyuntingnya. Teks yang sudah diketik pengguna tidak pernah ditimpa.
- Nama area dan hasil pencarian bersifat tampilan; model `Report` tidak berubah.
- Timeout 8 detik; galat 429 ditampilkan sebagai "terlalu banyak permintaan, coba lagi sebentar".
- Atribusi OSM muncul di bawah nama area dan daftar hasil.
- Semua teks baru tersedia dalam bahasa Indonesia dan Inggris.

## Yang diserahkan ke pelaksana
Nama kelas/berkas, bentuk JSON Nominatim, susunan widget, dan rincian tes mengikuti pola repo (`report_location_service.dart`, widget langkah lokasi, tes berlabel `ValueKey`).


## Revisi tata letak (disetujui setelah kritik UI)
Susunan inline sebelumnya dinilai terlalu bertumpuk: dua kartu informasi lokasi, dua atribusi, dan pencarian alamat di bawah koordinat. Revisi yang dipilih:

- Peta tetap di atas, diikuti satu baris dua aksi: "Gunakan lokasi saya" dan "Cari alamat".
- Satu kartu "Lokasi terpilih" berisi nama area, koordinat sebagai rincian, kolom patokan, dan satu atribusi di kaki kartu.
- Pencarian alamat pindah ke panel bawah: kolom, tombol cari, maksimal lima hasil, pesan kosong/galat, dan atribusi di dalam panel.
- Pemicu nama area menjadi tombol ikon di kartu, bukan tombol teks panjang.
