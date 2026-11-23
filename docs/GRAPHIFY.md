# Graphify — Knowledge Graph BlueTrack

Panduan operasional Graphify untuk proyek ini. Graphify mengubah kode menjadi
knowledge graph yang bisa di-query, sehingga agent dan developer dapat menelusuri
relasi antar-file/simbol tanpa membaca seluruh repository.

## Status instalasi

| Komponen | Status |
| --- | --- |
| CLI `graphify` | `graphifyy 0.9.115` (via `uv tool`, Python 3.12) |
| Graph kode | `graphify-out/graph.json` — 3.448 node, 4.994 edge, 170 komunitas (snapshot commit `2680a083`) |
| Laporan | `graphify-out/GRAPH_REPORT.md` |
| Visualisasi | `graphify-out/graph.html` (buka di browser) |
| Skill OpenCode | `.opencode/skills/graphify/SKILL.md` (lokal, di-gitignore) |
| Plugin OpenCode | `.opencode/plugins/graphify.js` (pengingat graph sebelum shell) |
| Aturan agent | Bagian `## graphify` di `AGENTS.md` |
| Git hook | `post-commit`, `post-checkout`, `post-merge`, `post-rewrite` |
| Merge driver | `graphify-out/graph.json merge=graphify` di `.gitattributes` |

Graph dibangun **code-only** dari AST tree-sitter: tidak memakai LLM, tidak
mengirim kode ke mana pun, dan tidak membutuhkan API key. Karena itu semua edge
bertipe `EXTRACTED` (0 `INFERRED`).

## Cakupan scan

`.graphifyignore` membatasi graph ke kode yang relevan:

- **Disertakan:** `lib/`, `test/`, `assets/`, `pubspec.yaml`, konfigurasi root.
- **Dikecualikan:** `graphify-out/`, `build/`, `.dart_tool/`, `coverage/`,
  `android/`, `web/`, `screenshoot/`, `.claude/`, `.opencode/`, `.vscode/`.

Folder platform dikecualikan karena `analysis_options.yaml` juga tidak
menganalisisnya. Mock JSON di `assets/` tetap disertakan agar relasi data mock
terlihat.

## Perintah harian

Jalankan dari root proyek. Jika `graphify` belum dikenali, buka terminal baru
setelah `uv tool update-shell`, atau pakai
`%USERPROFILE%\.local\bin\graphify.exe`.

```powershell
# Cari konteks untuk sebuah pertanyaan (subgraph, bukan seluruh graph)
graphify query "donation flow payment status" --budget 1500 --depth 3

# Jelaskan satu simbol dan semua koneksinya
graphify explain "ProjectRepository" --all

# Cari jalur antara dua simbol
graphify path "ExplorePage" "ProjectRepository" --undirected

# Cari semua yang terdampak jika sebuah simbol berubah
graphify affected "ReportRepository" --depth 2

# Simbol paling terhubung (arsitektur)
graphify god-nodes --top 15
```

### Contoh query yang sudah diverifikasi di proyek ini

```text
graphify explain "ProjectRepository"
  -> 8 koneksi: ExplorePage, ProjectDetailPage, OrgProfilePage,
     DonateConfirmationPage, MockProjectRepository, dan fake test.

graphify affected "ReportRepository" --depth 2
  -> my_reports_page.dart, p04_reports_tab.dart, project_detail_page.dart,
     org_profile_page.dart, p04_report_detail_sheet.dart, dan test terkait.

graphify path "ExplorePage" "ProjectRepository" --undirected
  -> 2 hop: ExplorePage <-defines- explore_page.dart -references-> ProjectRepository

graphify explain "DonationFlowStore"
  -> dipakai donate_confirmation_page.dart dan donate_status_page.dart.
```

**Catatan bahasa:** label simbol di graph adalah nama kode (Inggris). Query
natural-language berbahasa Indonesia sering tidak cocok dengan identifier
Inggris, misalnya "alur donasi" tidak menemukan `DonationFlowStore`. Gunakan
nama simbol (`graphify explain "DonationFlowStore"`) atau kata kunci Inggris
(`"donation flow"`). Ini keterbatasan pencocokan leksikal, bukan graph yang salah.

## Menjaga graph tetap segar

Git hook sudah terpasang dan berjalan di background setelah commit, checkout,
merge, dan rebase. Cek dengan:

```powershell
graphify hook status
```

Refresh manual setelah mengubah kode:

```powershell
graphify update .
```

Rebuild penuh setelah banyak file dihapus/dipindahkan (graph tidak akan mengecil
tanpa `--force`):

```powershell
graphify extract . --code-only --force
$env:GRAPHIFY_BACKEND="none"
graphify cluster-only .
```

`cluster-only` menghasilkan ulang `GRAPH_REPORT.md` dan `graph.html`. Nama
komunitas di laporan berasal dari hub file karena tidak ada backend LLM. Untuk
label semantik, jalankan `graphify label . --backend=gemini` (atau provider lain
yang API key-nya tersedia); ini opsional dan tidak diperlukan untuk query kode.

## Integrasi OpenCode

Saat sesi OpenCode dimulai, plugin menambahkan satu pengingat singkat sebelum
perintah shell pertama. Aturan di `AGENTS.md` meminta agent menjalankan
`graphify query` sebelum grep/read untuk pertanyaan tentang codebase, lalu
`graphify update .` setelah mengubah kode.

`.opencode/` dan `graphify-out/` di-gitignore, jadi instalasi ini bersifat lokal.
Di mesin lain:

```powershell
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
uv tool install --python 3.12 "graphifyy[leiden]"
graphify opencode install --project
graphify extract . --code-only
graphify hook install
```

Jika ingin graph dibagikan lewat Git, hapus baris `graphify-out/` dari
`.gitignore`, lalu commit `graphify-out/graph.json` dan
`graphify-out/GRAPH_REPORT.md` (jangan commit `cache/` atau `graph.html`).

## Troubleshooting

| Gejala | Perbaikan |
| --- | --- |
| `graphify` tidak ditemukan | `uv tool update-shell`, buka terminal baru |
| Graph tampak basi | `graphify update .` |
| Graph mengecil setelah refactor | `graphify extract . --code-only --force` |
| Query terlalu terpotong | Naikkan `--budget` atau turunkan `--depth` |
| Nama komunitas aneh | Normal; label hub-derived. Jalankan `graphify label` bila punya backend LLM |
| Ingin menghapus integrasi | `graphify opencode uninstall`, `graphify hook uninstall`, `uv tool uninstall graphifyy` |
