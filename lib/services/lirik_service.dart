import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/song.dart';
import 'api_exception.dart';
import 'music_api_service.dart';

/// Satu kata (atau potongan kata) beserta waktu mulai diucapkan.
class KataLirik {
  final Duration mulai;
  final String teks;

  const KataLirik(this.mulai, this.teks);
}

/// Satu baris lirik beserta waktu kemunculannya di dalam lagu.
class BarisLirik {
  final Duration waktu;
  final String teks;

  /// Timestamp per kata dari format Enhanced LRC, misalnya
  /// `[00:12.00] <00:12.00> Aku <00:12.40> di <00:12.70> sini`.
  /// Kosong bila sumber hanya menyediakan timestamp per baris; dalam hal itu
  /// waktu tiap kata diperkirakan oleh halaman lirik.
  final List<KataLirik> kata;

  const BarisLirik(this.waktu, this.teks, {this.kata = const []});
}

/// Hasil pengambilan lirik.
///
/// [baris] berisi lirik bertimestamp (format LRC) bila tersedia, sehingga
/// lirik dapat disorot mengikuti nyanyian. [teksBiasa] selalu terisi dan
/// dipakai bila lirik tidak tersinkron.
class Lirik {
  final List<BarisLirik> baris;
  final String teksBiasa;
  final String sumber;

  const Lirik({
    required this.baris,
    required this.teksBiasa,
    required this.sumber,
  });

  bool get tersinkron => baris.isNotEmpty;
}

/// Mengambil lirik dari LRCLIB (lrclib.net), basis data lirik terbuka yang
/// menyediakan lirik bertimestamp. Bila tidak ditemukan, aplikasi mencoba
/// lyrics.ovh sebagai cadangan (hanya teks biasa).
class LirikService {
  static const String _host = 'lrclib.net';
  static const Duration _batasWaktu = Duration(seconds: 7);

  /// LRCLIB meminta setiap aplikasi menyebutkan identitasnya.
  static const Map<String, String> _header = {
    'User-Agent': 'Melodia/1.0 (tugas UAS Mobile Programming)',
  };

  /// Lirik yang sudah pernah diambil disimpan sementara di memori agar
  /// tidak diunduh ulang ketika halaman dibuka kembali.
  static final Map<String, Lirik?> _simpanan = {};

  final MusicApiService _cadangan = MusicApiService();

  // ------------------------------------------------- penyetel waktu lirik

  static const String _kunciGeser = 'geser_lirik';

  /// Pergeseran waktu lirik (milidetik) untuk lagu [idLagu].
  ///
  /// Nilai positif membuat lirik muncul lebih awal, nilai negatif membuat
  /// lirik muncul lebih lambat. Disimpan per lagu karena selisih waktu
  /// lirik di LRCLIB berbeda-beda untuk setiap lagu.
  static Future<int> ambilGeser(String idLagu) async {
    final prefs = await SharedPreferences.getInstance();
    final teks = prefs.getString(_kunciGeser);
    if (teks == null) return 0;
    final data = json.decode(teks) as Map<String, dynamic>;
    return (data[idLagu] as num?)?.toInt() ?? 0;
  }

  static Future<void> simpanGeser(String idLagu, int milidetik) async {
    final prefs = await SharedPreferences.getInstance();
    final teks = prefs.getString(_kunciGeser);
    final data = teks == null
        ? <String, dynamic>{}
        : json.decode(teks) as Map<String, dynamic>;
    if (milidetik == 0) {
      data.remove(idLagu);
    } else {
      data[idLagu] = milidetik;
    }
    await prefs.setString(_kunciGeser, json.encode(data));
  }

  /// Pengambilan yang sedang berjalan. Bila halaman Lirik dibuka saat lirik
  /// masih diambil di latar, halaman cukup menunggu proses yang sama.
  static final Map<String, Future<Lirik?>> _proses = {};

  /// Batas waktu tiap sumber. Lagu yang tidak punya lirik tidak perlu
  /// ditunggu lama: lebih baik segera menampilkan "Lirik belum tersedia".
  static const Duration _batasLrclib = Duration(seconds: 8);
  static const Duration _batasCadangan = Duration(seconds: 6);

