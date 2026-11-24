import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/artis.dart';
import '../models/song.dart';
import 'api_exception.dart';

/// Mengambil data halaman artis dari penyedia lagu yang sesuai.
///
/// - iTunes Lookup API: lagu teratas dan daftar album. iTunes tidak
///   menyediakan foto artis, sehingga sampul album terbaru dipakai sebagai
///   gambar utama.
/// - Audius API: profil musisi (foto, bio, lokasi, pengikut) dan lagunya
///   yang diurutkan berdasarkan jumlah putar.
class ArtisService {
  static const Duration _batasWaktu = Duration(seconds: 15);
  static const String _audius = 'discoveryprovider.audius.co';
  static const String _namaAplikasi = 'MELODIA';

  Future<ProfilArtis> ambil(Song lagu) async {
    try {
      return lagu.sumber == SumberLagu.audius
          ? await _dariAudius(lagu)
          : await _dariItunes(lagu);
    } on SocketException {
      throw const ApiException(
        'Tidak ada koneksi internet. Periksa jaringan lalu coba lagi.',
      );
    } on TimeoutException {
      throw const ApiException('Server tidak merespons.');
    } on FormatException {
      throw const ApiException('Data artis tidak berformat JSON.');
    }
  }

  /// Mengirim GET lalu mengembalikan isi JSON.
  Future<dynamic> _json(Uri uri) async {
    final respons = await http.get(uri).timeout(_batasWaktu);
    if (respons.statusCode != 200) {
      throw ApiException(
        'Server menolak permintaan (kode ${respons.statusCode}).',
      );
    }
    return json.decode(utf8.decode(respons.bodyBytes));
  }

  // ---------------------------------------------------------------- iTunes

  Future<ProfilArtis> _dariItunes(Song lagu) async {
    // Lagu favorit lama belum menyimpan id artis, jadi dicari lewat nama.
    final id = lagu.idArtis ?? await _cariIdItunes(lagu.artistName);
    if (id == null) {
      throw const ApiException('Artis tidak ditemukan di iTunes.');
    }

    // Lagu dan album diambil bersamaan.
    final hasil = await Future.wait([
      _json(Uri.https('itunes.apple.com', '/lookup', {
        'id': id,
        'entity': 'song',
        'limit': '30',
        'country': 'ID',
      })),
      _json(Uri.https('itunes.apple.com', '/lookup', {
        'id': id,
        'entity': 'album',
        'limit': '25',
        'country': 'ID',
      })),
    ]);

    final dataLagu = (hasil[0] as Map<String, dynamic>)['results'] as List;
    final dataAlbum = (hasil[1] as Map<String, dynamic>)['results'] as List;

    // Elemen pertama hasil lookup adalah data artis itu sendiri.
    final artis = dataLagu.isEmpty
        ? const <String, dynamic>{}
        : dataLagu.first as Map<String, dynamic>;

    final judulTerlihat = <String>{};
    final laguTeratas = dataLagu
        .cast<Map<String, dynamic>>()
        .where((item) => item['wrapperType'] == 'track')
        .map(Song.fromItunes)
        .where((l) => l.urlAudio != null)
        // Satu judul bisa muncul berkali-kali (versi album dan single).
        .where((l) => judulTerlihat.add(l.trackName.toLowerCase()))
        .toList();

    final album = dataAlbum
        .cast<Map<String, dynamic>>()
        .where((item) => item['wrapperType'] == 'collection')
        .map(Album.fromItunes)
        .toList()
      ..sort((a, b) => b.tahun.compareTo(a.tahun));

    final gambar = album.isNotEmpty
        ? album.first.sampul?.replaceAll('400x400bb', '1000x1000bb')
        : lagu.artworkBesar;

    return ProfilArtis(
      nama: artis['artistName'] as String? ?? lagu.artistName,
      keterangan: artis['primaryGenreName'] as String? ?? lagu.genre,
      gambar: gambar,
      laguTeratas: laguTeratas,
      album: album,
      sumber: SumberLagu.itunes,
    );
  }

