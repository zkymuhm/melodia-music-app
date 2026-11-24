import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/playlist.dart';
import '../models/song.dart';

/// Penanda versi data playlist. Nilainya bertambah setiap kali ada
/// perubahan sehingga halaman lain dapat memuat ulang datanya.
final ValueNotifier<int> versiPlaylist = ValueNotifier<int>(0);

/// Menyimpan playlist buatan pengguna pada penyimpanan lokal perangkat.
///
/// Seluruh playlist disimpan sebagai satu teks JSON berisi daftar objek.
class PlaylistService {
  static const String _kunci = 'playlist_pengguna';

  Future<List<Playlist>> ambilSemua() async {
    final prefs = await SharedPreferences.getInstance();
    final teks = prefs.getString(_kunci);
    if (teks == null || teks.isEmpty) return [];
    final data = json.decode(teks) as List<dynamic>;
    return data
        .map((item) => Playlist.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Playlist?> ambil(String id) async {
    final semua = await ambilSemua();
    for (final p in semua) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> _simpan(List<Playlist> semua) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kunci,
      json.encode(semua.map((p) => p.toJson()).toList()),
    );
    versiPlaylist.value++;
  }

  Future<Playlist> buat(String nama) async {
    final semua = await ambilSemua();
    final baru = Playlist(
      // Waktu dalam mikrodetik cukup unik untuk satu perangkat.
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      nama: nama,
      lagu: const [],
      dibuat: DateTime.now(),
    );
    await _simpan([baru, ...semua]);
    return baru;
  }

  Future<void> ubahNama(String id, String nama) async {
    final semua = await ambilSemua();
    await _simpan([
      for (final p in semua) p.id == id ? p.salin(nama: nama) : p,
    ]);
  }

  Future<void> hapus(String id) async {
    final semua = await ambilSemua();
    await _simpan(semua.where((p) => p.id != id).toList());
  }

  /// Menambah lagu ke playlist. Mengembalikan false bila lagu sudah ada.
  Future<bool> tambahLagu(String id, Song lagu) async {
    final semua = await ambilSemua();
    final i = semua.indexWhere((p) => p.id == id);
    if (i < 0) return false;

    final playlist = semua[i];
    if (playlist.lagu.any((l) => l.id == lagu.id)) return false;

    semua[i] = playlist.salin(lagu: [...playlist.lagu, lagu]);
    await _simpan(semua);
    return true;
  }

  Future<void> hapusLagu(String id, String idLagu) async {
    final semua = await ambilSemua();
    await _simpan([
      for (final p in semua)
        p.id == id
            ? p.salin(lagu: p.lagu.where((l) => l.id != idLagu).toList())
            : p,
    ]);
  }
}
