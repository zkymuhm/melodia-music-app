import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Apakah latar aurora bergerak. Dipantau langsung oleh [AuroraBackground]
/// sehingga perubahan di halaman Akun langsung terlihat di seluruh aplikasi.
final ValueNotifier<bool> latarBergerak = ValueNotifier<bool>(true);

/// Benar selama pengguna sedang menggulir daftar. Latar aurora berhenti
/// bergerak selama itu, agar tenaga HP dipakai sepenuhnya untuk guliran.
/// Nilai ini tidak disimpan; diatur oleh RootPage.
final ValueNotifier<bool> sedangMenggulir = ValueNotifier<bool>(false);

/// Pengaturan tampilan yang disimpan di perangkat.
class PengaturanService {
  static const String _kunciLatar = 'latar_bergerak';

  /// Dipanggil sekali di main() sebelum aplikasi tampil.
  static Future<void> muat() async {
    final prefs = await SharedPreferences.getInstance();
    latarBergerak.value = prefs.getBool(_kunciLatar) ?? true;
  }

  static Future<void> aturLatarBergerak(bool nilai) async {
    latarBergerak.value = nilai;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kunciLatar, nilai);
  }
}
