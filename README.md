# Melodia — Penjelajah Musik Bergaya Apple Music

Aplikasi mobile berbasis **Flutter** yang menyajikan data lagu secara dinamis
dari tiga API publik, dengan antarmuka bergaya Apple Music: latar aurora
berwarna dan permukaan kaca buram (*glassmorphism*).

Dibuat untuk memenuhi tugas UTS matakuliah **Pemrograman Mobile (Praktikum)**.

## Deskripsi Singkat

Musik arus utama kini terkunci di balik layanan berlangganan berbayar,
sementara di sisi lain banyak musisi independen kesulitan memperoleh
pendengar. Melodia menjembatani keduanya dalam satu aplikasi:

- **Katalog populer** dari iTunes untuk menelusuri dan mengenali lagu melalui
  pratinjau 30 detik, lengkap dengan sampul album dan lirik.
- **Karya musisi independen** dari Audius yang dapat diputar **secara utuh**,
  legal, dan tanpa biaya langganan.

Dengan demikian pengguna tetap dapat menikmati musik tanpa berlangganan,
sekaligus memperluas jangkauan pendengar bagi musisi independen.

## Fitur Utama

### Tiga halaman utama

| Halaman | Isi |
|---|---|
| **Dashboard** | Sapaan sesuai waktu, kartu "Pilihan Hari Ini", dan empat baris rekomendasi mendatar (Sedang Populer, Pop Indonesia, Rock & Alternatif, Suasana Santai) yang seluruhnya diambil dari API. |
| **Indie** | Lagu dari musisi independen (Audius) yang dapat **diputar penuh**. Menampilkan lagu populer dan dilengkapi pencarian sendiri. |
| **Cari** | Pencarian lagu/artis/album dengan penundaan ketik 600 ms, dilengkapi saran artis berbentuk chip kaca. |
| **Akun** | Profil tamu, ringkasan jumlah lagu favorit dan artis berbeda, pustaka favorit, serta menu pengaturan. Proses masuk (login) belum tersedia pada versi ini. |

### Fitur pendukung

- **Halaman detail** — sampul resolusi tinggi, album, genre, durasi, tahun rilis.
- **Bar pemutar** menempel di bawah layar berisi sampul, judul lagu, garis kemajuan, dan tombol putar/jeda. Bar ini berlaku untuk seluruh aplikasi, sehingga lagu tetap berputar ketika pengguna menutup halaman detail dan kembali menjelajah.
- **Pratinjau audio 30 detik** dari iTunes.
- **Lirik lagu** dari API kedua, ditampilkan di dalam panel kaca.
- **Lagu favorit** tersimpan di perangkat sehingga tetap ada setelah aplikasi ditutup.
- **Penanganan status lengkap** — memuat, berhasil, kosong, dan gagal dengan tombol "Coba Lagi".
- **Tarik untuk menyegarkan** pada dashboard.

## API yang Digunakan

### 1. iTunes Search API (data utama)

```
https://itunes.apple.com/search?term={kata_kunci}&entity=song&limit=30&country=ID
```

Tanpa kunci API dan tanpa autentikasi. Atribut yang dipakai: `trackId`,
`trackName`, `artistName`, `collectionName`, `primaryGenreName`,
`artworkUrl100`, `previewUrl`, `trackTimeMillis`, dan `releaseDate`.

### 2. Audius API (lagu penuh)

```
https://discoveryprovider.audius.co/v1/tracks/trending?app_name=MELODIA&limit=20
https://discoveryprovider.audius.co/v1/tracks/search?query={kata_kunci}&app_name=MELODIA
https://discoveryprovider.audius.co/v1/tracks/{id}/stream?app_name=MELODIA
```

Tanpa kunci API. Struktur JSON-nya berbeda dari iTunes: nama musisi berada di
dalam objek `user`, sampul tersedia dalam tiga ukuran pada objek `artwork`, dan
durasi sudah berformat detik. Lagu yang terkunci (`is_stream_gated`) atau tidak
dapat diputar (`is_streamable`) disaring terlebih dahulu.

### 3. lyrics.ovh (data pelengkap)

```
https://api.lyrics.ovh/v1/{artis}/{judul}
```

Mengembalikan objek JSON berisi field `lyrics`. Bila lirik tidak tersedia,
server membalas kode 404 dan aplikasi menampilkan keterangan yang sesuai tanpa
mengganggu fungsi lainnya.

