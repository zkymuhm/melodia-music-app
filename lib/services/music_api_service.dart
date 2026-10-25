import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/song.dart';
import 'api_exception.dart';

/// Lapisan yang menangani seluruh komunikasi dengan API.
///
/// Dipisahkan dari widget agar proses pengambilan data tidak bercampur
/// dengan kode antarmuka.
class MusicApiService {
  static const Duration _batasWaktu = Duration(seconds: 15);

  /// Mengambil daftar lagu dari iTunes Search API berdasarkan [kataKunci].
  ///
  /// URL: https://itunes.apple.com/search?term=...&entity=song&limit=30&country=ID
  Future<List<Song>> cariLagu(String kataKunci) async {
    final uri = Uri.https('itunes.apple.com', '/search', {
      'term': kataKunci,
      'entity': 'song',
      'limit': '30',
      'country': 'ID',
    });

    try {
      // 1. Mengirim permintaan HTTP GET ke server.
      final respons = await http.get(uri).timeout(_batasWaktu);

      // 2. Memeriksa status respons sebelum data diolah.
      if (respons.statusCode != 200) {
        throw ApiException(
          'Server menolak permintaan (kode ${respons.statusCode}).',
        );
      }

      // 3. Mengubah teks JSON menjadi objek Dart melalui class model.
      final body = json.decode(utf8.decode(respons.bodyBytes));
      final hasil = (body as Map<String, dynamic>)['results'] as List<dynamic>?;

      if (hasil == null) {
        throw const ApiException('Struktur data dari server tidak dikenali.');
      }

      // Lagu tanpa berkas audio dibuang karena tidak dapat diputar.
      return hasil
          .map((item) => Song.fromItunes(item as Map<String, dynamic>))
          .where((lagu) => lagu.urlAudio != null)
          .toList();
    } on SocketException {
      throw const ApiException(
        'Tidak ada koneksi internet. Periksa jaringan lalu coba lagi.',
      );
    } on TimeoutException {
      throw const ApiException(
        'Permintaan melebihi batas waktu. Server tidak merespons.',
      );
    } on FormatException {
      throw const ApiException('Data dari server tidak berformat JSON.');
    }
  }

  /// Mengambil lirik lagu dari lyrics.ovh.
  ///
  /// Mengembalikan null bila lirik tidak tersedia, karena lirik merupakan
  /// pelengkap dan ketidakhadirannya bukan kegagalan aplikasi.
  Future<String?> ambilLirik(String artis, String judul) async {
    final uri = Uri.https(
      'api.lyrics.ovh',
      '/v1/${Uri.encodeComponent(_bersihkan(artis))}/'
          '${Uri.encodeComponent(_bersihkan(judul))}',
    );

    try {
      final respons = await http.get(uri).timeout(_batasWaktu);
      if (respons.statusCode != 200) return null;

      final body = json.decode(utf8.decode(respons.bodyBytes));
      final lirik = (body as Map<String, dynamic>)['lyrics'] as String?;
      final rapi = lirik?.trim();
      return (rapi == null || rapi.isEmpty) ? null : rapi;
    } on SocketException {
      throw const ApiException('Tidak ada koneksi internet.');
    } on TimeoutException {
      throw const ApiException('Server lirik tidak merespons.');
    } on FormatException {
      return null;
    }
  }

  /// Membuang keterangan tambahan seperti "(feat. ...)" atau "- Remastered"
  /// agar judul lebih mudah dicocokkan oleh penyedia lirik.
  String _bersihkan(String teks) {
    return teks
        .replaceAll(RegExp(r'\(.*?\)'), '')
        .replaceAll(RegExp(r'\[.*?\]'), '')
        .split(' - ')
        .first
        .trim();
  }

  /// Mengambil beberapa kategori lagu sekaligus untuk halaman dashboard.
  ///
  /// Seluruh permintaan dijalankan bersamaan dengan [Future.wait] agar waktu
  /// tunggu tidak menumpuk, bukan satu per satu secara berurutan.
  Future<Map<String, List<Song>>> ambilBeranda(List<String> kategori) async {
    final hasil = await Future.wait(kategori.map(cariLagu));
    return Map.fromIterables(kategori, hasil);
  }
}
