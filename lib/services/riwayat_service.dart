import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/song.dart';

/// Penanda versi riwayat agar baris "Terakhir Diputar" di beranda
/// diperbarui setiap kali ada lagu baru yang diputar.
final ValueNotifier<int> versiRiwayat = ValueNotifier<int>(0);

/// Mencatat lagu yang diputar pada penyimpanan lokal perangkat.
class RiwayatService {
  static const String _kunci = 'riwayat_putar';

  /// Hanya 20 lagu terakhir yang disimpan.
  static const int _maksimal = 20;

  Future<List<Song>> ambil() async {
    final prefs = await SharedPreferences.getInstance();
    final teks = prefs.getString(_kunci);
    if (teks == null || teks.isEmpty) return [];
    return (json.decode(teks) as List<dynamic>)
        .map((item) => Song.fromSimpan(item as Map<String, dynamic>))
        .toList();
  }

  /// Menaruh [lagu] di urutan paling depan. Bila lagu sudah pernah tercatat,
  /// catatan lamanya dihapus agar tidak muncul dua kali.
  Future<void> catat(Song lagu) async {
    final daftar = await ambil();
    daftar.removeWhere((item) => item.id == lagu.id);
    daftar.insert(0, lagu);
    if (daftar.length > _maksimal) daftar.removeRange(_maksimal, daftar.length);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kunci,
      json.encode(daftar.map((l) => l.toJson()).toList()),
    );
    versiRiwayat.value++;
  }
}
