import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/song.dart';
import '../services/lirik_service.dart';
import '../services/player_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/glass.dart';
import '../widgets/latar_sampul.dart';
import '../widgets/state_views.dart';

/// Halaman lirik layar penuh.
///
/// Bila lirik bertimestamp tersedia dan lagu diputar utuh, kata yang sedang
/// dinyanyikan disorot satu per satu dan baris aktif digulir otomatis ke
/// tengah layar. Latarnya mengikuti warna sampul lagu. Mengetuk sebuah baris
/// akan memindahkan lagu ke bagian tersebut.
class LirikPage extends StatefulWidget {
  const LirikPage({super.key});

  @override
  State<LirikPage> createState() => _LirikPageState();
}

class _LirikPageState extends State<LirikPage> {
  final LirikService _layanan = LirikService();

  String? _idLagu;
  Future<Lirik?>? _futureLirik;

  /// Pergeseran waktu lirik untuk lagu yang sedang diputar (milidetik).
  final ValueNotifier<int> _geser = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    final lagu = pemutarGlobal.lagu;
    if (lagu != null) {
      _idLagu = lagu.id;
      _futureLirik = _layanan.ambil(lagu);
      _muatGeser(lagu.id);
    }
    // Lirik ikut berganti ketika antrean pindah ke lagu berikutnya.
    pemutarGlobal.addListener(_periksaLagu);
  }

  @override
  void dispose() {
    pemutarGlobal.removeListener(_periksaLagu);
    _geser.dispose();
    super.dispose();
  }

  Future<void> _muatGeser(String idLagu) async {
    _geser.value = 0;
    final nilai = await LirikService.ambilGeser(idLagu);
    // Lagu sudah berganti selama proses membaca.
    if (mounted && _idLagu == idLagu) _geser.value = nilai;
  }

  /// Lembar penyetel waktu lirik. Berguna bila waktu lirik dari LRCLIB
  /// sedikit berbeda dengan versi lagu yang diputar, atau saat memakai
  /// earphone Bluetooth yang suaranya sedikit tertunda.
  void _aturGeser() {
    final idLagu = _idLagu;
    if (idLagu == null) return;

    void ubah(int nilai) {
      _geser.value = nilai.clamp(-3000, 3000);
      LirikService.simpanGeser(idLagu, _geser.value);
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.latarLembut,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: ValueListenableBuilder<int>(
            valueListenable: _geser,
            builder: (context, nilai, _) {
              final teks = Theme.of(context).textTheme;
              final detik =
                  (nilai.abs() / 1000).toStringAsFixed(2).replaceAll('.', ',');
              final keterangan = nilai == 0
                  ? 'Sesuai waktu asli'
                  : nilai > 0
                      ? 'Lirik $detik dtk lebih awal'
                      : 'Lirik $detik dtk lebih lambat';
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sesuaikan Waktu Lirik', style: teks.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    'Lirik terlambat? Tekan "Lebih awal". Lirik terlalu '
                    'cepat? Tekan "Lebih lambat". Setelan disimpan untuk '
                    'lagu ini.',
                    style: teks.bodySmall,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => ubah(nilai - 250),
                          icon: const Icon(Icons.remove_rounded),
                          label: const Text('Lebih lambat'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => ubah(nilai + 250),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Lebih awal'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(keterangan, style: teks.titleMedium),
                      ),
                      if (nilai != 0)
                        TextButton(
                          onPressed: () => ubah(0),
                          child: const Text('Atur ulang'),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _periksaLagu() {
    final lagu = pemutarGlobal.lagu;
    if (lagu == null || lagu.id == _idLagu) return;
    _idLagu = lagu.id;
    if (!mounted) return;
    _muatGeser(lagu.id);
    setState(() {
      _futureLirik = _layanan.ambil(lagu);
    });
  }

  void _muatUlang() {
    final lagu = pemutarGlobal.lagu;
    if (lagu == null) return;
    setState(() {
      _futureLirik = _layanan.ambil(lagu);
    });
  }

  @override
  Widget build(BuildContext context) {
    final lagu = pemutarGlobal.lagu;
    final teks = Theme.of(context).textTheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        actions: [
          if (lagu != null && lagu.dapatDiputarPenuh)
            IconButton(
              tooltip: 'Sesuaikan waktu lirik',
              icon: const Icon(Icons.tune_rounded),
              onPressed: _aturGeser,
            ),
        ],
        title: lagu == null
            ? null
            : Column(
                children: [
                  Text(lagu.trackName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: teks.titleMedium),
                  Text(lagu.artistName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: teks.bodySmall),
                ],
              ),
      ),
      body: Stack(
        children: [
          // Latar mengikuti warna sampul lagu yang sedang diputar.
          Positioned.fill(
            child: LatarSampul(url: lagu?.artworkBesar, kegelapan: 0.3),
          ),
          SafeArea(
            child: lagu == null || _futureLirik == null
                ? const EmptyView(pesan: 'Belum ada lagu yang diputar.')
                : FutureBuilder<Lirik?>(
                    future: _futureLirik,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const LoadingView(pesan: 'Mencari lirik...');
                      }
                      if (snapshot.hasError) {
                        return ErrorView(
                          pesan: snapshot.error.toString(),
                          onCobaLagi: _muatUlang,
                        );
                      }
                      final lirik = snapshot.data;
                      if (lirik == null) return _TidakAda(lagu: lagu);

                      // Pratinjau iTunes diambil dari tengah lagu, sehingga
                      // timestamp tidak cocok dan lirik ditampilkan biasa.
                      if (lirik.tersinkron && lagu.dapatDiputarPenuh) {
                        return _LirikTersinkron(
                          key: ValueKey(lagu.id),
                          baris: lirik.baris,
                          geser: _geser,
                        );
                      }
                      return _LirikBiasa(lirik: lirik, lagu: lagu);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Waktu mulai dan selesai setiap kata dalam satu baris.
typedef _WaktuKata = ({Duration mulai, Duration selesai, String teks});

/// Lirik bertimestamp yang mengikuti nyanyian, bergaya Beautiful Lyrics:
/// rata kiri, huruf tebal besar, kata yang sedang dinyanyikan terisi warna
/// secara bertahap, dan baris yang jauh dari baris aktif semakin redup.
class _LirikTersinkron extends StatefulWidget {
  final List<BarisLirik> baris;

  /// Pergeseran waktu lirik dari penyetel (milidetik).
  final ValueListenable<int> geser;

  const _LirikTersinkron({
    super.key,
    required this.baris,
    required this.geser,
  });

  @override
  State<_LirikTersinkron> createState() => _LirikTersinkronState();
}

class _LirikTersinkronState extends State<_LirikTersinkron> {
  /// Kunci tiap baris, dipakai untuk menggulir baris aktif ke tengah layar.
  late final List<GlobalKey> _kunci =
      List.generate(widget.baris.length, (_) => GlobalKey());

  /// Waktu tiap kata dihitung sekali saat halaman dibuka.
  late final List<List<_WaktuKata>> _kata =
      List.generate(widget.baris.length, _hitungKata);

  StreamSubscription<Duration>? _langganan;
  int _aktif = -1;

  /// Selama pengguna menggulir sendiri, gulir otomatis dijeda sebentar.
  DateTime _jedaSampai = DateTime.fromMillisecondsSinceEpoch(0);

  /// Baris disorot sedikit sebelum waktunya agar pergantian baris terasa
  /// tepat saat baris mulai dinyanyikan.
  static const int _majuBaris = 150;

  void _saatGeserBerubah() => _saatPosisi(pemutarGlobal.pemutar.position);

  static const TextStyle _gaya = TextStyle(
    fontSize: 30,
    height: 1.25,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
    color: Colors.white,
  );

  @override
  void initState() {
    super.initState();
    // Posisi dibaca setiap 50 ms. positionStream bawaan hanya diperbarui
    // sekitar setiap 200 ms, sehingga perpindahan baris bisa terlambat
    // hingga 0,2 detik dan terasa tidak konsisten.
    _langganan = pemutarGlobal.pemutar
        .createPositionStream(
          steps: 100000,
          minPeriod: const Duration(milliseconds: 50),
          maxPeriod: const Duration(milliseconds: 50),
        )
        .listen(_saatPosisi);
    widget.geser.addListener(_saatGeserBerubah);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _saatPosisi(pemutarGlobal.pemutar.position),
    );
  }

  @override
  void dispose() {
    _langganan?.cancel();
    widget.geser.removeListener(_saatGeserBerubah);
    super.dispose();
  }

  /// Menentukan kapan setiap kata pada baris ke-[i] dinyanyikan.
  ///
  /// 1. Bila lirik berformat Enhanced LRC, timestamp asli per kata dipakai.
  /// 2. Bila hanya ada timestamp per baris (paling umum di LRCLIB), waktu
  ///    tiap kata diperkirakan: penyanyi diasumsikan mengucapkan ±14 huruf
  ///    per detik, lalu durasi itu dibagi ke tiap kata sesuai panjangnya.
  List<_WaktuKata> _hitungKata(int i) {
    final b = widget.baris[i];
    final akhirBaris = i + 1 < widget.baris.length
        ? widget.baris[i + 1].waktu
        : b.waktu + const Duration(seconds: 5);

    final asli = b.kata;
    final asliCocok = asli.isNotEmpty &&
        asli.first.mulai >= b.waktu - const Duration(seconds: 1) &&
        asli.last.mulai < akhirBaris;
    if (asliCocok) {
      return [
        for (var j = 0; j < asli.length; j++)
          (
            mulai: asli[j].mulai,
            selesai: j + 1 < asli.length
                ? asli[j + 1].mulai
                : _lebihAwal(
                    akhirBaris, asli[j].mulai + const Duration(seconds: 1)),
            teks: asli[j].teks,
          ),
      ];
    }

    final kata =
        b.teks.split(RegExp(r'\s+')).where((k) => k.isNotEmpty).toList();
    if (kata.isEmpty) return const [];

    final jumlahHuruf = kata.fold<int>(0, (j, k) => j + k.length + 1);
    final tersedia = akhirBaris - b.waktu;
    var durasi = Duration(milliseconds: jumlahHuruf * 70);
    if (durasi > tersedia * 0.9) durasi = tersedia * 0.9;
    if (durasi < const Duration(milliseconds: 400)) {
      durasi = const Duration(milliseconds: 400);
    }

    final hasil = <_WaktuKata>[];
    var t = b.waktu;
    for (final k in kata) {
      final d = durasi * ((k.length + 1) / jumlahHuruf);
      hasil.add((mulai: t, selesai: t + d, teks: k));
      t += d;
    }
    return hasil;
  }

  static Duration _lebihAwal(Duration a, Duration b) => a < b ? a : b;

  /// Mencari baris terakhir yang waktunya sudah terlewati.
  void _saatPosisi(Duration posisi) {
    // Sedikit dimajukan agar sorotan muncul tepat saat baris mulai
    // dinyanyikan, bukan sesaat sesudahnya.
    final acuan =
        posisi + Duration(milliseconds: _majuBaris + widget.geser.value);
    var indeks = -1;
    for (var i = 0; i < widget.baris.length; i++) {
      if (widget.baris[i].waktu <= acuan) {
        indeks = i;
      } else {
        break;
      }
    }
    if (indeks == _aktif || !mounted) return;
    setState(() {
      _aktif = indeks;
    });
    _gulirKeAktif();
  }

  void _gulirKeAktif({bool paksa = false}) {
    if (_aktif < 0) return;
    if (!paksa && DateTime.now().isBefore(_jedaSampai)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final konteks = _kunci[_aktif].currentContext;
      if (konteks == null) return;
      Scrollable.ensureVisible(
        konteks,
        alignment: 0.35,
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final tinggi = MediaQuery.of(context).size.height;
    final dijeda = DateTime.now().isBefore(_jedaSampai);

    return Stack(
      children: [
        NotificationListener<UserScrollNotification>(
          onNotification: (_) {
            setState(() {
              _jedaSampai = DateTime.now().add(const Duration(seconds: 3));
            });
            return false;
          },
          child: SingleChildScrollView(
            // Ruang kosong atas-bawah agar baris pertama dan terakhir juga
            // dapat berada di tengah layar.
            padding: EdgeInsets.fromLTRB(28, tinggi * 0.3, 28, tinggi * 0.5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(widget.baris.length, _baris),
            ),
          ),
        ),

        // Tombol kembali ke baris aktif setelah pengguna menggulir sendiri.
        if (dijeda)
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: FilledButton.icon(
                onPressed: () {
                  setState(() {
                    _jedaSampai = DateTime.fromMillisecondsSinceEpoch(0);
                  });
                  _gulirKeAktif(paksa: true);
                },
                icon: const Icon(Icons.my_location_rounded, size: 18),
                label: const Text('Ikuti lagu'),
              ),
            ),
          ),
      ],
    );
  }

  Widget _baris(int i) {
    final baris = widget.baris[i];
    final aktif = i == _aktif;
    final jarak = (i - _aktif).abs();

    // Efek kedalaman memakai tingkat terang, bukan blur: semakin jauh dari
    // baris aktif semakin redup. Mengubah warna teks jauh lebih ringan
    // daripada mengaburkan setiap baris di setiap frame.
    final terang = switch (jarak) {
      1 => 0.5,
      2 => 0.38,
      3 => 0.3,
      _ => 0.22,
    };

    final Widget isi = aktif
        ? _BarisAktif(kata: _kata[i], gaya: _gaya, geser: widget.geser)
        : AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: _gaya.copyWith(color: Colors.white.withOpacity(terang)),
            child: Text(baris.teks),
          );

    return GestureDetector(
      key: _kunci[i],
      behavior: HitTestBehavior.opaque,
      onTap: () {
        pemutarGlobal.pemutar.seek(baris.waktu);
        setState(() {
          _jedaSampai = DateTime.fromMillisecondsSinceEpoch(0);
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: isi,
      ),
    );
  }
}

/// Baris yang sedang dinyanyikan. Setiap kata terisi putih dari kiri ke
/// kanan sesuai posisi lagu, lalu sedikit terangkat, seperti karaoke.
class _BarisAktif extends StatefulWidget {
  final List<_WaktuKata> kata;
  final TextStyle gaya;
  final ValueListenable<int> geser;

  const _BarisAktif({
    required this.kata,
    required this.gaya,
    required this.geser,
  });

  @override
  State<_BarisAktif> createState() => _BarisAktifState();
}

class _BarisAktifState extends State<_BarisAktif> {
  /// Posisi lagu diperbarui ±60 kali per detik agar isian kata mulus.
  late final Stream<Duration> _posisi =
      pemutarGlobal.pemutar.createPositionStream(
    steps: 100000,
    minPeriod: const Duration(milliseconds: 16),
    maxPeriod: const Duration(milliseconds: 16),
  );

  @override
  Widget build(BuildContext context) {
    final redup = widget.gaya.copyWith(color: const Color(0x73FFFFFF));

    return StreamBuilder<Duration>(
      stream: _posisi,
      initialData: pemutarGlobal.pemutar.position,
      builder: (context, snapshot) {
        final posisi = (snapshot.data ?? Duration.zero) +
            Duration(milliseconds: widget.geser.value);
        return Wrap(
          children: [
            for (final k in widget.kata)
              _kata(k, _progres(posisi, k.mulai, k.selesai), redup),
          ],
        );
      },
    );
  }

  /// Kata yang sudah atau belum dinyanyikan cukup berupa teks biasa. Hanya
  /// kata yang sedang dinyanyikan yang memakai gradasi (ShaderMask), karena
  /// ShaderMask cukup berat bila dipakai pada semua kata sekaligus.
  Widget _kata(_WaktuKata k, double progres, TextStyle redup) {
    final teks = '${k.teks} ';
    if (progres <= 0) return Text(teks, style: redup);
    if (progres >= 1) {
      return Transform.translate(
        offset: const Offset(0, -2),
        child: Text(teks, style: widget.gaya),
      );
    }
    return _Kata(teks: teks, gaya: widget.gaya, progres: progres);
  }

  static double _progres(Duration posisi, Duration mulai, Duration selesai) {
    final total = (selesai - mulai).inMilliseconds;
    if (total <= 0) return posisi >= mulai ? 1 : 0;
    return ((posisi - mulai).inMilliseconds / total).clamp(0.0, 1.0);
  }
}

class _Kata extends StatelessWidget {
  final String teks;
  final TextStyle gaya;
  final double progres;

  const _Kata({required this.teks, required this.gaya, required this.progres});

  @override
  Widget build(BuildContext context) {
    // Kata terangkat 2 px secara bertahap ketika mulai dinyanyikan.
    final angkat = -2.0 * (progres * 3).clamp(0.0, 1.0);

    return Transform.translate(
      offset: Offset(0, angkat),
      child: ShaderMask(
        blendMode: BlendMode.srcIn,
        // Gradasi tajam: bagian kiri (sudah dinyanyikan) putih penuh,
        // bagian kanan (belum) putih redup.
        shaderCallback: (kotak) => LinearGradient(
          colors: const [
            Colors.white,
            Colors.white,
            Color(0x73FFFFFF),
            Color(0x73FFFFFF),
          ],
          stops: [0, progres, progres, 1],
        ).createShader(kotak),
        child: Text(teks, style: gaya),
      ),
    );
  }
}

/// Lirik tanpa timestamp: ditampilkan sebagai teks biasa.
class _LirikBiasa extends StatelessWidget {
  final Lirik lirik;
  final Song lagu;

  const _LirikBiasa({required this.lirik, required this.lagu});

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;
    final keterangan = !lagu.dapatDiputarPenuh && lirik.tersinkron
        ? 'Lagu ini hanya pratinjau 30 detik, jadi lirik ditampilkan tanpa '
            'sorotan.'
        : 'Lirik ini belum memiliki penanda waktu, jadi ditampilkan tanpa '
            'sorotan.';

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 70, 24, 40),
      children: [
        GlassPanel(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 18, color: Colors.white60),
              const SizedBox(width: 10),
              Expanded(child: Text(keterangan, style: teks.bodySmall)),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Text(
          lirik.teksBiasa,
          style: const TextStyle(
            fontSize: 20,
            height: 1.6,
            fontWeight: FontWeight.w700,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 24),
        Text('Sumber: ${lirik.sumber}', style: teks.bodySmall),
      ],
    );
  }
}

class _TidakAda extends StatelessWidget {
  final Song lagu;

  const _TidakAda({required this.lagu});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lyrics_outlined, size: 48, color: Colors.white38),
            const SizedBox(height: 14),
            Text(
              'Lirik belum tersedia',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              lagu.dapatDiputarPenuh
                  ? 'Lagu indie jarang terdaftar di basis data lirik. '
                      'Coba lagu lain, ya.'
                  : 'Penyedia lirik belum memiliki lirik untuk lagu ini.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.kacaTepi),
              ),
              child: Text('Sumber: LRCLIB & lyrics.ovh',
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
        ),
      ),
    );
  }
}
