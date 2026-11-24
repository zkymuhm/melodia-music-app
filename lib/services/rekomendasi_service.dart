import '../models/song.dart';
import 'artis_service.dart';
import 'riwayat_service.dart';

/// Hasil rekomendasi "Pilihan Hari Ini".
class Pilihan {
  final Song lagu;

  /// Daftar asal lagu, dipakai sebagai antrean ketika kartu diketuk.
  final List<Song> antrean;

  /// Alasan yang ditampilkan ke pengguna, misalnya
  /// "Karena kamu sering memutar Hindia".
  final String alasan;

  const Pilihan({
    required this.lagu,
    required this.antrean,
    required this.alasan,
  });
}

/// Menentukan "Pilihan Hari Ini" di beranda.
///
/// 1. Personal (bila sudah ada riwayat putar): cari artis yang paling sering
///    muncul di riwayat, lalu pilih lagunya yang BELUM pernah diputar.
/// 2. Cadangan (pengguna baru atau terjadi kesalahan): pilih dari daftar
///    lagu populer.
///
/// Pada kedua cara, lagu dipilih berdasarkan tanggal (nomor hari), sehingga
/// dalam satu hari hasilnya tetap sama dan berganti keesokan harinya.
class RekomendasiService {
  final RiwayatService _riwayat = RiwayatService();
  final ArtisService _artis = ArtisService();

  /// Nomor hari sejak 1 Januari 2026, bertambah satu setiap hari.
  static int get _nomorHari =>
      DateTime.now().difference(DateTime(2026, 1, 1)).inDays;

  Future<Pilihan?> pilihanHariIni(List<Song> populer) async {
    try {
      final personal = await _dariRiwayat();
      if (personal != null) return personal;
    } catch (_) {
      // Gagal mengambil data artis: lanjut ke cara cadangan.
    }

    if (populer.isEmpty) return null;
    return Pilihan(
      lagu: populer[_nomorHari % populer.length],
      antrean: populer,
      alasan: 'Lagu populer pilihan, berganti setiap hari',
    );
  }

  Future<Pilihan?> _dariRiwayat() async {
    final riwayat = await _riwayat.ambil();
    if (riwayat.isEmpty) return null;

    // Menghitung berapa kali setiap artis muncul di riwayat.
    final jumlah = <String, int>{};
    final contohLagu = <String, Song>{};
    for (final lagu in riwayat) {
      final kunci = lagu.artistName.toLowerCase();
      jumlah[kunci] = (jumlah[kunci] ?? 0) + 1;
      // Riwayat urut dari yang terbaru, jadi lagu pertama yang ditemui
      // adalah lagu terbaru dari artis tersebut.
      contohLagu.putIfAbsent(kunci, () => lagu);
    }

    final artisFavorit =
        jumlah.entries.reduce((a, b) => b.value > a.value ? b : a).key;
    final contoh = contohLagu[artisFavorit]!;

    final profil = await _artis.ambil(contoh);
    final sudahDiputar = riwayat.map((l) => l.id).toSet();
    final belumDiputar =
        profil.laguTeratas.where((l) => !sudahDiputar.contains(l.id)).toList();

    // Bila semua lagu artis itu sudah pernah diputar, pakai semua lagunya.
    final kandidat =
        belumDiputar.isNotEmpty ? belumDiputar : profil.laguTeratas;
    if (kandidat.isEmpty) return null;

    return Pilihan(
      lagu: kandidat[_nomorHari % kandidat.length],
      antrean: kandidat,
      alasan: 'Karena kamu sering memutar ${profil.nama}',
    );
  }
}
