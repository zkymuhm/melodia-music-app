import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/song.dart';
import 'api_exception.dart';

/// Lapisan komunikasi dengan Audius API.
///
/// Audius adalah penyedia musik dari para musisi independen yang mengizinkan
/// pemutaran lagu secara utuh tanpa langganan, sehingga dipakai sebagai
/// pelengkap katalog iTunes yang hanya menyediakan pratinjau.
class AudiusApiService {
  static const String _host = 'discoveryprovider.audius.co';
  static const String _namaAplikasi = 'MELODIA';
  static const Duration _batasWaktu = Duration(seconds: 20);

  /// Genre yang ditawarkan pada halaman Indie. Nilainya harus sama persis
  /// dengan nama genre di Audius karena dikirim apa adanya sebagai parameter.
  static const List<String> daftarGenre = [
    'Lo-Fi',
    'Pop',
    'R&B/Soul',
    'Acoustic',
    'Alternative',
    'Hip-Hop/Rap',
    'Jazz',
    'Electronic',
    'Ambient',
    'Folk',
  ];

  /// Rentang waktu tangga lagu populer. Kunci = nilai parameter `time`
  /// di Audius, nilai = label yang ditampilkan.
  static const Map<String, String> daftarPeriode = {
    'week': 'Minggu Ini',
    'month': 'Bulan Ini',
    'year': 'Tahun Ini',
    'allTime': 'Sepanjang Masa',
  };

  /// Genre yang bukan lagu (siniar, buku audio, dll.) selalu disaring.
  static const Set<String> _bukanMusik = {
    'Podcasts',
    'Audiobooks',
    'Comedy',
    'Spoken Word',
  };

  /// Mengambil lagu yang sedang populer di Audius.
  ///
  /// [genre] bernilai null berarti semua genre. [periode] memakai salah satu
  /// kunci dari [daftarPeriode]. Periode yang panjang ("allTime") cenderung
  /// berisi lagu yang sudah teruji banyak pendengar.
  ///
  /// URL: https://discoveryprovider.audius.co/v1/tracks/trending
  ///      ?app_name=MELODIA&genre=Lo-Fi&time=allTime&limit=30
  Future<List<Song>> laguPopuler({
    String? genre,
    String periode = 'allTime',
    int jumlah = 30,
  }) {
    return _ambil(
      Uri.https(_host, '/v1/tracks/trending', {
        'app_name': _namaAplikasi,
        'limit': '$jumlah',
        'time': periode,
        if (genre != null) 'genre': genre,
      }),
    );
  }

  /// Mencari lagu di Audius berdasarkan [kataKunci].
  ///
  /// Endpoint pencarian tidak menyaring genre, sehingga bila [genre] diisi
  /// penyaringan dilakukan di sisi aplikasi.
  Future<List<Song>> cariLagu(
    String kataKunci, {
    String? genre,
    int jumlah = 30,
  }) async {
    final hasil = await _ambil(
      Uri.https(_host, '/v1/tracks/search', {
        'query': kataKunci,
        'app_name': _namaAplikasi,
        'limit': '$jumlah',
      }),
    );
    if (genre == null) return hasil;
    return hasil.where((lagu) => lagu.genre == genre).toList();
  }

  /// Proses pengambilan data yang dipakai bersama oleh kedua permintaan.
  Future<List<Song>> _ambil(Uri uri) async {
    try {
      // 1. Mengirim permintaan HTTP GET ke server.
      final respons = await http.get(uri).timeout(_batasWaktu);

      // 2. Memeriksa status respons sebelum data diolah.
      if (respons.statusCode != 200) {
        throw ApiException(
          'Server Audius menolak permintaan (kode ${respons.statusCode}).',
        );
      }

      // 3. Mengubah teks JSON menjadi objek Dart melalui class model.
      final body = json.decode(utf8.decode(respons.bodyBytes));
      final hasil = (body as Map<String, dynamic>)['data'] as List<dynamic>?;

      if (hasil == null) {
        throw const ApiException(
          'Struktur data dari server Audius tidak dikenali.',
        );
      }

      return hasil
          .map((item) => item as Map<String, dynamic>)
          // Lagu yang terkunci atau tidak dapat diputar disaring lebih dulu
          // agar tidak muncul sebagai lagu yang gagal diputar.
          .where((item) =>
              item['is_streamable'] != false && item['is_stream_gated'] != true)
          .map(Song.fromAudius)
          .where((lagu) =>
              lagu.urlAudio != null && !_bukanMusik.contains(lagu.genre))
          .toList();
    } on SocketException {
      throw const ApiException(
        'Tidak ada koneksi internet. Periksa jaringan lalu coba lagi.',
      );
    } on TimeoutException {
      throw const ApiException(
        'Permintaan ke Audius melebihi batas waktu.',
      );
    } on FormatException {
      throw const ApiException('Data dari Audius tidak berformat JSON.');
    }
  }
}
