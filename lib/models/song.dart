/// Asal data sebuah lagu.
///
/// Dipakai aplikasi untuk membedakan lagu yang hanya menyediakan pratinjau
/// dengan lagu yang dapat diputar utuh.
enum SumberLagu {
  /// iTunes Search API — katalog arus utama, hanya pratinjau 30 detik.
  itunes,

  /// Audius API — karya musisi independen, dapat diputar penuh.
  audius,
}

/// Model data satu lagu.
///
/// Satu class ini dipakai untuk kedua penyedia data agar seluruh widget
/// (daftar, kartu album, bar pemutar) tidak perlu tahu lagu itu berasal dari
/// mana. Perbedaan struktur JSON diselesaikan pada masing-masing factory.
class Song {
  final String id;
  final String trackName;
  final String artistName;
  final String collectionName;
  final String genre;
  final String? artworkKecil;
  final String? artworkBesar;

  /// Alamat berkas audio yang diputar. Untuk iTunes berisi pratinjau
  /// 30 detik, untuk Audius berisi lagu utuh.
  final String? urlAudio;

  final int durasiDetik;
  final String releaseDate;
  final SumberLagu sumber;

  const Song({
    required this.id,
    required this.trackName,
    required this.artistName,
    required this.collectionName,
    required this.genre,
    required this.artworkKecil,
    required this.artworkBesar,
    required this.urlAudio,
    required this.durasiDetik,
    required this.releaseDate,
    required this.sumber,
  });

  /// Mengubah satu objek lagu dari iTunes Search API menjadi objek Dart.
  factory Song.fromItunes(Map<String, dynamic> json) {
    final sampul = json['artworkUrl100'] as String?;
    return Song(
      id: (json['trackId'] ?? '').toString(),
      trackName: json['trackName'] as String? ?? 'Tanpa Judul',
      artistName: json['artistName'] as String? ?? 'Artis Tidak Diketahui',
      collectionName: json['collectionName'] as String? ?? '-',
      genre: json['primaryGenreName'] as String? ?? '-',
      artworkKecil: sampul,
      artworkBesar: sampul?.replaceAll('100x100bb', '600x600bb'),
      urlAudio: json['previewUrl'] as String?,
      durasiDetik: ((json['trackTimeMillis'] as num?) ?? 0) ~/ 1000,
      releaseDate: json['releaseDate'] as String? ?? '',
      sumber: SumberLagu.itunes,
    );
  }

  /// Mengubah satu objek lagu dari Audius API menjadi objek Dart.
  ///
  /// Struktur JSON Audius berbeda: nama penyanyi berada di dalam objek
  /// `user`, sampul tersedia dalam beberapa ukuran, dan durasi sudah
  /// berformat detik.
  factory Song.fromAudius(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? '';
    final sampul = json['artwork'] as Map<String, dynamic>?;
    final pengguna = json['user'] as Map<String, dynamic>?;

    return Song(
      id: id,
      trackName: json['title'] as String? ?? 'Tanpa Judul',
      artistName: pengguna?['name'] as String? ?? 'Musisi Independen',
      collectionName: 'Rilisan Mandiri',
      genre: json['genre'] as String? ?? '-',
      artworkKecil: sampul?['150x150'] as String?,
      artworkBesar: sampul?['480x480'] as String?,
      urlAudio: id.isEmpty ? null : alamatStream(id),
      durasiDetik: (json['duration'] as num?)?.toInt() ?? 0,
      releaseDate: json['release_date'] as String? ?? '',
      sumber: SumberLagu.audius,
    );
  }

  /// Membaca kembali lagu yang tersimpan pada penyimpanan lokal.
  factory Song.fromSimpan(Map<String, dynamic> json) {
    return Song(
      id: json['id'] as String? ?? '',
      trackName: json['trackName'] as String? ?? 'Tanpa Judul',
      artistName: json['artistName'] as String? ?? '-',
      collectionName: json['collectionName'] as String? ?? '-',
      genre: json['genre'] as String? ?? '-',
      artworkKecil: json['artworkKecil'] as String?,
      artworkBesar: json['artworkBesar'] as String?,
      urlAudio: json['urlAudio'] as String?,
      durasiDetik: (json['durasiDetik'] as num?)?.toInt() ?? 0,
      releaseDate: json['releaseDate'] as String? ?? '',
      sumber: json['sumber'] == 'audius'
          ? SumberLagu.audius
          : SumberLagu.itunes,
    );
  }

  /// Dipakai saat menyimpan lagu favorit ke penyimpanan lokal.
  Map<String, dynamic> toJson() => {
        'id': id,
        'trackName': trackName,
        'artistName': artistName,
        'collectionName': collectionName,
        'genre': genre,
        'artworkKecil': artworkKecil,
        'artworkBesar': artworkBesar,
        'urlAudio': urlAudio,
        'durasiDetik': durasiDetik,
        'releaseDate': releaseDate,
        'sumber': sumber == SumberLagu.audius ? 'audius' : 'itunes',
      };

  /// Menyusun alamat pemutaran lagu Audius berdasarkan id lagu.
  static String alamatStream(String id) =>
      'https://discoveryprovider.audius.co/v1/tracks/$id/stream'
      '?app_name=MELODIA';

  /// Benar bila lagu dapat diputar utuh, bukan sekadar pratinjau.
  bool get dapatDiputarPenuh => sumber == SumberLagu.audius;

  /// Keterangan singkat mengenai asal dan batasan pemutaran lagu.
  String get keteranganSumber => dapatDiputarPenuh
      ? 'Lagu penuh — Audius'
      : 'Pratinjau 30 detik — iTunes';

  /// Durasi lagu dalam format mm:ss.
  String get durasi {
    if (durasiDetik <= 0) return '--:--';
    final menit = durasiDetik ~/ 60;
    final detik = durasiDetik % 60;
    return '$menit:${detik.toString().padLeft(2, '0')}';
  }

  /// Tahun rilis yang diambil dari tanggal berformat ISO 8601.
  String get tahunRilis =>
      releaseDate.length >= 4 ? releaseDate.substring(0, 4) : '-';
}