## Teknologi dan Package

| Package | Versi | Fungsi |
|---|---|---|
| `http` | ^1.6.0 | Mengirim permintaan HTTP GET ke ketiga API. |
| `just_audio` | ^0.9.46 | Memutar berkas audio pratinjau dari URL. |
| `shared_preferences` | ^2.5.3 | Menyimpan daftar lagu favorit di penyimpanan lokal. |

Dikembangkan dengan Flutter 3.24.5 dan Dart 3.5.4.

## Struktur Project

```
lib/
├── main.dart                     # Titik masuk aplikasi
├── theme/
│   └── app_theme.dart            # Palet warna dan gaya teks
├── models/
│   └── song.dart                 # Class model + factory fromJson / toJson
├── services/
│   ├── api_exception.dart        # Pembungkus pesan kesalahan
│   ├── music_api_service.dart    # Permintaan HTTP ke iTunes & lyrics.ovh
│   ├── audius_api_service.dart   # Permintaan HTTP ke Audius
│   ├── favorite_service.dart     # Penyimpanan lagu favorit
│   └── player_controller.dart    # Pemutar audio bersama seluruh aplikasi
├── pages/
│   ├── root_page.dart            # Kerangka + bilah navigasi kaca
│   ├── dashboard_page.dart       # Halaman rekomendasi
│   ├── indie_page.dart           # Musik independen (lagu penuh)
│   ├── search_page.dart          # Halaman pencarian
│   ├── account_page.dart         # Halaman akun
│   └── detail_page.dart          # Detail lagu, pemutar audio, lirik
└── widgets/
    ├── glass.dart                # GlassPanel + AuroraBackground
    ├── mini_player.dart          # Bar pemutar di bagian bawah layar
    ├── album_card.dart           # Kartu sampul untuk daftar mendatar
    ├── song_tile.dart            # Satu baris daftar lagu
    └── state_views.dart          # Tampilan memuat, gagal, dan kosong
```

## Cara Kerja Efek Kaca

`GlassPanel` menumpuk tiga lapisan: `BackdropFilter` dengan `ImageFilter.blur`
untuk mengaburkan apa pun di belakangnya, lapisan putih semi transparan sebagai
badan kaca, dan garis tepi tipis sebagai pantulan cahaya. Agar efek ini terlihat,
di belakangnya dipasang `AuroraBackground` — tiga lingkaran gradien berwarna
yang menjadi objek untuk dikaburkan.

## Alur Pengambilan Data

1. `MusicApiService.cariLagu()` menyusun URL dan mengirim permintaan `GET`.
2. Status respons diperiksa; selain kode `200` dianggap gagal.
3. Badan respons didekode sebagai UTF-8 lalu diubah menjadi objek Dart. Karena
   struktur JSON iTunes dan Audius berbeda, class `Song` menyediakan dua
   factory terpisah — `Song.fromItunes()` dan `Song.fromAudius()` — sehingga
   seluruh widget dapat memakai satu model yang sama tanpa perlu tahu asal
   datanya.
4. `FutureBuilder` memantau `Future` tersebut dan menampilkan kondisi memuat,
   berhasil, atau gagal.
5. Khusus dashboard, empat kategori diminta bersamaan dengan `Future.wait()`
   agar waktu tunggu tidak menumpuk.
6. Kegagalan jaringan (`SocketException`), batas waktu (`TimeoutException`),
   dan data rusak (`FormatException`) diterjemahkan menjadi pesan berbahasa
   Indonesia melalui `ApiException`.

## Langkah Menjalankan Aplikasi

1. Pastikan Flutter SDK sudah terpasang:
   ```bash
   flutter doctor
   ```
2. Unduh kode sumber:
   ```bash
   git clone https://github.com/<username>/melodia_myversion.git
   cd melodia_myversion
   ```
3. Pasang seluruh dependency:
   ```bash
   flutter pub get
   ```
4. Jalankan pada emulator/perangkat Android:
   ```bash
   flutter run
   ```
   atau pada peramban:
   ```bash
   flutter run -d chrome
   ```

Kedua penyedia data mengirim header `Access-Control-Allow-Origin: *`, sehingga
aplikasi berjalan normal di peramban tanpa hambatan CORS.

## Pengujian

```bash
flutter analyze   # pemeriksaan statis, tanpa isu
flutter test      # pengujian widget bilah navigasi
```
