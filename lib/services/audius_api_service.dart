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

  /// Mengambil lagu yang sedang populer di Audius.
  ///
  /// URL: https://discoveryprovider.audius.co/v1/tracks/trending?app_name=MELODIA
  Future<List<Song>> laguPopuler({int jumlah = 20}) {
    return _ambil(
      Uri.https(_host, '/v1/tracks/trending', {
        'app_name': _namaAplikasi,
        'limit': '$jumlah',
      }),
    );
  }

  /// Mencari lagu di Audius berdasarkan [kataKunci].
  Future<List<Song>> cariLagu(String kataKunci, {int jumlah = 20}) {
    return _ambil(
      Uri.https(_host, '/v1/tracks/search', {
        'query': kataKunci,
        'app_name': _namaAplikasi,
        'limit': '$jumlah',
      }),
    );
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
          .where((lagu) => lagu.urlAudio != null)
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
