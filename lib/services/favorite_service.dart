import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/song.dart';

/// Menyimpan daftar lagu favorit pada penyimpanan lokal perangkat,
/// sehingga pilihan pengguna tetap tersimpan setelah aplikasi ditutup.
/// Penanda versi data favorit.
///
/// Nilainya bertambah setiap kali daftar favorit berubah, sehingga halaman
/// lain yang sedang tidak terlihat dapat memuat ulang datanya ketika kembali
/// ditampilkan.
final ValueNotifier<int> versiFavorit = ValueNotifier<int>(0);

class FavoriteService {
  static const String _kunci = 'lagu_favorit';

  Future<List<Song>> ambilSemua() async {
    final prefs = await SharedPreferences.getInstance();
    final daftar = prefs.getStringList(_kunci) ?? <String>[];
    return daftar
        .map((baris) => Song.fromSimpan(
              json.decode(baris) as Map<String, dynamic>,
            ))
        .toList();
  }

  Future<bool> apakahFavorit(String id) async {
    final favorit = await ambilSemua();
    return favorit.any((lagu) => lagu.id == id);
  }

  /// Menambah lagu bila belum ada, atau menghapusnya bila sudah tersimpan.
  /// Mengembalikan status favorit setelah perubahan.
  Future<bool> ubahStatus(Song lagu) async {
    final prefs = await SharedPreferences.getInstance();
    final favorit = await ambilSemua();
    final sudahAda = favorit.any((item) => item.id == lagu.id);

    if (sudahAda) {
      favorit.removeWhere((item) => item.id == lagu.id);
    } else {
      favorit.insert(0, lagu);
    }

    await prefs.setStringList(
      _kunci,
      favorit.map((item) => json.encode(item.toJson())).toList(),
    );
    versiFavorit.value++;
    return !sudahAda;
  }
}