  Future<String?> _cariIdItunes(String nama) async {
    final data = await _json(Uri.https('itunes.apple.com', '/search', {
      'term': nama,
      'entity': 'musicArtist',
      'limit': '1',
      'country': 'ID',
    })) as Map<String, dynamic>;
    final hasil = data['results'] as List;
    if (hasil.isEmpty) return null;
    return (hasil.first as Map<String, dynamic>)['artistId']?.toString();
  }

  /// Daftar lagu pada satu album, untuk lembar album di halaman artis.
  Future<List<Song>> laguAlbum(String idAlbum) async {
    try {
      final data = await _json(Uri.https('itunes.apple.com', '/lookup', {
        'id': idAlbum,
        'entity': 'song',
        'country': 'ID',
      })) as Map<String, dynamic>;
      return (data['results'] as List)
          .cast<Map<String, dynamic>>()
          .where((item) => item['wrapperType'] == 'track')
          .map(Song.fromItunes)
          .where((l) => l.urlAudio != null)
          .toList();
    } on SocketException {
      throw const ApiException('Tidak ada koneksi internet.');
    } on TimeoutException {
      throw const ApiException('Server tidak merespons.');
    }
  }

  // ---------------------------------------------------------------- Audius

  Future<ProfilArtis> _dariAudius(Song lagu) async {
    final id = lagu.idArtis ?? await _cariIdAudius(lagu.artistName);
    if (id == null) {
      throw const ApiException('Musisi tidak ditemukan di Audius.');
    }

    final hasil = await Future.wait([
      _json(Uri.https(_audius, '/v1/users/$id', {'app_name': _namaAplikasi})),
      _json(Uri.https(_audius, '/v1/users/$id/tracks', {
        'app_name': _namaAplikasi,
        'limit': '50',
      })),
    ]);

    final profil =
        (hasil[0] as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    final dataLagu = ((hasil[1] as Map<String, dynamic>)['data'] as List)
        .cast<Map<String, dynamic>>()
        .where((item) =>
            item['is_streamable'] != false && item['is_stream_gated'] != true)
        .toList()
      // Lagu teratas = paling banyak diputar.
      ..sort((a, b) => ((b['play_count'] as num?) ?? 0)
          .compareTo((a['play_count'] as num?) ?? 0));

    final foto = profil['profile_picture'] as Map<String, dynamic>?;
    final latar = profil['cover_photo'] as Map<String, dynamic>?;
    final bio = (profil['bio'] as String?)?.trim();
    final lokasi = (profil['location'] as String?)?.trim();
    final jumlahLagu = (profil['track_count'] as num?)?.toInt() ?? 0;

    return ProfilArtis(
      nama: profil['name'] as String? ?? lagu.artistName,
      keterangan: 'Musisi independen · $jumlahLagu lagu',
      gambar: foto?['1000x1000'] as String? ??
          foto?['480x480'] as String? ??
          latar?['2000x'] as String? ??
          lagu.artworkBesar,
      bio: (bio == null || bio.isEmpty) ? null : bio,
      lokasi: (lokasi == null || lokasi.isEmpty) ? null : lokasi,
      pengikut: (profil['follower_count'] as num?)?.toInt(),
      laguTeratas: dataLagu.map(Song.fromAudius).toList(),
      sumber: SumberLagu.audius,
    );
  }

  Future<String?> _cariIdAudius(String nama) async {
    final data = await _json(Uri.https(_audius, '/v1/users/search', {
      'query': nama,
      'app_name': _namaAplikasi,
    })) as Map<String, dynamic>;
    final hasil = data['data'] as List? ?? const [];
    if (hasil.isEmpty) return null;
    return (hasil.first as Map<String, dynamic>)['id'] as String?;
  }
}