  Future<Lirik?> ambil(Song lagu) {
    if (_simpanan.containsKey(lagu.id)) {
      return Future.value(_simpanan[lagu.id]);
    }
    // Penting: badan whenComplete ditulis sebagai blok { }. Bentuk panah
    // `() => _proses.remove(...)` akan MENGEMBALIKAN Future yang dihapus,
    // yaitu Future ini sendiri, lalu whenComplete menunggunya selesai.
    // Future menunggu dirinya sendiri sehingga tidak pernah selesai.
    return _proses[lagu.id] ??= _ambilBaru(lagu).whenComplete(() {
      _proses.remove(lagu.id);
    });
  }

  /// Mengambil lirik di latar ketika lagu mulai diputar, agar halaman Lirik
  /// langsung terisi saat dibuka. Kegagalan diabaikan.
  void siapkan(Song lagu) {
    ambil(lagu).catchError((Object _) => null);
  }

  Future<Lirik?> _ambilBaru(Song lagu) async {
    // LRCLIB dan lyrics.ovh dijalankan BERSAMAAN, bukan bergantian.
    // Dulu lyrics.ovh baru dicoba setelah LRCLIB selesai, sehingga lagu
    // tanpa lirik harus menunggu kedua server (bisa lebih dari 45 detik).
    final dariLrclib = _aman(_dariLrclib(lagu), _batasLrclib);
    final dariCadangan = _aman(
      _cadangan.ambilLirik(lagu.artistName, lagu.trackName),
      _batasCadangan,
    );

    final lrclib = await dariLrclib;
    if (lrclib.nilai != null) {
      _simpanan[lagu.id] = lrclib.nilai;
      return lrclib.nilai;
    }

    final cadangan = await dariCadangan;
    final teks = cadangan.nilai;
    if (teks != null) {
      final hasil =
          Lirik(baris: const [], teksBiasa: teks, sumber: 'lyrics.ovh');
      _simpanan[lagu.id] = hasil;
      return hasil;
    }

    // LRCLIB tidak dapat dihubungi dan lyrics.ovh juga gagal: kemungkinan
    // besar tidak ada internet.
    // (lyrics.ovh membungkus galat jaringan menjadi ApiException.)
    if (lrclib.galat is SocketException && cadangan.galat != null) {
      throw const ApiException('Tidak ada koneksi internet.');
    }

    // "Tidak ada lirik" hanya diingat bila kedua server benar-benar
    // menjawab. Bila salah satu kehabisan waktu, lain kali dicoba lagi.
    if (!lrclib.habisWaktu && !cadangan.habisWaktu) {
      _simpanan[lagu.id] = null;
    }
    return null;
  }

  /// Menjalankan [proses] dengan batas waktu tanpa melempar kesalahan.
  static Future<({T? nilai, Object? galat, bool habisWaktu})> _aman<T>(
    Future<T?> proses,
    Duration batas,
  ) async {
    try {
      return (
        nilai: await proses.timeout(batas),
        galat: null,
        habisWaktu: false
      );
    } on TimeoutException catch (e) {
      return (nilai: null, galat: e, habisWaktu: true);
    } catch (e) {
      return (nilai: null, galat: e, habisWaktu: false);
    }
  }

