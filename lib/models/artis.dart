import 'song.dart';

/// Satu album milik artis (hanya tersedia dari iTunes).
class Album {
  final String id;
  final String nama;
  final String? sampul;
  final String tahun;
  final int jumlahLagu;

  const Album({
    required this.id,
    required this.nama,
    required this.sampul,
    required this.tahun,
    required this.jumlahLagu,
  });

  factory Album.fromItunes(Map<String, dynamic> json) {
    final sampul = json['artworkUrl100'] as String?;
    final tanggal = json['releaseDate'] as String? ?? '';
    return Album(
      id: (json['collectionId'] ?? '').toString(),
      nama: json['collectionName'] as String? ?? 'Tanpa Judul',
      sampul: sampul?.replaceAll('100x100bb', '400x400bb'),
      tahun: tanggal.length >= 4 ? tanggal.substring(0, 4) : '-',
      jumlahLagu: (json['trackCount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Seluruh data yang ditampilkan pada halaman artis.
class ProfilArtis {
  final String nama;
  final String keterangan;

  /// Gambar besar di bagian atas halaman.
  final String? gambar;
  final String? bio;
  final String? lokasi;
  final int? pengikut;
  final List<Song> laguTeratas;
  final List<Album> album;
  final SumberLagu sumber;

  const ProfilArtis({
    required this.nama,
    required this.keterangan,
    required this.gambar,
    required this.laguTeratas,
    required this.sumber,
    this.bio,
    this.lokasi,
    this.pengikut,
    this.album = const [],
  });

  /// Jumlah pengikut dalam format singkat, misalnya "12,4 rb".
  String? get pengikutSingkat {
    final n = pengikut;
    if (n == null) return null;
    String satuDesimal(double x) =>
        x.toStringAsFixed(1).replaceAll('.0', '').replaceAll('.', ',');
    if (n >= 1000000) return '${satuDesimal(n / 1000000)} jt';
    if (n >= 1000) return '${satuDesimal(n / 1000)} rb';
    return '$n';
  }
}
