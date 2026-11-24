import 'song.dart';

/// Playlist buatan pengguna yang disimpan di perangkat.
class Playlist {
  final String id;
  final String nama;
  final List<Song> lagu;
  final DateTime dibuat;

  const Playlist({
    required this.id,
    required this.nama,
    required this.lagu,
    required this.dibuat,
  });

  Playlist salin({String? nama, List<Song>? lagu}) => Playlist(
        id: id,
        nama: nama ?? this.nama,
        lagu: lagu ?? this.lagu,
        dibuat: dibuat,
      );

  /// Sampul playlist diambil dari lagu pertama.
  String? get sampul => lagu.isEmpty ? null : lagu.first.artworkBesar;

  /// Total durasi seluruh lagu, misalnya "1 jam 12 menit" atau "23 menit".
  String get totalDurasi {
    final detik = lagu.fold<int>(0, (jumlah, l) => jumlah + l.durasiDetik);
    final jam = detik ~/ 3600;
    final menit = (detik % 3600) ~/ 60;
    if (jam > 0) return '$jam jam $menit menit';
    return '$menit menit';
  }

  factory Playlist.fromJson(Map<String, dynamic> json) => Playlist(
        id: json['id'] as String,
        nama: json['nama'] as String? ?? 'Tanpa Nama',
        lagu: (json['lagu'] as List<dynamic>? ?? const [])
            .map((item) => Song.fromSimpan(item as Map<String, dynamic>))
            .toList(),
        dibuat: DateTime.tryParse(json['dibuat'] as String? ?? '') ??
            DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nama': nama,
        'lagu': lagu.map((l) => l.toJson()).toList(),
        'dibuat': dibuat.toIso8601String(),
      };
}
