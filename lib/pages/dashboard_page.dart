import 'package:flutter/material.dart';

import '../models/song.dart';
import '../services/audius_api_service.dart';
import '../services/music_api_service.dart';
import '../services/rekomendasi_service.dart';
import '../services/riwayat_service.dart';
import '../theme/app_theme.dart';
import '../widgets/album_card.dart';
import '../widgets/glass.dart';
import '../widgets/state_views.dart';
import 'now_playing_page.dart';

/// Halaman dashboard: kumpulan baris rekomendasi mendatar yang seluruh
/// datanya diambil dari API.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final MusicApiService _api = MusicApiService();
  final AudiusApiService _apiIndie = AudiusApiService();

  /// Pemetaan judul baris pada tampilan ke kata kunci yang dikirim ke API.
  static const Map<String, String> _kategori = {
    'Sedang Populer': 'lagu indonesia',
    'Pop Indonesia': 'pop indonesia',
    'Rock & Alternatif': 'rock indonesia',
    'Suasana Santai': 'akustik indonesia',
  };

  late Future<Map<String, List<Song>>> _futureBeranda;

  final RekomendasiService _rekomendasi = RekomendasiService();

  /// "Pilihan Hari Ini": personal dari riwayat, atau lagu populer bila
  /// riwayat masih kosong. Dihitung setelah data beranda tersedia.
  late Future<Pilihan?> _futurePilihan;

  /// Lagu indie dimuat terpisah dari iTunes, sehingga bila Audius sedang
  /// bermasalah, bagian lain dashboard tetap tampil.
  late Future<List<Song>> _futureIndie;

  /// Rekomendasi genre yang disesuaikan dengan jam saat aplikasi dibuka.
  late ({String judul, String genre}) _suasana;
  late Future<List<Song>> _futureSuasana;

  @override
  void initState() {
    super.initState();
    _futureBeranda = _api.ambilBeranda(_kategori.values.toList());
    _futurePilihan = _ambilPilihan();
    _futureIndie = _ambilIndie();
    _suasana = _suasanaSekarang();
    _futureSuasana = _ambilSuasana();
  }

  Future<List<Song>> _ambilIndie() =>
      _apiIndie.laguPopuler(periode: 'allTime', jumlah: 15);

  Future<List<Song>> _ambilSuasana() => _apiIndie.laguPopuler(
        genre: _suasana.genre,
        periode: 'allTime',
        jumlah: 15,
      );

  Future<Pilihan?> _ambilPilihan() async {
    try {
      final data = await _futureBeranda;
      final populer = data.values
          .firstWhere((daftar) => daftar.isNotEmpty, orElse: () => const []);
      return await _rekomendasi.pilihanHariIni(populer);
    } catch (_) {
      // Beranda gagal dimuat: pesan kesalahan sudah ditampilkan oleh
      // FutureBuilder utama, jadi kartu ini cukup tidak ditampilkan.
      return null;
    }
  }

  /// Memetakan jam di HP ke genre yang suasananya cocok.
  static ({String judul, String genre}) _suasanaSekarang() {
    final jam = DateTime.now().hour;
    if (jam >= 4 && jam < 11) return (judul: 'Awali Pagimu', genre: 'Acoustic');
    if (jam >= 11 && jam < 15) return (judul: 'Semangat Siang', genre: 'Pop');
    if (jam >= 15 && jam < 19) return (judul: 'Santai Sore', genre: 'R&B/Soul');
    if (jam >= 19 && jam < 23) return (judul: 'Teman Malam', genre: 'Jazz');
    return (judul: 'Teman Begadang', genre: 'Lo-Fi');
  }

  void _muatUlang() {
    setState(() {
      _futureBeranda = _api.ambilBeranda(_kategori.values.toList());
      _futurePilihan = _ambilPilihan();
      _futureIndie = _ambilIndie();
      _suasana = _suasanaSekarang();
      _futureSuasana = _ambilSuasana();
    });
  }

  /// Menyaring agar satu baris tidak menampilkan beberapa lagu dari album
  /// yang sama, sehingga sampul pada daftar mendatar tampak beragam.
  List<Song> _ragam(List<Song> daftar) {
    final album = <String>{};
    final hasil = <Song>[];
    for (final lagu in daftar) {
      if (album.add(lagu.collectionName)) hasil.add(lagu);
    }
    return hasil;
  }

  void _bukaDetail(Song lagu, List<Song> antrean) {
    NowPlayingPage.putar(context, lagu, antrean: antrean);
  }

  String get _sapaan {
    final jam = DateTime.now().hour;
    if (jam < 11) return 'Selamat pagi';
    if (jam < 15) return 'Selamat siang';
    if (jam < 19) return 'Selamat sore';
    return 'Selamat malam';
  }

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;

    return SafeArea(
      bottom: false,
      child: FutureBuilder<Map<String, List<Song>>>(
        future: _futureBeranda,
        builder: (context, snapshot) {
          // Kondisi 1: menunggu respons dari server.
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }

          // Kondisi 2: permintaan gagal.
          if (snapshot.hasError) {
            return ErrorView(
              pesan: snapshot.error.toString(),
              onCobaLagi: _muatUlang,
            );
          }

          // Kondisi 3: data berhasil diperoleh.
          final data = snapshot.data ?? {};

          return RefreshIndicator(
            onRefresh: () async => _muatUlang(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 120),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_sapaan, style: teks.bodyMedium),
                      const SizedBox(height: 2),
                      Text('Dengarkan Sekarang', style: teks.headlineLarge),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: FutureBuilder<Pilihan?>(
                    future: _futurePilihan,
                    builder: (context, snapPilihan) {
                      if (snapPilihan.connectionState ==
                          ConnectionState.waiting) {
                        return const _KartuSorotanMemuat();
                      }
                      final pilihan = snapPilihan.data;
                      if (pilihan == null) return const SizedBox.shrink();
                      return _KartuSorotan(
                        lagu: pilihan.lagu,
                        alasan: pilihan.alasan,
                        onTap: () => _bukaDetail(pilihan.lagu, pilihan.antrean),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 26),
                _BarisRiwayat(onPilih: _bukaDetail),
                _BarisIndie(
                  judul: _suasana.judul,
                  label: _suasana.genre.toUpperCase(),
                  future: _futureSuasana,
                  onPilih: _bukaDetail,
                ),
                _BarisIndie(
                  judul: 'Indie Pilihan',
                  label: 'LAGU PENUH',
                  future: _futureIndie,
                  onPilih: _bukaDetail,
                ),
                ..._kategori.entries.map((entri) {
                  final daftar = data[entri.value] ?? const <Song>[];
                  if (daftar.isEmpty) return const SizedBox.shrink();
                  final isi = _ragam(daftar).take(12).toList();
                  return _BarisKategori(
                    judul: entri.key,
                    daftar: isi,
                    onPilih: (lagu) => _bukaDetail(lagu, isi),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Kartu besar di bagian atas dashboard untuk satu lagu pilihan.
class _KartuSorotan extends StatelessWidget {
  final Song lagu;
  final VoidCallback onTap;

  /// Alasan lagu ini dipilih, ditampilkan di bawah nama artis.
  final String alasan;

  const _KartuSorotan({
    required this.lagu,
    required this.alasan,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;

    return GlassPanel(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 92,
              height: 92,
              child: lagu.artworkBesar == null
                  ? const ColoredBox(color: Color(0xFF1C1C22))
                  : Image.network(lagu.artworkBesar!, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PILIHAN HARI INI',
                    style: teks.bodySmall?.copyWith(letterSpacing: 1.4)),
                const SizedBox(height: 6),
                Text(
                  lagu.trackName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: teks.titleLarge,
                ),
                Text(
                  lagu.artistName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: teks.bodyMedium,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded,
                        size: 13, color: AppTheme.aksen),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        alasan,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: teks.bodySmall?.copyWith(color: AppTheme.aksen),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.play_circle_fill_rounded, size: 40),
        ],
      ),
    );
  }
}

/// Penanda tempat selama "Pilihan Hari Ini" sedang dihitung, dengan tinggi
/// yang sama agar tata letak beranda tidak melompat.
class _KartuSorotanMemuat extends StatelessWidget {
  const _KartuSorotanMemuat();

  @override
  Widget build(BuildContext context) {
    return const GlassPanel(
      padding: EdgeInsets.all(14),
      child: SizedBox(
        height: 92,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ),
      ),
    );
  }
}

/// Satu baris kategori berisi daftar kartu album yang dapat digeser mendatar.
class _BarisKategori extends StatelessWidget {
  final String judul;
  final List<Song> daftar;
  final ValueChanged<Song> onPilih;

  const _BarisKategori({
    required this.judul,
    required this.daftar,
    required this.onPilih,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text(judul, style: Theme.of(context).textTheme.titleLarge),
        ),
        SizedBox(
          height: 188,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: daftar.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) => AlbumCard(
              lagu: daftar[index],
              onTap: () => onPilih(daftar[index]),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

/// Baris lagu Audius (dapat diputar penuh), dipakai untuk "Indie Pilihan"
/// dan rekomendasi sesuai waktu.
class _BarisIndie extends StatelessWidget {
  final String judul;
  final String label;
  final Future<List<Song>> future;
  final void Function(Song lagu, List<Song> antrean) onPilih;

  const _BarisIndie({
    required this.judul,
    required this.label,
    required this.future,
    required this.onPilih,
  });

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;

    return FutureBuilder<List<Song>>(
      future: future,
      builder: (context, snapshot) {
        final daftar = snapshot.data ?? const <Song>[];
        final memuat = snapshot.connectionState == ConnectionState.waiting;

        // Gagal atau kosong: baris disembunyikan tanpa mengganggu dashboard.
        if (!memuat && daftar.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  Flexible(
                    child: Text(judul,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: teks.titleLarge),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.aksen.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppTheme.aksen,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 188,
              child: memuat
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: daftar.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, i) => AlbumCard(
                        lagu: daftar[i],
                        onTap: () => onPilih(daftar[i], daftar),
                      ),
                    ),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}

/// Baris "Terakhir Diputar". Disembunyikan bila riwayat masih kosong dan
/// diperbarui otomatis setiap ada lagu baru yang diputar.
class _BarisRiwayat extends StatefulWidget {
  final void Function(Song lagu, List<Song> antrean) onPilih;

  const _BarisRiwayat({required this.onPilih});

  @override
  State<_BarisRiwayat> createState() => _BarisRiwayatState();
}

class _BarisRiwayatState extends State<_BarisRiwayat> {
  final RiwayatService _layanan = RiwayatService();
  List<Song> _daftar = const [];

  @override
  void initState() {
    super.initState();
    _muat();
    versiRiwayat.addListener(_muat);
  }

  @override
  void dispose() {
    versiRiwayat.removeListener(_muat);
    super.dispose();
  }

  Future<void> _muat() async {
    final hasil = await _layanan.ambil();
    if (!mounted) return;
    setState(() {
      _daftar = hasil;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_daftar.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text('Terakhir Diputar',
              style: Theme.of(context).textTheme.titleLarge),
        ),
        SizedBox(
          height: 188,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _daftar.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) => AlbumCard(
              lagu: _daftar[i],
              onTap: () => widget.onPilih(_daftar[i], _daftar),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