  Future<Lirik?> _dariLrclib(Song lagu) async {
    final judul = _bersihkan(lagu.trackName);
    final artis = lagu.artistName;

    // Pencocokan tepat (1) dan pencarian (2) dikirim bersamaan; hasil
    // pencarian hanya dipakai bila pencocokan tepat tidak menemukan apa-apa.
    final permintaanCari = http
        .get(
          Uri.https(_host, '/api/search', {
            'track_name': judul,
            'artist_name': artis,
          }),
          headers: _header,
        )
        .timeout(_batasWaktu);
    // Mencegah galat "tidak tertangani" bila hasil pencarian tidak dipakai.
    permintaanCari.ignore();

    // 1. Pencocokan tepat berdasarkan judul, artis, dan durasi (±2 detik).
    final tepat = await http
        .get(
          Uri.https(_host, '/api/get', {
            'track_name': judul,
            'artist_name': artis,
            if (lagu.durasiDetik > 0) 'duration': '${lagu.durasiDetik}',
          }),
          headers: _header,
        )
        .timeout(_batasWaktu);

    if (tepat.statusCode == 200) {
      final data = json.decode(utf8.decode(tepat.bodyBytes));
      final lirik = _jadikanLirik(data as Map<String, dynamic>);
      if (lirik != null) return lirik;
    }

    // 2. Bila tidak cocok, pakai hasil pencarian lalu pilih yang paling sesuai.
    final cari = await permintaanCari;
    if (cari.statusCode != 200) return null;

    final kandidat = (json.decode(utf8.decode(cari.bodyBytes)) as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .where((item) => item['instrumental'] != true)
        .toList();
    if (kandidat.isEmpty) return null;

    // Urutan prioritas: durasi paling mendekati, lalu yang punya timestamp.
    int skor(Map<String, dynamic> item) {
      final durasi = (item['duration'] as num?)?.round() ?? 0;
      final selisih =
          lagu.durasiDetik <= 0 ? 0 : (durasi - lagu.durasiDetik).abs();
      final adaSinkron = (item['syncedLyrics'] as String?)?.isNotEmpty ?? false;
      return selisih * 10 + (adaSinkron ? 0 : 5);
    }

    kandidat.sort((a, b) => skor(a).compareTo(skor(b)));
    final terbaik = kandidat.first;

    // Durasi yang terlalu jauh berbeda menandakan versi lagu lain (remix,
    // live), sehingga timestamp-nya tidak dipakai.
    final durasi = (terbaik['duration'] as num?)?.round() ?? 0;
    final versiBeda =
        lagu.durasiDetik > 0 && (durasi - lagu.durasiDetik).abs() > 3;
    return _jadikanLirik(terbaik, tanpaTimestamp: versiBeda);
  }

  Lirik? _jadikanLirik(
    Map<String, dynamic> data, {
    bool tanpaTimestamp = false,
  }) {
    if (data['instrumental'] == true) {
      return const Lirik(
        baris: [],
        teksBiasa: '♪ Lagu instrumental',
        sumber: 'LRCLIB',
      );
    }

    final baris = tanpaTimestamp
        ? <BarisLirik>[]
        : bacaLrc(data['syncedLyrics'] as String? ?? '');
    final biasa = (data['plainLyrics'] as String?)?.trim() ?? '';
    final teks = biasa.isNotEmpty ? biasa : baris.map((b) => b.teks).join('\n');

    if (teks.trim().isEmpty) return null;
    return Lirik(baris: baris, teksBiasa: teks, sumber: 'LRCLIB');
  }

  /// Membaca teks berformat LRC, misalnya:
  ///
  /// ```
  /// [00:12.30] Baris pertama
  /// [00:15.80] Baris kedua
  /// ```
  ///
  /// Satu baris boleh memiliki beberapa timestamp (bagian reff yang diulang).
  static List<BarisLirik> bacaLrc(String lrc) {
    final pola = RegExp(r'\[(\d+):(\d+(?:\.\d+)?)\]');
    final polaKata = RegExp(r'<(\d+):(\d+(?:\.\d+)?)>([^<]*)');
    final hasil = <BarisLirik>[];

    Duration waktu(String menit, String detik) => Duration(
        milliseconds:
            ((int.parse(menit) * 60 + double.parse(detik)) * 1000).round());

    for (final baris in const LineSplitter().convert(lrc)) {
      final cocok = pola.allMatches(baris).toList();
      if (cocok.isEmpty) continue;

      var teks = baris.substring(cocok.last.end).trim();

      // Enhanced LRC: ambil timestamp tiap kata, lalu susun ulang teksnya.
      final kata = <KataLirik>[];
      for (final k in polaKata.allMatches(teks)) {
        final isi = k.group(3)!.trim();
        if (isi.isNotEmpty) {
          kata.add(KataLirik(waktu(k.group(1)!, k.group(2)!), isi));
        }
      }
      if (kata.isNotEmpty) teks = kata.map((k) => k.teks).join(' ');

      for (final m in cocok) {
        hasil.add(BarisLirik(
          waktu(m.group(1)!, m.group(2)!),
          // Baris kosong menandakan jeda musik.
          teks.isEmpty ? '♪' : teks,
          kata: kata,
        ));
      }
    }

    hasil.sort((a, b) => a.waktu.compareTo(b.waktu));
    return hasil;
  }

  /// Membuang keterangan seperti "(feat. ...)" atau "- Remastered".
  String _bersihkan(String teks) {
    return teks
        .replaceAll(RegExp(r'\(.*?\)'), '')
        .replaceAll(RegExp(r'\[.*?\]'), '')
        .split(' - ')
        .first
        .trim();
  }
}
